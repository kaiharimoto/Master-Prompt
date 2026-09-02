import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../compile/compiled_prompt.dart';
import '../spec/mission_spec.dart';
import 'mp_state.dart';

/// A mission packaged for transfer between devices.
///
/// The reason this exists: a run started at a desk should be continuable on a
/// phone and back again. What travels is the spec, the compiled brief, the last
/// reported state and the exchange history — everything needed to pick the
/// mission up somewhere else.
///
/// What deliberately does **not** travel is anything device-scoped: a CLI
/// session id, a binary path, a working directory. A stale session id imported
/// onto another machine would "resume" into a conversation that is not there,
/// which is worse than starting cleanly.
@immutable
class MissionBundle {
  const MissionBundle({
    required this.spec,
    required this.exportedAt,
    this.compiledBody,
    this.state,
    this.producedArtifacts = const <String>[],
    this.history = const <BundleExchange>[],
    this.appVersion = '0.1.0',
    this.schemaVersion = 1,
  });

  final MissionSpec spec;
  final DateTime exportedAt;

  /// The rendered brief, so an importing device does not have to recompile to
  /// see exactly what was sent.
  final String? compiledBody;

  final MpState? state;
  final List<String> producedArtifacts;
  final List<BundleExchange> history;
  final String appVersion;
  final int schemaVersion;

  /// Integrity check over the payload, so a truncated file is detected on
  /// import rather than silently importing half a mission.
  String get digest =>
      sha256.convert(utf8.encode(_payloadJson())).toString().substring(0, 32);

  String _payloadJson() => jsonEncode(<String, Object?>{
    'spec': spec.toJson(),
    'compiledBody': compiledBody,
    'state': state?.toJson(),
    'producedArtifacts': producedArtifacts,
    'history': history.map((BundleExchange e) => e.toJson()).toList(),
  });

  /// Serialise for transfer. Indented, because a human debugging a failed
  /// import should be able to read it.
  String encode() =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'format': 'master-prompt-bundle',
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'taskId': spec.taskId,
        'title': spec.title,
        'digest': digest,
        'payload': jsonDecode(_payloadJson()),
      });

  static MissionBundle decode(String text) {
    final Object? raw = jsonDecode(text);
    if (raw is! Map<String, Object?>) {
      throw const BundleFormatException('The file is not a mission bundle.');
    }
    if (raw['format'] != 'master-prompt-bundle') {
      throw const BundleFormatException(
        'The file is not a Master Prompt mission bundle.',
      );
    }
    final int schema = (raw['schemaVersion'] as num?)?.toInt() ?? 1;
    if (schema > 1) {
      throw BundleFormatException(
        'This bundle was written by a newer version of Master Prompt '
        '(format $schema). Update the app to open it.',
      );
    }

    final Object? payload = raw['payload'];
    if (payload is! Map<String, Object?>) {
      throw const BundleFormatException('The bundle has no payload.');
    }

    final MissionBundle bundle = MissionBundle(
      spec: MissionSpec.fromJson(payload['spec']! as Map<String, Object?>),
      exportedAt:
          DateTime.tryParse('${raw['exportedAt']}') ?? DateTime.now().toUtc(),
      compiledBody: payload['compiledBody'] as String?,
      state: payload['state'] == null
          ? null
          : MpState.fromJson(payload['state']! as Map<String, Object?>),
      producedArtifacts: <String>[
        for (final Object? a
            in (payload['producedArtifacts'] as List<Object?>? ??
                const <Object?>[]))
          '$a',
      ],
      history: <BundleExchange>[
        for (final Object? e
            in (payload['history'] as List<Object?>? ?? const <Object?>[]))
          BundleExchange.fromJson(e! as Map<String, Object?>),
      ],
      appVersion: '${raw['appVersion'] ?? 'unknown'}',
      schemaVersion: schema,
    );

    final String? claimed = raw['digest'] as String?;
    if (claimed != null && claimed != bundle.digest) {
      throw const BundleFormatException(
        'This bundle is incomplete or was modified after export. Re-export it '
        'from the device it came from.',
      );
    }
    return bundle;
  }

  static MissionBundle from({
    required MissionSpec spec,
    CompiledPrompt? compiled,
    MpState? state,
    List<String> producedArtifacts = const <String>[],
    List<BundleExchange> history = const <BundleExchange>[],
    DateTime? at,
  }) => MissionBundle(
    spec: spec,
    exportedAt: at ?? DateTime.now().toUtc(),
    compiledBody: compiled?.body,
    state: state,
    producedArtifacts: producedArtifacts,
    history: history,
  );

  /// A filename that identifies the mission and when it left.
  String get suggestedFileName {
    final String date = exportedAt.toIso8601String().split('T').first;
    return '${spec.taskId}-$date.mpx';
  }
}

/// One recorded exchange, trimmed to what is worth carrying between devices.
@immutable
class BundleExchange {
  const BundleExchange({
    required this.sent,
    required this.text,
    required this.at,
    this.note,
  });

  final bool sent;
  final String text;
  final DateTime at;
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
    'sent': sent,
    'text': text,
    'at': at.toIso8601String(),
    if (note != null) 'note': note,
  };

  static BundleExchange fromJson(Map<String, Object?> j) => BundleExchange(
    sent: j['sent'] as bool? ?? false,
    text: '${j['text']}',
    at: DateTime.tryParse('${j['at']}') ?? DateTime.now().toUtc(),
    note: j['note'] as String?,
  );
}

class BundleFormatException implements Exception {
  const BundleFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}
