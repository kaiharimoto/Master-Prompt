import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sends on Ctrl+Enter, leaving Enter to insert a newline.
///
/// Every multi-line field in this app is somewhere you write a paragraph and
/// then send it, and until now there was no key that sent it — the desktop
/// chat's follow-up box could only be submitted with the mouse, after every
/// single turn. Enter cannot be the send key, because these are genuinely
/// multi-line: `maxLines != 1` makes Flutter route Enter to a newline and never
/// call `onSubmitted`, which is why the seed field's submit handler had been
/// dead code since it was written.
///
/// Cmd+Enter too, for a Mac, and the numpad's Enter, which is a different key
/// code and is the one on the right-hand side of most keyboards.
class MpSubmit extends StatelessWidget {
  const MpSubmit({required this.child, required this.onSubmit, super.key});

  final Widget child;

  /// Null disables the shortcut, so a busy screen cannot be double-sent from
  /// the keyboard while its button is correctly disabled.
  final VoidCallback? onSubmit;

  /// What to tell the user, once, near the field.
  static String hintFor(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.macOS ? '⌘↵' : 'Ctrl+Enter';

  @override
  Widget build(BuildContext context) {
    final VoidCallback? send = onSubmit;
    if (send == null) return child;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true): send,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): send,
        const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
            send,
        const SingleActivator(LogicalKeyboardKey.numpadEnter, meta: true): send,
      },
      child: child,
    );
  }
}

/// Escape backs out of a pushed screen, the way it does everywhere else on a
/// desktop. Flutter gives routes no Escape handling of their own.
///
/// It takes focus so that keys reach it before anything has been clicked, so
/// do not wrap a screen whose own field is autofocused — the two would fight
/// over which one the caret lands in.
class MpEscape extends StatelessWidget {
  const MpEscape({required this.child, this.onEscape, super.key});

  final Widget child;

  /// Defaults to popping the enclosing route.
  final VoidCallback? onEscape;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape):
            onEscape ?? () => Navigator.of(context).maybePop(),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
