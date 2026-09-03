import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../store/build_info.dart';
import 'release.dart';

/// What happened when the finished file was handed to the operating system.
enum InstallOutcome {
  /// The OS took it. Whatever it does next is out of our hands, including the
  /// user changing their mind at the confirmation screen.
  handedOver,

  /// Android has not been told this app may install packages. The user has
  /// been sent to the screen that grants it and has to come back.
  needsPermission,

  /// Nothing here can install it — the file is on disk and the user finishes
  /// by hand. This is the honest answer on Windows, where a running `.exe`
  /// cannot replace itself.
  manual,
}

/// Everything about updating that touches the world outside the process.
///
/// Behind an interface so the state machine above it can be tested without a
/// network, a filesystem or a platform channel — the three things that make an
/// updater otherwise only provable by shipping it.
abstract interface class UpdateTransport {
  /// Fetches and decodes JSON. Throws on anything that is not a readable 200.
  Future<Object?> fetch(Uri url);

  /// Streams [url] into [target], reporting bytes as they arrive. [total] is
  /// -1 when the server does not say how big the file is.
  Future<void> download(
    Uri url,
    File target,
    void Function(int received, int total) onProgress,
  );

  /// Hands the downloaded file to the OS.
  Future<InstallOutcome> install(File file);

  /// Where downloads are kept. Created if it does not exist.
  Future<Directory> workspace();
}

/// Where the updater is. The outcome of a check lives in [Updater.check],
/// not here, because "finished checking" and "found an update" are different
/// questions and conflating them is how an updater ends up claiming an update
/// exists whenever the network is down.
enum UpdatePhase { idle, checking, ready, downloading, downloaded, installing }

class Updater extends ChangeNotifier {
  Updater({
    UpdateTransport? transport,
    UpdatePlatform? platform,
    String? currentBuild,
  }) : _transport = transport ?? const _RealTransport(),
       platform = platform ?? _detect(),
       currentBuild = currentBuild ?? BuildInfo.build;

  static UpdatePlatform _detect() {
    if (Platform.isAndroid) return UpdatePlatform.android;
    if (Platform.isWindows) return UpdatePlatform.windows;
    return UpdatePlatform.other;
  }

  final UpdateTransport _transport;
  final UpdatePlatform platform;

  /// The build this copy is, as CI stamped it. Injectable only so a test can
  /// pretend to be a numbered build; the app always passes what it was built
  /// with.
  final String currentBuild;

  /// The rolling prerelease. A fixed tag, so the URL never changes and a build
  /// from a year ago still knows where to look.
  static final Uri feed = Uri.parse(
    'https://api.github.com/repos/${BuildInfo.repo}/releases/tags/dev',
  );

  UpdatePhase _phase = UpdatePhase.idle;
  UpdatePhase get phase => _phase;

  UpdateCheck? _check;
  UpdateCheck? get check => _check;

  /// 0..1 while downloading, or -1 when the size is not known in advance.
  double _progress = 0;
  double get progress => _progress;

  File? _file;
  File? get file => _file;

  /// The last thing that went wrong, already written for a human.
  String? _error;
  String? get error => _error;

  /// What the user has to do next when the OS could not finish the job alone.
  String? _handoff;
  String? get handoff => _handoff;

  bool _checkedThisLaunch = false;

  /// True when there is a newer build and it has not been downloaded yet.
  bool get hasUpdate => (_check?.isUpdate ?? false);

  /// True while something is in flight, so the button can refuse a second tap.
  bool get busy =>
      _phase == UpdatePhase.checking ||
      _phase == UpdatePhase.downloading ||
      _phase == UpdatePhase.installing;

  /// The check that runs itself at launch.
  ///
  /// Silent by design: a failure here means the phone is offline or GitHub is
  /// rate-limiting, neither of which is worth interrupting someone who opened
  /// the app to write a brief.
  Future<void> checkQuietly() async {
    if (_checkedThisLaunch || busy) return;
    await runCheck();
    _error = null;
    notifyListeners();
  }

  /// The check behind the button. Reports what it finds, including failures.
  Future<void> runCheck() async {
    if (busy) return;
    _phase = UpdatePhase.checking;
    _error = null;
    _handoff = null;
    notifyListeners();

    try {
      final Object? body = await _transport
          .fetch(feed)
          .timeout(const Duration(seconds: 20));
      _check = readRelease(
        body,
        currentBuild: currentBuild,
        platform: platform,
      );
      _checkedThisLaunch = true;
      // A file left over from a previous session is as good as one downloaded
      // now, so an install interrupted by the permission prompt resumes rather
      // than pulling twenty-odd megabytes again.
      await _adoptExistingDownload();
    } on TimeoutException {
      _fail('Checking for updates took too long. Try again in a moment.');
      return;
    } catch (e) {
      _check = UpdateCheck(
        outcome: UpdateOutcome.unreadable,
        detail: 'Could not reach the release page. ${_plain(e)}',
      );
      _fail('Could not reach the release page. ${_plain(e)}');
      return;
    }

    _phase = _file != null ? UpdatePhase.downloaded : UpdatePhase.ready;
    notifyListeners();
  }

  Future<void> _adoptExistingDownload() async {
    _file = null;
    try {
      final Directory dir = await _transport.workspace();
      final ReleaseAsset? a = _check?.asset;
      if (a == null || !(_check?.isUpdate ?? false)) {
        // Nothing is waiting, so anything in the cache is a build that has
        // already been installed — fifty megabytes of it, on a phone.
        await _sweep(dir, keep: '');
        return;
      }
      final File f = File('${dir.path}${Platform.pathSeparator}${a.name}');
      if (await f.exists() && (a.bytes <= 0 || await f.length() == a.bytes)) {
        _file = f;
      }
    } catch (_) {
      // A cache we cannot read is not a failure worth reporting; the download
      // below will surface anything that actually blocks the update.
    }
  }

