/// Reading the rolling `dev` release, with no network and no `dart:io`.
///
/// The interesting part of updating is not the download — it is deciding
/// whether there is anything to download, which of several assets belongs to
/// the machine asking, and what to say when the answer is "none of them". All
/// of that is here so it can be proven against captured GitHub payloads rather
/// than only against GitHub.
library;

/// Which artefact a platform can actually install.
enum UpdatePlatform {
  /// An APK, installed by the system package installer.
  android,

  /// A portable zip, extracted by hand over the existing folder.
  windows,

  /// Anything else: there is no published build to offer.
  other,
}

/// One downloadable file from the release, already identified.
///
/// [build] is CI's run number, which is the only monotonic thing available —
/// the marketing version stays `0.1.0` across dozens of builds, so comparing
/// versions would report "up to date" forever.
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.build,
    required this.sha,
    required this.bytes,
  });

  final String name;
  final Uri url;
  final int build;
  final String sha;
  final int bytes;

  /// `0.1.0+57 · a1b2c3d` reads the same way `BuildInfo.label` does, so the
  /// two can be compared by eye without translating between them.
  String label(String version) => '$version+$build · $sha';

  String get size {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// What a check found. Every outcome carries text the UI can show as-is,
/// because "update failed" with no reason is the thing that makes an updater
/// feel broken rather than merely unlucky.
enum UpdateOutcome {
  /// A newer build exists and can be installed from here.
  available,

  /// The release is the build already running.
  upToDate,

  /// The release exists but publishes nothing this platform can install.
  noAsset,

  /// The running build has no number to compare against — it was built
  /// locally rather than by CI.
  unknownBuild,

  /// The release could not be read: offline, rate-limited, or malformed.
  unreadable,
}

class UpdateCheck {
  const UpdateCheck({
    required this.outcome,
    required this.detail,
    this.asset,
    this.releaseUrl,
  });

  final UpdateOutcome outcome;

  /// One sentence, already written for a human.
  final String detail;

  /// The newest asset for this platform, when the release published one. Set
  /// even for [UpdateOutcome.upToDate] and [UpdateOutcome.unknownBuild], so
  /// the UI can always say what the latest build is.
  final ReleaseAsset? asset;

  /// The release page, for the cases where the app hands the job back over.
  final Uri? releaseUrl;

  bool get isUpdate => outcome == UpdateOutcome.available && asset != null;
}

/// `MasterPrompt-57-a1b2c3d.apk`
final RegExp _apk = RegExp(r'^MasterPrompt-(\d+)-([0-9a-f]{7,40})\.apk$');

/// `MasterPrompt-windows-x64-57-a1b2c3d.zip`
final RegExp _zip = RegExp(
  r'^MasterPrompt-windows-x64-(\d+)-([0-9a-f]{7,40})\.zip$',
);

/// Turns a GitHub release payload into a decision.
///
/// [currentBuild] is [BuildInfo.build] verbatim, including the `local`
/// sentinel; comparison is numeric so build 100 is correctly newer than 99,
/// which a string comparison gets wrong.
UpdateCheck readRelease(
  Object? decoded, {
  required String currentBuild,
  required UpdatePlatform platform,
}) {
  if (decoded is! Map<String, Object?>) {
    return const UpdateCheck(
      outcome: UpdateOutcome.unreadable,
      detail:
          'The release page did not come back in a shape this build '
          'understands.',
    );
  }

  final Uri? page = switch (decoded['html_url']) {
    final String s => Uri.tryParse(s),
    _ => null,
  };

  if (platform == UpdatePlatform.other) {
    return UpdateCheck(
      outcome: UpdateOutcome.noAsset,
      detail: 'Builds are published for Android and Windows only.',
      releaseUrl: page,
    );
  }

  final RegExp pattern = platform == UpdatePlatform.android ? _apk : _zip;
  final List<ReleaseAsset> found = <ReleaseAsset>[];

  final Object? assets = decoded['assets'];
  if (assets is List<Object?>) {
    for (final Object? entry in assets) {
      if (entry is! Map<String, Object?>) continue;
      final Object? name = entry['name'];
      final Object? url = entry['browser_download_url'];
      if (name is! String || url is! String) continue;
      final RegExpMatch? m = pattern.firstMatch(name);
      if (m == null) continue;
      final int? build = int.tryParse(m.group(1)!);
      final Uri? parsed = Uri.tryParse(url);
      if (build == null || parsed == null) continue;
      found.add(
        ReleaseAsset(
          name: name,
          url: parsed,
          build: build,
          sha: m.group(2)!.substring(0, 7),
          bytes: switch (entry['size']) {
            final int n => n,
            final num n => n.toInt(),
            _ => 0,
          },
        ),
      );
    }
  }

  if (found.isEmpty) {
    return UpdateCheck(
      outcome: UpdateOutcome.noAsset,
      detail: platform == UpdatePlatform.android
          ? 'The latest release has no Android build attached yet.'
          : 'The latest release has no Windows build attached yet.',
      releaseUrl: page,
    );
  }

  found.sort((ReleaseAsset a, ReleaseAsset b) => b.build.compareTo(a.build));
  final ReleaseAsset newest = found.first;

  final int? mine = int.tryParse(currentBuild);
  if (mine == null) {
    return UpdateCheck(
      outcome: UpdateOutcome.unknownBuild,
      detail:
          'This copy was built locally, so there is no build number to '
          'compare. Build ${newest.build} is the latest published.',
      asset: newest,
      releaseUrl: page,
    );
  }

  if (newest.build <= mine) {
    return UpdateCheck(
      outcome: UpdateOutcome.upToDate,
      detail: 'You are on the newest build.',
      asset: newest,
      releaseUrl: page,
    );
  }

  return UpdateCheck(
    outcome: UpdateOutcome.available,
    detail: 'Build ${newest.build} is ready to install.',
    asset: newest,
    releaseUrl: page,
  );
}
