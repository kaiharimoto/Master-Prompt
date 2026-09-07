import 'package:flutter/material.dart';
import 'package:mp_design/mp_design.dart';

import '../app.dart';

/// Shows a secondary panel the way the platform expects.
///
/// A modal bottom sheet is a phone gesture: you drag it up with a thumb from
/// the bottom edge, which is where the thumb already is. On a mouse-driven
/// window a metre from your face it is a panel that has slid in from off-screen
/// and has to be dismissed by aiming at the space above it. Progress, Missions
/// and Update were all sheets on both.
///
/// Keyed off the layout width rather than the platform, because this is a
/// question about the shape of the window — unlike anything to do with the CLI,
/// which is a question about the machine.
Future<void> present(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 640,
}) {
  final MpColors c = MpTheme.colorsOf(context);

  if (!isDesktop(context)) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surfaceRaised,
      showDragHandle: true,
      isScrollControlled: true,
      builder: builder,
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (BuildContext context) => Dialog(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(MpSpace.xl),
      shape: RoundedRectangleBorder(
        borderRadius: MpRadius.card,
        side: BorderSide(color: c.line),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          // Tall, but never so tall it has nowhere to sit on a short window.
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MpSpace.lg,
            MpSpace.lg,
            MpSpace.lg,
            MpSpace.md,
          ),
          child: builder(context),
        ),
      ),
    ),
  );
}
