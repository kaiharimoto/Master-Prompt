import 'package:meta/meta.dart';

import '../compile/compiled_prompt.dart';
import '../spec/mission_spec.dart';
import '../spec/spec_types.dart';
import 'interview_stage.dart';
import 'readiness.dart';

/// A block of text to hand to the model, and what it is for.
@immutable
class InterviewTurn {
  const InterviewTurn({
    required this.stage,
    required this.text,
    required this.gaps,
  });

  final InterviewStage stage;

  /// The text the user copies into the chat, or the CLI sends directly.
  final String text;

  /// What this turn is trying to settle.
  final List<ReadinessGap> gaps;

  int get estimatedTokens => (text.length / 3.6).ceil();
}

/// Generates the turns of the pre-build discussion.
///
/// The discussion is the product. The reference run this project is modelled on
/// went through several rounds of it before any prompt was written, on the
/// stated principle that asking *what* thoroughly is what lets the model end up
/// understanding the goal better than the author does.
///
/// One engine serves both transports: on the desktop the text goes straight to
/// the CLI, on a phone the user copies it into a chat and pastes the reply back.
/// Nothing above this class knows which.
class InterviewEngine {
  const InterviewEngine({this.gate = const ReadinessGate()});

  final ReadinessGate gate;

  ReadinessReport assess(MissionSpec spec) => gate.evaluate(spec);

  /// The next turn to put to the model.
  InterviewTurn nextTurn(MissionSpec spec) {
    final ReadinessReport report = gate.evaluate(spec);
    final InterviewStage stage = report.currentStage;
    final List<ReadinessGap> stageGaps = report.gaps
        .where((ReadinessGap g) => g.stage == stage)
        .toList();

    if (stage == InterviewStage.ready) {
      return InterviewTurn(
        stage: stage,
        text: _readyText(spec),
        gaps: const <ReadinessGap>[],
      );
    }

    final StringBuffer b = StringBuffer();
    _role(b);
    _missionSoFar(b, spec);

    b
      ..writeln('## This round: ${stage.title}')
      ..writeln()
      ..writeln(stage.purpose)
      ..writeln()
      ..writeln('Still unsettled:')
      ..writeln();
    for (final ReadinessGap g in stageGaps) {
      b.writeln('- **${g.label}** — ${g.why}');
    }
    b.writeln();

    b
      ..writeln('## What to do')
      ..writeln()
      ..writeln(
        'Ask me **two to four** focused questions about the items above. Ask '
        'about what the thing should be, not how to build it — implementation '
        'comes later and deciding it now would anchor the whole brief.',
      )
      ..writeln()
      ..writeln(
        '**For each question, offer two to four concrete numbered options**, '
        'each one a real answer I could take as written, plus the option of '
        'telling you something else. A specific proposal is far easier to react '
        'to than a blank page, and it means I can answer with just numbers.',
      )
      ..writeln()
      ..writeln(
        'Do not ask about anything already settled above. Do not write the '
        'brief yet.',
      )
      ..writeln()
      ..writeln('## How to hand the answers back')
      ..writeln()
      ..writeln(
        'Once I have answered, and only then, **end your reply with exactly one '
        'fenced `json` code block, and put nothing at all after it.** I copy '
        'that block with one tap, so it must be the last thing in the message '
        'and it must be a code block.',
      )
      ..writeln()
      ..writeln(
        'Include only the keys this round actually settled. Write full '
        'sentences in the values — they go into the brief verbatim. Do not '
        'include a key you are guessing at; leave it out and ask me next round.',
      )
      ..writeln();
    _patchFormat(b, stage);

    return InterviewTurn(stage: stage, text: b.toString(), gaps: stageGaps);
  }

