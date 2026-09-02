import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_core/mp_core.dart';
import 'package:mp_design/mp_design.dart';

import '../store/app_store.dart';
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

  CompiledPrompt _compile(TransportProfile profile) =>
      const PromptCompiler().compile(widget.project.spec, profile: profile);

  Future<void> _applyRedTeam(String reply) async {
    final Project p = widget.project;
    final SpecPatchResult r = _patcher.parse(reply, p.spec);
    await widget.store.addTranscript(
      p,
      TranscriptEntry(
        direction: TranscriptDirection.received,
        text: reply,
        at: DateTime.now().toUtc(),
        note: 'red-team: ${r.applied.length} fixes',
      ),
    );
    if (r.found && r.hasChanges) {
      p.spec = r.spec;
      await widget.store.save(p);
    }
    setState(() {
      _redTeamNote = r.found
          ? 'Applied ${r.applied.length} fixes from the red-team pass.'
          : 'No patch block in that reply. If it only listed findings, ask '
                'Claude to emit the mpspec block with the fixes.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final Project p = widget.project;
    final ReadinessReport report = _engine.assess(p.spec);

    if (!report.canCompile) {
      return Padding(
        padding: const EdgeInsets.all(MpSpace.xl),
        child: MpEmpty(
          title: 'The brief is not ready to compile',
          detail:
              '${report.blocking.length} required items are still unsettled. '
              'A brief with holes in it produces an agent that stops to ask, '
              'and the whole point is that it should never need to.',
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
                  text: paste.body,
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
                  MpOutbound(
                    title: 'Red-team prompt',
                    subtitle:
                        'Hunts ambiguities, unmeasurable criteria, coverage '
                        'holes and cheap escapes.',
                    text: _engine.redTeamTurn(p.spec, cli).text,
                  ),
                  const SizedBox(height: MpSpace.md),
                  MpInbound(
                    onSubmit: _applyRedTeam,
                    hint: 'Paste the findings and fixes',
                    actionLabel: 'Apply fixes',
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
