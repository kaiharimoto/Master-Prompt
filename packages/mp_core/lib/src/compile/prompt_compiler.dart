import '../spec/mission_spec.dart';
import '../spec/spec_sections.dart';
import '../spec/spec_types.dart';
import 'compiled_prompt.dart';

/// Renders a [MissionSpec] into a master prompt.
///
/// The output follows the anatomy of the reference brief this project was
/// modelled on: numbered sections from `00 / RUNTIME` through
/// `09 / FAILURE CONDITIONS`, a weighted rubric with an exit threshold, an
/// evidence-based review loop with fresh-context critics, and a cold-start
/// validation.
///
/// The function is pure and deterministic: the same spec, profile and compiler
/// version always produce byte-identical output. That is what makes the prompt
/// hash meaningful, spec edits diffable, and bundles trustworthy.
class PromptCompiler {
  const PromptCompiler();

  /// Bumped whenever rendering changes in a way that alters output bytes.
  static const String version = '1.0.0';

  CompiledPrompt compile(
    MissionSpec spec, {
    TransportProfile profile = TransportProfile.cli,
  }) {
    final _Writer w = _Writer();
    final List<CompileWarning> warnings = <CompileWarning>[];

    _header(w, spec, profile);
    _runtime(w, spec, profile, warnings);
    _task(w, spec, warnings);
    _protocol(w, spec, profile);
    _buildOrder(w, spec, warnings);
    _reviewLoop(w, spec, warnings);
    _rubric(w, spec, warnings);
    _validation(w, spec);
    _brief(w, spec, warnings);
    _deliverables(w, spec, warnings);
    _failureConditions(w, spec, warnings);
    _closing(w, spec, profile);

    return CompiledPrompt(
      body: w.text,
      profile: profile,
      specHash: spec.contentHash(),
      compilerVersion: version,
      sectionOffsets: w.offsets,
      warnings: warnings,
    );
  }

  // -- header --------------------------------------------------------------

  void _header(_Writer w, MissionSpec spec, TransportProfile profile) {
    w.line('# ${spec.title}');
    w.blank();
    final String summary = spec.missionStatement.value?.trim() ?? '';
    if (summary.isNotEmpty) {
      w.line(summary);
      w.blank();
    }
    w.line(
      '`task-id: ${spec.taskId}` · '
      '${spec.review.minimumCycles}+ review cycles · '
      '${spec.review.critics.length} critics · '
      '${spec.evidence.length} final artifacts · '
      'exit at ${spec.rubric.exitThreshold}/${spec.rubric.total}',
    );
  }

  // -- 00 / RUNTIME --------------------------------------------------------

  void _runtime(
    _Writer w,
    MissionSpec spec,
    TransportProfile profile,
    List<CompileWarning> warnings,
  ) {
    w.section('00 / RUNTIME');
    final RuntimeProfile r = spec.runtime;

    if (r.compute.isEmpty && profile == TransportProfile.cli) {
      warnings.add(
        const CompileWarning(
          '00 / RUNTIME',
          'No compute environment stated. The agent will spend its first turns '
              'discovering the machine instead of building.',
        ),
      );
    }

    w.field('COMPUTE', r.compute);
    w.field('PRIMARY TOOL', r.primaryTool);
    w.field('HARNESS', r.harness);
    w.field('STARTING ASSETS', r.startingAssets);
    w.field('BUDGET', r.tokenBudget);
    if (r.wallClock.isNotEmpty) w.field('WALL CLOCK', r.wallClock);
    w.field('AUTONOMY', r.autonomy);

    if (r.constraints.isNotEmpty) {
      w.blank();
      w.line('**Constraints**');
      w.bullets(r.constraints);
    }

    if (profile == TransportProfile.paste) {
      w.blank();
      w.line(
        'You have **no tool access and no filesystem** in this conversation. '
        'You are producing the work as text, turn by turn, for a human who is '
        'relaying your output by hand. Never claim to have run a command, '
        'written a file, or inspected an artifact. When the mission needs work '
        'you cannot perform here, produce the exact instructions or content the '
        'human should apply, and say plainly that it is unexecuted.',
      );
    }
  }

  // -- 01 / TASK -----------------------------------------------------------

