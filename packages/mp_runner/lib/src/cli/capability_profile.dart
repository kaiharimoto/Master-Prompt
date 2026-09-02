import 'package:meta/meta.dart';

/// What a specific `claude` binary actually supports.
///
/// Built by parsing `--help` rather than assuming, because published
/// documentation for this CLI drifts from the shipped binary. Two concrete
/// examples found while building this: `--effort` accepts only
/// `low, medium, high` in v2.1.42 although `xhigh` and `max` are widely
/// documented, and `--autocompact` does not exist at all. A flag composed from
/// documentation that the installed binary rejects is the failure this type
/// exists to prevent — discovered nine hours into an unattended run.
@immutable
class CapabilityProfile {
  const CapabilityProfile({
    required this.version,
    required this.fingerprint,
    required this.flags,
    this.choices = const <String, List<String>>{},
    this.subcommands = const <String>{},
  });

  /// Reported by `claude --version`.
  final String version;

  /// Identifies the exact binary. The CLI auto-updates, so this is re-checked
  /// before every launch and the profile rebuilt when it changes.
  final String fingerprint;

  /// Every long flag the binary advertises, including the leading dashes.
  final Set<String> flags;

  /// Enumerated values for flags that declare them, keyed by flag.
  final Map<String, List<String>> choices;

  final Set<String> subcommands;

  bool has(String flag) => flags.contains(flag);

  /// Whether [flag] accepts [value]. Flags that do not enumerate their values
  /// accept anything, so an unknown enumeration is permissive rather than
  /// blocking — the alternative is refusing to launch on a newer CLI.
  bool supportsValue(String flag, String value) {
    final List<String>? allowed = choices[flag];
    if (allowed == null || allowed.isEmpty) return true;
    return allowed.contains(value);
  }

  /// The best available value from [preferred], falling back through the list
  /// and finally to [fallback]. Used to degrade effort or permission mode on a
  /// CLI that does not know the requested value.
  String? bestValue(String flag, List<String> preferred, {String? fallback}) {
    if (!has(flag)) return null;
    for (final String p in preferred) {
      if (supportsValue(flag, p)) return p;
    }
    return fallback;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'fingerprint': fingerprint,
    'flags': flags.toList()..sort(),
    'choices': choices,
    'subcommands': subcommands.toList()..sort(),
  };

  static CapabilityProfile fromJson(Map<String, Object?> j) => CapabilityProfile(
    version: '${j['version']}',
    fingerprint: '${j['fingerprint']}',
    flags: <String>{
      for (final Object? f in (j['flags'] as List<Object?>? ?? const <Object?>[]))
        '$f',
    },
    choices: <String, List<String>>{
      for (final MapEntry<Object?, Object?> e
          in (j['choices'] as Map<Object?, Object?>? ?? const <Object?, Object?>{})
              .entries)
        '${e.key}': <String>[
          for (final Object? v in (e.value as List<Object?>? ?? const <Object?>[]))
            '$v',
        ],
    },
    subcommands: <String>{
      for (final Object? s
          in (j['subcommands'] as List<Object?>? ?? const <Object?>[]))
        '$s',
    },
  );

  @override
  String toString() =>
      'CapabilityProfile($version, ${flags.length} flags, '
      '${choices.length} enumerated)';
}

/// Parses `claude --help` output into a [CapabilityProfile].
///
/// Kept as a pure function over strings so it can be tested against captured
/// help text from several CLI versions without spawning anything.
class HelpParser {
  const HelpParser();

  static final RegExp _flagLine = RegExp(
    r'^\s{2,}(-[A-Za-z0-9], )?(--[A-Za-z0-9][A-Za-z0-9-]*)((?:, --[A-Za-z0-9][A-Za-z0-9-]*)*)',
  );

  /// `(choices: "a", "b", "c")` — the form commander emits for enumerated values.
  static final RegExp _explicitChoices =
      RegExp(r'\(choices:\s*([^)]*)\)', caseSensitive: false);

  /// `(low, medium, high)` — a bare parenthesised list at the end of a
  /// description. Only treated as an enumeration when every item is a plain
  /// lowercase token, so prose in parentheses is not mistaken for choices.
  static final RegExp _bareChoices = RegExp(r'\(([a-z0-9][a-z0-9, _-]*)\)\s*$');

  CapabilityProfile parse({
    required String helpText,
    required String version,
    required String fingerprint,
  }) {
    final Set<String> flags = <String>{};
    final Map<String, List<String>> choices = <String, List<String>>{};
    final Set<String> subcommands = <String>{};

    bool inCommands = false;

    for (final String raw in helpText.split('\n')) {
      final String line = raw.trimRight();
      if (line.trim().isEmpty) continue;

      if (RegExp(r'^Commands:').hasMatch(line.trim())) {
        inCommands = true;
        continue;
      }
      if (RegExp(r'^(Options|Arguments|Usage):').hasMatch(line.trim())) {
        inCommands = false;
        continue;
      }

      if (inCommands) {
        final Match? m = RegExp(r'^\s{2,}([a-z][a-z0-9|-]*)').firstMatch(line);
        if (m != null) {
          subcommands.addAll(m.group(1)!.split('|'));
        }
        continue;
      }

      final RegExpMatch? m = _flagLine.firstMatch(line);
      if (m == null) continue;

      final List<String> names = <String>[
        m.group(2)!,
        for (final String alias in (m.group(3) ?? '').split(','))
          if (alias.trim().startsWith('--')) alias.trim(),
      ];
      flags.addAll(names);

      final List<String>? found = _extractChoices(line);
      if (found != null && found.isNotEmpty) {
        for (final String n in names) {
          choices[n] = found;
        }
      }
    }

    return CapabilityProfile(
      version: version,
      fingerprint: fingerprint,
      flags: flags,
      choices: choices,
      subcommands: subcommands,
    );
  }

  List<String>? _extractChoices(String line) {
    final Match? explicit = _explicitChoices.firstMatch(line);
    if (explicit != null) {
      return explicit
          .group(1)!
          .split(',')
          .map((String s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
          .where((String s) => s.isNotEmpty)
          .toList();
    }

    final Match? bare = _bareChoices.firstMatch(line);
    if (bare != null) {
      final List<String> parts = bare
          .group(1)!
          .split(',')
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
      // Require several single-word items; "(only works with --print)" and
      // other prose must not be read as an enumeration.
      final bool allTokens = parts.every(
        (String p) => RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(p),
      );
      if (parts.length >= 2 && allTokens) return parts;
    }
    return null;
  }
}
