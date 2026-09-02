import 'package:meta/meta.dart';

import 'mp_state.dart';

/// What became of an attempt to read an `mpstate` block out of pasted text.
enum StateParseStatus {
  /// A complete, usable block.
  accepted,

  /// A block was found and is usable, but some fields were missing or had to
  /// be repaired. Safe to apply; worth showing the user what was recovered.
  partial,

  /// A block started but never finished. **State must not advance** — the tail
  /// of the reply, which is where `next` lives, is missing.
  truncated,

  /// A well-formed block belonging to a different mission. Almost always means
  /// the user pasted from the wrong chat.
  foreign,

  /// No block found at all. The text is kept; the user is offered manual
  /// reconciliation.
  unusable,
}

/// The result of parsing a paste. Always carries the original text.
///
/// The invariant this type exists to enforce: **a paste is never discarded.**
/// A parser bug, a model that forgot the block, or a clipboard that mangled it
/// must all degrade into something the user can recover from, because the
/// alternative is losing hours of work to a formatting accident.
@immutable
class StateParseResult {
  const StateParseResult({
    required this.status,
    required this.rawText,
    this.state,
    this.repairs = const <String>[],
    this.diagnostic,
    this.prose,
  });

  final StateParseStatus status;

  /// Exactly what was pasted, unmodified.
  final String rawText;

  final MpState? state;

  /// Human-readable notes on what had to be fixed to read the block.
  final List<String> repairs;

  /// Why parsing did not fully succeed.
  final String? diagnostic;

  /// The reply with the state block removed — the part meant for the user.
  final String? prose;

  bool get canAdvanceState =>
      status == StateParseStatus.accepted || status == StateParseStatus.partial;

  @override
  String toString() =>
      'StateParseResult(${status.name}${diagnostic == null ? '' : ': $diagnostic'})';
}

/// Reads the `mpstate` heartbeat out of a model reply that has been through a
/// chat UI and a system clipboard.
///
/// The wire format is line-oriented `key=value` rather than JSON, deliberately.
/// Text that round-trips through a chat app and a clipboard gets smart quotes
/// substituted, long lines reflowed, fences stripped by "copy as plain text",
/// and markdown emphasis applied by well-meaning renderers. JSON fails
/// all-or-nothing under any of those. A restricted line grammar degrades
/// field-by-field, and a human can repair it by eye.
class StateParser {
  const StateParser();

  static const String fenceTag = 'mpstate';

  /// Keys the app understands. Anything else is preserved in [MpState.extra].
  static const Set<String> knownKeys = <String>{
    'v',
    'task',
    'phase',
    'step',
    'cycle',
    'score',
    'next',
    'blocked',
    'ask',
  };

  StateParseResult parse(String pasted, {String? expectedTaskId}) {
    final List<String> repairs = <String>[];
    final String text = _normalise(pasted, repairs);

    final _Located? located = _locate(text, repairs);
    if (located == null) {
      return StateParseResult(
        status: StateParseStatus.unusable,
        rawText: pasted,
        repairs: repairs,
        prose: pasted.trim(),
        diagnostic:
            'No mpstate block found. The reply may have been copied without '
            'its final lines, or the assistant may have omitted the block.',
      );
    }

    final Map<String, String> fields = _tokenise(located.body, repairs);

    if (fields.isEmpty) {
      return StateParseResult(
        status: StateParseStatus.unusable,
        rawText: pasted,
        repairs: repairs,
        prose: located.prose,
        diagnostic:
            'An mpstate block was found but no readable key=value lines.',
      );
    }

    final String? taskId = fields['task'];

    // Wrong-chat detection comes before everything else. Silently applying
    // another mission's state is the worst outcome available here.
    if (expectedTaskId != null &&
        taskId != null &&
        taskId.isNotEmpty &&
        taskId != expectedTaskId) {
      return StateParseResult(
        status: StateParseStatus.foreign,
        rawText: pasted,
        repairs: repairs,
        prose: located.prose,
        state: _build(fields, taskId),
        diagnostic:
            'This block belongs to mission "$taskId", but this project is '
            '"$expectedTaskId". It looks like it was copied from a different '
            'conversation.',
      );
    }

    final String resolvedTask = taskId ?? expectedTaskId ?? '';
    final MpState state = _build(fields, resolvedTask);

    // Truncation is the dominant clipboard failure, and it is dangerous in a
    // specific way: the fields that go missing are the ones at the end, which
    // is where `next` lives. Advancing on a block whose `next` was cut off
    // would resume the run pointing at a stale action.
    if (located.unterminated && !fields.containsKey('ask')) {
      return StateParseResult(
        status: StateParseStatus.truncated,
        rawText: pasted,
        repairs: repairs,
        prose: located.prose,
        state: state,
        diagnostic:
            'The block was cut off before it finished. State was not advanced. '
            'Ask the assistant to reply with only the mpstate block.',
      );
    }

    final List<String> missing = <String>[
      for (final String k in const <String>['task', 'phase', 'next'])
        if (!fields.containsKey(k) || fields[k]!.trim().isEmpty) k,
    ];

    if (missing.isNotEmpty) {
      return StateParseResult(
        status: StateParseStatus.partial,
        rawText: pasted,
        repairs: repairs,
        prose: located.prose,
        state: state,
        diagnostic: 'Missing or empty: ${missing.join(', ')}.',
      );
    }

    return StateParseResult(
      status: repairs.isEmpty
          ? StateParseStatus.accepted
          : StateParseStatus.partial,
      rawText: pasted,
      repairs: repairs,
      prose: located.prose,
      state: state,
    );
  }

