import 'dart:io';

import 'package:mp_core/mp_core.dart';
import 'package:mp_runner/mp_runner.dart';
import 'package:test/test.dart';

/// The whole product, headless: a mission is discussed into a spec, compiled
/// into a brief, launched, interrupted by a usage limit, resumed on the same
/// session, and finished — then the state it reported is parsed back and turned
/// into a capsule that could carry it into a brand-new conversation.
///
/// Everything except the UI. If this passes, the mechanism works.
void main() {
  late Directory tmp;
  late String fakeClaude;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('mp_e2e_');
    fakeClaude = '${tmp.path}/claude';
    final ProcessResult r = Process.runSync(
      Platform.resolvedExecutable,
      <String>['compile', 'exe', 'tool/fake_claude.dart', '-o', fakeClaude],
    );
    if (r.exitCode != 0) throw StateError('build failed: ${r.stderr}');
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('discussion to finished run, through a session limit', () async {
    // --- 1. The discussion produces a spec ------------------------------
    const SpecPatchParser patcher = SpecPatchParser();
    const String round = '''
Settled.

```mpspec
mission=Build a rooftop restaurant and bar above a dense city at night.
story=Guests move from a compressed arrival toward panoramic windows.
scale=1200 square metres on one floor.
audience=Judged as premium architectural visualisation.
region+=Cocktail bar | Twenty seats with real service depth
region+=Open kitchen | Visible hot line and plating pass
family+=Dining furniture | tables, chairs, banquettes | min=130
avoid+=A generic hotel lounge
palette+=book-matched dark stone
detail=Must survive close inspection of joins and hardware.
evidence+=01 | 01_arrival.png | Arrival | The compressed threshold
evidence+=02 | 02_hero.png | Hero | Bar, dining and city together | hero
compute=GPU render device, no display server
tool=Blender via the command line
budget=100 million tokens
step+=01 | Graybox | Block out the whole environment at real scale
rubric+=Circulation | 50 | Arrival, covers and service routes | min=42
rubric+=Craft | 50 | Materials and construction | min=42
total=100
exit=90
critic+=Circulation critic | Guest arrival and clearances
failure+=Any required part built as a camera-facing shell.
coldstart=Reopen from a clean invocation and re-render the hero.
check+=All dependencies resolve.
dir=rooftop_bar
```
''';
    MissionSpec spec = patcher
        .parse(
          round,
          const MissionSpec(
            id: 'e2e',
            taskId: 'rooftop-bar',
            title: 'Rooftop bar',
            presetId: 'generic',
          ),
        )
        .spec;

    // The user accepts what the model proposed. Nothing the model inferred
    // satisfies the gate until this happens.
    spec = spec.copyWith(
      missionStatement: spec.missionStatement.confirm(
        spec.missionStatement.value!,
      ),
      definingStory: spec.definingStory.confirm(spec.definingStory.value!),
      scale: spec.scale.confirm(spec.scale.value!),
      audience: spec.audience.confirm(spec.audience.value!),
    );

    // --- 2. The gate lets it compile ------------------------------------
    final ReadinessReport report = const ReadinessGate().evaluate(spec);
    expect(
      report.canCompile,
      isTrue,
      reason: 'blocking: ${report.blocking.map((ReadinessGap g) => g.label)}',
    );

    final CompiledPrompt compiled = const PromptCompiler().compile(spec);
    expect(compiled.body, contains('## 05 / RUBRIC'));
    expect(compiled.body, contains('Exit threshold — 90 / 100'));
    expect(compiled.body, contains('```mpstate'));

    // --- 3. The brief lands on disk, recoverable without the app --------
    final Directory wd = Directory('${tmp.path}/rooftop_bar')
      ..createSync(recursive: true);
    File('${wd.path}/MASTER_PROMPT.md').writeAsStringSync(compiled.body);
    expect(File('${wd.path}/MASTER_PROMPT.md').existsSync(), isTrue);

    // --- 4. The run hits a limit and recovers on its own ----------------
    final TestClock clock = TestClock(DateTime.utc(2026, 9, 2, 12));
    final RunStore store = RunStore(Directory('${tmp.path}/runs'));
    final ProcessResult help = Process.runSync(fakeClaude, <String>['--help']);
    final RunSupervisor supervisor = RunSupervisor(
      executable: fakeClaude,
      capabilities: const HelpParser().parse(
        helpText: help.stdout as String,
        version: '2.1.42',
        fingerprint: 'e2e',
      ),
      store: store,
      clock: clock,
      environmentOverrides: <String, String>{
        'FAKE_CLAUDE_SCENARIO': 'limit_then_success',
        'FAKE_CLAUDE_STATE': '${tmp.path}/e2e-state',
      },
    );

    final List<String> limitMessages = <String>[];
    supervisor.events
        .where((SupervisorEvent e) => e.kind == 'limited')
        .listen((SupervisorEvent e) => limitMessages.add(e.message));

    final RunRecord out = await supervisor.execute(
      RunRecord(
        runId: 'e2e-run',
        taskId: spec.taskId,
        workingDirectory: wd.path,
        prompt: compiled.body,
        createdAt: clock.nowUtc(),
      ),
    );
    await supervisor.dispose();

    expect(out.conclusion, RunConclusion.completed);
    expect(out.attempts, hasLength(2));
    expect(out.attempts.first.verdict!.kind, LimitKind.fiveHour);
    expect(out.attempts[1].strategy, 'resume');
    expect(limitMessages, isNotEmpty);
    expect(
      clock.waitedUntil,
      hasLength(1),
      reason: 'it waited for the limit rather than failing',
    );

    // --- 5. Progress reported back parses, and becomes a capsule --------
    const String reply = '''
Graybox complete, moving to materials.

```mpstate
v=1
task=rooftop-bar
phase=review
step=material pass on the bar
cycle=2
score=71
next=Re-render 02 after fixing the backbar glow
blocked=none
ask=none
```
''';
    final StateParseResult parsed = const StateParser().parse(
      reply,
      expectedTaskId: spec.taskId,
    );
    expect(parsed.status, StateParseStatus.accepted);
    expect(parsed.state!.score, 71);

    final ResumeCapsule capsule = const ResumeCapsuleBuilder().build(
      spec: spec,
      state: parsed.state,
      compiled: compiled,
      producedArtifacts: <String>['01_arrival.png'],
    );

    // The capsule must be able to restart this mission from nothing.
    expect(capsule.text, contains('Do not start over'));
    expect(
      capsule.text,
      contains('Re-render 02 after fixing the backbar glow'),
    );
    expect(capsule.text, contains('exit at 90'));
    expect(
      capsule.text,
      contains('Any required part built as a camera-facing shell.'),
    );
    expect(capsule.text, contains('[x] `01_arrival.png`'));
    expect(capsule.text, contains('[ ] `02_hero.png`'));
    expect(capsule.text, contains('```mpstate'));

    // --- 6. The run record survives the app being closed ----------------
    final RunRecord? reloaded = await RunStore(
      Directory('${tmp.path}/runs'),
    ).load('e2e-run');
    expect(reloaded, isNotNull);
    expect(reloaded!.conclusion, RunConclusion.completed);
    expect(reloaded.prompt, contains('## 09 / FAILURE CONDITIONS'));
  });
}
