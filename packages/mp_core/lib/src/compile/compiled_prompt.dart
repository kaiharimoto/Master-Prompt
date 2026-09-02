import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// Which execution surface a prompt was compiled for.
///
/// The same spec produces materially different prompts: the CLI variant
/// describes real tools, a working directory and autonomous execution, while
/// the paste variant describes a turn-by-turn conversation with no tool access
/// and mandates a state block on every reply.
enum TransportProfile {
  /// Driven by the Claude Code CLI on the desktop.
  cli,

  /// Copied into a chat app by hand and pasted back.
  paste,
}

/// A problem the compiler found while rendering. Warnings never block
/// compilation — the readiness gate is what blocks — but they surface in the UI
/// so the author can see what the agent will be missing.
@immutable
class CompileWarning {
  const CompileWarning(this.section, this.message);

  final String section;
  final String message;

  @override
  String toString() => '[$section] $message';
}

/// The rendered master prompt plus everything needed to navigate and verify it.
@immutable
class CompiledPrompt {
  CompiledPrompt({
    required this.body,
    required this.profile,
    required this.specHash,
    required this.compilerVersion,
    required this.sectionOffsets,
    this.warnings = const <CompileWarning>[],
  }) : hash = sha256
           .convert(utf8.encode('$compilerVersion|${profile.name}|$body'))
           .toString()
           .substring(0, 16);

  /// The prompt text itself.
  final String body;

  final TransportProfile profile;

  /// Content hash of the spec this was rendered from, so the UI can tell the
  /// user when their compiled prompt has gone stale.
  final String specHash;

  final String compilerVersion;

  /// Section heading to character offset, for jump-to navigation and for
  /// extracting a single section into a resume capsule without re-rendering.
  final Map<String, int> sectionOffsets;

  final List<CompileWarning> warnings;

  /// Content hash of the rendered prompt.
  final String hash;

  int get characterCount => body.length;

  /// Rough token estimate. Deliberately crude — it exists to warn about paste
  /// limits and context pressure, not to bill anyone. English prose through a
  /// BPE tokenizer lands near four characters per token; structured text with
  /// many short lines runs denser, so this rounds up.
  int get estimatedTokens => (body.length / 3.6).ceil();

  /// Extract one rendered section by heading, for capsule assembly.
  String? section(String heading) {
    final int? start = sectionOffsets[heading];
    if (start == null) return null;
    int end = body.length;
    for (final int offset in sectionOffsets.values) {
      if (offset > start && offset < end) end = offset;
    }
    return body.substring(start, end).trimRight();
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'hash': hash,
    'specHash': specHash,
    'profile': profile.name,
    'compilerVersion': compilerVersion,
    'sectionOffsets': sectionOffsets,
    'estimatedTokens': estimatedTokens,
    'body': body,
  };
}
