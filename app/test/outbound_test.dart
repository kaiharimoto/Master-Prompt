import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/handover/sender.dart';
import 'package:master_prompt/src/widgets/exchange.dart';
import 'package:mp_design/mp_design.dart';

/// Stands in for the share sheet, the save picker and the cache directory.
///
/// None of those exist on a Linux runner, and the whole point of this change
/// is which of them gets offered — so they are values here.
class FakeTransport implements HandoverTransport {
  FakeTransport(this.dir, {this.canShare = true});

  final Directory dir;

  @override
  final bool canShare;

  bool shareSucceeds = true;
  bool saveSucceeds = true;

  final List<String> sharedText = <String>[];
  final List<String> sharedContent = <String>[];
  final List<String> savedNames = <String>[];

  @override
  Future<Directory> workspace() async => dir;

  @override
  Future<bool> share(File file, String text) async {
    sharedText.add(text);
    sharedContent.add(file.readAsStringSync());
    return shareSucceeds;
  }

  @override
  Future<bool> save(File file, String name) async {
    savedNames.add(name);
    return saveSucceeds;
  }
}

Widget wrap(Widget child) => MaterialApp(
  theme: buildMpTheme(MpColors.light, dark: false),
  home: MpTheme(
    colors: MpColors.light,
    isDark: false,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// Taps something whose handler writes a file or crosses a platform channel.
///
/// Neither can complete inside the tester's fake-async zone: an `await` on
/// real file I/O there simply never returns, so the code after it never runs
/// and the assertion sees nothing rather than something wrong.
Future<void> tapAsync(
  WidgetTester tester,
  Finder target, {
  required bool Function() until,
}) async {
  // Opening the disclosure pushes its button below the fold, and a tap that
  // misses reports as a warning rather than a failure — so it would otherwise
  // pass on whatever the previous action left behind.
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(target);
    // Polled rather than slept through. A fixed delay passes alone and fails
    // in a loaded suite, which is worse than no test at all: it teaches you
    // to ignore red.
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!until() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pumpAndSettle();
}

String longBody(int sections) => List<String>.generate(
  sections,
  (int i) => '## 0$i / SECTION\n\nParagraph $i. ${'word ' * 60}',
).join('\n\n');

void main() {
  late Directory tmp;
  late FakeTransport transport;
  final List<String> copied = <String>[];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mp-outbound');
    transport = FakeTransport(tmp);
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
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Widget panel({
    required String document,
    String note = '',
    int limit = 2000,
    bool canShare = true,
  }) {
    transport = FakeTransport(tmp, canShare: canShare);
    return wrap(
      MpOutbound(
        title: 'Brief',
        document: document,
        note: note,
        fileName: 'bar-brief.md',
        limit: limit,
        sender: HandoverSender(transport: transport),
      ),
    );
  }

  testWidgets('a document that fits keeps the plain one-tap copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(panel(document: 'short', note: 'Read this.'));

    expect(find.text('Copy for Claude'), findsOneWidget);
    expect(
      find.text('Send to Claude'),
      findsNothing,
      reason:
          'a file for something that fits in a message is ceremony, and the '
          'common case must not pay for the rare one',
    );
    expect(find.text('Copy it instead'), findsNothing);

    await tapAsync(
      tester,
      find.text('Copy for Claude'),
      until: () => copied.isNotEmpty,
    );
    expect(copied.single, 'Read this.\n\nshort');
  });

  testWidgets('an oversized one is sent as a file in one tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      panel(document: longBody(40), note: 'Attack the attached brief.'),
    );

    expect(find.text('Send to Claude'), findsOneWidget);
    expect(
      find.textContaining('Copy part'),
      findsNothing,
      reason:
          'eight trips through the app switcher is what this change exists to '
          'remove, so copying cannot be the offer that is on screen',
    );

    await tapAsync(
      tester,
      find.text('Send to Claude'),
      until: () => transport.sharedText.isNotEmpty,
    );

    expect(
      transport.sharedText.single,
      'Attack the attached brief.',
      reason: 'the instruction rides in the message, where it always fits',
    );
    expect(
      transport.sharedContent.single,
      contains('## 00 / SECTION'),
      reason:
          'and the document rides in the file, where length stops mattering',
    );
    expect(
      transport.sharedContent.single,
      contains('Attack the attached brief.'),
      reason:
          'the file carries the instruction too, so it is still sufficient '
          'when it is the only thing that arrives',
    );
  });

  testWidgets('save is offered beside it, and names the file', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(panel(document: longBody(40), note: 'Attack it.'));

    await tapAsync(
      tester,
      find.text('Save'),
      until: () => transport.savedNames.isNotEmpty,
    );

    expect(transport.savedNames.single, 'bar-brief.md');
  });

  testWidgets('without a share sheet, saving is the primary action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      panel(document: longBody(40), note: 'Attack it.', canShare: false),
    );

    expect(find.text('Send to Claude'), findsNothing);
    expect(
      find.text('Save the file'),
      findsOneWidget,
      reason:
          'this is the floor: it depends on no app registering for anything, '
          'which is why it is built rather than deferred',
    );

    await tapAsync(
      tester,
      find.text('Save the file'),
      until: () => transport.savedNames.isNotEmpty,
    );
    expect(transport.savedNames, hasLength(1));
  });

  testWidgets('copying in parts survives, one level down', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(panel(document: longBody(40), note: 'Attack it.'));

    expect(
      find.textContaining('Copy part'),
      findsNothing,
      reason: 'nothing is shown until it is looked for',
    );

    await tester.tap(find.text('Copy it instead'));
    await tester.pumpAndSettle();

    int guard = 0;
    while (find.textContaining('Copy part ').evaluate().isNotEmpty &&
        guard++ < 30) {
      final int before = copied.length;
      await tapAsync(
        tester,
        find.textContaining('Copy part '),
        until: () => copied.length > before,
      );
    }

    expect(copied.length, greaterThan(1));
    for (int i = 0; i < copied.length; i++) {
      expect(copied[i], contains('Part ${i + 1} of ${copied.length}'));
    }
    expect(find.text('Start over'), findsOneWidget);
  });

  testWidgets('a failed share points at the route that cannot fail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(panel(document: longBody(40), note: 'Attack it.'));
    transport.shareSucceeds = false;

    await tapAsync(
      tester,
      find.text('Send to Claude'),
      until: () => transport.sharedText.isNotEmpty,
    );

    expect(
      find.textContaining('Save the file instead'),
      findsOneWidget,
      reason:
          'a share sheet that will not open is exactly when the user needs to '
          'be told the other route exists',
    );
  });

  testWidgets('a regenerated document restarts the part sequence', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(panel(document: longBody(40)));
    await tester.tap(find.text('Copy it instead'));
    await tester.pumpAndSettle();
    await tapAsync(
      tester,
      find.textContaining('Copy part 1 of'),
      until: () => copied.isNotEmpty,
    );
    expect(find.textContaining('Copy part 2 of'), findsOneWidget);

    // The disclosure stays open across the rebuild, as it should — the user
    // opened it and nothing they did closed it.
    await tester.pumpWidget(panel(document: longBody(50)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Copy part 1 of'),
      findsOneWidget,
      reason:
          'carrying "you are on part two" across a different document sends '
          'the wrong two thousand characters, and nothing would say so',
    );
  });
}