  /// A turn that attacks the compiled prompt the way an unattended run would.
  ///
  /// Run after compilation. The failure this catches is the expensive one: an
  /// ambiguity nobody noticed, discovered nine hours into a build that cannot
  /// ask for clarification.
  InterviewTurn redTeamTurn(MissionSpec spec, CompiledPrompt compiled) {
    final StringBuffer b = StringBuffer()
      ..writeln('# Red-team this mission brief')
      ..writeln()
      ..writeln(
        'Below is a brief that is about to be handed to an autonomous agent. '
        'It will run for hours with no human available. It cannot ask '
        'questions. If something is ambiguous, it will guess, and nobody will '
        'find out until the run finishes.',
      )
      ..writeln()
      ..writeln('Attack it. Specifically, find:')
      ..writeln()
      ..writeln(
        '1. **Ambiguities** — anything two competent readers would build '
        'differently.',
      )
      ..writeln(
        '2. **Unmeasurable criteria** — rubric lines or acceptance rules that '
        'cannot be judged from the evidence set.',
      )
      ..writeln(
        '3. **Coverage holes** — required parts no artifact in the evidence set '
        'would reveal. These are where an agent quietly builds a facade.',
      )
      ..writeln(
        '4. **Missing decisions** — choices the agent must make that the brief '
        'does not make for it.',
      )
      ..writeln(
        '5. **Contradictions** — places where two instructions cannot both be '
        'satisfied.',
      )
      ..writeln(
        '6. **Cheap escapes** — ways to score well against the rubric without '
        'doing the work.',
      )
      ..writeln()
      ..writeln(
        'Be specific and cite the section. Do not praise the brief and do not '
        'summarise it. If a section is genuinely sound, say nothing about it.',
      )
      ..writeln()
      ..writeln(
        'Then end your reply with exactly one fenced `json` block containing '
        'only the fixes you would make, and nothing after it. Where a fix is a '
        'judgement call I should make, ask instead of guessing.',
      )
      ..writeln();
    _patchFormat(b, InterviewStage.ready);
    b
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln(compiled.body);

    return InterviewTurn(
      stage: InterviewStage.ready,
      text: b.toString(),
      gaps: const <ReadinessGap>[],
    );
  }

  void _role(StringBuffer b) {
    b
      ..writeln(
        'You are helping me specify a mission before any of it is built.',
      )
      ..writeln()
      ..writeln(
        'The result of this conversation is a brief precise enough that an '
        'autonomous agent can execute it for hours without asking anything. '
        'Every question you leave unasked now becomes a guess later.',
      )
      ..writeln();
  }

  void _missionSoFar(StringBuffer b, MissionSpec spec) {
    b
      ..writeln('## The mission so far')
      ..writeln();
    final String mission = spec.missionStatement.value?.trim() ?? '';
    b.writeln(
      mission.isEmpty
          ? '_Nothing settled yet._'
          : '**${spec.title}** — $mission',
    );
    b.writeln();

    final List<String> settled = <String>[
      if ((spec.definingStory.value ?? '').isNotEmpty)
        'Story: ${spec.definingStory.value}',
      if ((spec.scale.value ?? '').isNotEmpty) 'Scale: ${spec.scale.value}',
      if ((spec.audience.value ?? '').isNotEmpty)
        'Judged by: ${spec.audience.value}',
      if (spec.regions.isNotEmpty)
        'Parts (${spec.regions.length}): '
            '${spec.regions.map((ScopeRegion r) => r.name).join(', ')}',
      if (spec.families.isNotEmpty)
        'Families (${spec.families.length}): '
            '${spec.families.map((ComponentFamily f) => f.name).join(', ')}',
      if (spec.evidence.isNotEmpty)
        'Evidence set: ${spec.evidence.length} artifacts',
      if (spec.rubric.categories.isNotEmpty)
        'Rubric: ${spec.rubric.categories.length} categories, '
            'exit ${spec.rubric.exitThreshold}/${spec.rubric.total}',
      if (spec.review.critics.isNotEmpty)
        'Critics: ${spec.review.critics.map((Critic c) => c.name).join(', ')}',
      if (spec.quality.avoid.isNotEmpty)
        'Avoiding: ${spec.quality.avoid.join('; ')}',
      if (spec.failureConditions.isNotEmpty)
        'Failure conditions: ${spec.failureConditions.length} recorded',
    ];
    if (settled.isNotEmpty) {
      for (final String s in settled) {
        b.writeln('- $s');
      }
      b.writeln();
    }
  }

