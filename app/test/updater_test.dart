import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/update/release.dart';
import 'package:master_prompt/src/update/updater.dart';

/// Stands in for GitHub, the filesystem and the package installer.
///
/// The updater is the one part of the app that cannot be judged by running it
/// — a real check needs a network, a real install needs a phone, and a real
/// failure needs GitHub to be down. So every one of those is a value here.
class FakeTransport implements UpdateTransport {
  FakeTransport(this.dir);

  final Directory dir;

  Object? answer = jsonDecode('''
{
  "html_url": "https://github.com/kaiharimoto/Master-Prompt/releases/tag/dev",
  "assets": [{
    "name": "MasterPrompt-57-a1b2c3d.apk",
    "size": 12,
    "browser_download_url": "https://example.invalid/MasterPrompt-57-a1b2c3d.apk"
  }]
}
''');

  Object? fetchError;
  Object? downloadError;
  InstallOutcome outcome = InstallOutcome.handedOver;

  int fetches = 0;
  int downloads = 0;
  final List<String> installed = <String>[];

  @override
  Future<Object?> fetch(Uri url) async {
    fetches++;
    if (fetchError != null) throw fetchError!;
    return answer;
  }

  @override
  Future<void> download(
    Uri url,
    File target,
    void Function(int received, int total) onProgress,
  ) async {
    downloads++;
    if (downloadError != null) throw downloadError!;
    await target.parent.create(recursive: true);
    // Exactly the twelve bytes the release above publishes: the updater only
    // adopts a leftover file whose length matches, so a fake that disagreed
    // with itself would look like the bug that rule exists to catch.
    await target.writeAsString('apk' * 4);
    onProgress(6, 12);
    onProgress(12, 12);
  }

  @override
  Future<InstallOutcome> install(File file) async {
    installed.add(file.path);
    return outcome;
  }

  @override
  Future<Directory> workspace() async => dir;
}

