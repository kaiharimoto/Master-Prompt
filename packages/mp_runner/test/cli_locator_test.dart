import 'dart:io';

import 'package:mp_runner/mp_runner.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String fake;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('mp_locator_');
    fake = '${tmp.path}/claude';
    final ProcessResult r = Process.runSync(
      Platform.resolvedExecutable,
      <String>['compile', 'exe', 'tool/fake_claude.dart', '-o', fake],
    );
    if (r.exitCode != 0) throw StateError('build failed: ${r.stderr}');
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  const CliLocator locator = CliLocator();

  test('probes a real binary and reads its capabilities', () async {
    final CapabilityProfile? p = await locator.probe(fake);
    expect(p, isNotNull);
    expect(p!.version, contains('2.1.42'));
    expect(p.has('--print'), isTrue);
    expect(p.has('--session-id'), isTrue);
    expect(p.choices['--effort'], <String>['low', 'medium', 'high']);
  });

  test('an explicit path is preferred over the search list', () async {
    final ClaudeInstall install = await locator.locate(explicitPath: fake);
    expect(install.path, fake);
    expect(install.capabilities.has('--fork-session'), isTrue);
  });

  test('the fingerprint changes when the binary changes', () async {
    final CapabilityProfile? a = await locator.probe(fake);
    // Touching the file changes its mtime, which is what invalidates a cached
    // profile after the CLI auto-updates.
    await File(
      fake,
    ).setLastModified(DateTime.now().add(const Duration(seconds: 5)));
    final CapabilityProfile? b = await locator.probe(fake);
    expect(b!.fingerprint, isNot(a!.fingerprint));
  });

  test(
    'a path that is not a CLI probes as null rather than throwing',
    () async {
      expect(await locator.probe('${tmp.path}/definitely-not-here'), isNull);
      final File notExecutable = File('${tmp.path}/notes.txt')
        ..writeAsStringSync('hello');
      expect(await locator.probe(notExecutable.path), isNull);
    },
  );

  test('failing to find anything reports what was searched', () async {
    // An empty PATH so the bare `claude` candidates cannot resolve either.
    await expectLater(
      const _EmptyPathLocator().locate(explicitPath: '/nonexistent/claude'),
      throwsA(
        isA<ClaudeNotFound>().having(
          (ClaudeNotFound e) => e.searched,
          'searched',
          contains('/nonexistent/claude'),
        ),
      ),
    );
  });

  test('candidate paths cover the documented install locations', () {
    final List<String> paths = locator.candidatePaths();
    expect(paths.first, anyOf('claude', 'claude.exe'));
    expect(
      paths.any((String p) => p.contains('.local')),
      isTrue,
      reason: 'the native installer puts it under .local/bin',
    );
  });

  test('auth mode is reported, since it changes the limit policy', () {
    // A subscription hits a five-hour window worth waiting out; an API key
    // hits spend limits that waiting does not fix.
    expect(ClaudeAuthMode.values, contains(ClaudeAuthMode.subscription));
    expect(locator.detectAuthMode(), isA<ClaudeAuthMode>());
  });
}

/// Searches nothing, so `locate` is guaranteed to fail.
class _EmptyPathLocator extends CliLocator {
  const _EmptyPathLocator();

  @override
  List<String> candidatePaths() => const <String>[];
}
