import 'package:meta/meta.dart';

import '../compile/compiled_prompt.dart';
import '../spec/mission_spec.dart';
import '../spec/source_prompt.dart';
import '../spec/spec_types.dart';
import 'interview_stage.dart';
import 'readiness.dart';

/// How much the turn assumes its reader already knows.
///
/// The interview is meant to happen in one continuing chat, and that chat has
/// already been told who it is, what has been settled, and what shape the
/// answers come back in — it settled most of it itself. Re-sending all of that
/// every round costs tokens on a plan with limits, and buries the one thing the
/// round is actually about under three screens of preamble the user has already
/// read.
enum TurnStyle {
  /// Written for a reader that has seen nothing: the framing, everything
  /// settled so far, and the format rules in full. The first round of a
  /// mission, and any round after the chat has had to be restarted.
  standalone,

  /// Written for the chat that has been answering all along. Only what this
  /// round adds, plus the schema for it — everything else is already above it
  /// in the conversation.
  continuing,
}

/// A block of text to hand to the model, and what it is for.
@immutable
class InterviewTurn {
  const InterviewTurn({
    required this.stage,
    required this.text,
    required this.gaps,
    this.style = TurnStyle.standalone,
    this.document = '',
    this.reading = false,
    String? note,
  }) : note = note ?? text;

  final InterviewStage stage;

  /// Whether this is the round that reads a prompt the user already had,
  /// rather than one that asks about a stage.
  final bool reading;

  final TurnStyle style;

  /// The long artifact this turn is about, when it has one.
  ///
  /// The red-team pass is an instruction plus the whole compiled brief, and
  /// the two leave the app by different routes: the instruction fits in a chat
  /// message, the brief does not. Separating them here is what lets the brief
  /// travel as an attachment instead of as four pasted fragments. A mission
  /// started from a prompt carries that prompt here on every turn written for
  /// a fresh chat; every other interview turn has none.
  final String document;

  /// Everything but [document] — what goes in the message itself.
  final String note;

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
  ///
  /// [style] decides how much of it is preamble. The default is the safe one:
  /// a turn that stands on its own is correct in a chat that has seen it all
  /// before, whereas a continuing turn dropped into a fresh chat is not.
  InterviewTurn nextTurn(
    MissionSpec spec, {
    TurnStyle style = TurnStyle.standalone,
  }) {
    final ReadinessReport report = gate.evaluate(spec);
    final SourcePrompt? source = spec.source;

    // A prompt that has not been read yet is read before anything is asked:
    // most of what the stages would ask, a real prompt already answers.
    if (source != null && !source.read) return _readingTurn(spec, report);

    final InterviewStage stage = report.currentStage;
    final List<ReadinessGap> stageGaps = report.gaps
        .where((ReadinessGap g) => g.stage == stage)
        .toList();

    if (stage == InterviewStage.ready) {
      return InterviewTurn(
        stage: stage,
        text: _readyText(spec),
        gaps: const <ReadinessGap>[],
        style: style,
      );
    }

    if (style == TurnStyle.continuing) {
      return InterviewTurn(
        stage: stage,
        text: _continuingText(stage, stageGaps, fromSource: source != null),
        gaps: stageGaps,
        style: style,
      );
    }

    final StringBuffer b = StringBuffer();
    if (source == null) {
      _role(b);
    } else {
      _roleFromSource(b);
    }
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
        'Ask me **one or two questions per unsettled item above, up to six in '
        'all**. I answer these by tapping, not by typing, so a further '
        'question costs me a moment and a further round trip costs a minute — '
        'cover the round rather than saving me questions. Ask about what the '
        'thing should be, not how to build it: implementation comes later and '
        'deciding it now would anchor the whole brief.',
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
        'Give each option **one line on what it would mean for the build** — '
        'the consequence, not the label restated. "Twelve seats" is a label; '
        '"twelve seats, so the room reads as intimate and the pass can stay '
        'open" is a choice I can actually make.',
      )
      ..writeln()
      ..writeln(
        '**Mark one option recommended and say in a few words why**, based on '
        'what is already settled above rather than on general good practice. A '
        'recommendation that would fit any mission is worth nothing. If you '
        'genuinely have no basis to prefer one, say that instead of inventing '
        'a preference — this brief will run for hours with nobody available to '
        'correct it, and false confidence in it is worse than no opinion.',
      )
      ..writeln()
      ..writeln(
        'Do not ask about anything already settled above. Do not write the '
        'brief yet.',
      )
      ..writeln();
    if (source != null) {
      b
        ..writeln(
          '**Ground every question in my original prompt.** Where it says '
          'something about the item, quote the passage and ask about what it '
          'leaves open rather than starting from nothing; where it is silent, '
          'say so. Let what it says shape your options and your '
          'recommendation — it is the best evidence there is of what I meant.',
        )
        ..writeln();
    }
    b
      ..writeln()
      ..writeln('## Index your questions so I can answer by tapping')
      ..writeln()
      ..writeln(
        'After the questions, add one fenced `mpask` block listing them. One '
        'line per question, one per option, `|` between fields, and the word '
        '`recommended` as the last field on the one you recommend:',
      )
      ..writeln()
      ..writeln('```mpask')
      ..writeln('q1=How many seats should the room hold?')
      ..writeln('q1a=Twelve|a private room, and the pass can stay open')
      ..writeln('q1b=Twenty|the brief already says intimate|recommended')
      ..writeln('q1c=Forty|the bar stops being the point')
      ..writeln('```')
      ..writeln()
      ..writeln(
        'Keep the reasoning in the prose above — the block is an index to it, '
        'not a replacement, and it is read by the app rather than by me. Write '
        'it as lines exactly like that, never as JSON, and put it **before** '
        'the answer block below if you are sending both.',
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
      ..writeln()
      ..writeln(
        '**A recommendation is not an answer.** However obvious your '
        'recommended option looks, it does not go in the block until I have '
        'picked it. Waiting costs one message; a value I never agreed to '
        'reaching an unattended run costs the whole run.',
      )
      ..writeln();
    _patchFormat(b, stage);

    if (source == null) {
      return InterviewTurn(
        stage: stage,
        text: b.toString(),
        gaps: stageGaps,
        style: style,
      );
    }
    return _withSource(
      b.toString(),
      source,
      stage: stage,
      gaps: stageGaps,
      style: style,
    );
  }

