import 'dart:convert';

import 'package:meta/meta.dart';

/// One line of `--output-format stream-json`, decoded.
///
/// The subtypes here were read out of the shipped binary, not documentation.
/// In particular the retry/error event is `system/api_error`; there is no
/// `system/api_retry`, despite widespread claims otherwise.
@immutable
sealed class CliEvent {
  const CliEvent(this.raw);

  /// The decoded line, kept whole so nothing is lost to an incomplete model.
  final Map<String, Object?> raw;

  /// Decode one NDJSON line. Returns [MalformedEvent] rather than throwing:
  /// a single unparseable line must not take down a twelve-hour run.
  static CliEvent parse(String line) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) return MalformedEvent(const <String, Object?>{}, line);
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return MalformedEvent(const <String, Object?>{}, line);
    }
    if (decoded is! Map<String, Object?>) {
      return MalformedEvent(const <String, Object?>{}, line);
    }

    switch (decoded['type']) {
      case 'system':
        switch (decoded['subtype']) {
          case 'init':
            return InitEvent(decoded);
          case 'api_error':
            return ApiErrorEvent(decoded);
          case 'compact_boundary':
            return CompactionEvent(decoded);
          default:
            return SystemEvent(decoded);
        }
      case 'assistant':
        return AssistantEvent(decoded);
      case 'user':
        return UserEvent(decoded);
      case 'stream_event':
        return PartialEvent(decoded);
      case 'result':
        return ResultEvent(decoded);
      default:
        return SystemEvent(decoded);
    }
  }

  String? get sessionId => raw['session_id'] as String?;
}

/// First event of a run. Confirms which session the CLI actually used.
class InitEvent extends CliEvent {
  const InitEvent(super.raw);

  String? get model => raw['model'] as String?;

  List<String> get tools => <String>[
    for (final Object? t
        in (raw['tools'] as List<Object?>? ?? const <Object?>[]))
      '$t',
  ];
}

/// An API-level error or retry.
///
/// Critically, this event **cannot carry the human-readable error text**:
/// `Error.message` is a non-enumerable property and the CLI serialises with a
/// plain `JSON.stringify`, so the message is erased. What survives is timing
/// and status. The words live only on stderr.
class ApiErrorEvent extends CliEvent {
  const ApiErrorEvent(super.raw);

  int? get status => (raw['error_status'] as num?)?.toInt();

  int get attempt =>
      (raw['retryAttempt'] as num?)?.toInt() ??
      (raw['attempt'] as num?)?.toInt() ??
      0;

  int? get maxRetries =>
      (raw['maxRetries'] as num?)?.toInt() ??
      (raw['max_retries'] as num?)?.toInt();

  /// Milliseconds the CLI intends to wait before its next attempt.
  int? get retryInMs =>
      (raw['retryInMs'] as num?)?.toInt() ??
      (raw['retry_delay_ms'] as num?)?.toInt();

  /// A category string when one is present. Often absent.
  String? get category {
    final Object? e = raw['error'];
    if (e is String) return e;
    if (e is Map<String, Object?>) return e['type'] as String?;
    return null;
  }

  bool get looksRateLimited =>
      status == 429 ||
      (category?.contains('rate') ?? false) ||
      (category?.contains('billing') ?? false);
}

/// Context was compacted. Carries how much was dropped.
///
/// Only `compact_boundary` reaches the stream; `microcompact_boundary` is not
/// forwarded, so context can thin silently. That is why the mission prompt
/// requires an `mpstate` heartbeat on the desktop too — a divergence between
/// the model's claim and the app's projection is the only available signal.
class CompactionEvent extends CliEvent {
  const CompactionEvent(super.raw);

  Map<String, Object?> get _meta =>
      raw['compact_metadata'] as Map<String, Object?>? ??
      const <String, Object?>{};

  String? get trigger => _meta['trigger'] as String?;

  int? get preTokens => (_meta['pre_tokens'] as num?)?.toInt();
}

class AssistantEvent extends CliEvent {
  const AssistantEvent(super.raw);

  /// Concatenated text blocks of the assistant message.
  String get text {
    final Object? msg = raw['message'];
    if (msg is! Map<String, Object?>) return '';
    final Object? content = msg['content'];
    if (content is String) return content;
    if (content is! List<Object?>) return '';
    final StringBuffer b = StringBuffer();
    for (final Object? block in content) {
      if (block is Map<String, Object?> && block['type'] == 'text') {
        b.write(block['text'] ?? '');
      }
    }
    return b.toString();
  }

  /// Names of tools invoked in this message, for the run timeline.
  List<String> get toolUses {
    final Object? msg = raw['message'];
    if (msg is! Map<String, Object?>) return const <String>[];
    final Object? content = msg['content'];
    if (content is! List<Object?>) return const <String>[];
    return <String>[
      for (final Object? block in content)
        if (block is Map<String, Object?> && block['type'] == 'tool_use')
          '${block['name']}',
    ];
  }

  /// Null for the main agent; set for a subagent's messages.
  String? get parentToolUseId => raw['parent_tool_use_id'] as String?;

  bool get isSubagent => parentToolUseId != null;
}

class UserEvent extends CliEvent {
  const UserEvent(super.raw);
}

/// A partial chunk when `--include-partial-messages` is on.
class PartialEvent extends CliEvent {
  const PartialEvent(super.raw);

  String? get textDelta {
    final Object? e = raw['event'];
    if (e is! Map<String, Object?>) return null;
    final Object? d = e['delta'];
    if (d is! Map<String, Object?>) return null;
    return d['text'] as String?;
  }
}

/// Terminal event. The subtype set is closed and was read from the binary.
class ResultEvent extends CliEvent {
  const ResultEvent(super.raw);

  String get subtype => '${raw['subtype']}';

  bool get isSuccess => subtype == 'success';

  bool get hitBudget => subtype == 'error_max_budget_usd';

  bool get hitTurnLimit => subtype == 'error_max_turns';

  String get text => '${raw['result'] ?? ''}';

  double? get costUsd => (raw['total_cost_usd'] as num?)?.toDouble();

  Map<String, Object?> get usage =>
      raw['usage'] as Map<String, Object?>? ?? const <String, Object?>{};
}

/// Any other `system` event.
class SystemEvent extends CliEvent {
  const SystemEvent(super.raw);

  String? get subtype => raw['subtype'] as String?;
}

/// A line that could not be decoded. Kept rather than dropped.
class MalformedEvent extends CliEvent {
  const MalformedEvent(super.raw, this.line);

  final String line;
}
