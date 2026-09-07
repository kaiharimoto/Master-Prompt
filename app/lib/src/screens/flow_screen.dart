import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';
import 'package:mp_runner/mp_runner.dart';

import '../flow/flow_controller.dart';
import '../store/app_store.dart';
import '../store/claude_chat.dart';
import '../store/diagnostics.dart';
import '../store/project.dart';
import 'destinations.dart';

/// The whole app, most of the time: one question, one action.
///
/// Everything the first build stacked on a single scroll still exists. It has
/// stopped being *shown* — the current stage's open items are behind "What this
/// settles", the generated message behind "Preview", the full readiness list in
/// the menu. A screen is about one thing.
class FlowScreen extends StatefulWidget {
  const FlowScreen({
    required this.store,
    required this.flow,
    required this.chat,
    required this.onOpen,
    super.key,
  });

  final AppStore store;
  final FlowController flow;

  /// The desktop conversation. Idle and invisible until the CLI is connected,
  /// which is what keeps one screen serving both routes.
  final ClaudeChat chat;

  /// Where the flow hands off to the menu destinations. Navigation lives in the
  /// shell rather than the store, so the store stays a plain data holder.
  final void Function(AppDestination) onOpen;

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  static const InterviewEngine _engine = InterviewEngine();
  static const SpecPatchParser _patcher = SpecPatchParser();

  final TextEditingController _seedField = TextEditingController();
  final TextEditingController _replyField = TextEditingController();
  final TextEditingController _followUpField = TextEditingController();
  bool _busy = false;

  /// Which route this round took. Both are available on a connected desktop,
  /// and the waiting beat is a different screen for each: one is a paste box,
  /// the other is what Claude just said.
  bool _viaCli = false;

  @override
  void dispose() {
    _seedField.dispose();
    _replyField.dispose();
    _followUpField.dispose();
    super.dispose();
  }

  // -- actions -------------------------------------------------------------

