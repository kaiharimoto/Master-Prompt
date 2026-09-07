import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/store/data_migration.dart';

/// Real files, in a plain `test()` rather than `testWidgets`.
///
/// File I/O cannot complete inside the widget tester's fake-async zone, and
/// this is exactly the code where a hang or a race would be worst.
void main() {
  late Directory tmp;
  late Directory old;
  late Directory fresh;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mp_migrate_');
    old = Directory('${tmp.path}/old')..createSync();
    fresh = Directory('${tmp.path}/new')..createSync();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  void seedOld() {
    Directory('${old.path}/projects').createSync(recursive: true);
    File('${old.path}/projects/a1.json').writeAsStringSync('{"id":"a1"}');
    File('${old.path}/projects/settings.json').writeAsStringSync('{}');
    File('${old.path}/last_crash.txt').writeAsStringSync('boom');
  }

  Future<bool> migrate() =>
      DataMigration.run(to: fresh, from: <Directory>[old]);

  test('a rename does not lose the missions it moves', () async {
    seedOld();
    expect(await migrate(), isTrue);

    expect(
      File('${fresh.path}/projects/a1.json').readAsStringSync(),
      '{"id":"a1"}',
    );
    expect(File('${fresh.path}/projects/settings.json').existsSync(), isTrue);
    expect(
      File('${fresh.path}/last_crash.txt').existsSync(),
      isTrue,
      reason: 'the crash log is what a bug report is built from',
    );
  });

  test('the originals are left where they were', () async {
    seedOld();
    await migrate();
    expect(
      File('${old.path}/projects/a1.json').existsSync(),
      isTrue,
      reason:
          'a migration that goes wrong has to be recoverable by hand, and a '
          'few hundred kilobytes is nothing against losing hours of discussion',
    );
  });

  test('running it twice changes nothing the second time', () async {
    seedOld();
    expect(await migrate(), isTrue);
    expect(
      await migrate(),
      isFalse,
      reason: 'the marker is what stops it running on every launch forever',
    );
  });

  test('an interrupted copy is finished on the next launch', () async {
    seedOld();
    // A copy that got as far as one file and then died: no marker written.
    Directory('${fresh.path}/projects').createSync(recursive: true);
    File('${fresh.path}/projects/a1.json').writeAsStringSync('{"id":"a1"}');

    expect(await migrate(), isTrue);
    expect(File('${fresh.path}/last_crash.txt').existsSync(), isTrue);
  });

  test('nothing already in the new location is ever overwritten', () async {
    seedOld();
    Directory('${fresh.path}/projects').createSync(recursive: true);
    File('${fresh.path}/projects/a1.json').writeAsStringSync('{"id":"newer"}');

    await migrate();
    expect(
      File('${fresh.path}/projects/a1.json').readAsStringSync(),
      '{"id":"newer"}',
      reason:
          'copying is only ever additive, so a half-run migration cannot '
          'destroy work done after it',
    );
  });

  test('no previous install is not a failure', () async {
    old.deleteSync();
    expect(await migrate(), isFalse);
    expect(
      fresh.listSync(),
      isEmpty,
      reason:
          'a first install on a clean machine must not be given a marker for '
          'a migration that never happened',
    );
  });

  test('only Windows ever moved, so only Windows looks', () {
    expect(
      DataMigration.previousLocations(
        onWindows: false,
        roaming: r'C:\Users\k\AppData\Roaming',
      ),
      isEmpty,
      reason:
          'Android keys its directory off the applicationId, which has not '
          'changed and must not',
    );
  });

  test('it looks where the old build actually put things', () {
    // The one thing about this that can be wrong on a Windows machine and
    // nowhere else, so it is checked here rather than left to be discovered
    // by a user whose missions have vanished.
    final List<Directory> old = DataMigration.previousLocations(
      onWindows: true,
      roaming: r'C:\Users\k\AppData\Roaming',
    );
    expect(old, hasLength(1));
    expect(
      old.single.path,
      r'C:\Users\k\AppData\Roaming\com.masterprompt\master_prompt',
      reason:
          'path_provider builds this from the exe VERSIONINFO, so it is the '
          'CompanyName and ProductName the old build carried, verbatim',
    );
  });

  test('no APPDATA means nothing to bring forward, not a crash', () {
    expect(
      DataMigration.previousLocations(onWindows: true, roaming: ''),
      isEmpty,
    );
  });
}
