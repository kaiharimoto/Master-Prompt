import 'package:meta/meta.dart';

import '../spec/mission_spec.dart';
import '../spec/spec_field.dart';

/// A pitch prompt from Master Idea, read as the opening of a mission.
///
/// Master Idea is the other half of this pair: it takes one raw idea, argues
/// with itself unattended, and hands back the directions its client selected
/// together with what they become combined. Its export is prose — deliberately
/// portable, so it works in front of any model — with a small line-oriented
/// block at the end for the case where the reader is this program.
///
/// The block is line-oriented rather than JSON for the reason the `mpstate`
/// heartbeat is: a document that exceeds a chat's paste ceiling is cut without
/// warning, and losing one field is recoverable where losing the whole object
/// is not.
///
/// **Everything it carries arrives `proposed`.** Nothing about this import may
/// satisfy the readiness gate on its own. The council that wrote those
/// sentences is a model, however carefully its client chose which directions
/// to keep, and a value nobody in *this* conversation has accepted is exactly
/// what the proposed/confirmed distinction exists to hold back from an
/// unattended run.
@immutable
class IdeaPitch {
  const IdeaPitch({
    required this.document,
    required this.sessionId,
    required this.taskId,
    required this.title,
    required this.medium,
    required this.tier,
    required this.mission,
    required this.story,
    required this.scale,
    required this.audience,
    required this.directionIds,
  });

  /// The whole pitch, exactly as it arrived. Kept because the block is a
  /// summary and the prose is the thing: the reasoning, the integration and
  /// the marked assumptions all live in the document, and an import that threw
  /// them away would leave the mission starting from four sentences.
  final String document;

  /// The Master Idea session this came from, so a mission can be traced back
  /// to the deliberation that produced it.
  final String sessionId;

  final String taskId;
  final String title;

  /// Master Idea's domain profile — `essay`, `song`, `software` and so on.
  final String medium;

  /// Which harness tier that session ran at.
  final String tier;

  final String mission;
  final String story;
  final String scale;
  final String audience;

  /// The directions the client selected. Ids into the source session; kept so
  /// the mission can name what it was built from.
  final List<String> directionIds;

  static const String fence = 'mi-pitch';

  /// Read a pitch, or return null if this is not one.
  ///
  /// Returning null rather than throwing, because this runs as a fallback: a
  /// paste that is not a mission bundle is tried as a pitch, and 'not a pitch
  /// either' has to be an ordinary answer rather than an exception the caller
  /// must catch to get a sensible message.
  static IdeaPitch? read(String text) {
    final List<String> lines = text.split('\n');
    final int start = lines.indexWhere(
      (String l) => l.trim() == '```$fence' || l.trim() == fence,
    );
    if (start < 0) return null;

    final Map<String, String> f = <String, String>{};
    for (final String line in lines.skip(start + 1)) {
      final String trimmed = line.trim();
      if (trimmed == '```') break;
      final int eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      f[trimmed.substring(0, eq).trim()] = trimmed.substring(eq + 1).trim();
    }
    // A block with no version is a block from a future that changed the
    // grammar, or a coincidence. Neither should be read as a pitch.
    if (f['v'] != '1') return null;

    return IdeaPitch(
      document: text,
      sessionId: f['session'] ?? '',
      taskId: f['task'] ?? '',
      title: f['title'] ?? '',
      medium: f['medium'] ?? '',
      tier: f['tier'] ?? '',
      mission: f['mission'] ?? '',
      story: f['story'] ?? '',
      scale: f['scale'] ?? '',
      audience: f['audience'] ?? '',
      directionIds: (f['directions'] ?? '')
          .split(RegExp(r'\s+'))
          .where((String s) => s.isNotEmpty)
          .toList(),
    );
  }

  /// Whether there is enough here to open a mission at all.
  bool get isUsable => mission.trim().isNotEmpty;

  /// Fill a fresh spec from this pitch.
  ///
  /// Only fields the pitch actually carries are touched, and every one of them
  /// lands proposed. The interview then confirms them the same way it confirms
  /// anything else — which means an imported mission goes through the same
  /// gate as a typed one, and nothing arrives already settled because it came
  /// from a program rather than a person.
  MissionSpec seed(MissionSpec base, {DateTime? at}) {
    SpecField<String> propose(SpecField<String> field, String value) =>
        value.trim().isEmpty ? field : field.propose(value.trim(), at: at);

    return base.copyWith(
      title: title.trim().isEmpty ? base.title : title.trim(),
      missionStatement: propose(base.missionStatement, mission),
      definingStory: propose(base.definingStory, story),
      scale: propose(base.scale, scale),
      audience: propose(base.audience, audience),
      updatedAt: at,
    );
  }

  /// What to say about where this mission came from, for the transcript.
  String get provenance =>
      'Opened from a Master Idea pitch — session $sessionId, '
      '${directionIds.length} selected direction(s), $medium at the $tier '
      'tier. The whole pitch is below; its values are proposed and still have '
      'to be accepted.';
}
