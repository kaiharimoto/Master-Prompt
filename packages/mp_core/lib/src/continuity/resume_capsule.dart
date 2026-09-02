import 'package:meta/meta.dart';

import '../compile/compiled_prompt.dart';
import '../spec/mission_spec.dart';
import '../spec/spec_types.dart';
import 'mp_state.dart';

/// How much of the mission a capsule carries.
///
/// Degradation is by *priority*, never by summarising: a capsule that
/// paraphrases the rubric produces a run that scores itself against a rubric
/// that does not exist.
enum CapsuleTier {
  /// Everything, including the domain brief.
  full,

  /// Invariants, state, evidence ledger and next action. The default.
  standard,

  /// Invariants, state and next action only. For very tight paste limits.
  minimal,
}

/// A self-contained block that lets a brand-new conversation continue a run
/// that was cut off.
///
/// This is used in two places that look different and are the same thing: an
/// Android chat killed by a usage limit, and a desktop session whose CLI
/// transcript could no longer be resumed. Both need to hand a fresh context
/// everything it must not re-derive.
@immutable
class ResumeCapsule {
  const ResumeCapsule({
    required this.text,
    required this.tier,
    required this.taskId,
    this.droppedSections = const <String>[],
  });

  final String text;
  final CapsuleTier tier;
  final String taskId;

  /// What had to be left out to fit the budget, so the UI can say so plainly
  /// rather than pretending the capsule is complete.
  final List<String> droppedSections;

  int get characterCount => text.length;

  int get estimatedTokens => (text.length / 3.6).ceil();

  /// Split into numbered parts for a chat app that caps paste length.
  ///
  /// Each part is self-labelling so the assistant knows to wait rather than
  /// acting on half a capsule.
  List<String> chunk({int maxCharacters = 12000}) {
    if (text.length <= maxCharacters) return <String>[text];

    final List<String> parts = <String>[];
    final List<String> lines = text.split('\n');
    StringBuffer current = StringBuffer();
    for (final String line in lines) {
      if (current.length + line.length + 1 > maxCharacters &&
          current.isNotEmpty) {
        parts.add(current.toString().trimRight());
        current = StringBuffer();
      }
      current.writeln(line);
    }
    if (current.isNotEmpty) parts.add(current.toString().trimRight());

    return <String>[
      for (int i = 0; i < parts.length; i++)
        'MISSION CAPSULE — part ${i + 1} of ${parts.length} for `$taskId`.\n'
            '${i + 1 < parts.length ? 'Do not act yet. Reply only with "part ${i + 1} received" and wait for the next part.' : 'This is the final part. Now continue the mission from the state below.'}\n\n'
            '${parts[i]}',
    ];
  }
}

/// Builds [ResumeCapsule]s from a spec, its compiled prompt, and the last known
/// state.
class ResumeCapsuleBuilder {
  const ResumeCapsuleBuilder();

  /// Roughly how many characters a capsule may occupy before content is
  /// dropped. Generous by default; the chat app's paste limit is handled
  /// separately by [ResumeCapsule.chunk].
  static const int defaultBudget = 14000;

  ResumeCapsule build({
    required MissionSpec spec,
    required MpState? state,
    CompiledPrompt? compiled,
    CapsuleTier tier = CapsuleTier.standard,
    int budget = defaultBudget,
    List<String> producedArtifacts = const <String>[],
    List<String> openFindings = const <String>[],
    List<String> completedSteps = const <String>[],
  }) {
    final List<String> dropped = <String>[];
    String text = _render(
      spec: spec,
      state: state,
      compiled: compiled,
      tier: tier,
      producedArtifacts: producedArtifacts,
      openFindings: openFindings,
      completedSteps: completedSteps,
      dropped: dropped,
    );

    // Step down a tier at a time rather than truncating, so what survives is
    // always coherent.
    CapsuleTier effective = tier;
    while (text.length > budget && effective != CapsuleTier.minimal) {
      effective = effective == CapsuleTier.full
          ? CapsuleTier.standard
          : CapsuleTier.minimal;
      dropped.clear();
      text = _render(
        spec: spec,
        state: state,
        compiled: compiled,
        tier: effective,
        producedArtifacts: producedArtifacts,
        openFindings: openFindings,
        completedSteps: completedSteps,
        dropped: dropped,
      );
    }

    return ResumeCapsule(
      text: text,
      tier: effective,
      taskId: spec.taskId,
      droppedSections: List<String>.unmodifiable(dropped),
    );
  }

