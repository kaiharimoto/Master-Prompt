import 'dart:async';

/// Time, injected so a five-hour wait can be tested in milliseconds.
abstract class Clock {
  DateTime nowUtc();

  /// Wait until [when]. Returns immediately if it has already passed.
  Future<void> waitUntil(DateTime when);
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  Future<void> waitUntil(DateTime when) async {
    // Re-check rather than trusting one long Timer: a laptop that sleeps for
    // three hours leaves an in-flight timer wildly wrong, and wall-clock jumps
    // (suspend, DST, NTP correction) are routine on a machine left running
    // overnight for exactly this purpose.
    while (true) {
      final Duration remaining = when.difference(nowUtc());
      if (remaining <= Duration.zero) return;
      final Duration slice =
          remaining > const Duration(minutes: 1) ? const Duration(minutes: 1) : remaining;
      await Future<void>.delayed(slice);
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

  @override
  Future<void> waitUntil(DateTime when) async {
    waitedUntil.add(when);
    if (when.isAfter(_now)) _now = when;
  }
}
