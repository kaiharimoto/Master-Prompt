import 'package:meta/meta.dart';

import '../stream/cli_event.dart';

/// What kind of wall the run hit.
///
/// These map onto the CLI's own closed `rateLimitType` enum, read from the
/// shipped binary: `five_hour`, `seven_day`, `seven_day_opus`,
/// `seven_day_sonnet`, `overage`. The distinction matters because the recovery
/// stories are completely different — a five-hour window is worth waiting out,
/// a weekly cap usually is not, and neither is helped by switching devices.
enum LimitKind {
  /// Nothing wrong.
  none,

  /// The rolling five-hour session window. Wait it out.
  fiveHour,

  /// A weekly cap. Account-scoped: switching to another device does not help.
  sevenDay,

  /// Weekly cap specific to Opus. Stepping down to Sonnet may keep working.
  sevenDayOpus,

  /// Weekly cap specific to Sonnet.
  sevenDaySonnet,

  /// Spend or overage limit. Needs a billing decision, not time.
  overage,

  /// Network, overload, or a 5xx. Retry with backoff.
  transient,

  /// Credentials expired or invalid. Never consumes the retry budget.
  auth,

  /// Something unrecoverable: missing binary, bad flags, vanished directory.
  fatal,

  /// Something went wrong and the signals do not identify it.
  unknown;

  /// Whether waiting will plausibly fix this.
  bool get isWaitable =>
      this == LimitKind.fiveHour ||
      this == LimitKind.sevenDay ||
      this == LimitKind.sevenDayOpus ||
      this == LimitKind.sevenDaySonnet ||
      this == LimitKind.transient;

  /// Whether this is an account-wide cap, so moving to the phone will not help.
  bool get isAccountWide =>
      this == LimitKind.sevenDay ||
      this == LimitKind.sevenDayOpus ||
      this == LimitKind.sevenDaySonnet ||
      this == LimitKind.overage;
}

/// Where a reset time came from. Recorded because confidence differs wildly:
/// an explicit timestamp is worth acting on, a guess is worth re-checking.
enum ResetSource { explicit, retryDelay, blockInference, backoffGuess, none }

/// The detector's conclusion about one run's failure.
@immutable
class LimitVerdict {
  const LimitVerdict({
    required this.kind,
    this.resetAt,
    this.source = ResetSource.none,
    this.confidence = 0,
    this.evidence = const <String>[],
  });

  static const LimitVerdict clear = LimitVerdict(kind: LimitKind.none);

  final LimitKind kind;

  /// When the limit is expected to lift, in UTC.
  final DateTime? resetAt;

  final ResetSource source;

  /// 0..1. Drives whether the supervisor waits confidently or re-probes early.
  final double confidence;

  /// Which signals contributed, for the run log and for the user.
  final List<String> evidence;

  bool get isLimited => kind != LimitKind.none;

  @override
  String toString() =>
      'LimitVerdict(${kind.name}, resetAt=$resetAt, ${source.name}, '
      'confidence=${confidence.toStringAsFixed(2)})';
}

/// Everything the detector gets to look at for one run attempt.
@immutable
class LimitSignals {
  const LimitSignals({
    this.stderr = '',
    this.stdoutText = '',
    this.events = const <CliEvent>[],
    this.exitCode,
    this.blockStartedAt,
    this.now,
  });

  /// Captured stderr. **This is the only channel carrying the words.**
  final String stderr;

  /// Any plain-text stdout, for the text telemetry tier.
  final String stdoutText;

  final List<CliEvent> events;
  final int? exitCode;

  /// When the current five-hour usage block began, if known. Enables the most
  /// robust reset estimate available, since it needs no text parsing at all.
  final DateTime? blockStartedAt;

  final DateTime? now;
}

