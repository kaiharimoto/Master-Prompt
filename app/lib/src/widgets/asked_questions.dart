import 'package:flutter/material.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

/// The questions a round asked, as things to tap.
///
/// A round comes back at four or five thousand characters. Reading all of it,
/// scrolling to the bottom and typing "1, 2, 3" into a box is the slowest part
/// of the interview and the part with nothing to think about in it — the
/// thinking happened while reading the options.
///
/// Two rules from the project survive here intact and are worth restating,
/// because a button makes both easy to break:
///
/// **A recommendation is marked, never pre-selected.** Nothing is chosen when
/// this appears. A pre-pressed button is exactly the presumption the rule
/// exists to prevent, and it would walk straight past the readiness gate.
///
/// **There is no "take all the recommendations".** Every question is picked
/// one at a time, deliberately. The saving is in not typing, not in not
/// deciding.
class AskedQuestions extends StatefulWidget {
  const AskedQuestions({
    required this.round,
    required this.onSend,
    this.busy = false,
    super.key,
  });

  final AskedRound round;

  /// Called with the composed answer. Sending stays the caller's job so this
  /// widget works the same on a desktop, where it goes down a pipe, and on a
  /// phone, where it goes to the clipboard.
  final ValueChanged<String> onSend;

  final bool busy;

  @override
  State<AskedQuestions> createState() => _AskedQuestionsState();
}

class _AskedQuestionsState extends State<AskedQuestions> {
  final Map<String, Choice> _choices = <String, Choice>{};
  final Map<String, TextEditingController> _ownWords =
      <String, TextEditingController>{};
  final TextEditingController _note = TextEditingController();

  /// Which question has its "something else" box open.
  final Set<String> _writing = <String>{};

  @override
  void dispose() {
    for (final TextEditingController c in _ownWords.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  ComposedAnswer get _answer =>
      AnswerComposer.compose(widget.round, _choices, note: _note.text);

  void _pick(String question, Choice choice) {
    setState(() {
      _choices[question] = choice;
      _writing.remove(question);
    });
  }

  void _openOwnWords(String question) {
    setState(() {
      _writing.add(question);
      _choices.remove(question);
    });
    _ownWords[question] ??= TextEditingController();
  }

  void _commitOwnWords(String question) {
    final String text = _ownWords[question]?.text.trim() ?? '';
    if (text.isEmpty) {
      setState(() => _writing.remove(question));
      return;
    }
    _pick(question, Choice.ownWords(text));
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final int total = widget.round.questions.length;
    final ComposedAnswer answer = _answer;
    final int outstanding = total - answer.answered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final AskedQuestion q in widget.round.questions) ...<Widget>[
          _Question(
            question: q,
            chosen: _choices[q.key],
            writing: _writing.contains(q.key),
            controller: _ownWords[q.key],
            onPick: (Choice choice) => _pick(q.key, choice),
            onOwnWords: () => _openOwnWords(q.key),
            onCommitOwnWords: () => _commitOwnWords(q.key),
          ),
          const SizedBox(height: MpSpace.md),
        ],

        MpField(
          label: 'Anything else',
          child: MpSubmit(
            onSubmit: widget.busy ? null : _send,
            child: TextField(
              controller: _note,
              maxLines: 4,
              minLines: 2,
              enabled: !widget.busy,
              textCapitalization: TextCapitalization.sentences,
              style: MpType.body.copyWith(color: c.ink),
              decoration: const InputDecoration(
                hintText: 'Push back, or add something it did not ask about…',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(height: MpSpace.md),

        MpButton(
          label: widget.busy
              ? 'Asking Claude…'
              : answer.answered == 0
              ? 'Pick an answer'
              : outstanding == 0
              ? 'Send all $total'
              : 'Send ${answer.answered} of $total',
          icon: Icons.arrow_forward,
          kind: MpButtonKind.primary,
          expand: true,
          onPressed: widget.busy || answer.text.isEmpty ? null : _send,
        ),
        if (outstanding > 0 && answer.answered > 0) ...<Widget>[
          const SizedBox(height: MpSpace.xs),
          Text(
            outstanding == 1
                ? 'One question is still unanswered. Sending is fine — it will '
                      'ask again.'
                : '$outstanding questions are still unanswered. Sending is '
                      'fine — it will ask again.',
            style: MpType.caption.copyWith(color: c.inkFaint),
          ),
        ],
        const SizedBox(height: MpSpace.sm),
        MpDisclosure(
          label: 'What will be sent',
          child: SelectableText(
            answer.text.isEmpty ? 'Nothing yet.' : answer.text,
            style: MpType.mono.copyWith(color: c.inkMuted),
          ),
        ),
      ],
    );
  }

  void _send() {
    final String text = _answer.text;
    if (text.isEmpty) return;
    widget.onSend(text);
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.question,
    required this.chosen,
    required this.writing,
    required this.controller,
    required this.onPick,
    required this.onOwnWords,
    required this.onCommitOwnWords,
  });

  final AskedQuestion question;
  final Choice? chosen;
  final bool writing;
  final TextEditingController? controller;
  final ValueChanged<Choice> onPick;
  final VoidCallback onOwnWords;
  final VoidCallback onCommitOwnWords;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);

    return MpPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${question.key}. ${question.text}',
            style: MpType.label.copyWith(color: c.ink),
          ),
          const SizedBox(height: MpSpace.md),

