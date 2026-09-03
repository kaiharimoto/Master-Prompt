import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/update/release.dart';

/// A trimmed copy of what `releases/tags/dev` actually answers, with two builds
/// present so the newest-wins rule has something to choose between.
Object? payload({List<String> names = const <String>[]}) => jsonDecode('''
{
  "tag_name": "dev",
  "html_url": "https://github.com/kaiharimoto/Master-Prompt/releases/tag/dev",
  "prerelease": true,
  "assets": [
    ${names.map((String n) => '''{
      "name": "$n",
      "size": 26214400,
      "browser_download_url":
          "https://github.com/kaiharimoto/Master-Prompt/releases/download/dev/$n"
    }''').join(',')}
  ]
}
''');

void main() {
  group('reading the dev release', () {
    test('offers a newer Android build', () {
      final UpdateCheck r = readRelease(
        payload(names: <String>['MasterPrompt-57-a1b2c3d.apk']),
        currentBuild: '42',
        platform: UpdatePlatform.android,
      );

      expect(
        r.outcome,
        UpdateOutcome.available,
        reason: 'build 57 is newer than the running build 42',
      );
      expect(r.asset!.build, 57);
      expect(r.asset!.sha, 'a1b2c3d');
      expect(
        r.asset!.url.toString(),
        endsWith('MasterPrompt-57-a1b2c3d.apk'),
        reason: 'the download has to point at the asset, not the release page',
      );
      expect(r.asset!.size, '25.0 MB');
    });

    test('compares build numbers as numbers', () {
      final UpdateCheck r = readRelease(
        payload(names: <String>['MasterPrompt-99-a1b2c3d.apk']),
        currentBuild: '100',
        platform: UpdatePlatform.android,
      );

      expect(
        r.outcome,
        UpdateOutcome.upToDate,
        reason:
            'compared as strings "99" sorts above "100" and the app would '
            'offer to downgrade itself every launch',
      );
    });

    test('takes the highest build when the release carries several', () {
      final UpdateCheck r = readRelease(
        payload(
          names: <String>[
            'MasterPrompt-41-aaaaaaa.apk',
            'MasterPrompt-57-bbbbbbb.apk',
            'MasterPrompt-49-ccccccc.apk',
          ],
        ),
        currentBuild: '42',
        platform: UpdatePlatform.android,
      );

      expect(r.asset!.build, 57, reason: 'newest wins regardless of order');
    });

    test('ignores the other platform entirely', () {
      final UpdateCheck r = readRelease(
        payload(
          names: <String>[
            'MasterPrompt-57-a1b2c3d.apk',
            'MasterPrompt-windows-x64-57-a1b2c3d.zip',
          ],
        ),
        currentBuild: '42',
        platform: UpdatePlatform.windows,
      );

      expect(
        r.asset!.name,
        endsWith('.zip'),
        reason: 'a phone build offered to a desktop is not installable',
      );
    });

    test('says so when the release has nothing for this platform', () {
      final UpdateCheck r = readRelease(
        payload(names: <String>['MasterPrompt-57-a1b2c3d.apk']),
        currentBuild: '42',
        platform: UpdatePlatform.windows,
      );

      expect(r.outcome, UpdateOutcome.noAsset);
      expect(
        r.releaseUrl.toString(),
        contains('releases/tag/dev'),
        reason: 'the fallback is to hand the user the page, so it must survive',
      );
    });

    test('does not nag a locally built copy', () {
      final UpdateCheck r = readRelease(
        payload(names: <String>['MasterPrompt-57-a1b2c3d.apk']),
        currentBuild: 'local',
        platform: UpdatePlatform.android,
      );

      expect(
        r.outcome,
        UpdateOutcome.unknownBuild,
        reason:
            'a developer build has no run number, and treating that as "very '
            'old" would offer to replace their own work with CI output',
      );
      expect(
        r.asset,
        isNotNull,
        reason: 'it should still be able to say what the latest build is',
      );
    });

    test('skips assets that are not builds', () {
      final UpdateCheck r = readRelease(
        payload(
          names: <String>['checksums.txt', 'MasterPrompt-57-a1b2c3d.apk'],
        ),
        currentBuild: '42',
        platform: UpdatePlatform.android,
      );

      expect(r.asset!.build, 57);
    });

    test('reads the shape CI actually publishes', () {
      // Verbatim from the `dev` release after build 10, names and sizes
      // included. The updater's whole contract with CI is these two file
      // names, and nothing else in either repository would catch a change to
      // them until an install failed on a device.
      const String real = '''
{
  "tag_name": "dev",
  "html_url": "https://github.com/kaiharimoto/Master-Prompt/releases/tag/dev",
  "prerelease": true,
  "assets": [
    {
      "name": "MasterPrompt-10-917d3bb.apk",
      "size": 53073401,
      "content_type": "application/vnd.android.package-archive",
      "browser_download_url":
          "https://github.com/kaiharimoto/Master-Prompt/releases/download/dev/MasterPrompt-10-917d3bb.apk"
    },
    {
      "name": "MasterPrompt-windows-x64-10-917d3bb.zip",
      "size": 12931257,
      "content_type": "application/zip",
      "browser_download_url":
          "https://github.com/kaiharimoto/Master-Prompt/releases/download/dev/MasterPrompt-windows-x64-10-917d3bb.zip"
    }
  ]
}
''';

      final UpdateCheck apk = readRelease(
        jsonDecode(real),
        currentBuild: '9',
        platform: UpdatePlatform.android,
      );
      expect(apk.outcome, UpdateOutcome.available);
      expect(apk.asset!.build, 10);
      expect(apk.asset!.sha, '917d3bb');
      expect(apk.asset!.size, '50.6 MB');

      final UpdateCheck zip = readRelease(
        jsonDecode(real),
        currentBuild: '9',
        platform: UpdatePlatform.windows,
      );
      expect(zip.asset!.name, 'MasterPrompt-windows-x64-10-917d3bb.zip');
      expect(
        zip.asset!.build,
        10,
        reason:
            'the Windows name embeds the build after two hyphenated words, so '
            'a pattern written for the APK would read 64 as the build number',
      );
    });

    test('reports an unreadable answer rather than throwing', () {
      expect(
        readRelease(
          'not json',
          currentBuild: '42',
          platform: UpdatePlatform.android,
        ).outcome,
        UpdateOutcome.unreadable,
        reason:
            'GitHub answers rate limiting with a different shape, and a crash '
            'at launch is a worse outcome than a quiet failed check',
      );
    });

    test('survives a release with no assets at all', () {
      expect(
        readRelease(
          payload(),
          currentBuild: '42',
          platform: UpdatePlatform.android,
        ).outcome,
        UpdateOutcome.noAsset,
        reason: 'CI publishes the tag before the assets finish uploading',
      );
    });
  });
}
