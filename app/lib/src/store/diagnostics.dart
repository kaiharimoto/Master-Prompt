import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mp_core/mp_core.dart';
import 'package:path_provider/path_provider.dart';

import 'build_info.dart';
import 'project.dart';
import 'settings.dart';

/// Collects enough context to diagnose a problem from a pasted message.
///
/// This exists because feedback arrives as conversation rather than as a bug
/// tracker with attachments. On Android there is no log you can reach from the
/// device, so without this a crash is simply invisible to both of us — the
/// report would be "it closed", and there would be nowhere to look.
class Diagnostics {
  Diagnostics._();

  static final Diagnostics instance = Diagnostics._();

  /// Recent events, oldest first. Bounded so a long session cannot grow it
  /// without limit.
  static const int _capacity = 120;
  final Queue<String> _events = Queue<String>();

  File? _crashFile;

  /// Record something worth seeing in a report. Deliberately cheap: this is on
  /// the path of ordinary UI actions.
  void log(String message) {
    final String stamp = DateTime.now().toUtc().toIso8601String().substring(
      11,
      23,
    );
    _events.addLast('$stamp  $message');
    while (_events.length > _capacity) {
      _events.removeFirst();
    }
  }

  /// Install global error handlers.
  ///
  /// The crash is written to disk *before* the app dies, because the report
  /// necessarily happens after a restart — an in-memory buffer would already
  /// be gone by the time anyone could copy it.
  Future<void> install() async {
    try {
      final Directory dir = await getApplicationSupportDirectory();
      _crashFile = File('${dir.path}${Platform.pathSeparator}last_crash.txt');
    } on Object {
      // Diagnostics must never be the reason the app fails to start.
      _crashFile = null;
    }

    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _recordCrash(details.exception, details.stack, context: 'flutter');
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _recordCrash(error, stack, context: 'platform');
      return false;
    };
  }

  void _recordCrash(Object error, StackTrace? stack, {required String context}) {
    final String text =
        '${DateTime.now().toUtc().toIso8601String()}  [$context]  '
        '${BuildInfo.label}  ${BuildInfo.platform}\n$error\n$stack';
    log('CRASH ($context): $error');
    try {
      _crashFile?.writeAsStringSync(text, flush: true);
    } on Object {
      // Nothing useful to do if even this fails.
    }
  }

  String? readLastCrash() {
    try {
      final File? f = _crashFile;
      if (f == null || !f.existsSync()) return null;
      return f.readAsStringSync();
    } on Object {
      return null;
    }
  }

  Future<void> clearLastCrash() async {
    try {
      final File? f = _crashFile;
      if (f != null && f.existsSync()) await f.delete();
      log('Cleared the recorded crash.');
    } on Object {
      // ignore
    }
  }

  bool get hasCrash => readLastCrash() != null;

  /// The block the user copies and pastes back.
  ///
  /// Written to be read by a person as much as parsed by one: the build and the
  /// mission state come first, because they answer most questions on their own.
  String report({Project? project, AppSettings? settings}) {
    final StringBuffer b = StringBuffer()
      ..writeln('--- MASTER PROMPT DIAGNOSTICS ---')
      ..writeln('build     ${BuildInfo.label}')
      ..writeln('platform  ${BuildInfo.platform} · ${BuildInfo.osVersion}')
      ..writeln('captured  ${DateTime.now().toUtc().toIso8601String()}');
    if (BuildInfo.sha.isNotEmpty) {
      b.writeln('commit    ${BuildInfo.sha}');
    }
    if (!BuildInfo.isCiBuild) {
      b.writeln('note      local build, not from CI');
    }

    if (settings != null) {
      b
        ..writeln()
        ..writeln('[settings]')
        ..writeln('model       ${settings.model}')
        ..writeln('effort      ${settings.effort}')
        ..writeln('permission  ${settings.permissionMode}')
        ..writeln('theme       ${settings.themeMode.name}')
        // Paths can contain a user name; the key itself is never included.
        ..writeln(
          'cliPath     ${settings.claudePath == null || settings.claudePath!.isEmpty ? 'not set' : 'set'}',
        )
        ..writeln(
          'workingDir  ${settings.workingDirectory == null || settings.workingDirectory!.isEmpty ? 'not set' : 'set'}',
        );
    }

    if (project != null) {
      final ReadinessReport r = const InterviewEngine().assess(project.spec);
      b
        ..writeln()
        ..writeln('[mission]')
        ..writeln('taskId      ${project.spec.taskId}')
        ..writeln('title       ${project.spec.title}')
        ..writeln('readiness   ${r.satisfied}/${r.totalRequired} '
            '(${r.canCompile ? 'compilable' : '${r.blocking.length} blocking'})')
        ..writeln('stage       ${r.currentStage.name}')
        ..writeln('parts       ${project.spec.regions.length}')
        ..writeln('evidence    ${project.spec.evidence.length}')
        ..writeln('rubric      ${project.spec.rubric.categories.length} '
            'categories, exit ${project.spec.rubric.exitThreshold}')
        ..writeln('exchanges   ${project.transcript.length}');
      final MpState? s = project.lastState;
      if (s != null) {
        b
          ..writeln('phase       ${s.phase.name}')
          ..writeln('cycle       ${s.cycle}')
          ..writeln('score       ${s.score}')
          ..writeln('next        ${s.next}');
        if (s.isBlocked) b.writeln('blocked     ${s.blocked}');
      } else {
        b.writeln('state       none recorded');
      }
    }

    final String? crash = readLastCrash();
    if (crash != null) {
      b
        ..writeln()
        ..writeln('[last crash]')
        ..writeln(_clip(crash, 2500));
    }

    b
      ..writeln()
      ..writeln('[recent events]');
    if (_events.isEmpty) {
      b.writeln('(none)');
    } else {
      for (final String e in _events) {
        b.writeln(e);
      }
    }
    b.writeln('--- END DIAGNOSTICS ---');
    return b.toString();
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}\n…(${s.length - max} more characters)';
}
