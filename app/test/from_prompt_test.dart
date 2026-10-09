import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/flow/flow_controller.dart';
import 'package:master_prompt/src/screens/home.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: buildMpTheme(MpColors.light, dark: false),
  home: MpTheme(colors: MpColors.light, isDark: false, child: child),
);

const String pasted = '''
# Rooftop bar

Build a photorealistic rooftop cocktail bar above a city at night in Blender.
Never use stock HDRIs for the skyline.
''';

/// What a reading round comes back as: a few lines on what is open, then
/// the block.
const String readingReply = '''
It settles the subject and the tool. It says nothing about who judges the
result, how it is scored, or what proves it is finished.

```json
{
  "mission": "A photorealistic rooftop cocktail bar above a city at night.",
  "tool": "Blender with Cycles.",
  "carry": ["Never use stock HDRIs for the skyline."]
}
```
''';

Future<void> startFromPrompt(
  WidgetTester tester,
  AppStore store,
  String prompt,
) async {
  await tester.pumpWidget(wrap(HomeScreen(store: store)));
  await tester.pump();
  await tester.tap(find.text('START FROM A PROMPT I HAVE'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), prompt);
  await tester.tap(find.text('READ IT'));
  await tester.pumpAndSettle();
}

void main() {
  late AppStore store;
  final List<MethodCall> clipboard = <MethodCall>[];

  setUp(() async {
    store = AppStore(inMemory: true);
    await store.load();
    clipboard.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall c,
        ) async {
          clipboard.add(c);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    store.dispose();
  });

  String copied() {
    final MethodCall set = clipboard.lastWhere(
      (MethodCall c) => c.method == 'Clipboard.setData',
    );
    return (set.arguments as Map<Object?, Object?>)['text']! as String;
  }

  group('a mission can start from a prompt', () {
    testWidgets('the opening screen offers it without leading with it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pump();

      expect(find.text('What are you building?'), findsOneWidget);
      expect(find.text('START FROM A PROMPT I HAVE'), findsOneWidget);

      await tester.tap(find.text('START FROM A PROMPT I HAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Paste the prompt you have'), findsOneWidget);
      expect(find.text('READ IT'), findsOneWidget);

      await tester.ensureVisible(
        find.text('DESCRIBE IT IN A SENTENCE INSTEAD'),
      );
      await tester.tap(find.text('DESCRIBE IT IN A SENTENCE INSTEAD'));
      await tester.pumpAndSettle();
      expect(
        find.text('What are you building?'),
        findsOneWidget,
        reason: 'the way back has to be as plain as the way in',
      );
    });

    testWidgets('the pasted prompt is kept, and counts for nothing yet', (
      WidgetTester tester,
    ) async {
      await startFromPrompt(tester, store, pasted);

      final MissionSpec spec = store.current!.spec;
      expect(spec.source?.text, pasted.trim());
      expect(spec.title, 'Rooftop bar', reason: 'named from its first line');
      expect(
        spec.missionStatement.isSettled,
        isFalse,
        reason:
            'what the prompt settles is read out of it by a model, and has to '
            'be accepted like any other round',
      );
      expect(
        find.text('What does your prompt already settle?'),
        findsOneWidget,
      );
      expect(find.text('YOUR PROMPT · READING IT'), findsOneWidget);
    });

    testWidgets('the reading round carries the prompt to the chat', (
      WidgetTester tester,
    ) async {
      await startFromPrompt(tester, store, pasted);
      await tester.tap(find.text('COPY FOR CLAUDE'));
      await tester.pumpAndSettle();

      expect(copied(), contains('Never use stock HDRIs for the skyline.'));
      expect(copied(), contains('<original_prompt>'));
      expect(find.text("Paste Claude's reply"), findsOneWidget);
    });
  });

  group('accepting the reading', () {
    testWidgets('names what was taken, then moves on to the questions', (
      WidgetTester tester,
    ) async {
      await startFromPrompt(tester, store, pasted);
      await tester.tap(find.text('COPY FOR CLAUDE'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, readingReply);
      await tester.tap(find.text('APPLY REPLY'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Standing instruction: Never use stock HDRIs'),
        findsOneWidget,
        reason: 'an instruction carried over is named, so it can be checked',
      );
      expect(store.current!.spec.source!.read, isFalse);

      await tester.tap(find.text('ACCEPT AND CONTINUE'));
      await tester.pumpAndSettle();

      final MissionSpec spec = store.current!.spec;
      expect(spec.source!.read, isTrue);
      expect(spec.missionStatement.isSettled, isTrue);
      expect(spec.standingInstructions, hasLength(1));
      expect(
        find.text(InterviewStage.intent.question),
        findsOneWidget,
        reason: 'what the prompt left open is now asked, a stage at a time',
      );
      expect(find.text('Your original prompt'), findsOneWidget);
    });

    testWidgets('discarding it leaves the reading still to do', (
      WidgetTester tester,
    ) async {
      await startFromPrompt(tester, store, pasted);
      await tester.tap(find.text('COPY FOR CLAUDE'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, readingReply);
      await tester.tap(find.text('APPLY REPLY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DISCARD THIS REPLY'));
      await tester.pumpAndSettle();

      expect(store.current!.spec.source!.read, isFalse);
      expect(
        find.text('What does your prompt already settle?'),
        findsOneWidget,
      );
    });

    testWidgets('it can be skipped, and the prompt still goes along', (
      WidgetTester tester,
    ) async {
      await startFromPrompt(tester, store, pasted);
      await tester.tap(find.text('Your original prompt'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('SKIP THE READING'));
      await tester.tap(find.text('SKIP THE READING'));
      await tester.pumpAndSettle();

      expect(store.current!.spec.source!.read, isTrue);
      expect(find.text(InterviewStage.seed.question), findsOneWidget);

      await tester.tap(find.text('COPY FOR CLAUDE'));
      await tester.pumpAndSettle();
      expect(
        copied(),
        contains('Never use stock HDRIs'),
        reason: 'the questions are meant to quote the prompt they are about',
      );
    });
  });

  testWidgets('a prompt too long to paste leaves as a file', (
    WidgetTester tester,
  ) async {
    final String long = '$pasted\n${'Another paragraph of detail. ' * 400}';
    await startFromPrompt(tester, store, long);

    expect(
      find.text('COPY FOR CLAUDE'),
      findsNothing,
      reason: 'a chat app cuts an oversized paste off without saying so',
    );
    expect(find.text('Your prompt, to be read'), findsOneWidget);
    expect(find.text('BRING THE REPLY BACK'), findsOneWidget);

    await tester.ensureVisible(find.text('BRING THE REPLY BACK'));
    await tester.tap(find.text('BRING THE REPLY BACK'));
    await tester.pumpAndSettle();
    expect(find.text("Paste Claude's reply"), findsOneWidget);
  });

  group('a title from a prompt', () {
    test('is its first line with the markdown taken off', () {
      expect(
        MissionSeed.titleFromPrompt('# Rooftop bar\n\nBuild it.'),
        'Rooftop bar',
      );
      expect(
        MissionSeed.titleFromPrompt('---\n\n**Role:** an engineer'),
        'Role: an engineer',
      );
      expect(
        MissionSeed.titleFromPrompt('<task>\nWrite a parser\n</task>'),
        'Write a parser',
        reason: 'a line that is only a tag says nothing about the mission',
      );
      expect(MissionSeed.titleFromPrompt('  \n '), 'Untitled mission');
    });
  });
}
