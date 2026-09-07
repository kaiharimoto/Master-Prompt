import 'dart:io';
import 'dart:math';

/// Generates the session ids the CLI is given with `--session-id`.
///
/// This exists as one function, in one file, because the alternative was tried
/// and it failed. There were two generators twenty lines apart in this package:
/// the supervisor's was correct and the conversation's built `8-5-4-4-12`,
/// because `microsecondsSinceEpoch` is thirteen hex digits and the code assumed
/// twelve. The CLI rejects that outright — *"invalid session ID. Must be a
/// valid UUID"* — so the desktop interview failed on its first turn on every
/// machine, while nine tests passed.
///
/// They passed because every one of them injected a fixed id instead of calling
/// the generator, and the id they injected was not a UUID either. The tests
/// proved the value was plumbed through correctly and never once asked whether
/// it was valid.
String newSessionId() {
  final List<int> b = List<int>.generate(16, (_) => _random.nextInt(256));

  // Version 4 in the high nibble of byte 6, variant 10xx in byte 8. Without
  // these it is sixteen random bytes wearing a UUID's punctuation, and a strict
  // parser is entitled to refuse it.
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;

  final String hex = b
      .map((int x) => x.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// What a valid id looks like, so a test can assert the contract rather than
/// re-derive the implementation. Also used by `tool/fake_claude.dart`, which
/// refuses anything else exactly as the real binary does.
final RegExp sessionIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// True for a candidate Windows cannot start directly.
///
/// `CreateProcess` refuses a `.cmd` or `.bat`, which is how an npm install of
/// Claude Code — `%APPDATA%\npm\claude.cmd` — was reported as simply not found.
/// A shell is the only way to run one, and using one anywhere else would change
/// quoting for no reason.
///
/// Here rather than on either caller because there were two copies of this too,
/// and the run path was missing it entirely.
bool needsShell(String path) {
  if (!Platform.isWindows) return false;
  final String lower = path.toLowerCase();
  return lower.endsWith('.cmd') || lower.endsWith('.bat');
}

final Random _random = _secureOrNot();

Random _secureOrNot() {
  try {
    return Random.secure();
  } on UnsupportedError {
    // No platform entropy source. Ids only have to be unique, not secret, so
    // degrading is better than refusing to open a session at all.
    return Random(DateTime.now().microsecondsSinceEpoch);
  }
}
