import 'package:meta/meta.dart';

/// One option the model offered for one question.
@immutable
class AskedOption {
  const AskedOption({
    required this.key,
    required this.label,
    this.consequence = '',
    this.recommended = false,
  });

  /// `a`, `b`, `c` — what the user picks.
  final String key;

  /// The answer itself, as it would be taken.
  final String label;

  /// One line on what choosing it would mean for the build. The prompt asks
  /// for the consequence rather than the label restated, because "twelve
  /// seats" is a label and "twelve seats, so the room reads as intimate and
  /// the pass can stay open" is a choice you can actually make.
  final String consequence;

  /// Marked, never pre-selected. **A recommendation is not an answer** — the
  /// standing rule of this project — and a button that is already pressed is
  /// exactly the presumption that rule exists to prevent.
  final bool recommended;
}

/// One question, with everything needed to answer it by tapping.
@immutable
class AskedQuestion {
  const AskedQuestion({
    required this.key,
    required this.text,
    required this.options,
  });

  /// `1`, `2`, `3` — the model's own numbering, so an answer composed from
  /// these lines up with what it asked.
  final String key;

  final String text;
  final List<AskedOption> options;
}

/// The questions in a reply, if it asked any.
@immutable
class AskedRound {
  const AskedRound({
    required this.raw,
    this.questions = const <AskedQuestion>[],
    this.diagnostic,
  });

  /// Never discarded. Every parse outcome in this project keeps the text it
  /// was given, so a reply the app could not read is still a reply the user
  /// can read.
  final String raw;

  final List<AskedQuestion> questions;

  /// What was seen instead, when nothing was found. Written to be shown, not
  /// logged: a round that settled everything asks nothing, and that is not a
  /// failure.
  final String? diagnostic;

  bool get found => questions.isNotEmpty;
}

/// Reads the `mpask` block a questioning round ends with.
///
/// A round comes back at four or five thousand characters — two to four
/// questions, each with two to four options and a line on what each would
/// mean. Reading all of it and then typing "1, 2, 3" into a box is the slowest
/// part of the whole interview, and it is the part a machine can do.
///
/// **The block is line-oriented, and that is not a style choice.**
/// `SpecPatchParser` finds a patch by brace-matching *with or without a fence*,
/// because a chat app's copy button copies a block's contents and loses the
/// backticks. A questions block written as JSON would therefore be picked up
/// as a patch — the answers to questions nobody had agreed to yet. The same
/// reasoning already keeps `mpstate` line-oriented, with the added benefit
/// that a truncated line grammar loses one option rather than the whole round.
///
/// ```
/// mpask
/// q1=How many seats should the room hold?
/// q1a=Twelve|a private room, and the pass can stay open
/// q1b=Twenty|the brief already says intimate|recommended
/// q1c=Forty|a proper restaurant, and the bar stops being the point
/// q2=Real service depth behind the bar, or a facade?
/// q2a=Real depth|every bottle and tool modelled|recommended
/// q2b=Facade|reads at distance, falls apart in close-ups
/// ```
///
/// The prose above the block still carries the reasoning: this is an index
/// into the reply, not a replacement for it. On a phone the questions are read
/// in the chat app and the block is invisible; in Master Prompt, on either
/// platform, it becomes buttons.
class AskedRoundParser {
  const AskedRoundParser();

  static const String fenceTag = 'mpask';

  /// `q1=…` opens a question; `q1a=…` adds an option to it.
  static final RegExp _line = RegExp(
    r'^[ \t]*(?:>[ \t]*)?q[ \t]*(\d+)[ \t]*([a-z])?[ \t]*=[ \t]*(.*)$',
    caseSensitive: false,
  );

  AskedRound parse(String reply) {
    final String body = _blockIn(reply) ?? reply;

    final List<AskedQuestion> questions = <AskedQuestion>[];
    final Map<String, List<AskedOption>> options =
        <String, List<AskedOption>>{};
    final Map<String, String> text = <String, String>{};
    final List<String> order = <String>[];

    for (final String line in body.split('\n')) {
      final RegExpMatch? m = _line.firstMatch(line);
      if (m == null) continue;

      final String q = m.group(1)!;
      final String? opt = m.group(2)?.toLowerCase();
      final String value = m.group(3)!.trim();
      if (value.isEmpty) continue;

      if (opt == null) {
        if (!order.contains(q)) order.add(q);
        text[q] = value;
      } else {
        // An option before its question still belongs to it; the model
        // occasionally writes them out of order and losing the whole question
        // over that would be absurd.
        if (!order.contains(q)) order.add(q);
        (options[q] ??= <AskedOption>[]).add(_option(opt, value));
      }
    }

    for (final String q in order) {
      final List<AskedOption> opts = options[q] ?? const <AskedOption>[];
      // A question with nothing to pick from is a sentence, not a question,
      // and rendering it as an empty card would be worse than leaving it in
      // the prose where the user can read it.
      if (opts.length < 2) continue;
      questions.add(
        AskedQuestion(key: q, text: text[q] ?? 'Question $q', options: opts),
      );
    }

    return AskedRound(
      raw: reply,
      questions: questions,
      diagnostic: questions.isEmpty ? _why(reply) : null,
    );
  }