  void _task(_Writer w, MissionSpec spec, List<CompileWarning> warnings) {
    w.section('01 / TASK');

    final String story = spec.definingStory.value?.trim() ?? '';
    final String scale = spec.scale.value?.trim() ?? '';
    final String audience = spec.audience.value?.trim() ?? '';

    if (scale.isNotEmpty) w.field('SCALE', scale);
    if (audience.isNotEmpty) w.field('JUDGED BY', audience);

    if (story.isNotEmpty) {
      w.blank();
      w.line('**Defining story**');
      w.blank();
      w.line(story);
    } else {
      warnings.add(
        const CompileWarning(
          '01 / TASK',
          'No defining story. Without a through-line the agent optimises each '
              'part in isolation and the result reads as assembled rather than '
              'designed.',
        ),
      );
    }

    if (spec.quality.avoid.isNotEmpty) {
      w.blank();
      w.line('**Avoid these interpretations and shortcuts**');
      w.bullets(spec.quality.avoid);
    }
  }

  // -- 02 / PROTOCOL -------------------------------------------------------

  void _protocol(_Writer w, MissionSpec spec, TransportProfile profile) {
    w.section('02 / PROTOCOL');

    w.line(
      'Perform the actual work. Do not answer with only a plan, a tutorial, or '
      'sample code.',
    );
    w.blank();
    w.line(
      'The user may be unavailable. Make conservative, reversible assumptions, '
      'record them, and continue. Do not pause for non-blocking choices, '
      'optional downloads, or missing conveniences. Stop only for credentials, '
      'a potentially destructive external action, or an ambiguity that cannot '
      'be resolved without materially changing the authorised project.',
    );
    w.blank();
    w.line(
      'Continue until the explicit quality gates in this brief are satisfied — '
      'not merely until the first working result exists.',
    );

    w.blank();
    w.line('**Before committing to the implementation**');
    w.blank();
    w.line(
      'Inspect the working environment, the available tools and their versions, '
      'and any existing assets. Optional dependencies must not become blockers; '
      'provide a native alternative instead.',
    );

    w.blank();
    w.line('**Maintain these working documents throughout**');
    w.blank();
    final String dir = spec.deliverables.projectDirectory.isEmpty
        ? spec.taskId
        : spec.deliverables.projectDirectory;
    w.code(<String>[
      '$dir/',
      '  DIRECTION.md      # the visual or design language, and decisions made',
      '  PLAN.md           # dimensions, structure, coverage, required parts',
      '  INVENTORY.md      # component families, sources, status, substitutions',
      '  TASK_STATE.md     # completed work, worst problems, next action, score',
      '  checkpoints/      # a recoverable milestone after every stable stage',
    ]);

    w.blank();
    w.line('**If context is compacted or work resumes later**');
    w.blank();
    w.line(
      'Re-read this brief plus `DIRECTION.md` and `TASK_STATE.md`, open the '
      'latest valid checkpoint, and continue from the recorded next action '
      'rather than rebuilding blindly. Keep `TASK_STATE.md` carrying the last '
      'successful commands, the current rubric score, and known failures, so '
      'that any future session can resume mid-flight.',
    );

    // The state block is what lets an interrupted run be picked up. On the
    // paste transport it is the only channel; on the CLI transport it doubles
    // as a compaction detector, because micro-compaction is not observable
    // from the event stream.
    w.blank();
    w.line('**Progress heartbeat — required on every reply**');
    w.blank();
    w.line(
      'End every response with this block, fenced exactly as shown. It is read '
      'by tooling; keep it short, keep the keys, and never omit it.',
    );
    w.blank();
    w.raw('```mpstate');
    w.raw('v=1');
    w.raw('task=${spec.taskId}');
    w.raw('phase=<bootstrap|build|review|validation|done>');
    w.raw('step=<current step, a few words>');
    w.raw('cycle=<review cycle number, 0 before review begins>');
    w.raw('score=<current rubric score out of ${spec.rubric.total}, or 0>');
    w.raw('next=<the single next action>');
    w.raw('blocked=<none, or what is blocking>');
    w.raw('ask=<none, or one question for the user>');
    w.raw('```');

    if (profile == TransportProfile.paste) {
      w.blank();
      w.line(
        'Because this conversation may be cut off by a usage limit at any '
        'point, the block above is the only thing that survives. Treat it as '
        'the handover note to your own successor.',
      );
    }
  }

  // -- 03 / BUILD ORDER ----------------------------------------------------