  Future<void> _begin() async {
    final String sentence = _seedField.text.trim();
    if (sentence.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final Project p = await widget.store.create(
        title: MissionSeed.titleFrom(sentence),
      );
      // Typed by the user, so it is confirmed outright. Only what the model
      // proposes has to be accepted before it counts.
      p.spec = p.spec.copyWith(
        missionStatement: p.spec.missionStatement.confirm(sentence),
      );
      widget.flow.reset();
      _seedField.clear();
      Diagnostics.instance.log('Seeded mission "${p.spec.taskId}".');
      // Release the button before persisting: the mission exists in memory at
      // this point, and the first question should already be on screen.
      if (mounted) setState(() => _busy = false);
      await widget.store.save(p);
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _handOff(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    // No confirmation toast. The screen changing to "Paste Claude's reply" says
    // the copy worked, and a banner over the next action is exactly the kind of
    // extra thing this redesign is removing.
    setState(() => _viaCli = false);
    widget.flow.handedOff();
  }

  Future<void> _applyReply(Project p) async {
    final String reply = _replyField.text.trim();
    if (reply.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final bool advanced = await _read(p, reply, viaCli: false);
      if (advanced) _replyField.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reads one reply, whichever route brought it, and advances if it settled
  /// anything.
  ///
  /// The same parser either way. A reply that arrived down a pipe has no more
  /// authority than one that was pasted, and the proposed/confirmed gate still
  /// stands between both of them and an unattended run.
  Future<bool> _read(Project p, String reply, {required bool viaCli}) async {
    final SpecPatchResult r = _patcher.parse(reply, p.spec);
    Diagnostics.instance.log(
      'Reply ${viaCli ? 'from the CLI' : 'pasted'} (${reply.length} chars): '
      '${r.found ? '${r.applied.length} applied' : 'no mpspec block'}.',
    );
    await widget.store.addTranscript(
      p,
      TranscriptEntry(
        direction: TranscriptDirection.received,
        text: reply,
        at: DateTime.now().toUtc(),
        note: r.found ? '${r.applied.length} changes' : 'no patch block',
      ),
    );

    if (!r.found || !r.hasChanges) {
      // Down the CLI route the answer is already on screen with a box under
      // it, so a round of questions is the conversation working rather than
      // something that went wrong. Only the clipboard route needs telling.
      if (!viaCli) {
        widget.flow.rejected(
          r.found
              ? 'That reply had a block, but nothing in it changed the mission. '
                    'If Claude asked you questions, answer them in the same chat '
                    'and bring its next reply back.'
              : 'No settled answers in that reply yet. If Claude asked you '
                    'questions, answer them in the same chat and bring its next '
                    'reply back.',
        );
      }
      return false;
    }

    widget.flow.received(r);
    return true;
  }

  /// Sends a round straight into the CLI session.
  Future<void> _askClaude(Project p, String prompt) async {
    if (_busy || prompt.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _viaCli = true;
    });
    // Move to the waiting beat before the answer arrives, so the screen shows
    // the question being worked on rather than staying on the button.
    widget.flow.handedOff();
    try {
      await widget.store.addTranscript(
        p,
        TranscriptEntry(
          direction: TranscriptDirection.sent,
          text: prompt,
          at: DateTime.now().toUtc(),
          note: 'asked the CLI',
        ),
      );
      final ConversationReply? reply = await widget.chat.send(
        prompt,
        widget.store.settings,
      );
      if (reply == null) {
        widget.flow.rejected(
          widget.chat.error ?? 'The CLI answered with nothing.',
        );
        return;
      }
      await _read(p, reply.text, viaCli: true);
      _followUpField.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(Project p) async {
    final SpecPatchResult? r = widget.flow.pending;
    if (r == null) return;
    // One act for the whole round. The proposed/confirmed distinction survives,
    // because an invented requirement still cannot reach an unattended run
    // without a person having seen it — it just no longer costs a tap per field.
    // What the brief said before this round, so the preview can mark what the
    // round changed. Compiled from the outgoing spec while it is still the
    // current one.
    p.briefBaseline = const PromptCompiler().compile(p.spec).body;
    p.spec = r.spec.confirmProposals();
    await widget.store.save(p);
    widget.flow.accepted();
    Diagnostics.instance.log('Accepted a round: ${r.applied.length} changes.');
  }

  /// Leaves the CLI route without losing the session, so the round can be
  /// sent again or copied across instead.
  void _backToQuestion() {
    setState(() => _viaCli = false);
    widget.flow.reconsider();
  }

  Future<void> _pasteFromClipboard() async {
    final ClipboardData? d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null && mounted) {
      setState(() => _replyField.text = d!.text!);
    }
  }

  // -- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.store,
        widget.flow,
        widget.chat,
      ]),
      builder: (BuildContext context, _) {
        final Project? p = widget.store.current;
        final ReadinessReport? report = p == null
            ? null
            : _engine.assess(p.spec);
        final FlowBeat beat = widget.flow.beatFor(p?.spec, report);

        return switch (beat) {
          FlowBeat.seed => _seed(),
          FlowBeat.ask => _ask(p!, report!),
          FlowBeat.awaiting => _awaiting(p!, report!),
          FlowBeat.review => _review(p!, report!),
          FlowBeat.ready => _ready(p!),
        };
      },
    );
  }

  String _stageEyebrow(ReadinessReport r) =>
      'Step ${r.currentStage.step} of ${InterviewStage.stepCount} · '
      '${r.currentStage.title}';

  // -- beats ---------------------------------------------------------------

  Widget _seed() {
    final MpColors c = MpTheme.colorsOf(context);
    return MpFocal(
      key: const ValueKey<String>('beat-seed'),
      question: InterviewStage.seed.question,
      supporting:
          'One sentence is enough. Everything else gets worked out between you '
          'and Claude, a question at a time.',
      body: TextField(
        controller: _seedField,
        autofocus: false,
        maxLines: 4,
        minLines: 3,
        textCapitalization: TextCapitalization.sentences,
        style: MpType.body.copyWith(color: c.ink),
        decoration: const InputDecoration(
          hintText: 'A photorealistic rooftop bar above a city at night…',
        ),
        onSubmitted: (_) => _begin(),
      ),
      primary: MpButton(
        label: _busy ? 'Starting…' : 'Begin',
        kind: MpButtonKind.primary,
        expand: true,
        onPressed: _busy ? null : _begin,
      ),
    );
  }

  Widget _ask(Project p, ReadinessReport report) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool connected = widget.chat.available;

