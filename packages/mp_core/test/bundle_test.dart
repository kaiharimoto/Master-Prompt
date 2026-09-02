import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

import 'reference_spec.dart';

void main() {
  final MissionSpec spec = referenceSkylineSpec();
  final CompiledPrompt compiled = const PromptCompiler().compile(spec);
  const MpState state = MpState(
    taskId: 'skyline-restaurant-bar',
    phase: MissionPhase.review,
    step: 'diagnosing',
    cycle: 3,
    score: 78,
    next: 'Re-render 04 and 05',
  );

  MissionBundle build() => MissionBundle.from(
    spec: spec,
    compiled: compiled,
    state: state,
    producedArtifacts: <String>['01_lift_lobby_arrival.png'],
    history: <BundleExchange>[
      BundleExchange(sent: true, text: 'a turn', at: DateTime.utc(2026)),
      BundleExchange(sent: false, text: 'a reply', at: DateTime.utc(2026)),
    ],
    at: DateTime.utc(2026, 9, 2),
  );

  group('a mission survives the trip between devices', () {
    test('round trips without losing anything that matters', () {
      final MissionBundle a = build();
      final MissionBundle b = MissionBundle.decode(a.encode());

      expect(b.spec.contentHash(), spec.contentHash());
      expect(b.spec.evidence, hasLength(16));
      expect(b.spec.rubric.categories, hasLength(7));
      expect(b.state!.score, 78);
      expect(b.state!.next, 'Re-render 04 and 05');
      expect(b.producedArtifacts, <String>['01_lift_lobby_arrival.png']);
      expect(b.history, hasLength(2));
      expect(b.compiledBody, contains('## 05 / RUBRIC'));
    });

    test('the imported mission is immediately runnable again', () {
      final MissionBundle b = MissionBundle.decode(build().encode());
      expect(const ReadinessGate().evaluate(b.spec).canCompile, isTrue);
      final CompiledPrompt again = const PromptCompiler().compile(b.spec);
      expect(
        again.hash,
        compiled.hash,
        reason: 'compilation is deterministic, so the brief is identical',
      );
    });

    test('a capsule can be built on the receiving device', () {
      final MissionBundle b = MissionBundle.decode(build().encode());
      final ResumeCapsule c = const ResumeCapsuleBuilder().build(
        spec: b.spec,
        state: b.state,
        producedArtifacts: b.producedArtifacts,
      );
      expect(c.text, contains('Re-render 04 and 05'));
      expect(c.text, contains('[x] `01_lift_lobby_arrival.png`'));
    });

    test('the filename identifies the mission and the date', () {
      expect(
        build().suggestedFileName,
        'skyline-restaurant-bar-2026-09-02.mpx',
      );
    });
  });

  group('a damaged or foreign file is refused, not half-imported', () {
    test('truncation is caught by the digest', () {
      final String good = build().encode();
      final String truncated = good.replaceFirst('"score": 78', '"score": 12');
      expect(
        () => MissionBundle.decode(truncated),
        throwsA(
          isA<BundleFormatException>().having(
            (BundleFormatException e) => e.message,
            'message',
            contains('incomplete or was modified'),
          ),
        ),
      );
    });

    test('an unrelated JSON file is refused', () {
      expect(
        () => MissionBundle.decode('{"hello": "world"}'),
        throwsA(isA<BundleFormatException>()),
      );
    });

    test('a newer format tells the user to update rather than guessing', () {
      final String newer = build().encode().replaceFirst(
        '"schemaVersion": 1',
        '"schemaVersion": 99',
      );
      expect(
        () => MissionBundle.decode(newer),
        throwsA(
          isA<BundleFormatException>().having(
            (BundleFormatException e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('malformed JSON throws rather than returning a partial mission', () {
      expect(() => MissionBundle.decode('not json at all'), throwsA(anything));
    });
  });

  test('nothing device-scoped travels in the bundle', () {
    // A stale CLI session id imported onto another machine would "resume" into
    // a conversation that is not there.
    final String encoded = build().encode();
    expect(encoded.toLowerCase(), isNot(contains('sessionid')));
    expect(encoded.toLowerCase(), isNot(contains('workingdirectory')));
    expect(encoded.toLowerCase(), isNot(contains('claudepath')));
  });
}
