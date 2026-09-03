import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_design/mp_design.dart';

import '../store/build_info.dart';
import '../update/release.dart';
import '../update/updater.dart';

/// Updating, as one subject with one button.
///
/// The whole point of this screen is that nobody should have to visit GitHub,
/// work out which of several files is newest, and download it by hand. So it
/// never shows more than one action at a time: check, then download, then
/// install, and the label says which one you are on.
class UpdateSheet extends StatefulWidget {
  const UpdateSheet({required this.updater, super.key});

  final Updater updater;

  static Future<void> show(BuildContext context, Updater updater) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: MpTheme.colorsOf(context).surfaceRaised,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => UpdateSheet(updater: updater),
    );
  }

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  @override
  void initState() {
    super.initState();
    // Opened cold — for instance straight from Settings — there is nothing to
    // show yet, so start the check rather than making the user ask twice.
    if (widget.updater.check == null && !widget.updater.busy) {
      widget.updater.runCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.updater,
      builder: (BuildContext context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final Updater u = widget.updater;
    final UpdateCheck? check = u.check;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MpSpace.lg,
          0,
          MpSpace.lg,
          MpSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('UPDATE', style: MpType.eyebrow.copyWith(color: c.inkFaint)),
            const SizedBox(height: MpSpace.md),
            Text(_headline, style: MpType.display.copyWith(color: c.ink)),
            const SizedBox(height: MpSpace.sm),
            Text(_supporting, style: MpType.prose.copyWith(color: c.inkMuted)),
            if (u.phase == UpdatePhase.downloading) ...<Widget>[
              const SizedBox(height: MpSpace.lg),
              MpMeter(value: u.progress < 0 ? 0 : u.progress),
            ],
            if (u.error != null) ...<Widget>[
              const SizedBox(height: MpSpace.md),
              Text(u.error!, style: MpType.body.copyWith(color: c.danger)),
            ],
            if (u.handoff != null) ...<Widget>[
              const SizedBox(height: MpSpace.md),
              Text(u.handoff!, style: MpType.body.copyWith(color: c.warning)),
            ],
            const SizedBox(height: MpSpace.xl),
            MpButton(
              label: _action.label,
              icon: _action.icon,
              kind: MpButtonKind.primary,
              expand: true,
              onPressed: _action.onPressed,
            ),
            const SizedBox(height: MpSpace.sm),
            MpButton(
              label: 'Copy the release link',
              icon: Icons.link,
              kind: MpButtonKind.quiet,
              expand: true,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        check?.releaseUrl?.toString() ?? BuildInfo.releasePage,
                  ),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Release link copied.')),
                );
              },
            ),
            const SizedBox(height: MpSpace.md),
            Text(
              'Installed: ${BuildInfo.label}',
              style: MpType.caption.copyWith(color: c.inkFaint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String get _headline {
    final Updater u = widget.updater;
    switch (u.phase) {
      case UpdatePhase.checking:
        return 'Checking…';
      case UpdatePhase.downloading:
        return 'Downloading';
      case UpdatePhase.installing:
        return 'Handing it over…';
      case UpdatePhase.downloaded:
        return 'Ready to install';
      case UpdatePhase.idle:
      case UpdatePhase.ready:
        break;
    }
    final UpdateCheck? check = u.check;
    if (check == null) return 'Updates';
    return switch (check.outcome) {
      UpdateOutcome.available => 'Build ${check.asset?.build} is waiting',
      UpdateOutcome.upToDate => 'Up to date',
      UpdateOutcome.noAsset => 'Nothing to install',
      UpdateOutcome.unknownBuild => 'Built locally',
      UpdateOutcome.unreadable => 'Could not check',
    };
  }

  String get _supporting {
    final Updater u = widget.updater;
    if (u.phase == UpdatePhase.downloading) {
      return u.progress < 0
          ? 'Size unknown, so there is no bar to fill.'
          : '${(u.progress * 100).round()}% of '
                '${u.check?.asset?.size ?? ''}';
    }
    if (u.phase == UpdatePhase.downloaded) {
      return u.platform == UpdatePlatform.android
          ? 'Android will ask you to confirm. Your saved missions are kept — '
                'every build is signed with the same key.'
          : 'Extract it over your existing folder once the app is closed.';
    }
    return u.check?.detail ?? 'Looking for a newer build.';
  }

  _Action get _action {
    final Updater u = widget.updater;
    if (u.busy) {
      return _Action(
        label: u.phase == UpdatePhase.downloading
            ? 'Downloading'
            : u.phase == UpdatePhase.installing
            ? 'Working'
            : 'Checking',
        onPressed: null,
      );
    }
    if (u.phase == UpdatePhase.downloaded) {
      return _Action(
        label: 'Install',
        icon: Icons.download_done,
        onPressed: u.install,
      );
    }
    final UpdateCheck? check = u.check;
    if (check != null && check.isUpdate) {
      final String size = check.asset!.size;
      return _Action(
        label: size.isEmpty ? 'Download' : 'Download $size',
        icon: Icons.download,
        onPressed: u.download,
      );
    }
    return _Action(
      label: 'Check again',
      icon: Icons.refresh,
      onPressed: () {
        u.clearError();
        u.runCheck();
      },
    );
  }
}

class _Action {
  const _Action({required this.label, this.icon, this.onPressed});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
}
