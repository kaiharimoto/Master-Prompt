import 'package:meta/meta.dart';

import '../continuity/mp_state.dart';
import 'mission_spec.dart';
import 'spec_types.dart';

/// One thing the brief asked for that did not happen.
@immutable
class Shortfall {
  const Shortfall(this.what, {this.detail = ''});

  /// A line worth putting on screen, not a code.
  final String what;

  final String detail;
}

/// What the brief promised, checked against what actually happened.
///
/// The run was reported as finished on one signal: the process exited zero and
/// the CLI's result event said `success`. That is a fact about the process,
/// not about the mission. A twelve-hour run that produced three of eleven
/// artifacts, ran one review cycle of four and scored itself 61 against an
/// exit threshold of 90 was recorded as completed and painted green, which is
/// indistinguishable on screen from one that met every gate.
///
/// A silently wrong answer is worse than a missing one, and this is the only
/// place in the program that can tell the difference.
@immutable
class MissionOutcome {
  const MissionOutcome({
    required this.expected,
    required this.produced,
    required this.exitThreshold,
    required this.rubricTotal,
    required this.cyclesRequired,
    required this.criticsRequired,
    this.score,
    this.cyclesRun = 0,
    this.criticsSeen = 0,
    this.directivesMissing = const <String>[],
  });

  /// The fixed evidence set, by file name. The brief names these exactly so a
  /// re-capture overwrites rather than accumulates, which is also what makes
  /// them checkable.
  final List<String> expected;

  /// Which of them are on disk, non-empty.
  final Set<String> produced;

  final int exitThreshold;
  final int rubricTotal;
  final int cyclesRequired;

  /// The score the run last reported about itself, if it reported one.
  final double? score;

  final int cyclesRun;

  /// How many fresh-context critics the brief asked for.
  final int criticsRequired;

  /// How many distinct subagents the run actually spawned.
  ///
  /// `AssistantEvent.isSubagent` has always distinguished this traffic, and it
  /// was used only to keep subagent chatter out of the log. A brief that asks
  /// for four critics and gets none is a review that did not happen, and
  /// nothing could tell.
  final int criticsSeen;

  /// The working files the brief tells the agent to maintain, that are not
  /// there. `DIRECTION.md` and `TASK_STATE.md` are what a resumed session is
  /// told to re-read, so their absence is also the resume being hollow.
  final List<String> directivesMissing;

  bool get criticsMet => criticsSeen >= criticsRequired;

  bool get directivesMet => directivesMissing.isEmpty;

  List<String> get missing => <String>[
    for (final String f in expected)
      if (!produced.contains(f)) f,
  ];

  bool get artifactsComplete => missing.isEmpty;

  /// Null when the run never reported a score. Unknown is not the same as
  /// failed, and saying so is the point.
  bool? get scoreMet => score == null ? null : score! >= exitThreshold;

  bool get cyclesMet => cyclesRun >= cyclesRequired;

  /// True only when every gate the brief set was actually met. A run that
  /// reported no score at all cannot clear this, because nothing checked it.
  bool get met =>
      artifactsComplete &&
      (scoreMet ?? false) &&
      cyclesMet &&
      criticsMet &&
      directivesMet;

  /// Whether anything is known well enough to be worth saying. A mission with
  /// no evidence set, no rubric and no review loop has nothing to check.
  bool get hasGates =>
      expected.isNotEmpty ||
      rubricTotal > 0 ||
      cyclesRequired > 0 ||
      criticsRequired > 0;

  /// What is not right, in words worth showing to the person who waited.
  List<Shortfall> get shortfalls => <Shortfall>[
    if (missing.isNotEmpty)
      Shortfall(
        missing.length == 1
            ? 'One evidence artifact is missing'
            : '${missing.length} of ${expected.length} evidence artifacts are '
                  'missing',
        detail: missing.join(', '),
      ),
    if (score == null && rubricTotal > 0)
      const Shortfall(
        'The run never reported a score',
        detail:
            'The brief asks for an mpstate heartbeat on every reply. Without '
            'one there is nothing to check the exit threshold against.',
      )
    else if (scoreMet == false)
      Shortfall(
        'Scored ${score!.toStringAsFixed(0)} against an exit threshold of '
        '$exitThreshold',
        detail: 'The brief says not to declare completion below it.',
      ),
    if (!cyclesMet && cyclesRequired > 0)
      Shortfall(
        cyclesRun == 0
            ? 'No review cycle was reported, and the brief asks for '
                  '$cyclesRequired'
            : 'Ran $cyclesRun review cycles of $cyclesRequired',
      ),
    if (!criticsMet)
      Shortfall(
        criticsSeen == 0
            ? 'No fresh-context critic ran, and the brief names '
                  '$criticsRequired'
            : 'Saw $criticsSeen of $criticsRequired fresh-context critics',
        detail:
            'A critic reviews from a context that never built the thing. One '
            'that never ran is a review the builder gave itself.',
      ),
    if (directivesMissing.isNotEmpty)
      Shortfall(
        directivesMissing.length == 1
            ? 'One working file the brief asks for is not there'
            : '${directivesMissing.length} working files the brief asks for '
                  'are not there',
        detail:
            '${directivesMissing.join(', ')}. A resumed session is told to '
            're-read these, so without them a resume starts from nothing.',
      ),
  ];
}

/// Reads a mission's outcome from its spec, the files it produced, and the
/// last thing it said about itself.
///
/// Pure: the caller lists the directory. Which files exist is the one part
/// that needs a filesystem, and it is three lines; everything worth being
/// wrong about is here, where a test can reach it.
abstract final class MissionCheck {
  /// The working files the brief tells the agent to maintain. Named here
  /// rather than in the app so the compiler and the check cannot drift: these
  /// are the ones `prompt_compiler` writes into every brief.
  static const List<String> directiveFiles = <String>[
    'DIRECTION.md',
    'PLAN.md',
    'INVENTORY.md',
    'TASK_STATE.md',
  ];

  static MissionOutcome inspect({
    required MissionSpec spec,
    required Set<String> filesPresent,
    MpState? reported,
    int criticsSeen = 0,
  }) => MissionOutcome(
    expected: <String>[
      for (final EvidenceArtifact e in spec.evidence) e.fileName,
    ],
    produced: <String>{
      for (final EvidenceArtifact e in spec.evidence)
        if (filesPresent.contains(e.fileName)) e.fileName,
    },
    exitThreshold: spec.rubric.exitThreshold,
    // A rubric with no categories is not a rubric, whatever its total says —
    // `Rubric` defaults to 100 points whether or not anything scores them, and
    // reading that as "this mission has a scoring gate" would invent one.
    rubricTotal: spec.rubric.categories.isEmpty ? 0 : spec.rubric.total,
    cyclesRequired: spec.review.minimumCycles,
    score: reported?.score,
    cyclesRun: reported?.cycle ?? 0,
    criticsRequired: spec.review.critics.length,
    criticsSeen: criticsSeen,
    directivesMissing: <String>[
      for (final String f in directiveFiles)
        if (!filesPresent.contains(f)) f,
    ],
  );
}
