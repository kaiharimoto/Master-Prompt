import 'package:flutter/material.dart';

/// Everywhere the app can go that is not the flow itself.
///
/// These were four bottom tabs competing with the work. They are now a quiet
/// menu: reachable in one tap, present on screen in none.
enum AppDestination {
  /// A newer build is waiting. Only ever listed when one actually is, which
  /// is why it sits above everything else rather than in its usual place.
  update,

  /// The full readiness detail — every requirement and what it would cost.
  progress,

  /// The compiled brief, its warnings, and the red-team pass.
  brief,

  /// Launching and supervising a run.
  run,

  /// Everything sent and received, in full.
  transcript,

  /// Switching between missions.
  missions,

  /// Model, effort, autonomy, and the diagnostics report.
  settings;

  String get label => switch (this) {
    AppDestination.update => 'Update',
    AppDestination.progress => 'Progress',
    AppDestination.brief => 'Brief',
    AppDestination.run => 'Run',
    AppDestination.transcript => 'Transcript',
    AppDestination.missions => 'Missions',
    AppDestination.settings => 'Settings',
  };

  IconData get icon => switch (this) {
    AppDestination.update => Icons.system_update_alt,
    AppDestination.progress => Icons.checklist_rtl,
    AppDestination.brief => Icons.description_outlined,
    AppDestination.run => Icons.play_circle_outline,
    AppDestination.transcript => Icons.forum_outlined,
    AppDestination.missions => Icons.folder_outlined,
    AppDestination.settings => Icons.tune,
  };

  /// Destinations that mean nothing before a mission exists.
  bool get needsMission =>
      this != AppDestination.settings && this != AppDestination.update;

  /// The menu's fixed contents. [update] is not among them: it is prepended
  /// only while there is something to update to.
  static List<AppDestination> get standing => AppDestination.values
      .where((AppDestination d) => d != AppDestination.update)
      .toList(growable: false);
}