  void _buildOrder(_Writer w, MissionSpec spec, List<CompileWarning> warnings) {
    w.section('03 / BUILD ORDER');

    if (spec.buildOrder.isEmpty) {
      warnings.add(
        const CompileWarning(
          '03 / BUILD ORDER',
          'No build order. The agent will choose its own sequencing, which '
              'usually means detail before structure.',
        ),
      );
      w.line('_No explicit build order was specified._');
      return;
    }

    w.line(
      'Work in this order. Keep the whole thing viewable and evaluable after '
      'every stage — never leave it in a state that cannot be inspected.',
    );
    w.blank();

    final List<BuildStep> steps = <BuildStep>[...spec.buildOrder]
      ..sort((BuildStep a, BuildStep b) => a.ordinal.compareTo(b.ordinal));
    for (final BuildStep s in steps) {
      w.line('**STEP ${_pad(s.ordinal)} — ${s.name}**');
      w.blank();
      w.line(s.instruction);
      if (s.producesEvidence.isNotEmpty) {
        w.line(
          '_Capturable after this step: '
          '${s.producesEvidence.map(_pad).join(', ')}._',
        );
      }
      w.blank();
    }
  }

  // -- 04 / REVIEW LOOP ----------------------------------------------------

  void _reviewLoop(_Writer w, MissionSpec spec, List<CompileWarning> warnings) {
    w.section('04 / REVIEW LOOP');
    final ReviewLoopSpec r = spec.review;

    w.line(
      'Use the complete evidence set in section 08 as the fixed judgeset. '
      'Perform at least **${r.minimumCycles} complete cycles** of:',
    );
    w.blank();
    w.line(
      'build or change → capture the fixed evidence set → inspect the actual '
      'captured artifacts → diagnose → fix → re-capture the identical set',
    );
    w.blank();
    w.line(r.evidenceRule);
    w.blank();
    w.line(
      'For each finding, record the artifact it came from, the severity, the '
      'affected subsystem, the likely root cause, and an actionable correction. '
      'Repair systemic issues affecting several artifacts before isolated '
      'polish.',
    );

    if (r.critics.isEmpty) {
      warnings.add(
        const CompileWarning(
          '04 / REVIEW LOOP',
          'No critics defined. Self-review by the builder reliably misses what '
              'the builder rationalised while building.',
        ),
      );
    } else {
      w.blank();
      w.line(
        'Use ${r.critics.length} specialist critics. '
        '${spec.runtime.subagentsRequired ? 'Each must be a **fresh-context subagent** that receives only the mission goal, the captured evidence, and the rubric — never the build history.' : 'Each must review from the captured evidence alone.'}',
      );
      w.blank();
      for (final Critic c in r.critics) {
        w.line('- **${c.name}** — ${c.judges}');
      }
    }

    w.blank();
    w.line('**After every cycle**');
    w.blank();
    w.line(r.regressionPolicy);
    w.blank();
    w.line(r.plateauRule);
  }

  // -- 05 / RUBRIC ---------------------------------------------------------

  void _rubric(_Writer w, MissionSpec spec, List<CompileWarning> warnings) {
    w.section('05 / RUBRIC');
    final Rubric r = spec.rubric;

    if (r.categories.isEmpty) {
      warnings.add(
        const CompileWarning(
          '05 / RUBRIC',
          'No rubric. Without one the agent cannot decide when it is finished, '
              'and the review loop has no exit condition.',
        ),
      );
      w.line('_No rubric was specified._');
      return;
    }

    if (!r.isBalanced) {
      warnings.add(
        CompileWarning(
          '05 / RUBRIC',
          'Weights sum to ${r.weightSum}, not ${r.total}. Scores computed '
              'against this rubric will not be interpretable.',
        ),
      );
    }

    w.line('Score the work out of ${r.total} against these weighted categories.');
    w.blank();
    w.line('| # | Category | Weight | Minimum | Judged on |');
    w.line('|---|---|---:|---:|---|');
    int i = 1;
    for (final RubricCategory c in r.categories) {
      final String min = c.minimum == null
          ? '—'
          : _trimNum(c.minimum!);
      w.line('| ${_pad(i)} | ${c.name} | ${c.weight} | $min | ${c.criteria} |');
      i++;
    }
    w.line('| | **Total** | **${r.weightSum}** | | |');
    w.blank();
    w.line(
      '**Exit threshold — ${r.exitThreshold} / ${r.total}.** '
      'Do not declare the mission complete below it.',
    );
    w.blank();
    w.line('Additional exit conditions, all of which must hold:');
    w.bullets(<String>[
      'Every category at or above its stated minimum, where one is given.',
      'Complete coverage of every required part and every artifact in the evidence set.',
      'No regression across the final two review cycles.',
    ]);
  }

