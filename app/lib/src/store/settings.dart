import 'package:flutter/material.dart';

/// User preferences. Deliberately small; anything that belongs to a mission
/// lives in its spec, not here.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.claudePath,
    this.model = 'claude-opus-5',
    this.effort = 'high',
    this.permissionMode = 'bypassPermissions',
    this.workingDirectory,
    this.stepDownOnOpusLimit = false,
  });

  final ThemeMode themeMode;

  /// Explicit path to the CLI, when discovery does not find it.
  final String? claudePath;

  final String model;

  /// Preferred effort. The launch plan degrades this to whatever the installed
  /// CLI actually accepts.
  final String effort;

  final String permissionMode;
  final String? workingDirectory;

  /// Off by default: the chosen policy is to wait out a limit rather than
  /// silently changing which model does the work.
  final bool stepDownOnOpusLimit;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? claudePath,
    String? model,
    String? effort,
    String? permissionMode,
    String? workingDirectory,
    bool? stepDownOnOpusLimit,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    claudePath: claudePath ?? this.claudePath,
    model: model ?? this.model,
    effort: effort ?? this.effort,
    permissionMode: permissionMode ?? this.permissionMode,
    workingDirectory: workingDirectory ?? this.workingDirectory,
    stepDownOnOpusLimit: stepDownOnOpusLimit ?? this.stepDownOnOpusLimit,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'claudePath': claudePath,
    'model': model,
    'effort': effort,
    'permissionMode': permissionMode,
    'workingDirectory': workingDirectory,
    'stepDownOnOpusLimit': stepDownOnOpusLimit,
  };

  static AppSettings fromJson(Map<String, Object?> j) => AppSettings(
    themeMode: ThemeMode.values.firstWhere(
      (ThemeMode m) => m.name == j['themeMode'],
      orElse: () => ThemeMode.system,
    ),
    claudePath: j['claudePath'] as String?,
    model: '${j['model'] ?? 'claude-opus-5'}',
    effort: '${j['effort'] ?? 'high'}',
    permissionMode: '${j['permissionMode'] ?? 'bypassPermissions'}',
    workingDirectory: j['workingDirectory'] as String?,
    stepDownOnOpusLimit: j['stepDownOnOpusLimit'] as bool? ?? false,
  );
}
