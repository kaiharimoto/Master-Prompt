import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/screens/home.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:master_prompt/src/store/project.dart';
import 'package:mp_core/mp_core.dart';

import 'red_team_test.dart' show seedPatch;
import 'widget_test.dart' show wrap;

MissionSpec seeded() => const SpecPatchParser()
    .parse(
      seedPatch,
      const MissionSpec(
        id: 'from-the-phone',
        taskId: 'cocktail_bar',
        title: 'Cocktail bar',
        presetId: 'generic',
      ),
    )
    .spec
    .confirmProposals();

void main() {
  group('a mission moves between devices', () {
    test('an imported bundle arrives whole', () async {
      // The bundle has round-tripped and been fully tested since it was
      // written, and nothing in the app could produce or read one — so a
      // mission started on the phone and continued at the desk had no route
      // between the two at all, which is the workflow this program is for.
      final AppStore store = AppStore(inMemory: true);
      await store.load();
      addTearDown(store.dispose);

      final MissionBundle sent = MissionBundle.from(
        spec: seeded(),
        state: const MpState(taskId: 'cocktail_bar', score: 61, cycle: 2),
        producedArtifacts: <String>['01_arrival.png'],
        history: <BundleExchange>[
          BundleExchange(
            sent: true,
            text: 'Round one.',
            at: DateTime.utc(2026),
          ),
          BundleExchange(
            sent: false,
            text: 'Its answer.',
            at: DateTime.utc(2026),
          ),
        ],
      );

      final Project p = await store.importBundle(
        MissionBundle.decode(sent.encode()),
      );

      expect(p.spec.taskId, 'cocktail_bar');
      expect(p.lastState!.score, 61);
      expect(p.producedArtifacts, <String>['01_arrival.png']);
      expect(p.transcript, hasLength(2));
      expect(
        p.transcript.first.direction,
        TranscriptDirection.sent,
        reason:
            'which way an exchange went is what makes the history readable '
            'rather than a wall of text',
      );
      expect(store.current?.id, p.id);
    });

    test('an imported mission cannot overwrite one already here', () async {
      // Ids are minted from the clock, so carrying the exporting device's id
      // across could collide with something on this one.
      final AppStore store = AppStore(inMemory: true);
      await store.load();
      addTearDown(store.dispose);

      final MissionBundle b = MissionBundle.from(spec: seeded());
      final Project first = await store.importBundle(b);
      final Project second = await store.importBundle(b);

      expect(first.id, isNot(second.id));
      expect(store.projects, hasLength(2));
    });

    test('ids stay distinct on a clock that does not move', () async {
      // The version that actually bites. A loop against the real clock passed
      // on Linux, which has microsecond resolution, while the same code lost a
      // mission on Windows, where the clock advances in ticks of a millisecond
      // or more — so two missions made inside one tick were handed the same id,
      // and `save` writes each project to `<id>.json`.
      //
      // Freezing the clock is the coarse platform taken to its limit, and it
      // makes the property testable on the runner rather than only on the
      // machine that broke.
      final DateTime stopped = DateTime.utc(2026, 9, 9, 10);
      final AppStore store = AppStore(inMemory: true, now: () => stopped);
      await store.load();
      addTearDown(store.dispose);

      final MissionBundle b = MissionBundle.from(spec: seeded());
      final Set<String> ids = <String>{};
      for (int i = 0; i < 50; i++) {
        ids.add((await store.importBundle(b)).id);
      }

      expect(
        ids,
        hasLength(50),
        reason:
            'an id that repeats is a mission silently overwritten on disk, '
            'and a clock is not a source of unique values',
      );
    });

    test('create and import cannot collide with each other', () async {
      // Two different call sites, one mint. `create` is the one a double-tap on
      // the seed screen reaches, and it had this bug long before the import
      // path existed.
      final DateTime stopped = DateTime.utc(2026, 9, 9, 10);
      final AppStore store = AppStore(inMemory: true, now: () => stopped);
      await store.load();
      addTearDown(store.dispose);

      final Project a = await store.create(title: 'One');
      final Project b = await store.create(title: 'Two');
      final Project c = await store.importBundle(
        MissionBundle.from(spec: seeded()),
      );

      expect(<String>{a.id, b.id, c.id}, hasLength(3));
    });

    test('nothing device-specific travels', () async {
      // A stale session id imported onto another machine would "resume" into
      // a conversation that is not there, which is worse than starting clean.
      final MissionBundle b = MissionBundle.decode(
        MissionBundle.from(spec: seeded()).encode(),
      );
      final String text = MissionBundle.from(spec: b.spec).encode();

      expect(text, isNot(contains('sessionId')));
      expect(text, isNot(contains('workingDirectory')));
    });
  });

  group('the picker offers the route', () {
    testWidgets('export and import are there, behind a disclosure', (
      WidgetTester tester,
    ) async {
      final AppStore store = AppStore(inMemory: true);
      await store.load();
      addTearDown(store.dispose);
      await store.importBundle(MissionBundle.from(spec: seeded()));

      await tester.pumpWidget(wrap(HomeScreen(store: store)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Missions'));
      await tester.pumpAndSettle();

      expect(
        find.text('Move a mission between devices'),
        findsOneWidget,
        reason:
            'most openings of this sheet are just switching mission, so the '
            'route is offered without being in the way',
      );

      await tester.tap(find.text('Move a mission between devices'));
      await tester.pumpAndSettle();

      expect(find.text('Bring it in'), findsOneWidget);
      expect(find.text('This mission as a file'), findsOneWidget);
    });
  });
}
