import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/screens/home.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:master_prompt/src/store/claude_chat.dart';
import 'package:master_prompt/src/store/desktop_runner.dart';
import 'package:master_prompt/src/store/settings.dart';
import 'package:mp_runner/mp_runner.dart';

import 'connection_test.dart' show fakeInstall, FakeLocator;
import 'widget_test.dart' show shapeReply, wrap;

/// A CLI that answers with whatever the test lines up, without running one.
///
/// The point is not that a process is avoided for speed: a real process cannot
/// complete inside the tester's fake-async zone at all, so the desktop route
/// would otherwise be untestable on any runner.
class _ScriptedChat extends ClaudeChat {
  _ScriptedChat({
    required super.runner,
    required this.replies,
    this.manual = false,
  });

  /// Handed out in order, one per send.
  final List<String> replies;

  /// Hold each turn open until the test lets it finish, so the screen can be
  /// looked at mid-flight. A real turn takes a minute; this one would
  /// otherwise be over before anything could be asserted about it.
  final bool manual;

  Completer<void>? _gate;

  /// Lets the turn in flight complete.
  Future<void> release(WidgetTester tester) async {
    _gate?.complete();
    _gate = null;
    await tester.pumpAndSettle();
  }

  /// Everything the flow put to the CLI, so the round that was sent can be
  /// inspected rather than assumed.
  final List<String> asked = <String>[];

  final List<ChatTurn> _turns = <ChatTurn>[];
  String? _error;

  @override
  List<ChatTurn> get turns => List<ChatTurn>.unmodifiable(_turns);

  @override
  bool get busy => _gate != null;

  @override
  String? get error => _error;

  @override
  bool get available => runner.install != null;

  @override
  Future<ConversationReply?> send(String prompt, AppSettings settings) async {
    asked.add(prompt);
    _turns.add(
      ChatTurn(fromUser: true, text: prompt, at: DateTime.now().toUtc()),
    );
    if (manual) {
      final Completer<void> gate = Completer<void>();
      _gate = gate;
      notifyListeners();
      await gate.future;
      notifyListeners();
    }
    if (replies.isEmpty) {
      _error = 'nothing scripted';
      notifyListeners();
      return null;
    }
    final String reply = replies.removeAt(0);
    _turns.add(
      ChatTurn(fromUser: false, text: reply, at: DateTime.now().toUtc()),
    );
    notifyListeners();
    return ConversationReply(text: reply, sessionId: 'scripted');
  }

  @override
  void reset() {
    _turns.clear();
    _error = null;
    notifyListeners();
  }
}

/// A reply with the questions and no patch — the normal first round.
const String questionsOnly = '''
Two things to settle before I can write this down.

1. Twenty seats, or forty? (recommended: twenty — the brief already says
   "intimate", and forty would contradict it)
2. Real service depth behind the bar, or a facade?
''';

