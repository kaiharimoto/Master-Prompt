import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/store/desktop_runner.dart';
import 'package:master_prompt/src/store/keep_awake.dart';
import 'package:master_prompt/src/store/settings.dart';
import 'package:mp_runner/mp_runner.dart';

import 'connection_test.dart' show fakeInstall, GatedLocator;

/// Records what it was asked, and can refuse or throw the way a real platform
/// does.
class RecordingSurface implements AwakeSurface {
  RecordingSurface({this.answer = true, this.throws});

  final bool answer;
  final Object? throws;
  final List<bool> asked = <bool>[];

  @override
  Future<bool> keepAwake(bool awake) async {
    asked.add(awake);
    if (throws != null) throw throws!;
    return answer;
  }
}

void main() {
  group('holding a machine awake for a run', () {
    test(
      'holds while the run is going and lets go the moment it is not',
      () async {
        final RecordingSurface s = RecordingSurface();
        final KeepAwake k = KeepAwake(surface: s);

        await k.want(true);
        expect(k.held, isTrue);

        await k.want(false);
        expect(k.held, isFalse);
        expect(s.asked, <bool>[true, false]);
      },
    );

    test('saying the same thing again costs nothing', () async {
      // `want` is called from every notification a run produces, which over
      // twelve hours is thousands of times.
      final RecordingSurface s = RecordingSurface();
      final KeepAwake k = KeepAwake(surface: s);

      for (int i = 0; i < 50; i++) {
        await k.want(true);
      }

      expect(s.asked, <bool>[true]);
    });

    test('two changes in quick succession cannot land out of order', () async {
      // The leak this class exists to prevent: a release that overtakes a hold
      // leaves the machine awake after the run has ended, and nothing on
      // screen would ever say so.
      final RecordingSurface s = RecordingSurface();
      final KeepAwake k = KeepAwake(surface: s);

      final Future<void> a = k.want(true);
      final Future<void> b = k.want(false);
      await Future.wait(<Future<void>>[a, b]);

      expect(
        k.held,
        isFalse,
        reason: 'the last thing asked for is what must be true at the end',
      );
    });

    test('a platform that refuses is not asked again', () async {
      // Otherwise every log line of a twelve-hour run makes a channel call
      // that has already been answered.
      final RecordingSurface s = RecordingSurface(answer: false);
      final KeepAwake k = KeepAwake(surface: s);

      await k.want(true);
      await k.want(false);
      await k.want(true);

      expect(k.held, isFalse);
      expect(k.supported, isFalse);
      expect(s.asked, <bool>[true]);
    });

    test('a platform with no native half is an answer, not a crash', () async {
      final RecordingSurface s = RecordingSurface(
        throws: MissingPluginException('no implementation'),
      );
      final KeepAwake k = KeepAwake(surface: s);

      await k.want(true);

      expect(k.held, isFalse);
      expect(
        k.supported,
        isFalse,
        reason:
            'the run continues and the machine may sleep, which is the honest '
            'outcome on a platform that cannot be asked',
      );
    });

    test('a hold that failed is not remembered as held', () async {
      final RecordingSurface s = RecordingSurface(answer: false);
      final KeepAwake k = KeepAwake(surface: s);

      await k.want(true);

      expect(
        k.held,
        isFalse,
        reason:
            'believing a hold that never happened would hide the fact that a '
            'long run is unprotected',
      );
    });
  });

  group('the hold follows the run, not a call site', () {
    test('busy holds it, and finishing lets it go', () async {
      // Derived from `isBusy` inside `notifyListeners` rather than set where a
      // run starts and ends, so a path that ends a run without passing the
      // usual exit — a throw, a cancel, a supervisor returning early — cannot
      // leave a laptop awake indefinitely. A machine that never sleeps again
      // is a worse outcome than one that slept through hour three.
      //
      // `locating` is a busy state a test can reach; `running` needs a real
      // process, and it is the same getter either way.
      final RecordingSurface s = RecordingSurface();
      final Completer<ClaudeInstall> gate = Completer<ClaudeInstall>();
      final DesktopRunner runner = DesktopRunner(
        locator: GatedLocator(gate),
        awake: KeepAwake(surface: s),
      );

      final Future<void> searching = runner.detect(const AppSettings());
      await Future<void>.delayed(Duration.zero);
      expect(runner.isBusy, isTrue);
      expect(runner.holdingAwake, isTrue);

      gate.complete(fakeInstall());
      await searching;
      await Future<void>.delayed(Duration.zero);

      expect(runner.isBusy, isFalse);
      expect(
        runner.holdingAwake,
        isFalse,
        reason: 'the release is the half that, missed, is a real harm',
      );
      expect(s.asked, <bool>[true, false]);
    });

    test('disposing lets go even if nothing else did', () async {
      final RecordingSurface s = RecordingSurface();
      final Completer<ClaudeInstall> gate = Completer<ClaudeInstall>();
      final DesktopRunner runner = DesktopRunner(
        locator: GatedLocator(gate),
        awake: KeepAwake(surface: s),
      );

      unawaited(runner.detect(const AppSettings()));
      await Future<void>.delayed(Duration.zero);
      expect(runner.holdingAwake, isTrue);

      runner.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(runner.holdingAwake, isFalse);
    });
  });
}
