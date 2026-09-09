import 'mp_state.dart';
import 'state_parser.dart';

/// Reads `mpstate` heartbeats out of a run's output as it arrives.
///
/// The brief demands the block on every reply and says why it matters on the
/// CLI transport in particular: it doubles as a compaction detector, because
/// micro-compaction is not observable from the event stream. Nothing read it.
/// The block scrolled past in the log as three lines of `phase=build` among
/// thousands, and the Progress panel said "nothing recorded yet" for twelve
/// hours while the run reported its score, its phase, what it was blocked on
/// and what it wanted to ask, on every single turn.
///
/// This is a class rather than a method on the runner because the runner
/// cannot be driven without a real process, and a reader that no test can
/// reach is a reader that is broken the moment it is written.
///
/// Two things make it more than a call to [StateParser]:
///
/// **It reads a rolling tail, not one message.** A block can be split across
/// two events, and a heartbeat lost to a chunk boundary is indistinguishable
/// from a model that failed to send one.
///
/// **The tail is cleared once a block is read.** Otherwise the same block is
/// found again on every subsequent chunk, and a run that stopped reporting
/// would go on looking healthy from the last thing it said.
class RunHeartbeat {
  RunHeartbeat({this.expectedTaskId, this.window = 6000});

  /// The mission this run is for. A block from somewhere else is refused by
  /// the parser rather than adopted.
  final String? expectedTaskId;

  /// How much recent output to keep looking at. Bounded because a twelve-hour
  /// run's output is not.
  final int window;

  static const StateParser _parser = StateParser();

  String _tail = '';
  MpState? _state;

  /// The most recent heartbeat, or null if none has arrived yet.
  MpState? get state => _state;

  /// Feed the assistant's own words. Returns the state if this chunk completed
  /// a block, and null otherwise — so a caller can tell "a new heartbeat" from
  /// "more prose".
  MpState? read(String chunk) {
    if (chunk.trim().isEmpty) return null;
    _tail = _tail.isEmpty ? chunk : '$_tail\n$chunk';
    if (_tail.length > window) {
      _tail = _tail.substring(_tail.length - window);
    }

    final StateParseResult r = _parser.parse(
      _tail,
      expectedTaskId: expectedTaskId,
    );
    if (!r.canAdvanceState || r.state == null) return null;
    _tail = '';
    _state = r.state;
    return r.state;
  }

  void reset() {
    _tail = '';
    _state = null;
  }
}