  // -- 06 / VALIDATION -----------------------------------------------------

  void _validation(_Writer w, MissionSpec spec) {
    w.section('06 / VALIDATION');
    final ValidationPlan v = spec.validation;

    w.line(
      'Before declaring completion, prove the result survives being reopened '
      'from nothing.',
    );
    w.blank();
    if (v.coldStartProcedure.isNotEmpty) {
      w.line(v.coldStartProcedure);
      w.blank();
    }
    if (v.checks.isNotEmpty) {
      w.line('Confirm each of the following:');
      w.bullets(v.checks);
      w.blank();
    }
    w.line(v.reportContract);
  }

  // -- 07 / BRIEF ----------------------------------------------------------

  void _brief(_Writer w, MissionSpec spec, List<CompileWarning> warnings) {
    w.section('07 / BRIEF');

    if (spec.regions.isNotEmpty) {
      w.line('**Required parts**');
      w.blank();
      w.line(
        'Every one of the following must exist with real depth, believable '
        'access, and enough substance to explain its purpose.',
      );
      w.blank();
      int i = 1;
      for (final ScopeRegion r in spec.regions) {
        w.line('**${_pad(i)} · ${r.name}** — ${r.purpose}');
        if (r.requirements.isNotEmpty) {
          w.bullets(r.requirements);
        }
        w.blank();
        i++;
      }
      final bool anyLegible = spec.regions.any((ScopeRegion r) => r.mustBeLegible);
      if (anyLegible) {
        w.line(
          'No required part may exist only as a label. A part may be compact, '
          'but its interior, its boundaries, and its relationship to the rest '
          'must be legible in the final evidence.',
        );
        w.blank();
      }
    } else {
      warnings.add(
        const CompileWarning(
          '07 / BRIEF',
          'No required parts listed. Coverage cannot be checked and the agent '
              'will build only what the hero artifact shows.',
        ),
      );
    }

    if (spec.relationships.isNotEmpty) {
      w.line('**Relationships that must hold**');
      w.bullets(spec.relationships);
      w.blank();
    }

    if (spec.families.isNotEmpty) {
      w.line('**Component families**');
      w.blank();
      w.line(
        'Build coherent reusable families rather than unrelated one-offs. '
        'Repetition may use instances, but silhouette, orientation, state, and '
        'placement must vary enough to avoid copy-paste regularity.',
      );
      w.blank();
      for (final ComponentFamily f in spec.families) {
        final StringBuffer b = StringBuffer('- **${f.name}** — ${f.description}');
        if (f.minimumCount != null) {
          b.write(' _At least ${f.minimumCount}._');
        }
        w.line(b.toString());
        if (f.members.isNotEmpty) {
          w.line('  Includes: ${f.members.join(', ')}.');
        }
        if (f.variationRule != null) {
          w.line('  Variation: ${f.variationRule}');
        }
      }
      w.blank();
    }

    _qualityLanguage(w, spec.quality);
  }

  void _qualityLanguage(_Writer w, QualityLanguage q) {
    if (q.palette.isNotEmpty) {
      w.line('**Palette**');
      w.bullets(q.palette);
      w.blank();
    }
    if (q.materials.isNotEmpty) {
      w.line('**Materials and surfaces**');
      w.bullets(q.materials);
      w.blank();
    }
    if (q.atmosphere.isNotEmpty) {
      w.line('**Atmosphere and light**');
      w.blank();
      w.line(q.atmosphere);
      w.blank();
    }
    if (q.compositionRules.isNotEmpty) {
      w.line('**Composition**');
      w.bullets(q.compositionRules);
      w.blank();
    }
    if (q.detailStandard.isNotEmpty) {
      w.line('**Detail standard**');
      w.blank();
      w.line(q.detailStandard);
      w.blank();
    }
    if (q.storytelling.isNotEmpty) {
      w.line('**Evidence of use**');
      w.blank();
      w.line(
        'The result must feel operational rather than staged. Include '
        'restrained evidence such as:',
      );
      w.bullets(q.storytelling);
      w.blank();
      w.line(
        'Every detail must communicate function, recent activity, maintenance, '
        'or occupancy. Do not scatter clutter to hide weak fundamentals.',
      );
      w.blank();
    }
  }

  // -- 08 / DELIVERABLES ---------------------------------------------------

