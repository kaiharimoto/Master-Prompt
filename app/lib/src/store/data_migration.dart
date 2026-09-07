import 'dart:io';

import 'diagnostics.dart';

/// Brings a previous install's data forward when the app's data directory
/// moves out from under it.
///
/// On Windows `path_provider` builds the support directory as
/// `RoamingAppData\<CompanyName>\<ProductName>`, and it reads those two
/// strings **out of the running exe's VERSIONINFO resource at runtime**. So
/// renaming the app from `master_prompt` to `Master Prompt` — which is only a
/// change to a resource file — silently relocates every saved mission,
/// the settings, the crash log and the interview session directory. The app
/// starts up looking empty and nothing says why.
///
/// This runs before anything reads the new directory.
abstract final class DataMigration {
  /// Written last, so an interrupted copy is simply redone next launch.
  static const String marker = '.migrated-from';

  /// Where the data lived before the app was given a proper name.
  ///
  /// Only the Windows path ever changed: Android keys its directory off the
  /// `applicationId`, which must not change and has not.
  static List<Directory> previousLocations() {
    if (!Platform.isWindows) return const <Directory>[];
    final String? roaming = Platform.environment['APPDATA'];
    if (roaming == null || roaming.isEmpty) return const <Directory>[];
    return <Directory>[Directory('$roaming\\com.masterprompt\\master_prompt')];
  }

  /// Copies anything [to] does not already have from the first [from] that
  /// exists.
  ///
  /// **Copies rather than moves, and never overwrites.** A few hundred
  /// kilobytes of duplicate is nothing weighed against losing missions that
  /// took hours of discussion to produce, and leaving the old directory in
  /// place means a migration that goes wrong is recoverable by hand. Because
  /// nothing is ever overwritten, running this twice — or half of it twice —
  /// cannot destroy anything.
  static Future<bool> run({
    required Directory to,
    List<Directory>? from,
  }) async {
    final File done = File('${to.path}${Platform.pathSeparator}$marker');
    if (done.existsSync()) return false;

    for (final Directory old in from ?? previousLocations()) {
      if (!old.existsSync()) continue;

      int copied = 0;
      try {
        copied = await _copyMissing(old, to);
      } on FileSystemException catch (e) {
        // A failed migration must not stop the app starting. The old data is
        // untouched, so the next launch tries again.
        Diagnostics.instance.log(
          'Could not bring old data forward: ${e.message}',
        );
        return false;
      }

      to.createSync(recursive: true);
      done.writeAsStringSync(
        '${old.path}\n${DateTime.now().toUtc().toIso8601String()}\n'
        '$copied files copied. The originals were left where they were.\n',
      );
      Diagnostics.instance.log(
        'Brought $copied files forward from ${old.path}.',
      );
      return copied > 0;
    }
    return false;
  }

  static Future<int> _copyMissing(Directory from, Directory to) async {
    int copied = 0;
    if (!to.existsSync()) to.createSync(recursive: true);

    for (final FileSystemEntity e in from.listSync(recursive: true)) {
      final String relative = e.path.substring(from.path.length);
      final String target = '${to.path}$relative';
      if (e is Directory) {
        final Directory d = Directory(target);
        if (!d.existsSync()) d.createSync(recursive: true);
      } else if (e is File) {
        final File f = File(target);
        if (f.existsSync()) continue;
        final Directory parent = f.parent;
        if (!parent.existsSync()) parent.createSync(recursive: true);
        await e.copy(target);
        copied++;
      }
    }
    return copied;
  }
}