/// Decides whether a failed run hit a usage limit, and when to try again.
///
/// Fuses four channels because no single one suffices. The most important
/// consequence of the CLI's actual behaviour: **the human-readable limit
/// message never appears in the stdout JSON stream**, because `Error.message`
/// is non-enumerable and the CLI serialises with a plain `JSON.stringify`.
/// A detector that greps stdout JSON would match nothing, forever.
class LimitDetector {
  const LimitDetector({this.patterns = defaultPatterns});

  /// Text patterns are the least reliable part of the design — wording changes
  /// between CLI versions — so they are data, overridable by the app and
  /// updatable without a release. Structured signals are checked first.
  final LimitPatterns patterns;

  static const LimitPatterns defaultPatterns = LimitPatterns();

  /// How long a five-hour block actually lasts, plus a small margin so a resume
  /// does not land microseconds early and burn an attempt.
  static const Duration fiveHourWindow = Duration(hours: 5, minutes: 5);

  LimitVerdict detect(LimitSignals signals) {
    final DateTime now = (signals.now ?? DateTime.now()).toUtc();
    final List<String> evidence = <String>[];

    final String haystack =
        '${signals.stderr}\n${signals.stdoutText}'.toLowerCase();

    // --- 1. Auth first. It must never consume the retry budget. -------------
    if (patterns.auth.any(haystack.contains)) {
      return LimitVerdict(
        kind: LimitKind.auth,
        confidence: 0.95,
        evidence: const <String>['stderr matched an authentication pattern'],
      );
    }

    // --- 2. Named limits from stderr ----------------------------------------
    LimitKind kind = LimitKind.none;
    if (patterns.sevenDayOpus.any(haystack.contains)) {
      kind = LimitKind.sevenDayOpus;
      evidence.add('stderr names an Opus weekly limit');
    } else if (patterns.sevenDaySonnet.any(haystack.contains)) {
      kind = LimitKind.sevenDaySonnet;
      evidence.add('stderr names a Sonnet weekly limit');
    } else if (patterns.sevenDay.any(haystack.contains)) {
      kind = LimitKind.sevenDay;
      evidence.add('stderr names a weekly limit');
    } else if (patterns.overage.any(haystack.contains)) {
      kind = LimitKind.overage;
      evidence.add('stderr names a spend or credit limit');
    } else if (patterns.fiveHour.any(haystack.contains)) {
      kind = LimitKind.fiveHour;
      evidence.add('stderr names a session limit');
    }

    // --- 3. Structured signals from the event stream ------------------------
    ApiErrorEvent? lastApiError;
    ResultEvent? result;
    for (final CliEvent e in signals.events) {
      if (e is ApiErrorEvent) lastApiError = e;
      if (e is ResultEvent) result = e;
    }

    if (kind == LimitKind.none && lastApiError != null) {
      if (lastApiError.looksRateLimited) {
        // A 429 with no words is still a rate limit. Without the text we cannot
        // tell five-hour from weekly, so assume the recoverable one and let the
        // resume attempt disambiguate.
        kind = LimitKind.fiveHour;
        evidence.add(
          'api_error reported ${lastApiError.status ?? 'a rate limit'} with no '
          'readable message',
        );
      } else if (lastApiError.attempt > 0) {
        kind = LimitKind.transient;
        evidence.add(
          'api_error retry attempt ${lastApiError.attempt}'
          '${lastApiError.maxRetries == null ? '' : ' of ${lastApiError.maxRetries}'}',
        );
      }
    }

    if (kind == LimitKind.none && result != null && !result.isSuccess) {
      if (result.hitBudget) {
        return LimitVerdict(
          kind: LimitKind.overage,
          confidence: 0.9,
          evidence: <String>['run stopped at its configured budget ceiling'],
        );
      }
      if (result.hitTurnLimit) {
        return const LimitVerdict(
          kind: LimitKind.fatal,
          confidence: 0.9,
          evidence: <String>['run stopped at its turn ceiling'],
        );
      }
      kind = LimitKind.unknown;
      evidence.add('result reported ${result.subtype}');
    }

    if (kind == LimitKind.none) {
      if (patterns.transient.any(haystack.contains)) {
        kind = LimitKind.transient;
        evidence.add('stderr matched a transient failure pattern');
      } else if (patterns.fatal.any(haystack.contains)) {
        return LimitVerdict(
          kind: LimitKind.fatal,
          confidence: 0.8,
          evidence: const <String>['stderr matched an unrecoverable pattern'],
        );
      } else if ((signals.exitCode ?? 0) != 0) {
        kind = LimitKind.unknown;
        evidence.add('process exited with ${signals.exitCode}');
      }
    }

    if (kind == LimitKind.none) return LimitVerdict.clear;

    final _Reset reset = _estimateReset(
      kind: kind,
      haystack: '${signals.stderr}\n${signals.stdoutText}',
      apiError: lastApiError,
      blockStartedAt: signals.blockStartedAt,
      now: now,
    );
    evidence.addAll(reset.evidence);

    return LimitVerdict(
      kind: kind,
      resetAt: reset.at,
      source: reset.source,
      confidence: _confidence(kind, reset.source),
      evidence: List<String>.unmodifiable(evidence),
    );
  }

