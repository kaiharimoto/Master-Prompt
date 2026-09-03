import 'package:meta/meta.dart';

/// One pastable message.
@immutable
class HandoverPart {
  const HandoverPart({
    required this.index,
    required this.of,
    required this.text,
  });

  /// 1-based, as shown to the user.
  final int index;
  final int of;

  /// Header and content together, ready for the clipboard.
  final String text;

  bool get isLast => index == of;
  bool get isOnly => of == 1;
  int get estimatedTokens => (text.length / 3.6).ceil();
}

/// A message, the file it can travel as, and the parts it falls back to.
///
/// The two halves matter because they leave by different routes. A chat input
/// has a length limit; an attachment does not. So the short covering
/// instruction goes in the message and the long artifact goes in the file, and
/// the whole handover becomes one gesture instead of eight.
@immutable
class Handover {
  const Handover({
    required this.parts,
    required this.sourceLength,
    this.note = '',
    this.document = '',
    this.fileName = 'handover.md',
  });

  /// The covering message: what to do with the attachment. Short by
  /// construction — the red-team instruction is about 1,500 characters.
  final String note;

  /// The artifact itself, which becomes the attached file.
  final String document;

  /// What the attachment is called. Carries the task id so an attachment in a
  /// chat is identifiable weeks later.
  final String fileName;

  /// [note] and [document] together, cut into pastable pieces. The fallback
  /// for when nothing on the device will take a file.
  final List<HandoverPart> parts;

  /// Length of the original text, before any headers were added.
  final int sourceLength;

  bool get isSplit => parts.length > 1;
  int get count => parts.length;

  /// The whole thing, for the case where it fits.
  HandoverPart get only => parts.first;

  /// What goes on the clipboard or in a file when it is sent in one piece.
  String get whole => note.isEmpty
      ? document
      : document.isEmpty
      ? note
      : '$note\n\n$document';
}

/// Cuts a message into parts small enough to survive a chat's input field.
///
/// The compiled brief for a real mission is around twenty thousand characters
/// and the red-team pass is longer still, because it carries the brief inside
/// it. Pasted into a phone chat app, a message that size is silently cut off —
/// and a truncated brief is worse than no brief, because the run starts anyway
/// and nothing says which half arrived.
///
/// Splitting is only safe if the seams fall where the document already has
/// them, so cuts are made at a section heading if one is in reach, then a
/// paragraph break, then a line ending, and only as a last resort mid-line. A
/// fenced block is never cut through: the brief carries the `mpstate`
/// heartbeat template as one, and half a template is an instruction the agent
/// would follow wrongly rather than fail on.
class HandoverSplitter {
  const HandoverSplitter({this.limit = defaultLimit});

  /// Characters per part, headers included.
  ///
  /// Deliberately conservative. The real ceiling belongs to the chat app and
  /// is not documented anywhere we can read, so this is set well under the
  /// size that was observed being cut off, and is adjustable in settings by
  /// the only person who can actually measure it.
  final int limit;

  static const int defaultLimit = 8000;

  /// Enough for the longest header this class writes, with room for a part
  /// count in the hundreds. Asserted by test rather than trusted.
  static const int headerBudget = 320;

  /// Plans a handover of [document], introduced by [note].
  ///
  /// [note] belongs in the chat message and [document] in the attachment, but
  /// the parts this returns are the two concatenated and then cut — the copy
  /// fallback has no attachment to put anything in.
  Handover plan(
    String document, {
    String note = '',
    String fileName = 'handover.md',
  }) {
    final String doc = document.trimRight();
    final String head = note.trim();
    final String text = head.isEmpty
        ? doc
        : doc.isEmpty
        ? head
        : '$head\n\n$doc';

    Handover whole() => Handover(
      parts: <HandoverPart>[HandoverPart(index: 1, of: 1, text: text)],
      sourceLength: text.length,
      note: head,
      document: doc,
      fileName: safeFileName(fileName),
    );

    if (text.length <= limit) return whole();

    final int room = limit - headerBudget;
    // A limit this small cannot carry a header and content both. Rather than
    // emit parts that are all header, send it whole and let the user see it
    // is oversized.
    if (room <= 0) return whole();

    final List<_Fence> fences = _fences(text);
    final List<String> chunks = <String>[];
    int start = 0;
    while (start < text.length) {
      if (text.length - start <= room) {
        chunks.add(text.substring(start));
        break;
      }
      final int cut = _breakAt(text, start, start + room, fences);
      chunks.add(text.substring(start, cut));
      start = cut;
    }

    // A cut that had to land inside a fenced block leaves it open. Close it
    // and reopen it with the same info string, so each part is valid on its
    // own rather than turning the rest of the document into code.
    int at = 0;
    for (int i = 0; i < chunks.length; i++) {
      final int end = at + chunks[i].length;
      final _Fence? open = _fenceAround(fences, end);
      if (open != null && i + 1 < chunks.length) {
        chunks[i] = '${chunks[i]}\n```';
        chunks[i + 1] = '```${open.info}\n${chunks[i + 1]}';
      }
      at = end;
    }

    final int n = chunks.length;
    return Handover(
      parts: <HandoverPart>[
        for (int i = 0; i < n; i++)
          HandoverPart(
            index: i + 1,
            of: n,
            text: '${_header(i + 1, n)}${chunks[i].trimLeft()}',
          ),
      ],
      sourceLength: text.length,
      note: head,
      document: doc,
      fileName: safeFileName(fileName),
    );
  }

