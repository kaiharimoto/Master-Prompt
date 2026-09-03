import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/widgets/exchange.dart';
import 'package:mp_design/mp_design.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: buildMpTheme(MpColors.light, dark: false),
  home: MpTheme(
    colors: MpColors.light,
    isDark: false,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

String longBody(int paragraphs) => List<String>.generate(
  paragraphs,
  (int i) => '## 0$i / SECTION\n\nParagraph $i. ${'word ' * 60}',
).join('\n\n');

void main() {
  final List<String> copied = <String>[];

  setUp(() {
    copied.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall c,
        ) async {
          if (c.method == 'Clipboard.setData') {
            copied.add(
              ((c.arguments as Map<Object?, Object?>)['text'] ?? '').toString(),
            );
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('a message that fits keeps the plain one-tap copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(const MpOutbound(title: 'Brief', text: 'short', limit: 8000)),
    );

    expect(find.text('Copy for Claude'), findsOneWidget);
    expect(
      find.textContaining('part'),
      findsNothing,
      reason: 'the common case must not pay for the rare one',
    );

    await tester.tap(find.text('Copy for Claude'));
    await tester.pumpAndSettle();
    expect(copied.single, 'short');
  });

  testWidgets('a long one is copied in order, one part per tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(MpOutbound(title: 'Brief', text: longBody(40), limit: 2000)),
    );

    expect(find.textContaining('Copy part 1 of'), findsOneWidget);
    expect(
      find.textContaining('parts'),
      findsWidgets,
      reason: 'the count belongs on screen before the first tap, not after',
    );

    // Walk the whole sequence.
    int guard = 0;
    while (find.textContaining('Copy part ').evaluate().isNotEmpty &&
        guard++ < 30) {
      await tester.tap(find.textContaining('Copy part '));
      await tester.pumpAndSettle();
    }

    expect(copied.length, greaterThan(1));
    for (int i = 0; i < copied.length; i++) {
      expect(
        copied[i],
        contains('Part ${i + 1} of ${copied.length}'),
        reason: 'tapping in sequence has to yield the parts in sequence',
      );
    }
    expect(
      find.text('Start over'),
      findsOneWidget,
      reason:
          'the end of the sequence has to be visible, or you cannot tell a '
          'finished handover from one stuck on its last part',
    );
  });

  testWidgets('the preview shows the part about to be copied', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(MpOutbound(title: 'Brief', text: longBody(40), limit: 2000)),
    );

    expect(find.textContaining('Part 1 of'), findsWidgets);
    await tester.tap(find.textContaining('Copy part 1 of'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Part 2 of'),
      findsWidgets,
      reason: 'showing the whole document would not say what the tap sends',
    );
  });

  testWidgets('a regenerated document restarts the sequence', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(MpOutbound(title: 'Brief', text: longBody(40), limit: 2000)),
    );
    await tester.tap(find.textContaining('Copy part 1 of'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Copy part 2 of'), findsOneWidget);

    // The brief recompiles whenever the spec changes underneath it.
    await tester.pumpWidget(
      wrap(MpOutbound(title: 'Brief', text: longBody(50), limit: 2000)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Copy part 1 of'),
      findsOneWidget,
      reason:
          'carrying "you are on part two" across a different document sends '
          'the wrong two thousand characters, and nothing would say so',
    );
  });

  testWidgets('a larger paste size means fewer parts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(MpOutbound(title: 'Brief', text: longBody(40), limit: 2000)),
    );
    final String small = tester
        .widget<Text>(find.textContaining('Copy part 1 of'))
        .data!;

    await tester.pumpWidget(
      wrap(MpOutbound(title: 'Brief', text: longBody(40), limit: 8000)),
    );
    await tester.pumpAndSettle();
    final String large = tester
        .widget<Text>(find.textContaining('Copy part 1 of'))
        .data!;

    expect(
      small,
      isNot(large),
      reason:
          'the setting exists because only the person holding the phone can '
          'find the real ceiling, so it has to actually change the split',
    );
  });
}