  /// The round that reads a prompt the user already had.
  ///
  /// It asks nothing. Its whole job is to take what the prompt already
  /// settles, under the key each thing belongs to, and say which of the
  /// requirements it leaves open — the stages that follow ask about those, one
  /// at a time, grounded in what the prompt said. Splitting the two is what
  /// keeps the first reply short enough to review: the user accepts what was
  /// *taken* from their own words before being asked anything new.
  ///
  /// Everything it takes still arrives proposed and passes the same accept
  /// step as any round. A model reading a prompt is still a model inferring,
  /// and the line between "the prompt says" and "the prompt suggests" is
  /// exactly the one an unattended run cannot see.
  InterviewTurn _readingTurn(MissionSpec spec, ReadinessReport report) {
    final StringBuffer b = StringBuffer()
      ..writeln(
        'You are helping me turn a prompt I already wrote into a mission '
        'brief precise enough that an autonomous agent can execute it for '
        'hours without asking anything. Every question left unasked now '
        'becomes a guess later.',
      )
      ..writeln()
      ..writeln(
        'My prompt is included with this message, between '
        '`<original_prompt>` tags. Treat it as the evidence of what I want, '
        'not as a draft to overrule: where it is clear, keep its intent and '
        'its wording; where it is vague, silent or contradicts itself, that '
        'is what the next rounds will ask me about.',
      )
      ..writeln()
      ..writeln('## What a brief has to settle')
      ..writeln()
      ..writeln(
        'An unattended run needs every one of these. Each says what goes '
        'wrong without it.',
      )
      ..writeln();

    InterviewStage? heading;
    for (final SpecRequirement r in gate.requirements) {
      if (r.stage != heading) {
        if (heading != null) b.writeln();
        heading = r.stage;
        b
          ..writeln('**${r.stage.title}**')
          ..writeln();
      }
      b.writeln('- ${r.label}${r.required_ ? '' : ' (optional)'} — ${r.why}');
    }
    b
      ..writeln()
      ..writeln('## This round: read it, and do not ask anything yet')
      ..writeln()
      ..writeln(
        '1. **Take everything my prompt already settles** and put it in the '
        'block below, under the key it belongs to. Only what it states or '
        'plainly implies. If you would have to choose between two readings, '
        'leave the key out: a guess made here reaches an unattended run '
        'looking exactly like something I wrote.',
      )
      ..writeln(
        '2. **Keep my wording where it works.** Tighten it into full '
        'sentences that will stand in a brief, but do not add requirements it '
        'does not contain, and do not fill a gap with good practice.',
      )
      ..writeln(
        '3. **Lose nothing.** Anything in my prompt that matters but fits no '
        'key — a convention, a tone, a constraint, a thing never to do — goes '
        'in `carry`, word for word, one instruction per entry.',
      )
      ..writeln(
        '4. **Then say what it leaves open.** In a few short lines above the '
        'block, name the requirements from the list above that my prompt '
        'does not settle, the ones that would make an agent guess soonest '
        'first, and anywhere it contradicts itself. Do not ask the questions '
        'yet — the next rounds take them one stage at a time, with options.',
      )
      ..writeln()
      ..writeln('## How to hand it back')
      ..writeln()
      ..writeln(
        'End your reply with exactly one fenced `json` code block and put '
        'nothing at all after it. Use only the keys my prompt actually '
        'settles and leave every other key out entirely — an empty or '
        'placeholder value is worse than a missing one. Write full sentences '
        'in the values; they go into the brief verbatim.',
      )
      ..writeln()
      ..writeln('```json');
    for (final String line in _readingSchema()) {
      b.writeln(line);
    }
    b.writeln('```');

    return _withSource(
      b.toString(),
      spec.source!,
      stage: report.currentStage,
      gaps: report.gaps,
      style: TurnStyle.standalone,
      reading: true,
    );
  }

