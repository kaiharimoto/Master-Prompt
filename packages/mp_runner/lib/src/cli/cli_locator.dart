import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'capability_profile.dart';

/// Where a `claude` binary was found, and what it can do.
@immutable
class ClaudeInstall {
  const ClaudeInstall({
    required this.path,
    required this.capabilities,
    required this.authMode,
  });

  final String path;
  final CapabilityProfile capabilities;
  final ClaudeAuthMode authMode;

  String get version => capabilities.version;
}

/// How the CLI will authenticate.
///
/// This matters for the limit policy: a subscription hits a five-hour window
/// that is worth waiting out, whereas an API key hits spend limits that time
/// does not fix.
enum ClaudeAuthMode {
  /// An API key in the environment takes precedence over a stored login.
  apiKey,

  /// A stored OAuth login — the Pro/Max subscription path.
  subscription,

  /// Neither could be detected.
  unknown,
}

/// What happened to one candidate path.
enum ProbeOutcome {
  /// Nothing at that path, or the name did not resolve on PATH.
  missing,

  /// It exists but could not be executed — the usual cause on Windows is a
  /// `.cmd` or `.bat` run without a shell, which `CreateProcess` refuses.
  notExecutable,

  /// It ran and answered, but not as the Claude Code CLI would.
  notClaude,

  /// It is the CLI.
  found,
}

/// One line of the search, so a user who does not know how they installed the
/// CLI can be told rather than asked.
@immutable
class ProbeAttempt {
  const ProbeAttempt(this.path, this.outcome, [this.detail = '']);

  final String path;
  final ProbeOutcome outcome;
  final String detail;

  String get describe => switch (outcome) {
    ProbeOutcome.found => 'found',
    ProbeOutcome.missing => 'not there',
    ProbeOutcome.notExecutable => 'could not be run$_tail',
    ProbeOutcome.notClaude => 'ran, but is not Claude Code$_tail',
  };

  String get _tail => detail.isEmpty ? '' : ' — $detail';

  @override
  String toString() => '$path: $describe';
}

/// Why the CLI could not be used.
class ClaudeNotFound implements Exception {
  ClaudeNotFound(this.message, {this.attempts = const <ProbeAttempt>[]});

  final String message;

  /// Every candidate and what became of it.
  final List<ProbeAttempt> attempts;

  List<String> get searched =>
      attempts.map((ProbeAttempt a) => a.path).toList(growable: false);

  @override
  String toString() => message;
}

/// Finds the Claude Code CLI and probes what it supports.
class CliLocator {
  const CliLocator();

  /// Candidate locations, most likely first. Covers the native installer, npm
  /// global installs, and Homebrew, on all three desktop platforms.
  List<String> candidatePaths() {
    final Map<String, String> env = Platform.environment;
    final String home =
        env['USERPROFILE'] ?? env['HOME'] ?? Directory.current.path;
    final String sep = Platform.pathSeparator;

    if (Platform.isWindows) {
      return <String>[
        'claude.exe',
        'claude',
        '$home$sep.local${sep}bin${sep}claude.exe',
        '$home$sep.local${sep}bin${sep}claude',
        if (env['APPDATA'] != null)
          '${env['APPDATA']}${sep}npm${sep}claude.cmd',
        if (env['LOCALAPPDATA'] != null)
          '${env['LOCALAPPDATA']}${sep}Programs${sep}claude${sep}claude.exe',
      ];
    }
    return <String>[
      'claude',
      '$home/.local/bin/claude',
      '/usr/local/bin/claude',
      '/opt/homebrew/bin/claude',
      '$home/.npm-global/bin/claude',
    ];
  }

  /// Locate and probe. Throws [ClaudeNotFound] carrying what became of every
  /// candidate, so the UI can say why rather than only that it failed.
  ///
  /// [attempts] collects the search as it goes, so a caller can show it even
  /// on success — the path that worked is worth seeing too.
  Future<ClaudeInstall> locate({
    String? explicitPath,
    List<ProbeAttempt>? attempts,
  }) async {
    final List<ProbeAttempt> log = attempts ?? <ProbeAttempt>[];
    log.clear();

    // An explicit path is a directive, not a hint. Falling back to the search
    // when it fails would make the setting useless as a diagnostic: you would
    // set a path, get a working CLI at some other location, and never learn
    // that the one you named was wrong.
    final bool explicit =
        explicitPath != null && explicitPath.trim().isNotEmpty;

    final List<String> candidates = explicit
        ? <String>[explicitPath.trim()]
        : <String>[
            // What the operating system itself says, before anything guessed.
            // A fixed list cannot cover winget, a manual install, or a
            // directory someone added to PATH by hand.
            ...await resolveOnPath(),
            ...candidatePaths(),
          ];

    final Set<String> seen = <String>{};
    for (final String path in candidates) {
      if (!seen.add(path)) continue;
      final ProbeAttempt attempt = await inspect(path);
      log.add(attempt);
      if (attempt.outcome == ProbeOutcome.found) {
        final CapabilityProfile? p = await probe(path);
        if (p != null) {
          return ClaudeInstall(
            path: path,
            capabilities: p,
            authMode: detectAuthMode(),
          );
        }
      }
    }

    throw ClaudeNotFound(
      explicit
          ? 'The path set in Settings is not a working Claude Code CLI. Clear '
                'it to search for one instead.'
          : 'The Claude Code CLI could not be found. Install it, or set an '
                'explicit path in Settings.',
      attempts: List<ProbeAttempt>.unmodifiable(log),
    );
  }

