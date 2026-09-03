import 'package:flutter/foundation.dart';
import 'package:mp_core/mp_core.dart';

/// Where the user is inside a single round of the discussion.
///
/// A stage is three beats — hand the question over, bring the answer back,
/// accept what it settled — and the app moves between them itself. That
/// self-advancing is the difference between a tool you operate and one that
/// carries you, which is what the first build got wrong.
enum FlowBeat {
  /// No mission yet. One sentence starts everything.
  seed,

  /// This round's question is ready to hand to Claude.
  ask,

  /// Handed over; waiting for the reply to come back.
  awaiting,

  /// The reply landed. Here is what it settled, pending one acceptance.
  review,

  /// Everything required is settled; the brief can be compiled.
  ready,
}

/// The small amount of state that is genuinely transient.
///
/// Everything durable — what is settled, what is still open, which stage is
/// current — is derived from the spec by [ReadinessGate], so the flow cannot
/// drift out of step with the mission it is describing. Only the two facts the
/// spec cannot know are held here: whether the user has handed this round over
/// yet, and whether a reply is waiting to be accepted.
class FlowController extends ChangeNotifier {
  bool _handedOff = false;
  SpecPatchResult? _pending;
  String? _problem;

  /// A reply has landed and is waiting for the user to accept the round.
  SpecPatchResult? get pending => _pending;

  /// Why the last paste could not be used, if it could not.
  String? get problem => _problem;

  /// Lines in the last reply the parser could not understand. Surfaced in the
  /// review beat rather than dropped, so a misread never disappears silently.
  List<String> get unread => _pending?.rejected ?? const <String>[];

  FlowBeat beatFor(MissionSpec? spec, ReadinessReport? report) {
    if (spec == null || !isSeeded(spec)) return FlowBeat.seed;
    if (_pending != null) return FlowBeat.review;
    if (report != null && report.canCompile) return FlowBeat.ready;
    if (_handedOff) return FlowBeat.awaiting;
    return FlowBeat.ask;
  }

  /// A mission has begun once it has been described at all.
  static bool isSeeded(MissionSpec spec) =>
      spec.missionStatement.hasValue &&
      (spec.missionStatement.value ?? '').trim().isNotEmpty;

  /// The user handed this round to Claude. Advance without being asked to.
  void handedOff() {
    _handedOff = true;
    _problem = null;
    notifyListeners();
  }

  /// Back out of waiting, to look at the question again.
  void reconsider() {
    _handedOff = false;
    _problem = null;
    notifyListeners();
  }

  /// A reply came back and could be read.
  void received(SpecPatchResult result) {
    _pending = result;
    _problem = null;
    notifyListeners();
  }

  /// A reply came back and could not be used. The user stays where they are
  /// rather than being advanced past a round that did not land.
  void rejected(String why) {
    _problem = why;
    notifyListeners();
  }

  /// The round was accepted; begin the next one.
  void accepted() {
    _pending = null;
    _problem = null;
    _handedOff = false;
    notifyListeners();
  }

  /// Abandon a reply that landed but should not be kept.
  void discardPending() {
    _pending = null;
    _handedOff = false;
    notifyListeners();
  }

  /// Starting a different mission must not carry another one's round with it.
  void reset() {
    _handedOff = false;
    _pending = null;
    _problem = null;
    notifyListeners();
  }
}

/// Turns one typed sentence into a mission.
///
/// The first build opened a new mission as "Untitled mission" with an empty
/// spec and twenty-one unmet requirements on screen. Beginning from a sentence
/// means the flow has already started by the time anything is shown.
abstract final class MissionSeed {
  /// A short title from a longer sentence: enough to recognise it in a list.
  static String titleFrom(String sentence) {
    final String clean = sentence.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return 'Untitled mission';
    final List<String> words = clean.split(' ');
    if (words.length <= 6 && clean.length <= 48) {
      return clean.endsWith('.') ? clean.substring(0, clean.length - 1) : clean;
    }
    return '${words.take(6).join(' ')}…';
  }

  /// A kebab-case identifier used for directories and state files.
  static String taskIdFrom(String sentence) {
    final String base = titleFrom(sentence)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return base.isEmpty ? 'mission' : base;
  }
}
