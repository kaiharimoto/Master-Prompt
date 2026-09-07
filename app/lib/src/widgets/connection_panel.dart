import 'package:flutter/material.dart';
import 'package:mp_design/mp_design.dart';
import 'package:mp_runner/mp_runner.dart';

import '../store/app_store.dart';
import '../store/desktop_runner.dart';

/// Whether the Claude Code CLI is connected, and what to do when it is not.
///
/// This used to be a blank text field in Settings hinting "Leave blank to
/// search PATH", with the probe running only once you reached the Run screen —
/// which is behind the overflow menu and refuses to appear until the brief
/// compiles. There was no way to ask the question directly, and a failure
/// printed one line.
class ConnectionPanel extends StatefulWidget {
  const ConnectionPanel({required this.store, required this.runner, super.key});

  final AppStore store;
  final DesktopRunner runner;

  @override
  State<ConnectionPanel> createState() => _ConnectionPanelState();
}

class _ConnectionPanelState extends State<ConnectionPanel> {
  late final TextEditingController _path = TextEditingController(
    text: widget.store.settings.claudePath ?? '',
  );

  @override
  void initState() {
    super.initState();
    // Answer the question before it is asked. Arriving at a panel titled
    // "Connection" that says nothing until you press something is the problem
    // this replaces.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.runner.install == null) {
        widget.runner.detect(widget.store.settings);
      }
    });
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    await widget.store.updateSettings(
      widget.store.settings.copyWith(claudePath: _path.text.trim()),
    );
    await widget.runner.detect(widget.store.settings);
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);

    if (!DesktopRunner.isSupported) {
      return MpPanel(
        child: Text(
          'The CLI runs on a desktop. On this device the mission travels by '
          'file and clipboard instead.',
          style: MpType.prose.copyWith(color: c.inkMuted),
        ),
      );
    }

    return ListenableBuilder(
      listenable: widget.runner,
      builder: (BuildContext context, _) {
        final DesktopRunner r = widget.runner;
        final ClaudeInstall? install = r.install;
        final bool searching = r.status == DesktopRunStatus.locating;
        final bool found = install != null;

        return MpPanel(
          accent: found ? c.success : (searching ? null : c.warning),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                searching
                    ? 'Looking for the CLI…'
                    : found
                    ? 'Connected'
                    : 'Not connected',
                style: MpType.title.copyWith(color: c.ink),
              ),
              const SizedBox(height: MpSpace.xs),
              Text(
                found
                    ? 'Claude Code ${install.version} · '
                          '${_auth(install.authMode)}'
                    : r.error ??
                          'The interview and the run both go through the CLI '
                              'on this machine.',
                style: MpType.prose.copyWith(color: found ? c.inkMuted : c.ink),
              ),
              if (found) ...<Widget>[
                const SizedBox(height: MpSpace.xs),
                Text(
                  install.path,
                  style: MpType.mono.copyWith(color: c.inkFaint),
                ),
              ],

              const SizedBox(height: MpSpace.md),
              MpField(
                label: 'CLI path',
                child: TextFormField(
                  controller: _path,
                  style: MpType.mono.copyWith(color: c.ink),
                  decoration: const InputDecoration(
                    hintText: 'Leave blank to search for it',
                  ),
                  onFieldSubmitted: (_) => _test(),
                ),
              ),
              const SizedBox(height: MpSpace.xs),
              Text(
                'A path set here is used on its own — if it does not work the '
                'search is not tried instead, so a wrong one is reported '
                'rather than quietly bypassed.',
                style: MpType.caption.copyWith(color: c.inkMuted),
              ),

              const SizedBox(height: MpSpace.md),
              MpButton(
                label: searching ? 'Testing…' : 'Test the connection',
                icon: Icons.cable,
                kind: MpButtonKind.primary,
                expand: true,
                onPressed: searching ? null : _test,
              ),

              if (r.attempts.isNotEmpty) ...<Widget>[
                const SizedBox(height: MpSpace.sm),
                MpDisclosure(
                  label: 'Where it looked',
                  trailingNote: '${r.attempts.length}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final ProbeAttempt a in r.attempts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: MpSpace.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                a.path,
                                style: MpType.mono.copyWith(color: c.ink),
                              ),
                              Text(
                                a.describe,
                                style: MpType.caption.copyWith(
                                  color: a.outcome == ProbeOutcome.found
                                      ? c.success
                                      : c.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _auth(ClaudeAuthMode mode) => switch (mode) {
    // Which credential is in use decides the limit policy, so it is worth
    // stating plainly rather than as an enum name.
    ClaudeAuthMode.subscription => 'signed in with a subscription',
    ClaudeAuthMode.apiKey => 'using an API key from the environment',
    ClaudeAuthMode.unknown => 'no credential detected yet',
  };
}