  Future<void> download() async {
    final ReleaseAsset? a = _check?.asset;
    if (a == null || busy) return;

    _phase = UpdatePhase.downloading;
    _progress = 0;
    _error = null;
    _handoff = null;
    notifyListeners();

    try {
      final Directory dir = await _transport.workspace();
      await _sweep(dir, keep: a.name);
      final File target = File('${dir.path}${Platform.pathSeparator}${a.name}');
      final File part = File('${target.path}.part');
      await _transport.download(a.url, part, (int received, int total) {
        final double next = total > 0 ? received / total : -1;
        // Repainting on every chunk is thousands of frames of nothing; a
        // percent is as fine as the bar can show anyway.
        if (next < 0 || (next - _progress).abs() >= 0.01 || next >= 1) {
          _progress = next;
          notifyListeners();
        }
      });
      // Renamed only once complete, so an interrupted download is never
      // mistaken for a finished one on the next launch.
      _file = await part.rename(target.path);
      _phase = UpdatePhase.downloaded;
      _progress = 1;
      notifyListeners();
    } catch (e) {
      _fail('The download did not finish. ${_plain(e)}');
    }
  }

  Future<void> install() async {
    final File? f = _file;
    if (f == null || busy) return;

    _phase = UpdatePhase.installing;
    _error = null;
    _handoff = null;
    notifyListeners();

    try {
      final InstallOutcome outcome = await _transport.install(f);
      _handoff = switch (outcome) {
        InstallOutcome.handedOver => null,
        InstallOutcome.needsPermission =>
          'Android needs permission first. Turn on "Allow from this source", '
              'come back, and press Install again.',
        InstallOutcome.manual =>
          'Saved to ${f.path}. Close the app, extract the zip over your '
              'existing folder, and start it again.',
      };
      _phase = UpdatePhase.downloaded;
      notifyListeners();
    } catch (e) {
      _fail('The installer could not be started. ${_plain(e)}');
    }
  }

  /// Forgets a failure so the button goes back to offering the obvious action.
  void clearError() {
    if (_error == null && _handoff == null) return;
    _error = null;
    _handoff = null;
    notifyListeners();
  }

  void _fail(String message) {
    _error = message;
    _phase = _file != null ? UpdatePhase.downloaded : UpdatePhase.ready;
    notifyListeners();
  }

  /// Keeps exactly one build in the cache. Without this the folder grows by an
  /// APK per update and nothing ever removes them.
  static Future<void> _sweep(Directory dir, {required String keep}) async {
    try {
      await for (final FileSystemEntity e in dir.list()) {
        if (e is! File) continue;
        final String name = e.uri.pathSegments.last;
        if (name == keep) continue;
        await e.delete();
      }
    } catch (_) {
      // Housekeeping. Never worth failing an update over.
    }
  }

  static String _plain(Object e) {
    final String s = e is SocketException
        ? 'No connection.'
        : e is HttpException
        ? e.message
        : '$e';
    return s.length > 160 ? '${s.substring(0, 157)}…' : s;
  }
}

/// The real world: GitHub over HTTPS, the cache directory, and the Android
/// package installer behind a method channel.
class _RealTransport implements UpdateTransport {
  const _RealTransport();

  // Renamed from `masterprompt/updates` when sharing and saving joined it:
  // the channel is the app's whole native surface now, not only the updater.
  static const MethodChannel _channel = MethodChannel('masterprompt/platform');

  @override
  Future<Object?> fetch(Uri url) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final HttpClientRequest req = await client.getUrl(url);
      // GitHub rejects requests with no user agent outright, and the media
      // type pins the response shape against a future API default.
      req.headers.set(HttpHeaders.userAgentHeader, _agent);
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final HttpClientResponse res = await req.close();
      final String body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw HttpException('GitHub answered ${res.statusCode}.', uri: url);
      }
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> download(
    Uri url,
    File target,
    void Function(int received, int total) onProgress,
  ) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final HttpClientRequest req = await client.getUrl(url);
      req.headers.set(HttpHeaders.userAgentHeader, _agent);
      final HttpClientResponse res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('GitHub answered ${res.statusCode}.', uri: url);
      }
      await target.parent.create(recursive: true);
      final IOSink sink = target.openWrite();
      int received = 0;
      final int total = res.contentLength;
      try {
        await for (final List<int> chunk in res) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<InstallOutcome> install(File file) async {
    if (Platform.isAndroid) {
      final String? result = await _channel.invokeMethod<String>(
        'install',
        <String, Object?>{'path': file.path},
      );
      return switch (result) {
        'needsPermission' => InstallOutcome.needsPermission,
        'handedOver' => InstallOutcome.handedOver,
        _ => InstallOutcome.manual,
      };
    }
    if (Platform.isWindows) {
      // A running executable cannot be replaced underneath itself, so the
      // honest thing is to put the user in front of the file rather than
      // pretend. Explorer's exit code is not meaningful here.
      try {
        await Process.run('explorer.exe', <String>['/select,${file.path}']);
      } catch (_) {
        // Showing the folder is a courtesy; the path is in the message either
        // way, so a missing Explorer is not a failed update.
      }
      return InstallOutcome.manual;
    }
    return InstallOutcome.manual;
  }

  @override
  Future<Directory> workspace() async {
    final Directory base = await getTemporaryDirectory();
    final Directory dir = Directory(
      '${base.path}${Platform.pathSeparator}updates',
    );
    await dir.create(recursive: true);
    return dir;
  }

  static String get _agent =>
      'MasterPrompt/${BuildInfo.version}+${BuildInfo.build} '
      '(${BuildInfo.platform})';
}
