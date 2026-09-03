import 'dart:io';

/// Identifies exactly which build is running.
///
/// Without this, every report starts with working out which build you are on,
/// and there is no way to tell from inside the app. CI injects the values with
/// `--dart-define`; a local build falls back to something obviously local
/// rather than pretending to be a real build.
abstract final class BuildInfo {
  /// Marketing version, kept in step with `pubspec.yaml`.
  static const String version = '0.1.0';

  /// The CI run number. `local` when built on a developer machine.
  static const String build = String.fromEnvironment(
    'MP_BUILD',
    defaultValue: 'local',
  );

  /// The full commit SHA CI built from. Empty for a local build.
  static const String sha = String.fromEnvironment('MP_SHA');

  static bool get isCiBuild => build != 'local';

  static String get shortSha =>
      sha.isEmpty ? 'dev' : sha.substring(0, sha.length < 7 ? sha.length : 7);

  /// What the user sees and quotes back: `0.1.0+42 · a1b2c3d`.
  static String get label => '$version+$build · $shortSha';

  static String get platform {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isIOS) return 'iOS';
    return 'unknown';
  }

  static String get osVersion => Platform.operatingSystemVersion;

  /// The exact commit, so a report can be tied to a diff.
  static String get commitUrl => sha.isEmpty
      ? ''
      : 'https://github.com/kaiharimoto/Master-Prompt/commit/$sha';
}