void main() {
  late AppStore store;
  late DesktopRunner runner;

  setUp(() async {
    store = AppStore(inMemory: true);
    await store.load();
    runner = DesktopRunner(locator: FakeLocator(install: fakeInstall()));
    await runner.detect(store.settings);
  });

  tearDown(() {
    runner.dispose();
    store.dispose();
  });

  Future<_ScriptedChat> seedDesktop(
    WidgetTester tester,
    List<String> replies, {
    bool manual = false,
  }) async {
    final _ScriptedChat chat = _ScriptedChat(
      runner: runner,
      replies: <String>[...replies],
      manual: manual,
    );
    await tester.pumpWidget(
      wrap(HomeScreen(store: store, runner: runner, chat: chat)),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'A rooftop bar at night');
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    return chat;
  }

  testWidgets('a connected CLI turns the round into a question it can send', (
    WidgetTester tester,
  ) async {
    await seedDesktop(tester, <String>[questionsOnly]);

    expect(find.text('Ask Claude'), findsOneWidget);
    expect(
      find.text('Copy for Claude instead'),
      findsOneWidget,
      reason:
          'the CLI can be logged out or rate-limited, so the clipboard route '
          'stays reachable one level down rather than being removed',
    );
  });

  testWidgets('a reply with questions is shown, with a box to answer in', (
    WidgetTester tester,
  ) async {
    final _ScriptedChat chat = await seedDesktop(tester, <String>[
      questionsOnly,
    ]);

    await tester.tap(find.text('Ask Claude'));
    await tester.pumpAndSettle();

    expect(chat.asked, hasLength(1));
    expect(find.text('Claude answered'), findsOneWidget);
    expect(find.textContaining('Twenty seats, or forty?'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(
      find.textContaining('No settled answers'),
      findsNothing,
      reason:
          'a round of questions is the interview working; the clipboard '
          "route's warning would read as a failure",
    );
  });

  testWidgets('an answer goes back into the same session', (
    WidgetTester tester,
  ) async {
    final _ScriptedChat chat = await seedDesktop(tester, <String>[
      questionsOnly,
      shapeReply,
    ]);

    await tester.tap(find.text('Ask Claude'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Twenty seats.');
    await tester.ensureVisible(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(chat.asked, hasLength(2));
    expect(chat.asked.last, 'Twenty seats.');
    expect(
      find.textContaining('things settled'),
      findsOneWidget,
      reason: 'a reply that carries a patch advances to the accept step',
    );
  });

  testWidgets('a patch from the CLI still has to be accepted', (
    WidgetTester tester,
  ) async {
    await seedDesktop(tester, <String>[shapeReply]);

    await tester.tap(find.text('Ask Claude'));
    await tester.pumpAndSettle();

    expect(find.text('Accept and continue'), findsOneWidget);
    expect(
      store.current!.spec.regions,
      isEmpty,
      reason:
          'a reply that arrived down a pipe has no more authority than a '
          'pasted one; the gate is the whole reason a hallucination cannot '
          'reach an unattended run',
    );

    await tester.tap(find.text('Accept and continue'));
    await tester.pumpAndSettle();
    expect(store.current!.spec.regions, isNotEmpty);
  });

  testWidgets('a failed turn says so instead of looking like a quiet answer', (
    WidgetTester tester,
  ) async {
    await seedDesktop(tester, <String>[]);

    await tester.tap(find.text('Ask Claude'));
    await tester.pumpAndSettle();

    expect(find.textContaining('nothing scripted'), findsOneWidget);
    expect(
      find.text('Send'),
      findsNothing,
      reason:
          'there is nothing to answer when nothing came back, and a Send that '
          'does nothing is worse than no Send',
    );

    await tester.tap(find.text('Back to the question'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ask Claude'),
      findsOneWidget,
      reason: 'the round survives a failed turn and can be sent again',
    );
  });

  testWidgets('the first round is written for a session that knows nothing', (
    WidgetTester tester,
  ) async {
    final _ScriptedChat chat = await seedDesktop(tester, <String>[
      questionsOnly,
      questionsOnly,
    ]);

    await tester.tap(find.text('Ask Claude'));
    await tester.pumpAndSettle();

    expect(
      chat.asked.first,
      contains('The mission so far'),
      reason:
          'a continuing turn sent into a session that has seen nothing is '
          'unusable, and the session is fresh whatever the transcript says',
    );
  });

  testWidgets('the next round drops what the session already holds', (
    WidgetTester tester,
  ) async {
    final _ScriptedChat chat = await seedDesktop(tester, <String>[
      shapeReply,
      questionsOnly,
    ]);

    await tester.tap(find.text('Ask Claude'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept and continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask Claude'));
    await tester.pumpAndSettle();

    expect(chat.asked, hasLength(2));
    expect(
      chat.asked.last,
      isNot(contains('The mission so far')),
      reason:
          'the session already carries the framing and everything settled; '
          'resending it is the redundancy the continuing style exists to stop',
    );
    expect(chat.asked.last.length, lessThan(chat.asked.first.length));
  });

  testWidgets('a turn in flight cannot be sent twice', (
    WidgetTester tester,
  ) async {
    final _ScriptedChat chat = await seedDesktop(tester, <String>[
      questionsOnly,
    ], manual: true);

    await tester.tap(find.text('Ask Claude'));
    await tester.pump();

    expect(find.text('Asking Claude…'), findsWidgets);
    await tester.tap(find.text('Asking Claude…').last, warnIfMissed: false);
    await tester.pump();
    expect(
      chat.asked,
      hasLength(1),
      reason:
          'a second send would put the same round into the session twice and '
          'leave the conversation answering itself',
    );

    await chat.release(tester);
    expect(find.text('Claude answered'), findsOneWidget);
  });

  testWidgets('without a CLI the desktop behaves exactly as the phone does', (
    WidgetTester tester,
  ) async {
    final DesktopRunner absent = DesktopRunner(
      locator: FakeLocator(
        failure: ClaudeNotFound('not found', attempts: const <ProbeAttempt>[]),
      ),
    );
    addTearDown(absent.dispose);
    final _ScriptedChat chat = _ScriptedChat(
      runner: absent,
      replies: <String>[],
    );

    await tester.pumpWidget(
      wrap(HomeScreen(store: store, runner: absent, chat: chat)),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'A rooftop bar at night');
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();

    expect(find.text('Copy for Claude'), findsOneWidget);
    expect(find.text('Ask Claude'), findsNothing);
  });
}