  /// Makes a name a filesystem and content-provider will both accept.
  ///
  /// Task ids come from the interview and are whatever the user typed, so they
  /// can carry spaces, slashes and quotes. A slash in particular would be read
  /// as a path and write the attachment somewhere unintended.
  static String safeFileName(String name) {
    final String cleaned = name
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^[-.]+'), '');
    if (cleaned.isEmpty) return 'handover.md';
    return cleaned.length > 96
        ? cleaned.substring(cleaned.length - 96)
        : cleaned;
  }

  /// What each part says about itself.
  ///
  /// The instruction to hold off is the load-bearing part. Without it the
  /// model starts answering the first third of a brief, and by the time the
  /// rest arrives it has already committed to a reading of it.
  static String _header(int i, int n) {
    if (n == 1) return '';
    if (i == 1) {
      return '**Part 1 of $n.** This is too long to send in one message, so it '
          'comes in $n parts. Do not act on it yet, and do not summarise it — '
          'reply with just `ok`. I will say when it is complete.\n\n---\n\n';
    }
    if (i < n) {
      return '**Part $i of $n.** Still sending. Reply with just '
          '`ok`.\n\n---\n\n';
    }
    return '**Part $n of $n — this is the end of it.** That is the whole '
        'document. Go ahead and do what it asks.\n\n---\n\n';
  }

  /// The best place to cut between [start] and [ceiling].
  ///
  /// Searched backwards from the ceiling so each part is as full as it can be:
  /// more parts means more pastes, and every extra paste is a chance to lose
  /// one.
  static int _breakAt(
    String text,
    int start,
    int ceiling,
    List<_Fence> fences,
  ) {
    final String window = text.substring(start, ceiling);

    // A section heading, so a part begins where the document does.
    for (final RegExpMatch m in _heading.allMatches(window).toList().reversed) {
      final int at = start + m.start + 1;
      if (at > start && _fenceAround(fences, at) == null) return at;
    }
    // A paragraph break.
    int i = window.lastIndexOf('\n\n');
    while (i > 0) {
      final int at = start + i + 2;
      if (_fenceAround(fences, at) == null) return at;
      i = window.lastIndexOf('\n\n', i - 1);
    }
    // Any line ending, including one inside a fence — a fence longer than a
    // whole part has to be cut somewhere, and the reopen above repairs it.
    i = window.lastIndexOf('\n');
    if (i > 0) return start + i + 1;

    // One line longer than a part. Nothing to do but cut it.
    return ceiling;
  }

  /// Matches a blank line followed by a markdown heading.
  static final RegExp _heading = RegExp(r'\n(#{1,3} )', multiLine: true);

  static _Fence? _fenceAround(List<_Fence> fences, int at) {
    for (final _Fence f in fences) {
      if (at > f.start && at < f.end) return f;
    }
    return null;
  }

  /// Fenced blocks, as half-open spans over [text].
  static List<_Fence> _fences(String text) {
    final List<_Fence> out = <_Fence>[];
    int? openAt;
    String info = '';
    int offset = 0;
    for (final String line in text.split('\n')) {
      if (line.startsWith('```')) {
        if (openAt == null) {
          openAt = offset;
          info = line.substring(3).trim();
        } else {
          out.add(_Fence(openAt, offset + line.length, info));
          openAt = null;
          info = '';
        }
      }
      offset += line.length + 1;
    }
    // An unterminated fence still owns the rest of the document.
    if (openAt != null) out.add(_Fence(openAt, text.length, info));
    return out;
  }
}

@immutable
class _Fence {
  const _Fence(this.start, this.end, this.info);
  final int start;
  final int end;
  final String info;
}
