import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/screens/prompt_screen.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:master_prompt/src/store/project.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: buildMpTheme(MpColors.light, dark: false),
  home: MpTheme(
    colors: MpColors.light,
    isDark: false,
    child: Scaffold(body: child),
  ),
);

/// The smallest mission that satisfies every blocking requirement, delivered
/// as patch lines because that is how a real one is assembled.
///
/// The app package had no compilable spec to test against — the reference one
/// lives in mp_core's own tests and is 564 lines. This is the floor: remove
/// any line and the readiness gate refuses, which is the property that makes
/// it a useful fixture rather than a pile of plausible strings.
const String seedPatch = '''
```mpspec
mission=A late-night cocktail bar interior, built to survive close inspection.
story=Arriving alone at midnight and deciding to stay.
scale=One room, 120 square metres, seating twenty.
audience=An interior architect who has built one.
tool=Blender 4.2
budget=100M tokens
coldstart=Open the file and render 01 at full resolution.
dir=cocktail_bar
total=100
exit=90
region+=Cocktail bar | Twenty seats with real service depth
relationship+=The bar and the room must share one sightline.
family+=Seating | stools and banquettes | min=30
avoid+=A hotel lobby with a counter in it.
palette+=Warm brass against deep green.
evidence+=1 | 01_arrival.png | Arrival | The first read of the room | hero
step+=1 | Shell | Build the room before anything in it.
rubric+=Craft | 100 | Holds up at 4K with no visible shortcuts.
critic+=Materials | Whether every surface reads as the thing it claims to be
failure+=A region built as a facade with no interior depth.
```
''';

/// A red-team reply that does both things a real one does: replaces a value
/// and adds to a list. The replaced value is the interesting half — it lands
/// as `proposed` and is the one that used to go nowhere.
const String reply = '''
Two problems worth fixing.

```json
{
  "mission": "A cocktail bar judged at 4K, where every surface survives a crop.",
  "failures": ["Glassware modelled as a single opaque solid."]
}
```
''';

/// The Brief screen is a long scroll and the tester's viewport is 800x600, so
/// nearly everything worth tapping starts below the fold. A tap that misses is
/// only a warning, so without this a test passes on whatever was already there.
Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  late Directory tmp;
  late AppStore store;
  late Project project;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mp-redteam');
    store = AppStore(inMemory: true);
    await store.load();
    final SpecPatchResult seeded = const SpecPatchParser().parse(
      seedPatch,
      const MissionSpec(
        id: 'p',
        taskId: 'cocktail_bar',
        title: 'Cocktail bar',
        presetId: 'generic',
      ),
    );
    project = Project(id: 'p', spec: seeded.spec.confirmProposals());
    expect(
      const InterviewEngine().assess(project.spec).canCompile,
      isTrue,
      reason: 'the red-team panel only exists on a brief that compiles',
    );
  });

  tearDown(() {
    store.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> pasteReply(WidgetTester tester) async {
    await tester.pumpWidget(wrap(PromptScreen(store: store, project: project)));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Generate the red-team pass'));
    await tester.enterText(find.byType(TextField).last, reply);
    await tapVisible(tester, find.text('Read the fixes'));
  }

  testWidgets('a pasted pass changes nothing until it is accepted', (
    WidgetTester tester,
  ) async {
    final String before = project.spec.missionStatement.value ?? '';
    await pasteReply(tester);

    expect(find.textContaining('waiting'), findsOneWidget);
    expect(
      project.spec.missionStatement.value,
      before,
      reason:
          'writing the fixes in first meant the gate could then refuse to '
          'compile, replacing this screen with the not-ready notice and taking '
          'the red-team panel with it',
    );
  });

  testWidgets('it names every fix rather than counting them', (
    WidgetTester tester,
  ) async {
    await pasteReply(tester);

    expect(
      find.textContaining('opaque solid'),
      findsOneWidget,
      reason:
          '"Applied 80 fixes" is indistinguishable from "applied nothing" once '
          'you go looking at a twenty-thousand-character brief',
    );
  });

  testWidgets('accepting puts them through the gate and into the brief', (
    WidgetTester tester,
  ) async {
    await pasteReply(tester);
    await tapVisible(tester, find.text('Accept and put them in the brief'));

    expect(
      project.spec.missionStatement.value,
      contains('survives a crop'),
      reason: 'the replaced value has to actually land',
    );
    expect(
      project.spec.missionStatement.isSettled,
      isTrue,
      reason:
          'a replaced value arrives as `proposed`, and this screen never '
          'confirmed it — so the fixes that mattered most sat outside the '
          'readiness gate while the screen reported them applied',
    );

    // The question that started this: is it actually in the brief?
    final CompiledPrompt compiled = const PromptCompiler().compile(
      project.spec,
    );
    expect(compiled.body, contains('survives a crop'));
    expect(compiled.body, contains('single opaque solid'));
  });

  testWidgets('accepting sets a baseline the preview can mark against', (
    WidgetTester tester,
  ) async {
    expect(project.briefBaseline, isNull);
    await pasteReply(tester);
    await tapVisible(tester, find.text('Accept and put them in the brief'));

    expect(
      project.briefBaseline,
      isNotNull,
      reason:
          'without the brief as it stood before the round there is nothing to '
          'diff against, and the preview cannot say what moved',
    );
    final BriefDiff d = BriefDiff.between(
      project.briefBaseline!,
      const PromptCompiler().compile(project.spec).body,
    );
    expect(d.isEmpty, isFalse);
    expect(
      BriefDocument.parse(const PromptCompiler().compile(project.spec).body)
          .blocks
          .where(d.marks)
          .any((BriefBlock b) => b.plain.contains('survives a crop')),
      isTrue,
      reason: 'the block carrying the accepted fix is the one marked',
    );
  });

  testWidgets('the preview opens on the brief and marks the round', (
    WidgetTester tester,
  ) async {
    await pasteReply(tester);
    await tapVisible(tester, find.text('Accept and put them in the brief'));
    await tapVisible(tester, find.textContaining('Read the brief'));

    expect(
      find.text('What the last round changed'),
      findsOneWidget,
      reason: 'the marks are the reason to open it after a round',
    );
    expect(
      find.textContaining('survives a crop'),
      findsWidgets,
      reason: 'and the brief itself has to be readable, not a payload',
    );
  });

  testWidgets('discarding leaves the mission alone', (
    WidgetTester tester,
  ) async {
    final String before = project.spec.missionStatement.value ?? '';
    await pasteReply(tester);
    await tapVisible(tester, find.text('Discard'));

    expect(project.spec.missionStatement.value, before);
    expect(
      find.textContaining('still in the transcript'),
      findsOneWidget,
      reason: 'a paste is never discarded, even when its changes are',
    );
  });
}