  void _deliverables(
    _Writer w,
    MissionSpec spec,
    List<CompileWarning> warnings,
  ) {
    w.section('08 / DELIVERABLES');

    if (spec.evidence.isEmpty) {
      warnings.add(
        const CompileWarning(
          '08 / DELIVERABLES',
          'No evidence set. Nothing fixes what the review loop re-captures each '
              'cycle, so regressions cannot be detected by comparison.',
        ),
      );
    } else {
      w.line('**Evidence set — the fixed judgeset**');
      w.blank();
      w.line(
        'Produce exactly these ${spec.evidence.length} artifacts, with these '
        'names. They are re-captured identically every review cycle, and they '
        'must collectively prove that every required part is complete — not '
        'merely repeat the best angle.',
      );
      w.blank();
      final List<EvidenceArtifact> set = <EvidenceArtifact>[...spec.evidence]
        ..sort((EvidenceArtifact a, EvidenceArtifact b) =>
            a.ordinal.compareTo(b.ordinal));
      for (final EvidenceArtifact e in set) {
        w.line('**${_pad(e.ordinal)} · `${e.fileName}`** — ${e.name}');
        w.line('  ${e.proves}');
        final List<String> notes = <String>[
          if (e.minimumSpec != null) 'Minimum: ${e.minimumSpec}',
          if (e.acceptance != null) 'Accepted when: ${e.acceptance}',
          if (e.isHero) 'This is the hero artifact.',
        ];
        for (final String n in notes) {
          w.line('  _${n}_');
        }
        w.blank();
      }
    }

    final DeliverablePlan d = spec.deliverables;
    if (d.tree.isNotEmpty) {
      w.line('**File structure**');
      w.blank();
      final int width = d.tree.keys
          .fold<int>(0, (int a, String k) => k.length > a ? k.length : a);
      w.code(<String>[
        for (final MapEntry<String, String> e in d.tree.entries)
          '${e.key.padRight(width + 2)}# ${e.value}',
      ]);
      w.blank();
    }
    if (d.namingRules.isNotEmpty) {
      w.line('**Organisation and naming**');
      w.bullets(d.namingRules);
      w.blank();
    }
    if (d.portabilityRules.isNotEmpty) {
      w.line('**Portability**');
      w.bullets(d.portabilityRules);
      w.blank();
    }
  }

  // -- 09 / FAILURE CONDITIONS ---------------------------------------------

  void _failureConditions(
    _Writer w,
    MissionSpec spec,
    List<CompileWarning> warnings,
  ) {
    w.section('09 / FAILURE CONDITIONS');

    if (spec.failureConditions.isEmpty) {
      warnings.add(
        const CompileWarning(
          '09 / FAILURE CONDITIONS',
          'No failure conditions. These do more than the rubric to prevent the '
              'specific shortcuts an agent reaches for under time pressure.',
        ),
      );
      w.line('_No failure conditions were specified._');
      return;
    }

    w.line('The following make the delivered result unacceptable:');
    w.blank();
    for (final FailureCondition f in spec.failureConditions) {
      w.line('- ${f.text}');
    }
  }

  void _closing(_Writer w, MissionSpec spec, TransportProfile profile) {
    w.blank();
    w.rule();
    w.blank();
    w.line(
      'Begin now. Work in `${spec.deliverables.projectDirectory.isEmpty ? spec.taskId : spec.deliverables.projectDirectory}`. '
      'Do not ask for confirmation before starting.',
    );
  }
}

String _pad(int n) => n < 10 ? '0$n' : '$n';

String _trimNum(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// Accumulates prompt text while recording where each section starts.
class _Writer {
  final StringBuffer _b = StringBuffer();
  final Map<String, int> offsets = <String, int>{};

  String get text => '${_b.toString().trimRight()}\n';

  void section(String heading) {
    if (_b.isNotEmpty) {
      blank();
      rule();
      blank();
    }
    offsets[heading] = _b.length;
    _b.writeln('## $heading');
    _b.writeln();
  }

  void line(String s) => _b.writeln(s);

  void raw(String s) => _b.writeln(s);

  void blank() => _b.writeln();

  void rule() => _b.writeln('---');

  void field(String label, String value) {
    if (value.trim().isEmpty) return;
    _b.writeln('**$label** · ${value.trim()}');
    _b.writeln();
  }

  void bullets(Iterable<String> items) {
    for (final String i in items) {
      if (i.trim().isEmpty) continue;
      _b.writeln('- ${i.trim()}');
    }
  }

  void code(List<String> lines) {
    _b.writeln('```');
    for (final String l in lines) {
      _b.writeln(l);
    }
    _b.writeln('```');
  }
}