  /// Fields are separated by `|`, the same as an `mpspec` value, so there is
  /// one separator convention in the project rather than two.
  AskedOption _option(String key, String value) {
    final List<String> parts = value
        .split('|')
        .map((String s) => s.trim())
        .toList();
    final bool recommended = parts.any(
      (String s) => s.toLowerCase() == 'recommended',
    );
    final List<String> rest = parts
        .where((String s) => s.toLowerCase() != 'recommended')
        .toList();
    return AskedOption(
      key: key,
      label: rest.isEmpty ? value : rest.first,
      consequence: rest.length > 1 ? rest.sublist(1).join(' — ') : '',
      recommended: recommended,
    );
  }

  String? _blockIn(String reply) {
    final RegExp open = RegExp(
      '^[ \\t]*(?:>[ \\t]*)?`{3,}[ \\t]*$fenceTag[ \\t]*\$',
      multiLine: true,
      caseSensitive: false,
    );
    final RegExpMatch? start = open.firstMatch(reply);
    if (start == null) return null;

    final String after = reply.substring(start.end);
    final RegExp close = RegExp(
      r'^[ \t]*(?:>[ \t]*)?`{3,}[ \t]*$',
      multiLine: true,
    );
    final RegExpMatch? end = close.firstMatch(after);
    // An unclosed fence means the reply was cut off. Take what arrived rather
    // than nothing: a truncated line grammar costs one option.
    return end == null ? after : after.substring(0, end.start);
  }

  /// Why there was nothing to show, in words worth putting on screen.
  String _why(String reply) {
    if (reply.trim().isEmpty) return 'The reply was empty.';
    if (reply.contains(fenceTag)) {
      return 'There is an $fenceTag block, but no `q1=` lines could be read '
          'in it. It may have been cut off.';
    }
    return 'No $fenceTag block in this reply, so the questions are in the '
        'prose above and have to be answered in your own words.';
  }
}

/// Turns a set of choices into the message that goes back.
///
/// Sends the option's key **and** its label. A bare "1, 2, 3" is what the user
/// types today, and it depends on the model remembering exactly what it
/// offered several thousand characters ago; restating the choice costs a line
/// and removes the ambiguity.
@immutable
class ComposedAnswer {
  const ComposedAnswer({required this.text, required this.answered});

  final String text;

  /// How many questions were actually answered, so the screen can say what is
  /// still outstanding rather than sending a half-answer silently.
  final int answered;
}

/// What the user picked for one question: an option, their own words, or an
/// explicit deferral.
@immutable
class Choice {
  const Choice.option(this.optionKey) : ownWords = null, deferred = false;
  const Choice.ownWords(String words)
    : optionKey = null,
      ownWords = words,
      deferred = false;
  const Choice.deferred() : optionKey = null, ownWords = null, deferred = true;

  final String? optionKey;
  final String? ownWords;

  /// "You choose." Different from the model assuming: the user said so, and
  /// the value still arrives as `proposed` and still has to be accepted.
  final bool deferred;
}

abstract final class AnswerComposer {
  static ComposedAnswer compose(
    AskedRound round,
    Map<String, Choice> choices, {
    String note = '',
  }) {
    final StringBuffer b = StringBuffer();
    int answered = 0;

    for (final AskedQuestion q in round.questions) {
      final Choice? choice = choices[q.key];
      if (choice == null) continue;
      answered++;

      if (choice.deferred) {
        b.writeln('${q.key}. No preference — use your judgement.');
        continue;
      }
      if (choice.ownWords != null) {
        b.writeln('${q.key}. ${choice.ownWords!.trim()}');
        continue;
      }
      final AskedOption? picked = q.options
          .where((AskedOption o) => o.key == choice.optionKey)
          .firstOrNull;
      if (picked == null) continue;
      b.writeln('${q.key}. (${picked.key}) ${picked.label}');
    }

    if (note.trim().isNotEmpty) {
      if (b.isNotEmpty) b.writeln();
      b.writeln(note.trim());
    }
    return ComposedAnswer(text: b.toString().trim(), answered: answered);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