  double _confidence(LimitKind kind, ResetSource source) {
    double base = switch (kind) {
      LimitKind.auth || LimitKind.fatal => 0.9,
      LimitKind.fiveHour ||
      LimitKind.sevenDay ||
      LimitKind.sevenDayOpus ||
      LimitKind.sevenDaySonnet ||
      LimitKind.overage => 0.8,
      LimitKind.transient => 0.6,
      LimitKind.unknown => 0.3,
      LimitKind.none => 1.0,
    };
    base += switch (source) {
      ResetSource.explicit => 0.15,
      ResetSource.retryDelay => 0.1,
      ResetSource.blockInference => 0.05,
      ResetSource.backoffGuess => -0.1,
      ResetSource.none => 0,
    };
    return base.clamp(0, 1);
  }

  /// Reset-time ladder. First success wins, but the source is always recorded
  /// so the supervisor knows how much to trust it.
  _Reset _estimateReset({
    required LimitKind kind,
    required String haystack,
    required ApiErrorEvent? apiError,
    required DateTime? blockStartedAt,
    required DateTime now,
  }) {
    // 1. An explicit epoch. The CLI's own rate-limit bookkeeping stores this as
    //    epoch *seconds*; reading it as milliseconds would schedule a resume
    //    fifty years out, so the unit is asserted by range.
    final Match? epoch =
        RegExp(r'\b(1[6-9]\d{8}|2[0-9]{9})\b').firstMatch(haystack);
    if (epoch != null) {
      final int seconds = int.parse(epoch.group(1)!);
      final DateTime at =
          DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
      if (at.isAfter(now) && at.difference(now) < const Duration(days: 30)) {
        return _Reset(at, ResetSource.explicit, <String>[
          'reset timestamp found in output',
        ]);
      }
    }

    // 2. A relative delay the CLI stated.
    final int? ms = apiError?.retryInMs;
    if (ms != null && ms > 0) {
      return _Reset(
        now.add(Duration(milliseconds: ms)),
        ResetSource.retryDelay,
        <String>['CLI asked to retry in ${(ms / 1000).round()}s'],
      );
    }

    // 3. Five-hour block inference. The most robust estimate available: it
    //    needs no text parsing, no locale assumptions, and no CLI cooperation.
    if (kind == LimitKind.fiveHour && blockStartedAt != null) {
      final DateTime at = blockStartedAt.toUtc().add(fiveHourWindow);
      if (at.isAfter(now)) {
        return _Reset(at, ResetSource.blockInference, <String>[
          'inferred from the start of the current five-hour block',
        ]);
      }
      // The block already elapsed; the limit should be liftable now.
      return _Reset(
        now.add(const Duration(minutes: 2)),
        ResetSource.blockInference,
        <String>['five-hour block has already elapsed'],
      );
    }

    // 4. A guess, clearly labelled as one.
    final Duration guess = switch (kind) {
      LimitKind.fiveHour => fiveHourWindow,
      LimitKind.sevenDay ||
      LimitKind.sevenDayOpus ||
      LimitKind.sevenDaySonnet => const Duration(hours: 12),
      LimitKind.transient => const Duration(minutes: 2),
      _ => const Duration(minutes: 15),
    };
    return _Reset(now.add(guess), ResetSource.backoffGuess, <String>[
      'no reset time available; estimated ${guess.inMinutes} minutes',
    ]);
  }
}

