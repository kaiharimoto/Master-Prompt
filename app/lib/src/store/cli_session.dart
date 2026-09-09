import 'dart:io';

import 'package:mp_runner/mp_runner.dart';
import 'package:path_provider/path_provider.dart';

import 'settings.dart';

/// How this app opens a conversation with the CLI. One place, on purpose.
///
/// Two screens now talk to Claude Code — the interview and the red-team pass —
/// and a second copy of this would be free to disagree with the first about
/// the three things below, every one of which was decided the hard way:
///
/// **A turn runs in a directory of its own**, not the mission's working
/// directory, so a `CLAUDE.md` in the project the mission is *about* does not
/// join the conversation uninvited. Each caller names its own, because the
/// review and the interview are different conversations.
///
/// **The permission mode is never the user's run setting.** `CliConversation`
/// pins `default` itself: `bypassPermissions` exists so an unattended build
/// need not stop to ask, and a question about what to build needs no tools at
/// all.
///
/// **Effort degrades downward.** A ladder that put `high` after the chosen
/// level would upgrade a turn someone had set to `low`.
Future<CliConversation> openConversation({
  required ClaudeInstall install,
  required AppSettings settings,
  required String named,
}) async {
  final Directory support = await getApplicationSupportDirectory();
  final Directory dir = Directory(
    '${support.path}${Platform.pathSeparator}$named',
  );
  if (!dir.existsSync()) dir.createSync(recursive: true);

  return CliConversation(
    executable: install.path,
    capabilities: install.capabilities,
    workingDirectory: dir.path,
    // Empty means no --model at all, leaving the CLI on whatever the user
    // chose with /model. The flag refuses anything that is not an alias or a
    // full dated name, and it enumerates no choices, so the capability probe
    // cannot catch a bad one before it fails the turn.
    model: settings.model.trim().isEmpty ? null : settings.model.trim(),
    effortPreference: effortLadder(settings.effort),
  );
}