  MpState _build(Map<String, String> f, String taskId) {
    final Map<String, String> extra = <String, String>{
      for (final MapEntry<String, String> e in f.entries)
        if (!knownKeys.contains(e.key)) e.key: e.value,
    };
    return MpState(
      version: int.tryParse(f['v'] ?? '') ?? 1,
      taskId: taskId,
      phase: MissionPhase.parse(f['phase']),
      step: f['step']?.trim() ?? '',
      cycle: _int(f['cycle']),
      score: _double(f['score']),
      next: f['next']?.trim() ?? '',
      blocked: f['blocked'],
      ask: f['ask'],
      extra: extra,
    );
  }

  /// Strip the characters a chat UI and a clipboard introduce.
  String _normalise(String input, List<String> repairs) {
    String s = input;
    final String before = s;

    s = s
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        // Smart quotes, which break value comparison and look identical.
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        // Non-breaking and zero-width characters that survive a copy.
        .replaceAll(' ', ' ')
        .replaceAll('​', '')
        .replaceAll('‌', '')
        .replaceAll('‍', '')
        .replaceAll('﻿', '');

    if (s != before) {
      repairs.add('Normalised smart quotes and invisible characters.');
    }
    return s;
  }

  /// Find the block. Three strategies, most reliable first.
  ///
  /// Deliberately scans lines rather than using one large regex: an anchored
  /// `$` under `multiLine` matches at the end of *every* line, which silently
  /// truncates a lazy body capture to its first line.
  _Located? _locate(String text, List<String> repairs) {
    final List<String> lines = text.split('\n');

    // 1. A proper fence. Accept mpstate, mp-state, mp_state, any case.
    final RegExp open = RegExp(
      r'^[ \t]*(?:>[ \t]*)?```[ \t]*mp[-_]?state[ \t]*$',
      caseSensitive: false,
    );
    final RegExp close = RegExp(r'^[ \t]*(?:>[ \t]*)?```[ \t]*$');

    int openAt = -1;
    for (int i = 0; i < lines.length; i++) {
      // Last block wins: if a reply quotes the template and then emits a real
      // block, the real one is the later of the two.
      if (open.hasMatch(lines[i])) openAt = i;
    }
    if (openAt >= 0) {
      int closeAt = -1;
      for (int i = openAt + 1; i < lines.length; i++) {
        if (close.hasMatch(lines[i])) {
          closeAt = i;
          break;
        }
      }
      final bool unterminated = closeAt < 0;
      if (unterminated) {
        repairs.add('The block was not closed by a fence.');
      }
      final int bodyEnd = unterminated ? lines.length : closeAt;
      final List<String> prose = <String>[
        ...lines.sublist(0, openAt),
        if (!unterminated) ...lines.sublist(closeAt + 1),
      ];
      return _Located(
        body: lines.sublist(openAt + 1, bodyEnd).join('\n'),
        prose: prose.join('\n').trim(),
        unterminated: unterminated,
        fenced: true,
      );
    }

    // 2. No fence — "copy as plain text" strips them routinely. Look for a run
    //    of lines starting at a `v=` marker that reads like the block.
    final RegExp vMarker = RegExp(
      r'^[ \t]*(?:>[ \t]*)?(?:\*\*|__)?v(?:\*\*|__)?[ \t]*[=:][ \t]*\d+[ \t]*$',
      caseSensitive: false,
    );
    int startAt = -1;
    for (int i = 0; i < lines.length; i++) {
      if (vMarker.hasMatch(lines[i])) startAt = i;
    }
    if (startAt >= 0) {
      final List<String> kept = <String>[];
      for (int i = startAt; i < lines.length; i++) {
        final String line = lines[i];
        if (line.trim().isEmpty) break;
        if (line.trim() == '```') break;
        if (!_looksLikeField(line)) break;
        kept.add(line);
      }
      if (kept.length >= _minimumFallbackFields) {
        repairs.add(
          'The code fence was missing; recovered the block by its keys.',
        );
        return _Located(
          body: kept.join('\n'),
          prose: <String>[
            ...lines.sublist(0, startAt),
            ...lines.sublist(startAt + kept.length),
          ].join('\n').trim(),
          unterminated: false,
          fenced: false,
        );
      }
    }

    // 3. Last resort: the mission's own keys appear scattered in the reply.
    final RegExp anyKey = RegExp(
      r'^[ \t]*(?:>[ \t]*)?(?:\*\*|__)?(task|phase|next|step|cycle|score)(?:\*\*|__)?[ \t]*[=:]',
      caseSensitive: false,
    );
    final List<String> scattered = <String>[
      for (final String line in lines)
        if (anyKey.hasMatch(line)) line,
    ];
    if (scattered.length >= _minimumFallbackFields) {
      repairs.add('No block delimiters found; recovered scattered key lines.');
      return _Located(
        body: scattered.join('\n'),
        prose: text.trim(),
        unterminated: false,
        fenced: false,
      );
    }

    return null;
  }

