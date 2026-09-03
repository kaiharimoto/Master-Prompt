import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

import '../store/app_store.dart';
import '../store/diagnostics.dart';
import '../store/project.dart';
import '../widgets/exchange.dart';

/// The compiled brief: what it says, what is missing from it, and the
/// adversarial pass over it before anything runs.
class PromptScreen extends StatefulWidget {
  const PromptScreen({required this.store, required this.project, super.key});

  final AppStore store;
  final Project project;

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  static const InterviewEngine _engine = InterviewEngine();
  static const SpecPatchParser _patcher = SpecPatchParser();

  bool _redTeaming = false;
  String? _redTeamNote;

  /// A parsed red-team reply, held rather than applied.
  ///
  /// It used to go straight into the spec, which was wrong twice over. A value
  /// the model replaces lands as `proposed` and nothing on this screen ever
  /// confirmed it, so eighty fixes could report as applied while the ones that
  /// mattered most sat outside the readiness gate — and writing them in first
  /// meant the gate could then refuse to compile, replacing this whole screen
  /// with the not-ready notice and taking the red-team panel with it.
  SpecPatchResult? _pending;

  CompiledPrompt _compile(TransportProfile profile) =>
      const PromptCompiler().compile(widget.project.spec, profile: profile);

  Future<void> _applyRedTeam(String reply) async {
    final Project p = widget.project;
    final SpecPatchResult r = _patcher.parse(reply, p.spec);
    Diagnostics.instance.log(
      'Red-team reply (${reply.length} chars): '
      '${r.found ? '${r.applied.length} proposed' : 'no patch block'}.',
    );
    // Recorded on arrival, before anything is decided, so a reply is never
    // lost to a decision not to take it.
    await widget.store.addTranscript(
      p,
      TranscriptEntry(
        direction: TranscriptDirection.received,
        text: reply,
        at: DateTime.now().toUtc(),
        note: 'red-team: ${r.applied.length} proposed',
      ),
    );
    setState(() {
      _pending = r.found && r.hasChanges ? r : null;
      _redTeamNote = r.found
          ? null
          : 'No patch block in that reply. ${r.diagnostic ?? 'If it only '
                    'listed findings, ask Claude to end with the json block '
                    'carrying the fixes.'}';
    });
  }

  Future<void> _acceptRedTeam() async {
    final SpecPatchResult? r = _pending;
    if (r == null) return;
    final Project p = widget.project;
    // confirmProposals is what makes a replaced value count. Without it the
    // fix is in the spec but not through the gate, which is indistinguishable
    // from nothing having happened.
    p.spec = r.spec.confirmProposals();
    await widget.store.save(p);
    Diagnostics.instance.log('Accepted ${r.applied.length} red-team fixes.');
    if (!mounted) return;
    setState(() {
      _redTeamNote =
          '${r.applied.length} fixes are in the brief. Read it above — the '
          'section index jumps to any part of it.';
      _pending = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final Project p = widget.project;
    final ReadinessReport report = _engine.assess(p.spec);

    if (!report.canCompile) {
      // A value the model replaced lands as `proposed`, which does not satisfy
      // the gate. Before the red-team pass had an accept step, that could
      // strand a mission here with the fixes already in the spec and no way to
      // make them count. Offer the way out rather than only the diagnosis.
      final int waiting = p.spec.proposedCount;
      return Padding(
        padding: const EdgeInsets.all(MpSpace.xl),
        child: MpEmpty(
          title: 'The brief is not ready to compile',
          detail:
              '${report.blocking.length} required items are still unsettled. '
              'A brief with holes in it produces an agent that stops to ask, '
              'and the whole point is that it should never need to.'
              '${waiting > 0 ? '\n\n$waiting value${waiting == 1 ? '' : 's'} '
                        'here were proposed and never accepted. Accepting '
                        'them may be all that is missing.' : ''}',
          action: waiting == 0
              ? null
              : MpButton(
                  label: waiting == 1
                      ? 'Accept 1 proposed value'
                      : 'Accept $waiting proposed values',
                  icon: Icons.check,
                  kind: MpButtonKind.primary,
                  onPressed: () async {
                    p.spec = p.spec.confirmProposals();
                    await widget.store.save(p);
                    Diagnostics.instance.log(
                      'Accepted $waiting stranded proposals.',
                    );
                    if (mounted) setState(() {});
                  },
                ),
        ),
      );
    }

    final CompiledPrompt cli = _compile(TransportProfile.cli);
    final CompiledPrompt paste = _compile(TransportProfile.paste);

    return ListView(
      padding: const EdgeInsets.all(MpSpace.md),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: MpSpace.readingWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MpSectionHeader(
                  number: '01',
                  title: 'Compiled brief',
                  subtitle:
                      '${cli.body.length} characters, roughly '
                      '${cli.estimatedTokens} tokens, across ten numbered '
                      'sections.',
                ),
                const SizedBox(height: MpSpace.md),

                if (cli.warnings.isNotEmpty) ...<Widget>[
                  MpPanel(
                    accent: c.warning,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'It will compile, but with gaps',
                          style: MpType.heading.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: MpSpace.sm),
                        for (final CompileWarning w in cli.warnings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: MpSpace.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  w.section,
                                  style: MpType.eyebrow.copyWith(
                                    color: c.inkFaint,
                                  ),
                                ),
                                Text(
                                  w.message,
                                  style: MpType.caption.copyWith(
                                    color: c.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MpSpace.md),
                ],

                _SectionIndex(compiled: cli),
                const SizedBox(height: MpSpace.md),

                MpOutbound(
                  title: 'For the Claude app',
                  subtitle:
                      'The copy-paste variant: no tool access, and a state '
                      'heartbeat required on every reply.',
                  document: paste.body,
                  note:
                      'This is a mission brief. Read all of it, then '
                      'begin. Follow it exactly, including the state block on '
                      'every reply.',
                  fileName: '${p.spec.taskId}-brief.md',
                  limit: widget.store.settings.pasteLimit,
                ),
                const SizedBox(height: MpSpace.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: MpButton(
                        label: 'Copy the CLI variant',
                        icon: Icons.terminal,
                        expand: true,
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: cli.body),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied the CLI brief.'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: MpSpace.xl),
                MpSectionHeader(
                  number: '02',
                  title: 'Red team',
                  subtitle:
                      'Attack the brief before an agent runs it for hours '
                      'with nobody available to answer questions.',
                ),
                const SizedBox(height: MpSpace.md),
                if (!_redTeaming)
                  MpButton(
                    label: 'Generate the red-team pass',
                    icon: Icons.bug_report_outlined,
                    expand: true,
                    onPressed: () => setState(() => _redTeaming = true),
                  )
                else ...<Widget>[
                  Builder(
                    builder: (BuildContext context) {
                      final InterviewTurn red = _engine.redTeamTurn(
                        p.spec,
                        cli,
                      );
                      return MpOutbound(
                        title: 'Red-team prompt',
                        subtitle:
                            'Hunts ambiguities, unmeasurable criteria, '
                            'coverage holes and cheap escapes.',
                        // The instruction fits in a message; the brief it
                        // attacks does not. Separating them is what makes this
                        // one tap rather than four.
                        document: red.document,
                        note: red.note,
                        fileName: '${p.spec.taskId}-red-team.md',
                        limit: widget.store.settings.pasteLimit,
                      );
                    },
                  ),
                  const SizedBox(height: MpSpace.md),
                  MpInbound(
                    onSubmit: _applyRedTeam,
                    hint: 'Paste the findings and fixes',
                    actionLabel: 'Read the fixes',
                  ),
                ],
                if (_pending != null) ...<Widget>[
                  const SizedBox(height: MpSpace.md),
                  _RedTeamReview(
                    result: _pending!,
                    onAccept: _acceptRedTeam,
                    onDiscard: () => setState(() {
                      _pending = null;
                      _redTeamNote =
                          'Nothing was changed. The reply is still in the '
                          'transcript if you want it back.';
                    }),
                  ),
                ],
                if (_redTeamNote != null) ...<Widget>[
                  const SizedBox(height: MpSpace.md),
                  MpPanel(
                    child: Text(
                      _redTeamNote!,
                      style: MpType.prose.copyWith(color: c.inkMuted),
                    ),
                  ),
                ],
                const SizedBox(height: MpSpace.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A jumpable index of the compiled sections, so a 20k-character brief can be
/// navigated rather than scrolled.
class _SectionIndex extends StatelessWidget {
  const _SectionIndex({required this.compiled});

  final CompiledPrompt compiled;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final List<String> headings = compiled.sectionOffsets.keys.toList();
    return MpPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('SECTIONS', style: MpType.eyebrow.copyWith(color: c.inkFaint)),
          const SizedBox(height: MpSpace.sm),
          Wrap(
            spacing: MpSpace.sm,
            runSpacing: MpSpace.sm,
            children: <Widget>[
              for (final String h in headings)
                InkWell(
                  onTap: () {
                    final String? body = compiled.section(h);
                    if (body == null) return;
                    showDialog<void>(
                      context: context,
                      builder: (BuildContext context) => Dialog(
                        backgroundColor: c.surfaceRaised,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Padding(
                            padding: const EdgeInsets.all(MpSpace.lg),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                body,
                                style: MpType.mono.copyWith(color: c.ink),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: MpTag(h),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What a red-team reply would change, before it changes anything.
///
/// The count on its own was the problem: "Applied 80 fixes" is
/// indistinguishable from "applied nothing" once you go looking at the brief,
/// and it said "applied" for values that had not passed the gate. Every line
/// is listed, and accepting is a deliberate act.
class _RedTeamReview extends StatelessWidget {
  const _RedTeamReview({
    required this.result,
    required this.onAccept,
    required this.onDiscard,
  });

  final SpecPatchResult result;
  final Future<void> Function() onAccept;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final List<String> applied = result.applied;

    return MpPanel(
      accent: c.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            applied.length == 1
                ? 'One fix, waiting'
                : '${applied.length} fixes, waiting',
            style: MpType.title.copyWith(color: c.ink),
          ),
          const SizedBox(height: MpSpace.xs),
          Text(
            'Nothing has changed yet. A value the pass replaced does not count '
            'until it is accepted.',
            style: MpType.caption.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: MpSpace.md),
          // Every line, in a plain column. Not a bounded scroller: an accented
          // MpPanel wraps its child in IntrinsicHeight, which cannot measure a
          // lazy viewport and throws on layout — and a scroll area inside a
          // scrolling page is miserable on a phone regardless. The screen
          // already scrolls, and reading all of them is the point.
          for (final String line in applied)
            Padding(
              padding: const EdgeInsets.only(bottom: MpSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.check, size: 18, color: c.success),
                  const SizedBox(width: MpSpace.sm + 2),
                  Expanded(
                    child: Text(
                      line,
                      style: MpType.body.copyWith(color: c.ink),
                    ),
                  ),
                ],
              ),
            ),
          if (result.rejected.isNotEmpty) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            MpDisclosure(
              label: 'Could not be read',
              trailingNote: '${result.rejected.length}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final String line in result.rejected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MpSpace.xs),
                      child: Text(
                        line,
                        style: MpType.mono.copyWith(color: c.inkMuted),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: MpSpace.md),
          MpButton(
            label: 'Accept and put them in the brief',
            icon: Icons.check,
            kind: MpButtonKind.primary,
            expand: true,
            onPressed: onAccept,
          ),
          const SizedBox(height: MpSpace.sm),
          MpButton(
            label: 'Discard',
            kind: MpButtonKind.quiet,
            expand: true,
            onPressed: onDiscard,
          ),
        ],
      ),
    );
  }
}
