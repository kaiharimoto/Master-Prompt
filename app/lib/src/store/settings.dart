import 'package:flutter/material.dart';

/// User preferences. Deliberately small; anything that belongs to a mission
/// lives in its spec, not here.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.claudePath,
    this.model = '',
    this.effort = 'high',
    this.permissionMode = 'bypassPermissions',
    this.workingDirectory,
    this.stepDownOnOpusLimit = false,
    this.standaloneTurns = false,
    this.pasteLimit = 8000,
  });

  final ThemeMode themeMode;

  /// Explicit path to the CLI, when discovery does not find it.
  final String? claudePath;

  /// Which model the CLI is asked for, or empty to leave it alone.
  ///
  /// **Empty is the default, and it means no `--model` at all.** The flag takes
  /// an alias (`opus`, `sonnet`) or a full dated name
  /// (`claude-sonnet-4-5-20250929`); anything else is refused, and because
  /// `--model` enumerates no choices in `--help`, the capability probe cannot
  /// catch a bad one. The app shipped `claude-opus-5` here, which is neither
  /// form, so every turn and every run would have failed on it. Sending
  /// nothing leaves the CLI on whatever the user already chose with `/model`,
  /// which cannot be a value this build rejects.
  final String model;

  /// Preferred effort. The launch plan degrades this to whatever the installed
  /// CLI actually accepts.
  final String effort;

  final String permissionMode;
  final String? workingDirectory;

  /// Off by default: the chosen policy is to wait out a limit rather than
  /// silently changing which model does the work.
  final bool stepDownOnOpusLimit;

  /// Write every round as if the chat had seen nothing before it.
  ///
  /// Off by default, because the interview is meant to happen in one
  /// continuing chat: that chat already holds the framing, everything settled,
  /// and the format rules — most of which it worked out itself. On for anyone
  /// who starts a fresh chat each round. The first round of a mission is sent
  /// in full either way.
  final bool standaloneTurns;

  /// Characters that fit in one message in the chat app.
  ///
  /// Anything longer is copied in numbered parts. There is no published figure
  /// for the real ceiling and it is not something the app can probe, so the
  /// default is set well under a size that was seen being cut off, and this is
  /// adjustable by the only person who can measure it.
  final int pasteLimit;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? claudePath,
    String? model,
    String? effort,
    String? permissionMode,
    String? workingDirectory,
    bool? stepDownOnOpusLimit,
    bool? standaloneTurns,
    int? pasteLimit,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    claudePath: claudePath ?? this.claudePath,
    model: model ?? this.model,
    effort: effort ?? this.effort,
    permissionMode: permissionMode ?? this.permissionMode,
    workingDirectory: workingDirectory ?? this.workingDirectory,
    stepDownOnOpusLimit: stepDownOnOpusLimit ?? this.stepDownOnOpusLimit,
    standaloneTurns: standaloneTurns ?? this.standaloneTurns,
    pasteLimit: pasteLimit ?? this.pasteLimit,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'claudePath': claudePath,
    'model': model,
    'effort': effort,
    'permissionMode': permissionMode,
    'workingDirectory': workingDirectory,
    'stepDownOnOpusLimit': stepDownOnOpusLimit,
    'standaloneTurns': standaloneTurns,
    'pasteLimit': pasteLimit,
  };

  static AppSettings fromJson(Map<String, Object?> j) => AppSettings(
    themeMode: ThemeMode.values.firstWhere(
      (ThemeMode m) => m.name == j['themeMode'],
      orElse: () => ThemeMode.system,
    ),
    claudePath: j['claudePath'] as String?,
    model: _readModel(j['model']),
    effort: '${j['effort'] ?? 'high'}',
    permissionMode: '${j['permissionMode'] ?? 'bypassPermissions'}',
    workingDirectory: j['workingDirectory'] as String?,
    stepDownOnOpusLimit: j['stepDownOnOpusLimit'] as bool? ?? false,
    standaloneTurns: j['standaloneTurns'] as bool? ?? false,
    pasteLimit: (j['pasteLimit'] as num?)?.toInt() ?? 8000,
  );

  /// Migrates a stored value the CLI would refuse.
  ///
  /// Settings shipped with a dropdown of `claude-opus-5` / `claude-sonnet-5` /
  /// `claude-haiku-4-5`. None of those is an alias or a dated full name, so
  /// every saved copy holds a value that fails on use. They map to the alias
  /// they meant; anything else unrecognised falls back to leaving the flag off,
  /// which always works.
  static String _readModel(Object? raw) {
    final String v = '${raw ?? ''}'.trim();
    if (v.isEmpty) return '';
    if (const <String>['opus', 'sonnet', 'haiku'].contains(v)) return v;
    if (RegExp(r'^claude-[a-z0-9-]+-\d{8}$').hasMatch(v)) return v;
    for (final String alias in const <String>['opus', 'sonnet', 'haiku']) {
      if (v.contains(alias)) return alias;
    }
    return '';
  }
}