  /// How many field lines an *unfenced* candidate needs before it is treated as
  /// a state block. Without this, a sentence like "v=1 is the version we use"
  /// parses as a block and silently advances the run.
  static const int _minimumFallbackFields = 3;

  static final RegExp _fieldLine = RegExp(
    r'^[ \t]*(?:>[ \t]*)?(?:[-*][ \t]+)?(?:\*\*|__)?([A-Za-z_][A-Za-z0-9_]*)(?:\*\*|__)?[ \t]*[=:][ \t]*(.*)$',
  );

  bool _looksLikeField(String line) => _fieldLine.hasMatch(line);

  /// Read `key=value` lines, tolerating everything a renderer might add.
  Map<String, String> _tokenise(String body, List<String> repairs) {
    final Map<String, String> out = <String, String>{};
    bool sawMarkdown = false;
    String? pendingKey;

    for (final String rawLine in body.split('\n')) {
      final String line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;
      if (line.trim() == '```') continue;

      final RegExpMatch? m = _fieldLine.firstMatch(line);
      if (m != null) {
        final String key = m.group(1)!.toLowerCase();
        String value = (m.group(2) ?? '').trim();
        if (rawLine.contains('**') || rawLine.contains('__')) {
          sawMarkdown = true;
        }
        // Strip a wrapping quote pair the model may have added.
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        }
        out[key] = value;
        pendingKey = key;
        continue;
      }

      // A continuation of the previous value, produced by line reflow in the
      // chat UI. Reattach it rather than dropping it.
      if (pendingKey != null && out.containsKey(pendingKey)) {
        out[pendingKey] = '${out[pendingKey]} ${line.trim()}'.trim();
        repairs.add('Rejoined a value that had been wrapped onto a new line.');
      }
    }

    if (sawMarkdown) {
      repairs.add('Removed markdown emphasis from key names.');
    }
    return out;
  }

  static int _int(String? v) {
    if (v == null) return 0;
    final Match? m = RegExp(r'-?\d+').firstMatch(v);
    return m == null ? 0 : int.tryParse(m.group(0)!) ?? 0;
  }

  static double _double(String? v) {
    if (v == null) return 0;
    final Match? m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(v);
    return m == null ? 0 : double.tryParse(m.group(0)!) ?? 0;
  }
}

@immutable
class _Located {
  const _Located({
    required this.body,
    required this.prose,
    required this.unterminated,
    required this.fenced,
  });

  final String body;
  final String prose;
  final bool unterminated;

  /// Whether a real code fence delimited the block. A fence is a strong signal;
  /// without one the parser demands more corroborating fields.
  final bool fenced;
}
