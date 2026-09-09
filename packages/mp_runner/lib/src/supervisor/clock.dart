import 'dart:async';

/// Time, injected so a five-hour wait can be tested in milliseconds.
abstract class Clock {
  DateTime nowUtc();

  /// Wait until [when]. Returns immediately if it has already passed.
  ///
  /// [interrupted] cuts the wait short. A five-hour pause is the longest thing
  /// this program does, and Stop used to do nothing at all inside it: the
  /// process was already dead so `kill()` was a no-op, and the only
  /// cancellation check happened after the wait returned. The run sat in
  /// `paused`, which counts as busy, so Run stayed disabled and Stop stayed
  /// inert — a state the user could leave only by killing the app.
  Future<void> waitUntil(DateTime when, {Future<void>? interrupted});
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  Future<void> waitUntil(DateTime when, {Future<void>? interrupted}) async {
    // Re-check rather than trusting one long Timer: a laptop that sleeps for
    // three hours leaves an in-flight timer wildly wrong, and wall-clock jumps
    // (suspend, DST, NTP correction) are routine on a machine left running
    // overnight for exactly this purpose.
    bool stopped = false;
    final Future<void>? watch = interrupted?.then((_) => stopped = true);

    while (true) {
      if (stopped) return;
      final Duration remaining = when.difference(nowUtc());
      if (remaining <= Duration.zero) return;
      final Duration slice = remaining > const Duration(minutes: 1)
          ? const Duration(minutes: 1)
          : remaining;
      if (watch == null) {
        await Future<void>.delayed(slice);
        continue;
      }
      // Racing the slice rather than checking between slices: someone who
      // presses Stop is standing at the machine, and up to a minute of nothing
      // happening reads as a second bug.
      await Future.any(<Future<void>>[Future<void>.delayed(slice), watch]);
    }
  }
}

/// A clock that never really waits. Records what it was asked to wait for so
/// tests can assert scheduling without spending the time.
class TestClock implements Clock {
  TestClock(this._now);

  DateTime _now;
  final List<DateTime> waitedUntil = <DateTime>[];

  @override
  DateTime nowUtc() => _now;

  void advance(Duration d) => _now = _now.add(d);

  void setTo(DateTime t) => _now = t.toUtc();

  /// Set when the last wait was cut short rather than served out, so a test
  /// can tell "Stop was felt" from "the wait was never entered".
  bool wasInterrupted = false;

  @override
  Future<void> waitUntil(DateTime when, {Future<void>? interrupted}) async {
    waitedUntil.add(when);
    if (interrupted != null) {
      // A real wait is a race between time passing and Stop arriving, and a
      // clock that only ever advances would let a supervisor that never wires
      // Stop up pass every test. Microtasks always drain before timers, so an
      // interrupt that has already been signalled wins a zero timeout and one
      // that has not cannot.
      final bool stop = await interrupted
          .then((_) => true)
          .timeout(Duration.zero, onTimeout: () => false);
      if (stop) {
        wasInterrupted = true;
        return;
      }
    }
    if (when.isAfter(_now)) _now = when;
  }
}