  String _render({
    required MissionSpec spec,
    required MpState? state,
    required CompiledPrompt? compiled,
    required CapsuleTier tier,
    required List<String> producedArtifacts,
    required List<String> openFindings,
    required List<String> completedSteps,
    required List<String> dropped,
  }) {
    final StringBuffer b = StringBuffer();

    b.writeln('# MISSION RESUME — ${spec.title}');
    b.writeln();
    b.writeln(
      'You are continuing an in-progress mission that was interrupted. A '
      'previous session did the work described below. **Do not start over and '
      'do not re-plan.** Read the state, then carry out the single next action.',
    );
    b.writeln();
    b.writeln('`task-id: ${spec.taskId}`');
    b.writeln();
    b.writeln('---');
    b.writeln();

    // --- pinned: what the run is -------------------------------------------
    b.writeln('## The mission');
    b.writeln();
    final String statement = spec.missionStatement.value?.trim() ?? '';
    if (statement.isNotEmpty) {
      b.writeln(statement);
      b.writeln();
    }
    final String story = spec.definingStory.value?.trim() ?? '';
    if (story.isNotEmpty && tier != CapsuleTier.minimal) {
      b.writeln('**Defining story** — $story');
      b.writeln();
    }

    // --- pinned: where it stands -------------------------------------------
    b.writeln('## Where it stands');
    b.writeln();
    if (state == null) {
      b.writeln(
        '_No state was recorded. Re-read the working documents in the project '
        'directory and establish the current position before changing anything._',
      );
      b.writeln();
    } else {
      b.writeln('- **Phase** — ${state.phase.name}');
      if (state.step.isNotEmpty) {
        b.writeln('- **Current step** — ${state.step}');
      }
      if (state.cycle > 0) b.writeln('- **Review cycle** — ${state.cycle}');
      if (state.score > 0) {
        b.writeln(
          '- **Score** — ${state.score} of ${spec.rubric.total} '
          '(exit at ${spec.rubric.exitThreshold})',
        );
      }
      if (state.isBlocked) b.writeln('- **Blocked by** — ${state.blocked}');
      b.writeln();
      if (state.next.isNotEmpty) {
        b.writeln('**The next action is:** ${state.next}');
        b.writeln();
      }
    }

    if (completedSteps.isNotEmpty && tier != CapsuleTier.minimal) {
      b.writeln('**Already done**');
      for (final String s in completedSteps) {
        b.writeln('- $s');
      }
      b.writeln();
    } else if (completedSteps.isNotEmpty) {
      dropped.add('completed steps');
    }

    // --- pinned: the invariants, verbatim ----------------------------------
    b.writeln('---');
    b.writeln();
    b.writeln('## Rules that still apply');
    b.writeln();
    b.writeln(
      'Perform the actual work; do not answer with only a plan. The user may be '
      'unavailable — make conservative, reversible assumptions, record them, and '
      'continue. Stop only for credentials, a destructive external action, or an '
      'ambiguity that would materially change the authorised project.',
    );
    b.writeln();

    if (spec.rubric.categories.isNotEmpty) {
      b.writeln(
        '**Rubric — ${spec.rubric.total} points, exit at '
        '${spec.rubric.exitThreshold}.** Score against these exactly:',
      );
      b.writeln();
      for (final RubricCategory c in spec.rubric.categories) {
        b.writeln('- ${c.name} (${c.weight}) — ${c.criteria}');
      }
      b.writeln();
    }

    if (spec.failureConditions.isNotEmpty) {
      b.writeln('**These make the result unacceptable:**');
      b.writeln();
      for (final FailureCondition f in spec.failureConditions) {
        b.writeln('- ${f.text}');
      }
      b.writeln();
    }

    // --- high: the evidence ledger -----------------------------------------
    if (spec.evidence.isNotEmpty && tier != CapsuleTier.minimal) {
      final Set<String> done = producedArtifacts.toSet();
      b.writeln('---');
      b.writeln();
      b.writeln('## Evidence set — the fixed judgeset');
      b.writeln();
      b.writeln(
        'Re-capture all of these identically each cycle. '
        '${done.isEmpty ? 'None recorded as produced yet.' : '${done.length} of ${spec.evidence.length} recorded as produced.'}',
      );
      b.writeln();
      for (final EvidenceArtifact e in spec.evidence) {
        final String mark = done.contains(e.fileName) ? 'x' : ' ';
        b.writeln('- [$mark] `${e.fileName}` — ${e.name}');
      }
      b.writeln();
    } else if (spec.evidence.isNotEmpty) {
      dropped.add('evidence ledger');
    }

    if (openFindings.isNotEmpty && tier != CapsuleTier.minimal) {
      b.writeln('**Open findings to resolve**');
      b.writeln();
      for (final String f in openFindings) {
        b.writeln('- $f');
      }
      b.writeln();
    } else if (openFindings.isNotEmpty) {
      dropped.add('open findings');
    }

    // --- low: the full domain brief ----------------------------------------
    if (tier == CapsuleTier.full && compiled != null) {
      final String? brief = compiled.section('07 / BRIEF');
      if (brief != null) {
        b.writeln('---');
        b.writeln();
        b.writeln(brief);
        b.writeln();
      }
    } else if (compiled != null) {
      dropped.add('full domain brief (section 07)');
    }

    // --- pinned: the heartbeat contract ------------------------------------
    b.writeln('---');
    b.writeln();
    b.writeln('## Required on every reply');
    b.writeln();
    b.writeln(
      'End every response with this block so the run can be tracked and resumed '
      'again if this conversation is also cut off:',
    );
    b.writeln();
    // Fenced with tildes: the capsule itself is pasted into a chat, and a
    // backtick fence here would terminate any backtick fence wrapping it.
    b.writeln('~~~');
    b.writeln('```mpstate');
    b.writeln('v=1');
    b.writeln('task=${spec.taskId}');
    b.writeln('phase=<bootstrap|build|review|validation|done>');
    b.writeln('step=<current step>');
    b.writeln('cycle=<review cycle number>');
    b.writeln('score=<current score, or 0>');
    b.writeln('next=<the single next action>');
    b.writeln('blocked=<none, or what is blocking>');
    b.writeln('ask=<none, or one question>');
    b.writeln('```');
    b.writeln('~~~');
    b.writeln();
    b.writeln('Begin with the next action above. Do not ask for confirmation.');

    return b.toString();
  }
}