  /// A turn whose reader also needs the prompt the mission started from.
  ///
  /// The prompt is the turn's [InterviewTurn.document], wrapped in tags so it
  /// cannot be mistaken for instructions to the chat itself: whether it goes
  /// as the tail of one paste or as an attached file, it reads the same.
  InterviewTurn _withSource(
    String instruction,
    SourcePrompt source, {
    required InterviewStage stage,
    required List<ReadinessGap> gaps,
    required TurnStyle style,
    bool reading = false,
  }) {
    final String note = instruction.trimRight();
    final String document =
        '<original_prompt>\n${source.text.trim()}\n</original_prompt>';
    return InterviewTurn(
      stage: stage,
      text: '$note\n\n$document\n',
      note: note,
      document: document,
      gaps: gaps,
      style: style,
      reading: reading,
    );
  }

  /// The same round, for a chat that has been answering all along.
  ///
  /// Everything the standalone turn opens with — who the model is, what the
  /// mission is, everything settled so far, and the rules for handing answers
  /// back — that chat has already read, and mostly wrote. What is left is the
  /// subject of this round and the shape of this round's answer.
  ///
  /// The two rules survive as one sentence rather than two paragraphs. They are
  /// kept at all because format drift over nine rounds is real, and the cost of
  /// it is a reply the app cannot read; the schema below carries the rest.
  String _continuingText(
    InterviewStage stage,
    List<ReadinessGap> gaps, {
    bool fromSource = false,
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln('## Next: ${stage.title}')
      ..writeln()
      ..writeln(stage.purpose)
      ..writeln()
      ..writeln('Still unsettled:')
      ..writeln();
    for (final ReadinessGap g in gaps) {
      b.writeln('- **${g.label}** — ${g.why}');
    }
    b
      ..writeln()
      ..writeln(
        'Same as before: cover these in up to six questions, each with '
        'numbered options I can answer by number, one of them recommended with '
        'a reason, an `mpask` block indexing them so I can tap rather than '
        'type, nothing in the answer block I have not picked, and then end '
        'your reply with one fenced `json` block and nothing after it.',
      )
      ..writeln();
    if (fromSource) {
      b
        ..writeln(
          'Keep my original prompt in view: quote it where it bears on a '
          'question, and let it shape your recommendations.',
        )
        ..writeln();
    }
    _patchFormat(b, stage);
    return b.toString();
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
        'You have been given a brief that is about to be handed to an '
        'autonomous agent. It will run for hours with no human available. It '
        'cannot ask questions. If something is ambiguous, it will guess, and '
        'nobody will find out until the run finishes.',
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
        'judgement call I should make, ask instead of guessing — and ask it '
        'the same way: numbered options, one of them recommended with a '
        'reason, an `mpask` block indexing them, and nothing in the block '
        'until I have picked it.',
      )
      ..writeln();
    _patchFormat(b, InterviewStage.ready);
    final String note = b.toString().trimRight();

    // `text` stays the instruction and the brief together, because that is
    // what the copy fallback pastes and what every existing caller reads.
    b
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln(compiled.body);

    return InterviewTurn(
      stage: InterviewStage.ready,
      text: b.toString(),
      gaps: const <ReadinessGap>[],
      note: note,
      document: compiled.body,
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

  void _roleFromSource(StringBuffer b) {
    b
      ..writeln(
        'You are helping me turn a prompt I already wrote into a mission '
        'brief, before any of it is built.',
      )
      ..writeln()
      ..writeln(
        'The result is a brief precise enough that an autonomous agent can '
        'execute it for hours without asking anything. My original prompt is '
        'included with this message, between `<original_prompt>` tags; what '
        'it already settled is summarised below, and this round is about '
        'something it leaves open.',
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
      if (spec.standingInstructions.isNotEmpty)
        'Standing instructions: ${spec.standingInstructions.length} carried '
            'over',
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
    for (final String line in _schema(stage)) {
      b.writeln(line);
    }
    b.writeln('```');
  }

  /// The answer block for one stage, a line at a time.
  ///
  /// Lines rather than one string so the reading round can join every stage's
  /// keys into a single object, which is what a prompt that settles things
  /// across all of them needs.
  static List<String> _schema(InterviewStage stage) => switch (stage) {
    InterviewStage.seed || InterviewStage.intent => <String>[
      '{',
      '  "mission": "one paragraph on what is being built",',
      '  "story": "the through-line someone should experience",',
      '  "scale": "concrete extent, in real units",',
      '  "audience": "who judges it and by what standard"',
      '}',
    ],
    InterviewStage.shape => <String>[
      '{',
      '  "regions": [',
      '    {"name": "...", "purpose": "what it is for",',
      '     "requirements": ["...", "..."]}',
      '  ],',
      '  "relationships": ["a rule the parts must obey"],',
      '  "families": [',
      '    {"name": "...", "description": "...", "min": 30,',
      '     "vary": "how instances must differ"}',
      '  ]',
      '}',
    ],
    InterviewStage.quality => <String>[
      '{',
      '  "avoid": ["an interpretation to steer away from"],',
      '  "palette": ["a colour, tone or stylistic anchor"],',
      '  "materials": ["a surface or substance rule"],',
      '  "atmosphere": "the light, mood or tone",',
      '  "detail": "how close an inspection it must survive",',
      '  "storytelling": ["evidence of real use"]',
      '}',
    ],
    InterviewStage.evidence => <String>[
      '{',
      '  "evidence": [',
      '    {"ordinal": 1, "file": "01_arrival.png",',
      '     "name": "...", "proves": "what it demonstrates",',
      '     "min": "1920x1080"},',
      '    {"ordinal": 3, "file": "03_hero.png", "name": "Hero",',
      '     "proves": "...", "hero": true, "min": "2560x1440"}',
      '  ]',
      '}',
    ],
    InterviewStage.runtime => <String>[
      '{',
      '  "compute": "the machine and environment",',
      '  "tool": "the tool the work is done with",',
      '  "harness": "subagents, parallelism, orchestration",',
      '  "budget": "how many tokens",',
      '  "wallclock": "how long",',
      '  "steps": [{"ordinal": 1, "name": "...",',
      '             "instruction": "what happens in this step"}]',
      '}',
    ],
    InterviewStage.rubric => <String>[
      '{',
      '  "rubric": [',
      '    {"name": "...", "weight": 20, "criteria": "...",',
      '     "min": 17}',
      '  ],',
      '  "total": 100,',
      '  "exit": 90',
      '}',
    ],
    InterviewStage.review => <String>[
      '{',
      '  "cycles": 4,',
      '  "critics": [',
      '    {"name": "...", "judges": "the one thing it judges"}',
      '  ]',
      '}',
    ],
    InterviewStage.acceptance || InterviewStage.ready => <String>[
      '{',
      '  "failures": ["what makes the result unacceptable"],',
      '  "coldstart": "how to reopen it from nothing and verify",',
      '  "checks": ["something that must be true at the end"],',
      '  "dir": "project_directory_name",',
      '  "files": {"renders/final/": "what lives here"}',
      '}',
    ],
  };

  /// Every stage's keys in one object, for the round that reads a whole
  /// prompt at once, plus the two keys only that round needs: a name, and the
  /// instructions that belong to no stage.
  static List<String> _readingSchema() {
    final List<String> out = <String>[
      '{',
      '  "title": "a short name for the mission",',
    ];
    for (final InterviewStage s in <InterviewStage>[
      InterviewStage.intent,
      InterviewStage.shape,
      InterviewStage.quality,
      InterviewStage.evidence,
      InterviewStage.runtime,
      InterviewStage.rubric,
      InterviewStage.review,
      InterviewStage.acceptance,
    ]) {
      final List<String> lines = _schema(s);
      final List<String> inner = lines.sublist(1, lines.length - 1);
      out
        ..addAll(inner.take(inner.length - 1))
        ..add('${inner.last},');
    }
    out
      ..add(
        '  "carry": ["an instruction of mine that fits no key above, '
        'word for word"]',
      )
      ..add('}');
    return out;
  }

  String _readyText(MissionSpec spec) =>
      'Everything required is settled for "${spec.title}". '
      '${spec.regions.length} parts, ${spec.families.length} component '
      'families, ${spec.evidence.length} evidence artifacts, '
      '${spec.rubric.categories.length} rubric categories with an exit at '
      '${spec.rubric.exitThreshold}/${spec.rubric.total}, and '
      '${spec.review.critics.length} critics. The brief can be compiled.';
}
