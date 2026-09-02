import 'package:mp_runner/mp_runner.dart';
import 'package:test/test.dart';

final DateTime t0 = DateTime.utc(2026, 9, 2, 12, 0, 0);

CliEvent ev(String json) => CliEvent.parse(json);

void main() {
  const LimitDetector d = LimitDetector();

  group('a healthy run is not mistaken for a limit', () {
    test('clean success', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          exitCode: 0,
          now: t0,
          events: <CliEvent>[
            ev('{"type":"result","subtype":"success","total_cost_usd":1.2}'),
          ],
        ),
      );
      expect(v.isLimited, isFalse);
      expect(v.kind, LimitKind.none);
    });

    test('prose that merely mentions limits', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          exitCode: 0,
          now: t0,
          stdoutText: 'I have documented the rate limit handling in the README.',
        ),
      );
      expect(v.isLimited, isFalse);
    });
  });

  group('reads the limit words from stderr, where they actually live', () {
    test('five-hour session limit', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: "Error: You've hit your session limit. Try again later.",
          exitCode: 1,
          now: t0,
        ),
      );
      expect(v.kind, LimitKind.fiveHour);
      expect(v.kind.isWaitable, isTrue);
      expect(v.kind.isAccountWide, isFalse);
      expect(v.resetAt, isNotNull);
    });

    test('weekly limit is recognised as account-wide', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: "You've hit your weekly limit.",
          exitCode: 1,
          now: t0,
        ),
      );
      expect(v.kind, LimitKind.sevenDay);
      expect(v.kind.isAccountWide, isTrue,
          reason: 'switching to the phone will not help');
    });

    test('Opus-specific weekly limit is distinguished', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: "You've hit your Opus limit for this week.",
          exitCode: 1,
          now: t0,
        ),
      );
      expect(v.kind, LimitKind.sevenDayOpus);
    });

    test('spend limits are billing, not time', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: 'Credit balance is too low.',
          exitCode: 1,
          now: t0,
        ),
      );
      expect(v.kind, LimitKind.overage);
      expect(v.kind.isWaitable, isFalse);
    });
  });

  group('auth never consumes the retry budget', () {
    test('an auth failure short-circuits everything else', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: 'Invalid API key. Please run /login.',
          exitCode: 1,
          now: t0,
          events: <CliEvent>[
            ev('{"type":"system","subtype":"api_error","error_status":429}'),
          ],
        ),
      );
      expect(v.kind, LimitKind.auth,
          reason: 'auth must win even alongside a 429');
      expect(v.kind.isWaitable, isFalse);
      expect(v.resetAt, isNull);
    });
  });

  group('works from structured signals alone, with no readable message', () {
    // This is the realistic desktop case: Error.message is non-enumerable, so
    // the stdout JSON stream carries a 429 and nothing else.
    test('a bare 429 api_error is treated as a recoverable session limit', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          exitCode: 1,
          now: t0,
          events: <CliEvent>[
            ev('{"type":"system","subtype":"api_error","error_status":429,'
                '"retryAttempt":3,"maxRetries":5,"error":{}}'),
          ],
        ),
      );
      expect(v.kind, LimitKind.fiveHour);
      expect(
        v.evidence.any((String e) => e.contains('no readable message')),
        isTrue,
      );
    });

    test('retries without a 429 read as transient', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          exitCode: 1,
          now: t0,
          events: <CliEvent>[
            ev('{"type":"system","subtype":"api_error","error_status":503,'
                '"retryAttempt":2}'),
          ],
        ),
      );
      expect(v.kind, LimitKind.transient);
    });

    test('the budget ceiling is reported as overage, not a rate limit', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          exitCode: 1,
          now: t0,
          events: <CliEvent>[
            ev('{"type":"result","subtype":"error_max_budget_usd"}'),
          ],
        ),
      );
      expect(v.kind, LimitKind.overage);
    });

    test('the turn ceiling is fatal, not waitable', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          exitCode: 1,
          now: t0,
          events: <CliEvent>[
            ev('{"type":"result","subtype":"error_max_turns"}'),
          ],
        ),
      );
      expect(v.kind, LimitKind.fatal);
      expect(v.kind.isWaitable, isFalse);
    });

    test('a missing binary is fatal', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: 'claude: command not found',
          exitCode: 127,
          now: t0,
        ),
      );
      expect(v.kind, LimitKind.fatal);
    });
  });

  group('the reset-time ladder', () {
    test('an explicit epoch is read as seconds, never milliseconds', () {
      // 1788369600 = 2026-09-02T17:20:00Z. Read as millis this would land in
      // 1970 and the resume would fire instantly, in a loop.
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: "You've hit your session limit. resetsAt: 1788369600",
          exitCode: 1,
          now: t0,
        ),
      );
      expect(v.source, ResetSource.explicit);
      expect(v.resetAt!.year, 2026);
      expect(v.resetAt!.isAfter(t0), isTrue);
      expect(v.resetAt!.difference(t0), lessThan(const Duration(days: 30)));
    });

    test('a stale timestamp is ignored rather than firing an instant loop', () {
      // A reset time already in the past must not be trusted: acting on it
      // schedules an immediate resume, which fails, which reads the same stale
      // timestamp again — a tight loop that burns the retry budget in seconds.
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: "You've hit your session limit. resetsAt: 1788264000",
          exitCode: 1,
          now: t0,
        ),
      );
      expect(v.source, isNot(ResetSource.explicit));
      expect(v.resetAt!.isAfter(t0), isTrue);
    });

    test('a stated retry delay is used when no timestamp exists', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: "You've hit your session limit.",
          exitCode: 1,
          now: t0,
          events: <CliEvent>[
            ev('{"type":"system","subtype":"api_error","error_status":429,'
                '"retryInMs":900000}'),
          ],
        ),
      );
      expect(v.source, ResetSource.retryDelay);
      expect(v.resetAt, t0.add(const Duration(minutes: 15)));
    });

    test('five-hour block inference needs no text at all', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: "You've hit your session limit.",
          exitCode: 1,
          now: t0,
          blockStartedAt: t0.subtract(const Duration(hours: 4)),
        ),
      );
      expect(v.source, ResetSource.blockInference);
      // Block began 4h ago, window is 5h05m, so ~65 minutes remain.
      expect(v.resetAt!.difference(t0).inMinutes, closeTo(65, 1));
    });

    test('an already-elapsed block schedules an immediate retry', () {
      final LimitVerdict v = d.detect(
        LimitSignals(
          stderr: "You've hit your session limit.",
          exitCode: 1,
          now: t0,
          blockStartedAt: t0.subtract(const Duration(hours: 9)),
        ),
      );
      expect(v.source, ResetSource.blockInference);
      expect(v.resetAt!.difference(t0), lessThan(const Duration(minutes: 5)));
    });

    test('a guess is labelled as one and lowers confidence', () {
      final LimitVerdict guessed = d.detect(
        LimitSignals(
          stderr: "You've hit your session limit.",
          exitCode: 1,
          now: t0,
        ),
      );
      final LimitVerdict known = d.detect(
        LimitSignals(
          stderr: "You've hit your session limit. resetsAt: 1788369600",
          exitCode: 1,
          now: t0,
        ),
      );
      expect(guessed.source, ResetSource.backoffGuess);
      expect(guessed.confidence, lessThan(known.confidence));
      expect(
        guessed.evidence.any((String e) => e.contains('estimated')),
        isTrue,
      );
    });

    test('transient failures retry in minutes, not hours', () {
      final LimitVerdict v = d.detect(
        LimitSignals(stderr: 'Service unavailable', exitCode: 1, now: t0),
      );
      expect(v.kind, LimitKind.transient);
      expect(v.resetAt!.difference(t0), lessThan(const Duration(minutes: 10)));
    });
  });

  group('patterns are data, so wording changes do not require a release', () {
    test('a custom pattern set is honoured', () {
      const LimitDetector custom = LimitDetector(
        patterns: LimitPatterns(fiveHour: <String>['quota exhausted for now']),
      );
      final LimitVerdict v = custom.detect(
        LimitSignals(
          stderr: 'Quota exhausted for now, friend.',
          exitCode: 1,
          now: t0,
        ),
      );
      expect(v.kind, LimitKind.fiveHour);
    });

    test('patterns survive a JSON round trip and fall back when empty', () {
      final LimitPatterns p =
          LimitPatterns.fromJson(const LimitPatterns().toJson());
      expect(p.fiveHour, contains("you've hit your session limit"));

      final LimitPatterns empty =
          LimitPatterns.fromJson(<String, Object?>{'fiveHour': <Object?>[]});
      expect(empty.fiveHour, isNotEmpty,
          reason: 'an empty override must not blind the detector');
    });
  });

  group('unknown failures are surfaced, never silently swallowed', () {
    test('a nonzero exit with no recognisable signal is unknown', () {
      final LimitVerdict v =
          d.detect(LimitSignals(stderr: 'weird', exitCode: 3, now: t0));
      expect(v.kind, LimitKind.unknown);
      expect(v.confidence, lessThan(0.5));
      expect(v.evidence, isNotEmpty);
    });
  });
}
