import 'package:mp_core/mp_core.dart';

/// One mission the user is working on: its spec, the discussion so far, the
/// compiled brief, and whatever state the run has reported.
class Project {
  Project({
    required this.id,
    required this.spec,
    this.transcript = const <TranscriptEntry>[],
    this.compiled,
    this.lastState,
    this.producedArtifacts = const <String>[],
    this.updatedAt,
  });

  final String id;
  MissionSpec spec;

  /// Everything sent and received, so a project can be picked up cold.
  List<TranscriptEntry> transcript;

  /// True once a reply has been brought back for this mission.
  ///
  /// Which is the only reliable sign that a chat is running and holds the
  /// framing: the first round has been sent and answered in it. Before that,
  /// nothing can be assumed known.
  bool get hasAnsweredOnce => transcript.any(
    (TranscriptEntry e) => e.direction == TranscriptDirection.received,
  );

  CompiledPrompt? compiled;

  /// The most recent heartbeat parsed from a reply.
  MpState? lastState;

  List<String> producedArtifacts;
  DateTime? updatedAt;

  String get title => spec.title;

  /// Whether the compiled brief still matches the spec it came from.
  bool get compiledIsStale =>
      compiled != null && compiled!.specHash != spec.contentHash();

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'spec': spec.toJson(),
    'transcript': transcript.map((TranscriptEntry e) => e.toJson()).toList(),
    'lastState': lastState?.toJson(),
    'producedArtifacts': producedArtifacts,
    'updatedAt': (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
  };

  static Project fromJson(Map<String, Object?> j) => Project(
    id: '${j['id']}',
    spec: MissionSpec.fromJson(j['spec']! as Map<String, Object?>),
    transcript: <TranscriptEntry>[
      for (final Object? e
          in (j['transcript'] as List<Object?>? ?? const <Object?>[]))
        TranscriptEntry.fromJson(e! as Map<String, Object?>),
    ],
    lastState: j['lastState'] == null
        ? null
        : MpState.fromJson(j['lastState']! as Map<String, Object?>),
    producedArtifacts: <String>[
      for (final Object? a
          in (j['producedArtifacts'] as List<Object?>? ?? const <Object?>[]))
        '$a',
    ],
    updatedAt: DateTime.tryParse('${j['updatedAt']}'),
  );
}

enum TranscriptDirection { sent, received }

/// One side of one exchange. Raw text is always kept, even when parsing failed,
/// so nothing the user copied is ever lost to a formatting accident.
class TranscriptEntry {
  const TranscriptEntry({
    required this.direction,
    required this.text,
    required this.at,
    this.stage,
    this.note,
  });

  final TranscriptDirection direction;
  final String text;
  final DateTime at;
  final String? stage;

  /// What the app made of it: what was applied, or why it could not be.
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
    'direction': direction.name,
    'text': text,
    'at': at.toIso8601String(),
    if (stage != null) 'stage': stage,
    if (note != null) 'note': note,
  };

  static TranscriptEntry fromJson(Map<String, Object?> j) => TranscriptEntry(
    direction: j['direction'] == 'sent'
        ? TranscriptDirection.sent
        : TranscriptDirection.received,
    text: '${j['text']}',
    at: DateTime.tryParse('${j['at']}') ?? DateTime.now().toUtc(),
    stage: j['stage'] as String?,
    note: j['note'] as String?,
  );
}