@immutable
class _Reset {
  const _Reset(this.at, this.source, this.evidence);

  final DateTime at;
  final ResetSource source;
  final List<String> evidence;
}

/// Text patterns, kept as data because CLI wording is the least stable part of
/// this contract. All entries are matched against lowercased output.
@immutable
class LimitPatterns {
  const LimitPatterns({
    this.fiveHour = const <String>[
      "you've hit your session limit",
      'hit your session limit',
      'session limit reached',
      '5-hour limit',
      'five-hour limit',
    ],
    this.sevenDay = const <String>[
      "you've hit your weekly limit",
      'hit your weekly limit',
      'weekly limit reached',
      '7-day limit',
    ],
    this.sevenDayOpus = const <String>[
      'hit your opus limit',
      'opus weekly limit',
      'opus limit reached',
    ],
    this.sevenDaySonnet = const <String>[
      'hit your sonnet limit',
      'sonnet weekly limit',
    ],
    this.overage = const <String>[
      'spend limit',
      'credit balance is too low',
      'insufficient credit',
      'billing',
      'overage',
    ],
    this.transient = const <String>[
      'overloaded',
      'timed out',
      'timeout',
      'econnreset',
      'socket hang up',
      'network error',
      'service unavailable',
      'internal server error',
      '502',
      '503',
      '529',
    ],
    this.auth = const <String>[
      'invalid api key',
      'authentication_error',
      'authentication failed',
      'unauthorized',
      'please run /login',
      'oauth token expired',
      'credentials',
    ],
    this.fatal = const <String>[
      'command not found',
      'no such file or directory',
      'enoent',
      'is not recognized as an internal or external command',
      'cannot be launched inside another claude code session',
    ],
  });

  final List<String> fiveHour;
  final List<String> sevenDay;
  final List<String> sevenDayOpus;
  final List<String> sevenDaySonnet;
  final List<String> overage;
  final List<String> transient;
  final List<String> auth;
  final List<String> fatal;

  Map<String, Object?> toJson() => <String, Object?>{
    'fiveHour': fiveHour,
    'sevenDay': sevenDay,
    'sevenDayOpus': sevenDayOpus,
    'sevenDaySonnet': sevenDaySonnet,
    'overage': overage,
    'transient': transient,
    'auth': auth,
    'fatal': fatal,
  };

  static LimitPatterns fromJson(Map<String, Object?> j) {
    List<String> pick(String key, List<String> fallback) {
      final Object? raw = j[key];
      if (raw is! List<Object?> || raw.isEmpty) return fallback;
      return <String>[for (final Object? v in raw) '$v'.toLowerCase()];
    }

    const LimitPatterns d = LimitPatterns();
    return LimitPatterns(
      fiveHour: pick('fiveHour', d.fiveHour),
      sevenDay: pick('sevenDay', d.sevenDay),
      sevenDayOpus: pick('sevenDayOpus', d.sevenDayOpus),
      sevenDaySonnet: pick('sevenDaySonnet', d.sevenDaySonnet),
      overage: pick('overage', d.overage),
      transient: pick('transient', d.transient),
      auth: pick('auth', d.auth),
      fatal: pick('fatal', d.fatal),
    );
  }
}