void main() {
  late Directory tmp;
  late FakeTransport transport;
  late Updater updater;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mp-update-test');
    transport = FakeTransport(tmp);
    updater = Updater(
      transport: transport,
      platform: UpdatePlatform.android,
      currentBuild: '42',
    );
  });

  tearDown(() {
    updater.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('check, download, install', () async {
    await updater.runCheck();
    expect(updater.hasUpdate, isTrue);
    expect(updater.phase, UpdatePhase.ready);

    await updater.download();
    expect(updater.phase, UpdatePhase.downloaded);
    expect(updater.progress, 1);
    expect(
      updater.file!.path,
      endsWith('MasterPrompt-57-a1b2c3d.apk'),
      reason:
          'the file keeps the published name, so a user who finishes the '
          'install by hand can tell what they are looking at',
    );
    expect(
      File('${updater.file!.path}.part').existsSync(),
      isFalse,
      reason: 'the partial file is renamed, not left beside the finished one',
    );

    await updater.install();
    expect(transport.installed.single, updater.file!.path);
    expect(updater.handoff, isNull, reason: 'the OS took it without comment');
  });

  test('an interrupted install does not download again', () async {
    await updater.runCheck();
    await updater.download();
    final String path = updater.file!.path;

    // Android bounces the user to a settings screen the first time, which is a
    // different launch of the app as far as the updater is concerned.
    final Updater second = Updater(
      transport: transport,
      platform: UpdatePlatform.android,
      currentBuild: '42',
    );
    addTearDown(second.dispose);
    await second.runCheck();

    expect(
      second.phase,
      UpdatePhase.downloaded,
      reason: 'a complete file from last time is as good as one fetched now',
    );
    expect(second.file!.path, path);
    expect(transport.downloads, 1, reason: 'nothing was fetched twice');
  });

  test('a half-written file from a killed download is not adopted', () async {
    File('${tmp.path}/MasterPrompt-57-a1b2c3d.apk').writeAsStringSync('nope');

    await updater.runCheck();

    expect(
      updater.phase,
      UpdatePhase.ready,
      reason:
          'the size does not match what the release publishes, so installing '
          'it would fail with a corrupt-package error and no explanation',
    );
  });

  test('downloading sweeps the previous build out of the cache', () async {
    final File stale = File('${tmp.path}/MasterPrompt-41-9999999.apk')
      ..writeAsStringSync('an older build');

    await updater.runCheck();
    await updater.download();

    expect(
      stale.existsSync(),
      isFalse,
      reason: 'otherwise the cache grows by an APK per update, forever',
    );
  });

  test('an installed build is swept out of the cache', () async {
    await updater.runCheck();
    await updater.download();
    final File apk = updater.file!;

    // What the next launch sees once the install has actually gone through.
    final Updater after = Updater(
      transport: transport,
      platform: UpdatePlatform.android,
      currentBuild: '57',
    );
    addTearDown(after.dispose);
    await after.runCheck();

    expect(
      apk.existsSync(),
      isFalse,
      reason:
          'otherwise fifty-odd megabytes of a build already running sits in '
          'the cache until some later update happens to overwrite it',
    );
  });

  test('a failed check reports why and stays usable', () async {
    transport.fetchError = const SocketException('nope');

    await updater.runCheck();

    expect(updater.error, contains('No connection'));
    expect(updater.check!.outcome, UpdateOutcome.unreadable);
    expect(
      updater.hasUpdate,
      isFalse,
      reason: 'an unreachable release must never look like an available one',
    );

    transport.fetchError = null;
    await updater.runCheck();
    expect(updater.hasUpdate, isTrue, reason: 'and it recovers on the retry');
  });

  test('the launch check stays quiet about failure', () async {
    transport.fetchError = const SocketException('nope');

    await updater.checkQuietly();

    expect(
      updater.error,
      isNull,
      reason:
          'someone opening the app to write a brief should not be met by a '
          'network error they did not ask for',
    );
  });

  test('the launch check runs once, the button always runs', () async {
    await updater.checkQuietly();
    await updater.checkQuietly();
    expect(transport.fetches, 1, reason: 'once per launch is enough');

    await updater.runCheck();
    expect(transport.fetches, 2, reason: 'but asking explicitly always asks');
  });

  test('a failed download can be retried', () async {
    transport.downloadError = const SocketException('cut off');
    await updater.runCheck();
    await updater.download();

    expect(updater.error, isNotNull);
    expect(
      updater.phase,
      UpdatePhase.ready,
      reason: 'back to offering the download rather than stuck mid-flight',
    );

    transport.downloadError = null;
    updater.clearError();
    await updater.download();
    expect(updater.phase, UpdatePhase.downloaded);
    expect(updater.error, isNull);
  });

  test('a refused install permission says what to do next', () async {
    transport.outcome = InstallOutcome.needsPermission;
    await updater.runCheck();
    await updater.download();
    await updater.install();

    expect(updater.handoff, contains('Allow from this source'));
    expect(
      updater.phase,
      UpdatePhase.downloaded,
      reason: 'the file is still there, so Install has to remain offerable',
    );
  });

  test('Windows is told to finish by hand', () async {
    final Updater desktop = Updater(
      transport: transport,
      platform: UpdatePlatform.windows,
      currentBuild: '42',
    );
    addTearDown(desktop.dispose);
    transport.outcome = InstallOutcome.manual;
    transport.answer = jsonDecode('''
{
  "assets": [{
    "name": "MasterPrompt-windows-x64-57-a1b2c3d.zip",
    "size": 12,
    "browser_download_url": "https://example.invalid/w.zip"
  }]
}
''');

    await desktop.runCheck();
    await desktop.download();
    await desktop.install();

    expect(
      desktop.handoff,
      contains('extract'),
      reason:
          'a running exe cannot replace itself, and pretending otherwise is '
          'worse than saying so',
    );
  });

  test('nothing runs twice at once', () async {
    final Future<void> first = updater.runCheck();
    final Future<void> second = updater.runCheck();
    await Future.wait(<Future<void>>[first, second]);

    expect(
      transport.fetches,
      1,
      reason: 'a double tap must not start two checks',
    );
  });
}
