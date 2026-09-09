import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'diagnostics.dart';

/// The one native thing this needs, behind an interface so the rest is
/// testable on a runner that has no Windows in it.
abstract interface class AwakeSurface {
  /// Ask the operating system to keep the machine awake, or stop asking.
  /// Returns whether the request was honoured.
  Future<bool> keepAwake(bool awake);
}

/// Holds the machine awake for as long as a run is in flight.
///
/// The failure this prevents is total and silent. A twelve-hour unattended run
/// on a laptop that sleeps at hour three did not fail — it stopped, the log
/// ends mid-sentence, and nothing on screen says why. It is the largest
/// remaining gap in a program whose whole claim is a night's work without a
/// human.
///
/// **The opposite failure is a real harm, and it is what shapes this class.**
/// A program that quietly keeps a laptop awake forever, because it crashed
/// while holding the lock, is worse than one that lets the machine sleep. So
/// nothing here is a call site deciding to hold or to release. [want] is handed
/// the run's own busy flag and works out the rest; it is idempotent, and it is
/// serialised, so two changes in quick succession cannot land out of order and
/// leave the hold on after the run has ended.
class KeepAwake {
  KeepAwake({AwakeSurface? surface})
    : _surface = surface ?? const NativeAwakeSurface();

  final AwakeSurface _surface;

  bool _desired = false;
  bool _held = false;
  bool _supported = true;
  bool _said = false;
  Future<void> _queue = Future<void>.value();

  /// Whether the machine is currently being held awake. For tests and for the
  /// diagnostics report; nothing in the app sets this by hand.
  bool get held => _held;

  /// True until the platform tells us it cannot do this.
  bool get supported => _supported;

  /// Say what is wanted. Safe to call on every notification.
  Future<void> want(bool awake) {
    _desired = awake;
    final Future<void> next = _queue.then((_) => _apply());
    _queue = next;
    return next;
  }

  Future<void> _apply() async {
    if (_held == _desired) return;
    if (!_supported && _desired) return;

    final bool target = _desired;
    bool ok = false;
    try {
      ok = await _surface.keepAwake(target);
    } on Object catch (e) {
      // A platform with no native half throws MissingPluginException. That is
      // an answer, not a crash: the run continues and the machine may sleep.
      _supported = false;
      _report('Keeping the machine awake is not available here: $e');
      return;
    }

    if (ok) {
      _held = target;
      return;
    }

    // A failed hold means nothing is held; a failed release may still be
    // holding. `_held` is left telling the truth either way, so the next call
    // tries again rather than assuming.
    if (target) {
      _supported = false;
      _report(
        'The system refused to keep this machine awake. A long run may be '
        'cut short if it sleeps.',
      );
    }
  }

  void _report(String message) {
    if (_said) return;
    _said = true;
    Diagnostics.instance.log('keepAwake: $message');
  }
}

/// The real one. Everything worth being wrong about is in [KeepAwake]; this is
/// a channel call and a platform default.
class NativeAwakeSurface implements AwakeSurface {
  const NativeAwakeSurface();

  static const MethodChannel _channel = MethodChannel('masterprompt/platform');

  @override
  Future<bool> keepAwake(bool awake) async {
    // Windows is the only platform carrying the native half, and this is the
    // one place allowed to know that: it chooses a default rather than
    // guarding logic — a run is driven from Linux and macOS too, and there the
    // answer is simply "not available".
    if (!Platform.isWindows) return false;
    return await _channel.invokeMethod<bool>('keepAwake', <String, Object?>{
          'awake': awake,
        }) ??
        false;
  }
}