  /// Asks the operating system where `claude` is.
  ///
  /// `where` on Windows and `which -a` elsewhere. Both can list several, and
  /// both fail quietly when there is nothing, which is the answer we want.
  Future<List<String>> resolveOnPath() async {
    try {
      final ProcessResult r = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        Platform.isWindows ? <String>['claude'] : <String>['-a', 'claude'],
        environment: _childEnvironment(),
        includeParentEnvironment: false,
        runInShell: Platform.isWindows,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (r.exitCode != 0) return const <String>[];
      return '${r.stdout}'
          .split('\n')
          .map((String l) => l.trim())
          .where((String l) => l.isNotEmpty)
          .toList(growable: false);
    } on Exception {
      return const <String>[];
    }
  }

  /// Runs `--version` against one candidate and says what happened.
  Future<ProbeAttempt> inspect(String path) async {
    try {
      final ProcessResult r = await Process.run(
        path,
        <String>['--version'],
        environment: _childEnvironment(),
        includeParentEnvironment: false,
        runInShell: needsShell(path),
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (r.exitCode != 0) {
        return ProbeAttempt(path, ProbeOutcome.notClaude, 'exit ${r.exitCode}');
      }
      return ProbeAttempt(path, ProbeOutcome.found, '${r.stdout}'.trim());
    } on ProcessException catch (e) {
      // errno 2 and Windows 3 are "not there"; anything else ran into
      // something that exists but would not start.
      final bool absent = e.errorCode == 2 || e.errorCode == 3;
      return ProbeAttempt(
        path,
        absent ? ProbeOutcome.missing : ProbeOutcome.notExecutable,
        absent ? '' : e.message,
      );
    } on Exception catch (e) {
      return ProbeAttempt(path, ProbeOutcome.notExecutable, '$e');
    }
  }

  /// True for a candidate Windows cannot start directly.
  ///
  /// `CreateProcess` refuses a `.cmd` or `.bat`, which is how an npm install
  /// of Claude Code — `%APPDATA%\npm\claude.cmd` — was reported as simply not
  /// found. A shell is the only way to run one.
  static bool needsShell(String path) {
    if (!Platform.isWindows) return false;
    final String lower = path.toLowerCase();
    return lower.endsWith('.cmd') || lower.endsWith('.bat');
  }

  /// Run `--version` and `--help` against one candidate.
  Future<CapabilityProfile?> probe(String path) async {
    try {
      final ProcessResult version = await Process.run(
        path,
        <String>['--version'],
        environment: _childEnvironment(),
        includeParentEnvironment: false,
        runInShell: needsShell(path),
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (version.exitCode != 0) return null;

      final ProcessResult help = await Process.run(
        path,
        <String>['--help'],
        environment: _childEnvironment(),
        includeParentEnvironment: false,
        runInShell: needsShell(path),
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      return const HelpParser().parse(
        helpText: '${help.stdout}',
        version: '${version.stdout}'.trim().split('\n').first,
        fingerprint: await _fingerprint(path),
      );
    } on ProcessException {
      return null;
    } on Exception {
      return null;
    }
  }

  /// Which credential the CLI will use.
  ///
  /// An API key in the environment wins over a stored login, so it is checked
  /// first — the same precedence the CLI itself applies.
  ClaudeAuthMode detectAuthMode() {
    final Map<String, String> env = Platform.environment;
    if ((env['ANTHROPIC_API_KEY'] ?? '').isNotEmpty ||
        (env['ANTHROPIC_AUTH_TOKEN'] ?? '').isNotEmpty) {
      return ClaudeAuthMode.apiKey;
    }
    final String home =
        env['USERPROFILE'] ?? env['HOME'] ?? Directory.current.path;
    final String sep = Platform.pathSeparator;
    for (final String p in <String>[
      '$home$sep.claude$sep.credentials.json',
      if (env['CLAUDE_CONFIG_DIR'] != null)
        '${env['CLAUDE_CONFIG_DIR']}$sep.credentials.json',
    ]) {
      if (File(p).existsSync()) return ClaudeAuthMode.subscription;
    }
    if ((env['CLAUDE_CODE_OAUTH_TOKEN'] ?? '').isNotEmpty) {
      return ClaudeAuthMode.subscription;
    }
    return ClaudeAuthMode.unknown;
  }

  /// Identifies the binary so a cached capability profile can be invalidated
  /// when the CLI auto-updates.
  Future<String> _fingerprint(String path) async {
    try {
      final File f = File(path);
      if (!f.existsSync()) return path;
      final FileStat s = await f.stat();
      return '${s.size}-${s.modified.millisecondsSinceEpoch}';
    } on FileSystemException {
      return path;
    }
  }

  /// The CLI refuses to start inside another Claude Code session, keying off
  /// these variables. Master Prompt may itself have been launched from one.
  static Map<String, String> _childEnvironment() {
    final Map<String, String> env =
        Map<String, String>.from(Platform.environment)
          ..remove('CLAUDECODE')
          ..remove('CLAUDE_CODE_ENTRYPOINT');
    return env;
  }
}
