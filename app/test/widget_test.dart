import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/screens/home.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:mp_design/mp_design.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: buildMpTheme(MpColors.light, dark: false),
  home: MpTheme(colors: MpColors.light, isDark: false, child: child),
);

/// Taps something that performs real file I/O and waits for it to land.
///
/// Storage writes cannot complete inside the tester's fake-async zone, and a
/// fixed delay is a race: it passes alone and fails in a loaded suite. Wait for
/// the observable result instead.
Future<void> tapAndSettle(
  WidgetTester tester,
  Finder target,
  bool Function() until,
) async {
  await tester.runAsync(() async {
    await tester.tap(target);
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!until() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pumpAndSettle();
}

/// Taps something whose handler crosses a platform channel.
///
/// `Clipboard.setData` is answered by the mock binary messenger, which needs a
/// real event-loop turn — inside the tester's fake-async zone the await can
/// simply never return, so the code after it never runs.
Future<void> tapAsync(WidgetTester tester, Finder target) async {
  await tester.runAsync(() async {
    await tester.tap(target);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pumpAndSettle();
}

/// Drives the flow to the ASK beat of a freshly seeded mission.
Future<void> seed(WidgetTester tester, AppStore store, String sentence) async {
  await tester.pumpWidget(wrap(HomeScreen(store: store)));
  await tester.pump();
  await tester.enterText(find.byType(TextField), sentence);
  await tester.tap(find.text('Begin'));
  await tester.pumpAndSettle();
}

/// A reply of the shape Claude actually returns for the shape stage.
const String shapeReply = '''
Good. Here is what we settled.

```mpspec
region+=Cocktail bar | Twenty seats with real service depth
region+=Open kitchen | Visible hot line and plating pass
family+=Dining furniture | tables and chairs | min=130
```
''';

void main() {
  late Directory tmp;
  late AppStore store;
  final List<MethodCall> clipboard = <MethodCall>[];

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mp_flow_');
    // The flow tests are about the interface, so they use the in-memory store:
    // real writes cannot complete in the tester's fake-async zone, and a test
    // that races on machine load teaches you to ignore red. Persistence is
    // covered separately, outside that zone.
    store = AppStore(inMemory: true);
    await store.load();
    clipboard.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall c,
        ) async {
          clipboard.add(c);
          if (c.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': shapeReply};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    store.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('a mission begins from one sentence', () {
    testWidgets('the opening screen asks one question and nothing else', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pump();

      expect(find.text('What are you building?'), findsOneWidget);
      expect(find.text('Begin'), findsOneWidget);

      // The complaint that prompted this redesign: everything at once. None of
      // the old dashboard may appear before a mission exists.
      expect(find.text('READINESS'), findsNothing);
      expect(find.text('Copy for Claude'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('one sentence produces a titled mission and the first round', (
      WidgetTester tester,
    ) async {
      await seed(tester, store, 'A photorealistic rooftop bar above a city');

      expect(store.projects, hasLength(1));
      expect(store.current!.spec.taskId, isNotEmpty);
      // Typed by the user, so it counts immediately.
      expect(store.current!.spec.missionStatement.isSettled, isTrue);
      expect(find.text('Copy for Claude'), findsOneWidget);
    });
  });

  group('each beat shows only its own subject', () {
    testWidgets('ASK shows the question, not the paste field', (
      WidgetTester tester,
    ) async {
      await seed(tester, store, 'A rooftop bar');

      expect(find.text('Copy for Claude'), findsOneWidget);
      expect(find.text("Paste Claude's reply"), findsNothing);
      expect(find.text('Apply reply'), findsNothing);
      // The stage's open items exist but are folded away.
      expect(find.text('What this round settles'), findsOneWidget);
      expect(find.text('Preview the message'), findsOneWidget);
    });

    testWidgets('copying advances to AWAIT, which shows only the paste', (
      WidgetTester tester,
    ) async {
      await seed(tester, store, 'A rooftop bar');
      await tester.tap(find.text('Copy for Claude'));
      await tester.pumpAndSettle();

      expect(
        clipboard.any((MethodCall c) => c.method == 'Clipboard.setData'),
        isTrue,
        reason: 'the round should actually be on the clipboard',
      );
      expect(find.text("Paste Claude's reply"), findsOneWidget);
      expect(find.text('Apply reply'), findsOneWidget);
      expect(find.text('Copy for Claude'), findsNothing);
    });

    testWidgets('a good reply advances to REVIEW and names what landed', (
      WidgetTester tester,
    ) async {
      await seed(tester, store, 'A rooftop bar');
      await tester.tap(find.text('Copy for Claude'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, shapeReply);
      await tester.tap(find.text('Apply reply'));
      await tester.pumpAndSettle();

      expect(find.textContaining('things settled'), findsOneWidget);
      expect(find.textContaining('Cocktail bar'), findsOneWidget);
      expect(find.text('Accept and continue'), findsOneWidget);
      // REVIEW is about what happened, not about the question.
      expect(find.text('What parts must exist?'), findsNothing);
    });
  });

  group('accepting a round', () {
    testWidgets('one tap confirms the round and returns to a question', (
      WidgetTester tester,
    ) async {
      await seed(tester, store, 'A rooftop bar');
      await tester.tap(find.text('Copy for Claude'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, shapeReply);
      await tester.tap(find.text('Apply reply'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept and continue'));
      await tester.pumpAndSettle();

      // The mission actually took the changes.
      expect(store.current!.spec.regions, hasLength(2));
      expect(store.current!.spec.families, hasLength(1));
      // And we are asking the next question rather than sitting on a summary.
      expect(find.text('Copy for Claude'), findsOneWidget);
      expect(find.text('Accept and continue'), findsNothing);
    });

    testWidgets('a reply that settles nothing never advances the flow', (
      WidgetTester tester,
    ) async {
      await seed(tester, store, 'A rooftop bar');
      await tester.tap(find.text('Copy for Claude'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'Sure! What sort of atmosphere are you going for?',
      );
      await tester.tap(find.text('Apply reply'));
      await tester.pumpAndSettle();

      // Stays put, explains itself, and does not pretend a round completed.
      expect(find.text("Paste Claude's reply"), findsOneWidget);
      expect(find.text('Accept and continue'), findsNothing);
      expect(
        find.textContaining('answer them in the same chat'),
        findsOneWidget,
      );
    });

    testWidgets('you can go back to the question without losing the mission', (
      WidgetTester tester,
    ) async {
      await seed(tester, store, 'A rooftop bar');
      await tester.tap(find.text('Copy for Claude'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to the question'));
      await tester.pumpAndSettle();

      expect(find.text('Copy for Claude'), findsOneWidget);
      expect(store.projects, hasLength(1));
    });
  });

  group('nothing was removed, only deferred', () {
    testWidgets('disclosures start closed and open on tap', (
      WidgetTester tester,
    ) async {
      await seed(tester, store, 'A rooftop bar');

      // Seeding settles the mission statement, so the first round is Intent,
      // whose open items are the audience, the story and the scale.
      expect(find.textContaining('Determines the standard'), findsNothing);

      await tester.tap(find.text('What this round settles'));
      await tester.pumpAndSettle();

      // Open: it is exactly the same detail the old dashboard printed.
      expect(find.textContaining('Determines the standard'), findsOneWidget);
    });

    testWidgets('the menu reaches everything the tabs used to', (
      WidgetTester tester,
    ) async {
      await seed(tester, store, 'A rooftop bar');
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      for (final String label in const <String>[
        'Progress',
        'Brief',
        'Run',
        'Transcript',
        'Missions',
        'Settings',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '$label is unreachable',
        );
      }
    });

    testWidgets('Progress still shows the full readiness detail', (
      WidgetTester tester,
    ) async {
      await seed(tester, store, 'A rooftop bar');
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();

      expect(find.text('STILL NEEDED'), findsOneWidget);
      expect(find.textContaining('required things settled'), findsOneWidget);
    });
  });

  group('persistence', () {
    test('a seeded mission survives a reload', () async {
      final AppStore a = AppStore(root: tmp);
      await a.load();
      await a.create(title: 'Rooftop bar');
      a.dispose();

      final AppStore b = AppStore(root: tmp);
      await b.load();
      expect(b.projects, hasLength(1));
      expect(b.projects.single.title, 'Rooftop bar');
      b.dispose();
    });
  });
}
