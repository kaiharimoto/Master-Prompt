import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mp_core/mp_core.dart';
import 'package:path_provider/path_provider.dart';

import 'data_migration.dart';
import 'diagnostics.dart';
import 'project.dart';
import 'settings.dart';

/// The app's single source of truth.
///
/// Projects are plain JSON files, one per mission, written atomically. Not a
/// database on purpose: a mission that took hours of discussion to produce
/// should be recoverable with a text editor if this app ever fails to start.
class AppStore extends ChangeNotifier {
  AppStore({Directory? root, this.inMemory = false, DateTime Function()? now})
    : _root = root,
      _now = now ?? DateTime.now;

  /// Where the time for a new id comes from.
  ///
  /// Injected for one reason: the bug this guards against only appears on a
  /// platform whose clock is coarse, and the runner the tests run on has a
  /// fine one. A test against the real clock passed on Linux while the same
  /// code lost a mission on Windows — so the clock is a parameter, the same
  /// way `RunSupervisor` takes one, and a frozen clock proves the property on
  /// every platform.
  final DateTime Function() _now;

  /// Skip the filesystem entirely.
  ///
  /// Exists for widget tests. Real file I/O cannot complete inside the widget
  /// tester's fake-async zone, so a test that persists either hangs or races
  /// depending on machine load — and a flaky test about the interface is worse
  /// than no test, because it teaches you to ignore red. Persistence has its
  /// own tests, which run outside that zone.
  final bool inMemory;

  Directory? _root;
  final List<Project> _projects = <Project>[];
  String? _currentId;
  AppSettings _settings = const AppSettings();
  bool _loaded = false;

  List<Project> get projects => List<Project>.unmodifiable(_projects);

  bool get isLoaded => _loaded;

  AppSettings get settings => _settings;

  Project? get current {
    for (final Project p in _projects) {
      if (p.id == _currentId) return p;
    }
    return null;
  }

  Future<Directory> _dir() async {
    if (_root == null) {
      final Directory support = await getApplicationSupportDirectory();
      // Before anything reads the new location. Renaming the app moved this
      // directory, and an app that starts up empty with no explanation is the
      // worst possible way to find that out.
      await DataMigration.run(to: support);
      _root = Directory('${support.path}/projects');
    }
    if (!_root!.existsSync()) _root!.createSync(recursive: true);
    return _root!;
  }

