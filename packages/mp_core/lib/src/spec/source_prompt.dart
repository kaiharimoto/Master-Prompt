import 'package:meta/meta.dart';

/// A prompt the user already had, which this mission was started from.
///
/// Starting from a prompt is a different interview, not a shortcut through
/// the same one. The first round reads the prompt against everything an
/// unattended run needs and takes what it already settles; every round after
/// that asks about what it leaves open, grounded in what it actually says. So
/// the text stays with the mission for as long as the mission does: a fresh
/// chat started halfway through has to be shown it again, or its questions
/// are about a prompt it has never seen.
@immutable
class SourcePrompt {
  const SourcePrompt({required this.text, this.read = false});

  /// The prompt exactly as it was pasted. Never rewritten — it is the
  /// evidence of what the author wanted, and the brief is the improved copy.
  final String text;

  /// Whether the reading round has been accepted.
  ///
  /// Until it has, the next turn is that round and nothing else. Held on the
  /// spec rather than on the screen because it decides which turn comes next,
  /// and everything that decides that is derived from the spec.
  final bool read;

  SourcePrompt markRead() => SourcePrompt(text: text, read: true);

  Map<String, Object?> toJson() => <String, Object?>{
    'text': text,
    'read': read,
  };

  static SourcePrompt? fromJson(Object? j) {
    if (j is! Map) return null;
    final Object? text = j['text'];
    if (text is! String || text.trim().isEmpty) return null;
    return SourcePrompt(text: text, read: j['read'] == true);
  }

  @override
  bool operator ==(Object other) =>
      other is SourcePrompt && other.text == text && other.read == read;

  @override
  int get hashCode => Object.hash(text, read);
}
