import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mp_core/mp_core.dart';
import 'package:path_provider/path_provider.dart';

import 'diagnostics.dart';
import 'project.dart';
import 'settings.dart';

/// The app's single source of truth.
///
/// Projects are plain JSON files, one per mission, written atomically. Not a
/// database on purpose: a mission that took hours of discussion to produce
/// should be recoverable with a text editor if this app ever fails to start.
class AppStore extends ChangeNotifier {
  AppStore({Directory? root, this.inMemory = false}) : _root = root;

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
    _root ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/projects',
    );
    if (!_root!.existsSync()) _root!.createSync(recursive: true);
    return _root!;
  }

  Future<void> load() async {
    if (inMemory) {
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

    _currentId ??= _projects.isEmpty ? null : _projects.first.id;
    _loaded = true;
    Diagnostics.instance.log('Loaded ${_projects.length} mission(s).');
    notifyListeners();
  }

  Future<Project> create({
    String title = 'Untitled mission',
    String preset = 'generic',
  }) async {
    final String id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
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