    // The interview happens in one continuing chat, and that chat already
    // holds the framing, everything settled and the format rules — it worked
    // most of it out itself. Once it has answered once, the round only carries
    // what the round adds.
    // The CLI route keeps its own session, so what the far end already knows
    // is a fact about that session rather than about the transcript: a fresh
    // session after clipboard rounds still has to be told everything.
    final bool continuing = connected
        ? widget.chat.hasExchange
        : p.hasAnsweredOnce && !widget.store.settings.standaloneTurns;
    final InterviewTurn turn = _engine.nextTurn(
      p.spec,
      style: continuing ? TurnStyle.continuing : TurnStyle.standalone,
    );
    final List<ReadinessGap> gaps = turn.gaps;

    return MpFocal(
      key: const ValueKey<String>('beat-ask'),
      eyebrow: _stageEyebrow(report),
      question: report.currentStage.question,
      supporting: connected
          ? 'Claude will ask you two to four questions about this. Answer them '
                'here; nothing leaves the app.'
          : 'Claude will ask you two to four questions about this. Answer them '
                'in the chat, then bring its reply back here.',
      primary: connected
          ? MpButton(
              label: _busy ? 'Asking Claude…' : 'Ask Claude',
              icon: Icons.arrow_forward,
              kind: MpButtonKind.primary,
              expand: true,
              onPressed: _busy ? null : () => _askClaude(p, turn.text),
            )
          : MpButton(
              label: 'Copy for Claude',
              icon: Icons.content_copy,
              kind: MpButtonKind.primary,
              expand: true,
              onPressed: () => _handOff(turn.text),
            ),
      // The clipboard route survives on a connected desktop, one level down.
      // The CLI can be missing, logged out or rate-limited, and none of those
      // should leave the mission stranded.
      secondary: connected
          ? MpButton(
              label: 'Copy for Claude instead',
              icon: Icons.content_copy,
              kind: MpButtonKind.quiet,
              expand: true,
              // The full version, always. A copy is leaving this session for
              // somewhere else, and a continuing turn pasted into a chat that
              // has seen none of it is unusable.
              onPressed: () => _handOff(_engine.nextTurn(p.spec).text),
            )
          : MpButton(
              label: 'I already have a reply',
              kind: MpButtonKind.quiet,
              expand: true,
              onPressed: () {
                setState(() => _viaCli = false);
                widget.flow.handedOff();
              },
            ),
      disclosures: <Widget>[
        MpDisclosure(
          label: 'What this round settles',
          trailingNote: '${gaps.length}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final ReadinessGap g in gaps)
                Padding(
                  padding: const EdgeInsets.only(bottom: MpSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(g.label, style: MpType.body.copyWith(color: c.ink)),
                      const SizedBox(height: 2),
                      Text(
                        g.why,
                        style: MpType.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        MpDisclosure(
          label: 'Preview the message',
          trailingNote: '~${turn.estimatedTokens} tokens',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SelectableText(
                turn.text,
                style: MpType.mono.copyWith(color: c.inkMuted),
              ),
              // A session limit ends the chat, and the whole app exists
              // because that happens. Starting a fresh one needs the full
              // version once, and hunting for a setting mid-recovery is the
              // wrong place to put it.
              if (continuing) ...<Widget>[
                const SizedBox(height: MpSpace.md),
                Text(
                  'Written for the chat you have been using. If that chat is '
                  'gone, take the full version instead.',
                  style: MpType.caption.copyWith(color: c.inkFaint),
                ),
                const SizedBox(height: MpSpace.sm),
                MpButton(
                  label: 'Copy for a new chat',
                  icon: Icons.open_in_new,
                  expand: true,
                  onPressed: () => _handOff(_engine.nextTurn(p.spec).text),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _awaiting(Project p, ReadinessReport report) {
    if (_viaCli) return _conversing(p, report);

    final MpColors c = MpTheme.colorsOf(context);
    final String? problem = widget.flow.problem;

    return MpFocal(
      key: const ValueKey<String>('beat-await'),
      eyebrow: _stageEyebrow(report),
      question: "Paste Claude's reply",
      supporting:
          'Everything it said, including the block at the end. Anything it could '
          'not read is shown rather than dropped.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _replyField,
            maxLines: 8,
            minLines: 4,
            style: MpType.mono.copyWith(color: c.ink),
            decoration: InputDecoration(
              hintText: 'Paste here',
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste, size: 22),
                tooltip: 'Paste from clipboard',
                onPressed: _pasteFromClipboard,
              ),
            ),
          ),
          if (problem != null) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            MpPanel(
              accent: c.warning,
              child: Text(
                problem,
                style: MpType.prose.copyWith(color: c.inkMuted),
              ),
            ),
          ],
        ],
      ),
      primary: MpButton(
        label: _busy ? 'Reading…' : 'Apply reply',
        kind: MpButtonKind.primary,
        expand: true,
        onPressed: _busy ? null : () => _applyReply(p),
      ),
      secondary: MpButton(
        label: 'Back to the question',
        kind: MpButtonKind.quiet,
        expand: true,
        onPressed: widget.flow.reconsider,
      ),
    );
  }

  /// The desktop waiting beat: what Claude just said, and a box to answer in.
  ///
  /// The clipboard route's version of this screen is a paste box, because
  /// there the reply has to be carried by hand. Here the reply is already in,
  /// so the screen is about reading it and answering — which is what makes a
  /// recommendation arguable before it becomes a patch.
  Widget _conversing(Project p, ReadinessReport report) {
    final MpColors c = MpTheme.colorsOf(context);
    final String? problem = widget.flow.problem;
    final bool busy = _busy || widget.chat.busy;
    // While the turn is running the answer being written is what the screen is
    // about; once it lands, the finished one is. A turn that failed after an
    // earlier success used to leave the *previous* answer on screen under the
    // heading "Claude answered", with the failure tucked underneath.
    final String? reply = busy
        ? (widget.chat.liveText.isEmpty ? null : widget.chat.liveText)
        : (widget.flow.problem != null ? null : widget.chat.lastReply);

    // Nothing came back at all, so there is nothing to answer and Send would
    // be a button that does nothing. The way on is the question again, where
    // the round can be sent a second time or copied instead.
    final bool failed = !busy && reply == null;
    final int seconds = widget.chat.elapsed.inSeconds;

    return MpFocal(
      key: const ValueKey<String>('beat-chat'),
      eyebrow: _stageEyebrow(report),
      question: busy
          ? 'Asking Claude…'
          : failed
          ? 'That turn did not go through'
          : 'Claude answered',
      supporting: busy
          ? (widget.chat.activity.isNotEmpty
                ? widget.chat.activity
                : '${seconds}s so far. A round takes about as long as it '
                      'would in the chat app.')
          : failed
          ? 'Nothing was lost. The round is still there to send again, or to '
                'copy across by hand.'
          : 'Answer below and it goes back into the same session. Anything it '
                'settles arrives as a round to accept.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (reply != null)
            MpPanel(
              child: SelectableText(
                reply,
                style: MpType.prose.copyWith(color: c.ink),
              ),
            ),
          // What the installed build could not do as asked. This reached the
          // diagnostics log and nowhere else, so a CLI that silently restarted
          // the conversation every round looked exactly like one that did not.
          for (final String note in widget.chat.notes) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            MpPanel(
              accent: c.warning,
              child: Text(
                note,
                style: MpType.prose.copyWith(color: c.inkMuted),
              ),
            ),
          ],
          if (problem != null) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            MpPanel(
              accent: c.warning,
              child: Text(
                problem,
                style: MpType.prose.copyWith(color: c.inkMuted),
              ),
            ),
          ],
          if (reply != null) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            TextField(
              controller: _followUpField,
              maxLines: 6,
              minLines: 3,
              enabled: !busy,
              textCapitalization: TextCapitalization.sentences,
              style: MpType.body.copyWith(color: c.ink),
              decoration: const InputDecoration(
                hintText: 'Answer its questions, or push back on one…',
              ),
            ),
          ],
        ],
      ),
      primary: failed
          ? MpButton(
              label: 'Back to the question',
              icon: Icons.arrow_back,
              kind: MpButtonKind.primary,
              expand: true,
              onPressed: _backToQuestion,
            )
          : MpButton(
              label: busy ? 'Asking Claude…' : 'Send',
              icon: Icons.arrow_forward,
              kind: MpButtonKind.primary,
              expand: true,
              onPressed: busy
                  ? null
                  : () => _askClaude(p, _followUpField.text.trim()),
            ),
      secondary: failed
          ? null
          : busy
          ? MpButton(
              label: 'Stop',
              kind: MpButtonKind.quiet,
              expand: true,
              onPressed: widget.chat.cancel,
            )
          : MpButton(
              label: 'Back to the question',
              kind: MpButtonKind.quiet,
              expand: true,
              onPressed: _backToQuestion,
            ),
      disclosures: <Widget>[
        MpDisclosure(
          label: 'Paste a reply instead',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'For a reply that came from somewhere else — the chat app on '
                'the phone, or a session this one could not reach.',
                style: MpType.caption.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: MpSpace.sm),
              TextField(
                controller: _replyField,
                maxLines: 6,
                minLines: 3,
                style: MpType.mono.copyWith(color: c.ink),
                decoration: const InputDecoration(hintText: 'Paste here'),
              ),
              const SizedBox(height: MpSpace.sm),
              MpButton(
                label: 'Apply reply',
                expand: true,
                onPressed: busy ? null : () => _applyReply(p),
              ),
            ],
          ),
        ),
        if (widget.chat.turns.length > 2)
          MpDisclosure(
            label: 'Everything said so far',
            trailingNote: '${widget.chat.turns.length}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final ChatTurn t in widget.chat.turns)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MpSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          t.fromUser ? 'You' : 'Claude',
                          style: MpType.eyebrow.copyWith(color: c.inkFaint),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.text,
                          style: MpType.caption.copyWith(color: c.inkMuted),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _review(Project p, ReadinessReport report) {
    final MpColors c = MpTheme.colorsOf(context);
    final SpecPatchResult r = widget.flow.pending!;
    final List<String> applied = r.applied;
    final List<String> unread = widget.flow.unread;
    const int shown = 5;

    return MpFocal(
      key: const ValueKey<String>('beat-review'),
      eyebrow: _stageEyebrow(report),
      question: applied.length == 1
          ? 'One thing settled'
          : '${applied.length} things settled',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final String a in applied.take(shown))
            Padding(
              padding: const EdgeInsets.only(bottom: MpSpace.sm + 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.check, size: 18, color: c.success),
                  const SizedBox(width: MpSpace.sm + 2),
                  Expanded(
                    child: Text(a, style: MpType.body.copyWith(color: c.ink)),
                  ),
                ],
              ),
            ),
          if (applied.length > shown)
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                'and ${applied.length - shown} more',
                style: MpType.caption.copyWith(color: c.inkFaint),
              ),
            ),
        ],
      ),
      primary: MpButton(
        label: 'Accept and continue',
        icon: Icons.arrow_forward,
        kind: MpButtonKind.primary,
        expand: true,
        onPressed: () => _accept(p),
      ),
      secondary: MpButton(
        label: 'Discard this reply',
        kind: MpButtonKind.quiet,
        expand: true,
        onPressed: widget.flow.discardPending,
      ),
      disclosures: <Widget>[
        if (applied.length > shown)
          MpDisclosure(
            label: 'Everything this round settled',
            trailingNote: '${applied.length}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String a in applied)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '· $a',
                      style: MpType.caption.copyWith(color: c.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
        if (unread.isNotEmpty)
          MpDisclosure(
            label: 'Lines that could not be read',
            trailingNote: '${unread.length}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Kept in the transcript rather than dropped.',
                  style: MpType.caption.copyWith(color: c.inkFaint),
                ),
                const SizedBox(height: MpSpace.sm),
                for (final String l in unread.take(8))
                  Text(
                    l,
                    style: MpType.mono.copyWith(color: c.inkFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _ready(Project p) {
    final MissionSpec s = p.spec;
    return MpFocal(
      key: const ValueKey<String>('beat-ready'),
      eyebrow: 'Ready',
      question: 'Your brief is ready',
      supporting:
          '${s.regions.length} parts, ${s.evidence.length} artifacts to produce, '
          'scored out of ${s.rubric.total} with an exit at '
          '${s.rubric.exitThreshold}.',
      info: const MpInfo(
        title: 'What happens now',
        body:
            'The brief is a complete set of instructions an agent can work from '
            'for hours without asking anything. Copy it into Claude, or on a '
            'desktop let the app drive the Claude Code CLI directly and watch it '
            'run.',
      ),
      primary: MpButton(
        label: 'Open the brief',
        icon: Icons.description_outlined,
        kind: MpButtonKind.primary,
        expand: true,
        onPressed: () => widget.onOpen(AppDestination.brief),
      ),
      secondary: MpButton(
        label: 'Run it',
        kind: MpButtonKind.secondary,
        expand: true,
        onPressed: () => widget.onOpen(AppDestination.run),
      ),
    );
  }
}