  /// The shape the answers come back in.
  ///
  /// JSON, and self-delimiting on purpose. Tapping copy on a fenced code block
  /// in a chat app copies the block's *contents*, not the backticks — so a
  /// format that depends on its fence to be found is broken on the very path
  /// the user is meant to take. An object can be located by its braces alone.
  void _patchFormat(StringBuffer b, InterviewStage stage) {
    b.writeln('```json');
    switch (stage) {
      case InterviewStage.seed:
      case InterviewStage.intent:
        b
          ..writeln('{')
          ..writeln('  "mission": "one paragraph on what is being built",')
          ..writeln('  "story": "the through-line someone should experience",')
          ..writeln('  "scale": "concrete extent, in real units",')
          ..writeln('  "audience": "who judges it and by what standard"')
          ..writeln('}');
      case InterviewStage.shape:
        b
          ..writeln('{')
          ..writeln('  "regions": [')
          ..writeln('    {"name": "...", "purpose": "what it is for",')
          ..writeln('     "requirements": ["...", "..."]}')
          ..writeln('  ],')
          ..writeln('  "relationships": ["a rule the parts must obey"],')
          ..writeln('  "families": [')
          ..writeln('    {"name": "...", "description": "...", "min": 30,')
          ..writeln('     "vary": "how instances must differ"}')
          ..writeln('  ]')
          ..writeln('}');
      case InterviewStage.quality:
        b
          ..writeln('{')
          ..writeln('  "avoid": ["an interpretation to steer away from"],')
          ..writeln('  "palette": ["a colour, tone or stylistic anchor"],')
          ..writeln('  "materials": ["a surface or substance rule"],')
          ..writeln('  "atmosphere": "the light, mood or tone",')
          ..writeln('  "detail": "how close an inspection it must survive",')
          ..writeln('  "storytelling": ["evidence of real use"]')
          ..writeln('}');
      case InterviewStage.evidence:
        b
          ..writeln('{')
          ..writeln('  "evidence": [')
          ..writeln('    {"ordinal": 1, "file": "01_arrival.png",')
          ..writeln('     "name": "...", "proves": "what it demonstrates",')
          ..writeln('     "min": "1920x1080"},')
          ..writeln('    {"ordinal": 3, "file": "03_hero.png", "name": "Hero",')
          ..writeln('     "proves": "...", "hero": true, "min": "2560x1440"}')
          ..writeln('  ]')
          ..writeln('}');
      case InterviewStage.runtime:
        b
          ..writeln('{')
          ..writeln('  "compute": "the machine and environment",')
          ..writeln('  "tool": "the tool the work is done with",')
          ..writeln('  "harness": "subagents, parallelism, orchestration",')
          ..writeln('  "budget": "how many tokens",')
          ..writeln('  "wallclock": "how long",')
          ..writeln('  "steps": [{"ordinal": 1, "name": "...",')
          ..writeln('             "instruction": "what happens in this step"}]')
          ..writeln('}');
      case InterviewStage.rubric:
        b
          ..writeln('{')
          ..writeln('  "rubric": [')
          ..writeln('    {"name": "...", "weight": 20, "criteria": "...",')
          ..writeln('     "min": 17}')
          ..writeln('  ],')
          ..writeln('  "total": 100,')
          ..writeln('  "exit": 90')
          ..writeln('}');
      case InterviewStage.review:
        b
          ..writeln('{')
          ..writeln('  "cycles": 4,')
          ..writeln('  "critics": [')
          ..writeln('    {"name": "...", "judges": "the one thing it judges"}')
          ..writeln('  ]')
          ..writeln('}');
      case InterviewStage.acceptance:
      case InterviewStage.ready:
        b
          ..writeln('{')
          ..writeln('  "failures": ["what makes the result unacceptable"],')
          ..writeln(
            '  "coldstart": "how to reopen it from nothing and verify",',
          )
          ..writeln('  "checks": ["something that must be true at the end"],')
          ..writeln('  "dir": "project_directory_name",')
          ..writeln('  "files": {"renders/final/": "what lives here"}')
          ..writeln('}');
    }
    b.writeln('```');
  }

  String _readyText(MissionSpec spec) =>
      'Everything required is settled for "${spec.title}". '
      '${spec.regions.length} parts, ${spec.families.length} component '
      'families, ${spec.evidence.length} evidence artifacts, '
      '${spec.rubric.categories.length} rubric categories with an exit at '
      '${spec.rubric.exitThreshold}/${spec.rubric.total}, and '
      '${spec.review.critics.length} critics. The brief can be compiled.';
}
