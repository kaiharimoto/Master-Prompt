import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mp_core/mp_core.dart';
import 'package:path_provider/path_provider.dart';

/// What became of an attempt to hand a document over.
enum SendOutcome {
  /// The share sheet opened. What the user picks from it is their business.
  shared,

  /// Written to wherever the user chose.
  saved,

  /// The user backed out of the picker. An ordinary outcome, not a failure.
  cancelled,

  /// Nothing on this platform can do it.
  unsupported,

  /// It should have worked and did not.
  failed,
}

/// Everything about sending a document that touches the world outside Dart.
abstract interface class HandoverTransport {
  /// Where documents are staged before being handed out.
  Future<Directory> workspace();

  /// True where the share sheet exists at all.
  bool get canShare;

  /// Offers [file] to the share sheet with [text] as the message beside it.
  Future<bool> share(File file, String text);

  /// Copies [file] to somewhere the user picks, or to a known folder on a
  /// desktop. False when they cancelled.
  Future<bool> save(File file, String name);
}

/// Gets a long document into a chat without pasting it.
///
/// The compiled brief is around twenty thousand characters and a phone chat
/// input will not take it, so it was arriving as four pasted fragments — and
/// with the red-team pass right behind it, eight round trips through the app
/// switcher. A file has no such limit. So the artifact leaves as an attachment
/// and only the covering instruction goes in the message.
class HandoverSender {
  HandoverSender({HandoverTransport? transport})
    : _transport = transport ?? const _RealTransport();

  final HandoverTransport _transport;

  bool get canShare => _transport.canShare;

  /// Opens the share sheet with the document attached.
  Future<SendOutcome> share(Handover h) async {
    if (!_transport.canShare) return SendOutcome.unsupported;
    try {
      final File f = await _write(h);
      return await _transport.share(f, h.note)
          ? SendOutcome.shared
          : SendOutcome.failed;
    } catch (_) {
      return SendOutcome.failed;
    }
  }

  /// Writes the document out for the user to attach themselves.
  Future<SendOutcome> save(Handover h) async {
    try {
      final File f = await _write(h);
      return await _transport.save(f, h.fileName)
          ? SendOutcome.saved
          : SendOutcome.cancelled;
    } catch (_) {
      return SendOutcome.failed;
    }
  }

  /// Stages the file.
  ///
  /// It carries the covering note as well as the document, even though sharing
  /// also puts the note in the message. Saving does not: a file the user
  /// attaches by hand has to be sufficient on its own, or the instruction is
  /// nowhere and they have to type it out.
  Future<File> _write(Handover h) async {
    final Directory dir = await _transport.workspace();
    final File f = File('${dir.path}${Platform.pathSeparator}${h.fileName}');
    await f.parent.create(recursive: true);
    await f.writeAsString(h.whole, flush: true);
    return f;
  }
}

class _RealTransport implements HandoverTransport {
  const _RealTransport();

  static const MethodChannel _channel = MethodChannel('masterprompt/platform');

  @override
  bool get canShare => Platform.isAndroid;

  @override
  Future<Directory> workspace() async {
    final Directory base = await getTemporaryDirectory();
    final Directory dir = Directory(
      '${base.path}${Platform.pathSeparator}handover',
    );
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<bool> share(File file, String text) async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('share', <String, Object?>{
          'path': file.path,
          'text': text,
        }) ??
        false;
  }

  @override
  Future<bool> save(File file, String name) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod<bool>('save', <String, Object?>{
            'path': file.path,
            'name': name,
          }) ??
          false;
    }

    // A desktop has no picker to offer from here and no paste limit to work
    // around either, so the file simply lands in Downloads and Explorer is
    // pointed at it.
    final Directory? downloads = await getDownloadsDirectory();
    if (downloads == null) return false;
    final File out = File('${downloads.path}${Platform.pathSeparator}$name');
    await out.writeAsString(await file.readAsString(), flush: true);
    if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', <String>['/select,${out.path}']);
      } catch (_) {
        // Revealing it is a courtesy; the file is written either way.
      }
    }
    return true;
  }
}
