import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/store/build_info.dart';
import 'package:master_prompt/src/store/diagnostics.dart';
import 'package:master_prompt/src/store/project.dart';
import 'package:master_prompt/src/store/settings.dart';
import 'package:mp_core/mp_core.dart';

Project projectWithState() => Project(
  id: 'p1',
  spec: const MissionSpec(
    id: 'p1',
    taskId: 'rooftop-bar',
    title: 'Rooftop bar',
    presetId: 'generic',
  ),
  lastState: const MpState(
    taskId: 'rooftop-bar',
    phase: MissionPhase.review,
    step: 'material pass',
    cycle: 2,
    score: 71,
    next: 'Re-render 02',
  ),
  transcript: <TranscriptEntry>[
    TranscriptEntry(
      direction: TranscriptDirection.sent,
      text: 'a turn',
      at: DateTime.utc(2026),
    ),
  ],
);

void main() {
  test('the report identifies the build', () {
    final String r = Diagnostics.instance.report();
    expect(r, contains('MASTER PROMPT DIAGNOSTICS'));
    expect(r, contains(BuildInfo.label));
    expect(r, contains(BuildInfo.platform));
    // A local build must say so, or a report could be mistaken for a CI build.
    expect(r, contains('local build, not from CI'));
  });

  test('the report carries the mission state, which answers most questions', () {
    final String r = Diagnostics.instance.report(project: projectWithState());
    expect(r, contains('rooftop-bar'));
    expect(r, contains('review'));
    expect(r, contains('material pass'));
    expect(r, contains('Re-render 02'));
    expect(r, contains('71'));
    // The readiness summary explains why the Brief tab is refusing to compile.
    expect(r, contains('blocking'));
  });

  test('recent events appear, newest last, and are bounded', () {
    for (int i = 0; i < 300; i++) {
      Diagnostics.instance.log('event $i');
    }
    final String r = Diagnostics.instance.report();
    expect(r, contains('event 299'));
    expect(
      r,
      isNot(contains('event 5\n')),
      reason: 'the buffer is bounded, so the oldest entries are dropped',
    );
    // Bounded, so a long session cannot produce an unpasteable report.
    expect(r.length, lessThan(40000));
  });

  test('settings are summarised without leaking paths or keys', () {
    const AppSettings s = AppSettings(
      claudePath: r'C:\Users\kai\AppData\claude.exe',
      workingDirectory: r'C:\Users\kai\missions',
    );
    final String r = Diagnostics.instance.report(settings: s);
    expect(r, contains('claude-opus-5'));
    expect(r, contains('bypassPermissions'));
    // The paths contain a user name, so only their presence is reported.
    expect(r, isNot(contains('kai')));
    expect(r, contains('cliPath     set'));
    expect(r, contains('workingDir  set'));
  });

  test('a report with nothing recorded still produces something usable', () {
    final Diagnostics d = Diagnostics.instance;
    final String r = d.report();
    expect(r, contains('--- END DIAGNOSTICS ---'));
    expect(r.trim(), isNotEmpty);
  });
}
