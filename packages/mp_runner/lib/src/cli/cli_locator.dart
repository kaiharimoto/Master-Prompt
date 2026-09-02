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

/// Why the CLI could not be used.
class ClaudeNotFound implements Exception {
  ClaudeNotFound(this.message, {this.searched = const <String>[]});

  final String message;
  final List<String> searched;

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

  /// Locate and probe. Throws [ClaudeNotFound] with everything that was tried,
  /// so the UI can tell the user where to look rather than just failing.
  Future<ClaudeInstall> locate({String? explicitPath}) async {
    final List<String> tried = <String>[];
    final List<String> candidates = <String>[
      if (explicitPath != null && explicitPath.trim().isNotEmpty)
        explicitPath.trim(),
      ...candidatePaths(),
    ];

    for (final String path in candidates) {
      tried.add(path);
      final CapabilityProfile? p = await probe(path);
      if (p != null) {
        return ClaudeInstall(
          path: path,
          capabilities: p,
          authMode: detectAuthMode(),
        );
      }
    }

    throw ClaudeNotFound(
      'The Claude Code CLI could not be found. Install it, or set an explicit '
      'path in Settings.',
      searched: tried,
    );
  }

  /// Run `--version` and `--help` against one candidate.
  Future<CapabilityProfile?> probe(String path) async {
    try {
      final ProcessResult version = await Process.run(
        path,
        <String>['--version'],
        environment: _childEnvironment(),
        includeParentEnvironment: false,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (version.exitCode != 0) return null;

      final ProcessResult help = await Process.run(
        path,
        <String>['--help'],
        environment: _childEnvironment(),
        includeParentEnvironment: false,
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