          for (final AskedOption o in question.options) ...<Widget>[
            _Option(
              option: o,
              selected: chosen?.optionKey == o.key,
              onTap: () => onPick(Choice.option(o.key)),
            ),
            const SizedBox(height: MpSpace.sm),
          ],

          // Always offered, whether or not the model remembered to. The prompt
          // asks for "the option of telling you something else"; a real answer
          // that is none of the above must never be unreachable.
          if (writing) ...<Widget>[
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: MpType.body.copyWith(color: c.ink),
              decoration: const InputDecoration(
                hintText: 'Your own answer to this one…',
              ),
              onSubmitted: (_) => onCommitOwnWords(),
              onTapOutside: (_) => onCommitOwnWords(),
            ),
            const SizedBox(height: MpSpace.sm),
          ] else
            _Option(
              option: AskedOption(
                key: '_own',
                label: chosen?.ownWords ?? 'Something else',
                consequence: chosen?.ownWords != null ? 'in your words' : '',
              ),
              selected: chosen?.ownWords != null,
              onTap: onOwnWords,
            ),
          const SizedBox(height: MpSpace.sm),

          // Deferring is a decision the user made, which is a different thing
          // from the model assuming. The value still arrives proposed and
          // still has to be accepted, so the gate is untouched either way.
          _Option(
            option: const AskedOption(
              key: '_defer',
              label: 'You choose',
              consequence: 'no preference — use your judgement',
            ),
            selected: chosen?.deferred ?? false,
            onTap: () => onPick(const Choice.deferred()),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AskedOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: MpRadius.card,
      child: Container(
        padding: const EdgeInsets.all(MpSpace.sm + 2),
        decoration: BoxDecoration(
          color: selected ? c.surface : Colors.transparent,
          borderRadius: MpRadius.card,
          border: Border.all(color: selected ? c.ink : c.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? c.ink : c.inkFaint,
            ),
            const SizedBox(width: MpSpace.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          option.label,
                          style: MpType.body.copyWith(color: c.ink),
                        ),
                      ),
                      if (option.recommended) ...<Widget>[
                        const SizedBox(width: MpSpace.sm),
                        // Marked, and that is all. Nothing here selects it.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: c.lineStrong),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: MpType.eyebrow.copyWith(color: c.inkMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (option.consequence.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      option.consequence,
                      style: MpType.caption.copyWith(color: c.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