  Future<void> load() async {
    if (inMemory) {
      _seedMintFloor();
      _currentId ??= _projects.isEmpty ? null : _projects.first.id;
      _loaded = true;
      notifyListeners();
      return;
    }
    final Directory dir = await _dir();
    _projects.clear();
    for (final FileSystemEntity e in dir.listSync()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      if (e.path.endsWith('settings.json')) continue;
      try {
        final Object? j = jsonDecode(await e.readAsString());
        if (j is Map<String, Object?>) _projects.add(Project.fromJson(j));
      } on FormatException {
        // A corrupt file must not stop the rest of the projects loading.
        Diagnostics.instance.log(
          'Skipped an unreadable project file: ${e.path}',
        );
        continue;
      }
    }
    _projects.sort(
      (Project a, Project b) =>
          (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
    );

    final File s = File('${dir.path}/settings.json');
    if (s.existsSync()) {
      try {
        final Object? j = jsonDecode(await s.readAsString());
        if (j is Map<String, Object?>) _settings = AppSettings.fromJson(j);
      } on FormatException {
        _settings = const AppSettings();
      }
    }

    _seedMintFloor();
    _currentId ??= _projects.isEmpty ? null : _projects.first.id;
    _loaded = true;
    Diagnostics.instance.log('Loaded ${_projects.length} mission(s).');
    notifyListeners();
  }

  int _lastMintedMicros = 0;

  /// A mission id that cannot collide with the one before it.
  ///
  /// Ids are minted from the clock, and the clock is not fine-grained
  /// everywhere: Windows advances it in ticks of a millisecond or more, so two
  /// missions made inside one tick were handed the *same* id — and `save`
  /// writes each project to `<id>.json`, so the second silently overwrote the
  /// first on disk, while `delete` would then take both.
  ///
  /// Caught by a Windows CI run, on a test written for the import path against
  /// a bug that had always been in `create` — where a double-tap on the seed
  /// screen is enough to reach it.
  ///
  /// Monotonic within the process, so a tight loop cannot repeat, and floored
  /// at load by the largest id already on disk, so a clock that moved backwards
  /// between launches cannot reissue one either.
  /// Never issue an id that has already been issued, even if the clock has
  /// moved backwards since.
  ///
  /// The counter alone only holds within one run of the app. A system clock
  /// corrected backwards by NTP, or set by hand, or read from a dead RTC, puts
  /// the next launch below ids already on disk — and an id that repeats is a
  /// mission overwritten. Ids are base36 microseconds, so the largest one
  /// already saved is the floor for the next.
  void _seedMintFloor() {
    for (final Project p in _projects) {
      final int? issued = int.tryParse(p.id, radix: 36);
      if (issued != null && issued > _lastMintedMicros) {
        _lastMintedMicros = issued;
      }
    }
  }

  String _mintId() {
    int micros = _now().microsecondsSinceEpoch;
    if (micros <= _lastMintedMicros) micros = _lastMintedMicros + 1;
    _lastMintedMicros = micros;
    return micros.toRadixString(36);
  }

  Future<Project> create({
    String title = 'Untitled mission',
    String preset = 'generic',
  }) async {
    final String id = _mintId();
    final Project p = Project(
      id: id,
      spec: MissionSpec(
        id: id,
        taskId: _slug(title),
        title: title,
        presetId: preset,
        createdAt: DateTime.now().toUtc(),
      ),
      updatedAt: DateTime.now().toUtc(),
    );
    _projects.insert(0, p);
    _currentId = id;
    Diagnostics.instance.log('Created mission "${p.spec.taskId}".');
    await save(p);
    notifyListeners();
    return p;
  }

  /// Bring a mission in from another device.
  ///
  /// The bundle round-trips and has been fully tested since it was written,
  /// and nothing in the app could produce or read one — so a mission started
  /// on the phone and continued at the desk had no route between them at all,
  /// which is the workflow this program is for.
  ///
  /// The project gets a **fresh local id**. Ids here are minted from the
  /// clock, so an imported one could collide with something already on this
  /// device, and the imported mission would overwrite it. The bundle
  /// deliberately carries nothing device-scoped — no session id, no binary
  /// path, no working directory — so an import cannot "resume" into a
  /// conversation that does not exist on this machine.
  Future<Project> importBundle(MissionBundle b) async {
    final String id = _mintId();
    final Project p = Project(
      id: id,
      spec: b.spec,
      lastState: b.state,
      producedArtifacts: List<String>.from(b.producedArtifacts),
      transcript: <TranscriptEntry>[
        for (final BundleExchange e in b.history)
          TranscriptEntry(
            direction: e.sent
                ? TranscriptDirection.sent
                : TranscriptDirection.received,
            text: e.text,
            at: e.at,
            note: e.note,
          ),
      ],
      updatedAt: DateTime.now().toUtc(),
    );
    _projects.insert(0, p);
    _currentId = id;
    Diagnostics.instance.log(
      'Imported mission "${p.spec.taskId}" '
      '(${b.history.length} exchanges, exported ${b.exportedAt.toIso8601String()}).',
    );
    await save(p);
    notifyListeners();
    return p;
  }

  /// Open a mission from a Master Idea pitch.
  ///
  /// The other half of this pair hands back a launch document: the directions
  /// its client selected, what they become combined, and the assumptions its
  /// council made while nobody was watching. That is a better start than one
  /// typed sentence, and it should not have to be retyped to get here.
  ///
  /// **Everything it carries arrives proposed.** The prose was written by a
  /// model, however carefully its client chose which directions to keep, so it
  /// goes through the same gate a typed mission does — see `IdeaPitch.seed`.
  /// The whole document is kept as a received exchange rather than only the
  /// values, because the reasoning and the marked assumptions are the part
  /// worth having in front of you while the interview runs.
  Future<Project> importPitch(IdeaPitch pitch) async {
    final String id = _mintId();
    final Project p = Project(
      id: id,
      spec: pitch.seed(
        MissionSpec(
          id: id,
          taskId: pitch.taskId.isEmpty ? _slug(pitch.title) : pitch.taskId,
          title: pitch.title.isEmpty ? 'Untitled mission' : pitch.title,
          presetId: 'generic',
          createdAt: DateTime.now().toUtc(),
        ),
      ),
      transcript: <TranscriptEntry>[
        TranscriptEntry(
          direction: TranscriptDirection.received,
          text: pitch.document,
          at: DateTime.now().toUtc(),
          note: pitch.provenance,
        ),
      ],
      updatedAt: DateTime.now().toUtc(),
    );
    _projects.insert(0, p);
    _currentId = id;
    Diagnostics.instance.log(
      'Opened mission "${p.spec.taskId}" from a Master Idea pitch '
      '(session ${pitch.sessionId}, ${pitch.directionIds.length} direction(s)).',
    );
    await save(p);
    notifyListeners();
    return p;
  }

  void select(String id) {
    _currentId = id;
    notifyListeners();
  }

  /// Step back to no mission, which is what puts the flow on its opening
  /// question. Starting a mission now happens by answering that question, so
  /// there is no such thing as an empty untitled project waiting to be filled.
  void deselect() {
    _currentId = null;
    notifyListeners();
  }

  Future<void> save(Project p) async {
    p.updatedAt = DateTime.now().toUtc();
    // Reflect the change straight away. Waiting for the write means the screen
    // sits on the previous state for the length of a disk round trip, which on
    // a phone is long enough to feel like the tap was ignored.
    notifyListeners();
    if (inMemory) return;
    final Directory dir = await _dir();
    final File target = File('${dir.path}/${p.id}.json');
    final File temp = File('${target.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(p.toJson()),
      flush: true,
    );
    await temp.rename(target.path);
    notifyListeners();
  }

  Future<void> delete(Project p) async {
    _projects.removeWhere((Project x) => x.id == p.id);
    if (_currentId == p.id) {
      _currentId = _projects.isEmpty ? null : _projects.first.id;
    }
    if (!inMemory) {
      final Directory dir = await _dir();
      final File f = File('${dir.path}/${p.id}.json');
      if (f.existsSync()) f.deleteSync();
    }
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings s) async {
    _settings = s;
    notifyListeners();
    if (inMemory) return;
    final Directory dir = await _dir();
    await File('${dir.path}/settings.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(s.toJson()),
      flush: true,
    );
    notifyListeners();
  }

  /// Record an exchange and persist it.
  Future<void> addTranscript(Project p, TranscriptEntry entry) async {
    p.transcript = <TranscriptEntry>[...p.transcript, entry];
    await save(p);
  }

  static String _slug(String s) {
    final String base = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return base.isEmpty ? 'mission' : base;
  }
}
