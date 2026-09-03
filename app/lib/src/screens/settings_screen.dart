import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_design/mp_design.dart';

import '../store/app_store.dart';
import '../store/build_info.dart';
import '../store/diagnostics.dart';
import '../store/settings.dart';
import '../update/release.dart';
import '../update/updater.dart';
import 'update_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.store, required this.updater, super.key});

  final AppStore store;
  final Updater updater;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final AppSettings s = store.settings;

    return ListView(
      padding: const EdgeInsets.all(MpSpace.md),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: MpSpace.readingWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const MpSectionHeader(
                  number: '01',
                  title: 'Updates',
                  subtitle:
                      'Builds are checked at launch and installed from here, '
                      'so there is no reason to visit GitHub.',
                ),
                const SizedBox(height: MpSpace.md),
                _UpdatePanel(updater: updater),

                const SizedBox(height: MpSpace.xl),
                const MpSectionHeader(
                  number: '02',
                  title: 'The interview',
                  subtitle:
                      'How much each copied message carries, and how much of '
                      'it fits in one paste.',
                ),
                const SizedBox(height: MpSpace.md),
                MpPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MpField(
                        label: 'Paste size',
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const <ButtonSegment<int>>[
                            ButtonSegment<int>(
                              value: 4000,
                              label: Text('Small'),
                            ),
                            ButtonSegment<int>(
                              value: 8000,
                              label: Text('Standard'),
                            ),
                            ButtonSegment<int>(
                              value: 16000,
                              label: Text('Large'),
                            ),
                          ],
                          selected: <int>{s.pasteLimit},
                          onSelectionChanged: (Set<int> v) => store
                              .updateSettings(s.copyWith(pasteLimit: v.first)),
                        ),
                      ),
                      const SizedBox(height: MpSpace.xs),
                      Text(
                        'How much fits in one message in your chat app, in '
                        'characters: ${s.pasteLimit}. The brief and the '
                        'red-team pass are longer than this, so they are '
                        'copied in numbered parts. Raise it if your chat '
                        'takes more; lower it if a paste arrives cut off.',
                        style: MpType.caption.copyWith(color: c.inkMuted),
                      ),
                      const SizedBox(height: MpSpace.md),
                      const MpRule(),
                      const SizedBox(height: MpSpace.sm),
                    ],
                  ),
                ),
                const SizedBox(height: MpSpace.md),
                MpPanel(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: s.standaloneTurns,
                    onChanged: (bool v) =>
                        store.updateSettings(s.copyWith(standaloneTurns: v)),
                    title: Text(
                      'Every message stands alone',
                      style: MpType.body.copyWith(color: c.ink),
                    ),
                    subtitle: Text(
                      'Off by default: the interview is meant to run in one '
                      'continuing chat, which already holds the framing and '
                      'everything settled, so each round only carries what '
                      'that round adds. Turn this on if you start a fresh '
                      'chat every round.',
                      style: MpType.caption.copyWith(color: c.inkMuted),
                    ),
                  ),
                ),

                const SizedBox(height: MpSpace.xl),
                const MpSectionHeader(number: '03', title: 'Appearance'),
                const SizedBox(height: MpSpace.md),
                MpPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MpField(
                        label: 'Theme',
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const <ButtonSegment<ThemeMode>>[
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.system,
                              label: Text('System'),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.light,
                              label: Text('Light'),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                            ),
                          ],
                          selected: <ThemeMode>{s.themeMode},
                          onSelectionChanged: (Set<ThemeMode> v) => store
                              .updateSettings(s.copyWith(themeMode: v.first)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MpSpace.xl),
                const MpSectionHeader(
                  number: '04',
                  title: 'Model',
                  subtitle:
                      'The requested effort is degraded automatically if the '
                      'installed CLI does not accept it, rather than failing '
                      'the launch.',
                ),
                const SizedBox(height: MpSpace.md),
                MpPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MpField(
                        label: 'Model',
                        child: DropdownButtonFormField<String>(
                          initialValue: s.model,
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'claude-opus-5',
                              child: Text('Opus 5'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'claude-sonnet-5',
                              child: Text('Sonnet 5'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'claude-haiku-4-5',
                              child: Text('Haiku 4.5'),
                            ),
                          ],
                          onChanged: (String? v) => v == null
                              ? null
                              : store.updateSettings(s.copyWith(model: v)),
                        ),
                      ),
                      const SizedBox(height: MpSpace.md),
                      MpField(
                        label: 'Effort',
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'low',
                              label: Text('Low'),
                            ),
                            ButtonSegment<String>(
                              value: 'medium',
                              label: Text('Medium'),
                            ),
                            ButtonSegment<String>(
                              value: 'high',
                              label: Text('High'),
                            ),
                          ],
                          selected: <String>{s.effort},
                          onSelectionChanged: (Set<String> v) =>
                              store.updateSettings(s.copyWith(effort: v.first)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MpSpace.xl),
                const MpSectionHeader(
                  number: '05',
                  title: 'Desktop runner',
                  subtitle:
                      'Where the Claude Code CLI lives, and where it works.',
                ),
                const SizedBox(height: MpSpace.md),
                MpPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MpField(
                        label: 'CLI path',
                        child: TextFormField(
                          initialValue: s.claudePath ?? '',
                          style: MpType.mono.copyWith(color: c.ink),
                          decoration: const InputDecoration(
                            hintText: 'Leave blank to search PATH',
                          ),
                          onFieldSubmitted: (String v) => store.updateSettings(
                            s.copyWith(claudePath: v.trim()),
                          ),
                        ),
                      ),
                      const SizedBox(height: MpSpace.md),
                      MpField(
                        label: 'Working directory',
                        child: TextFormField(
                          initialValue: s.workingDirectory ?? '',
                          style: MpType.mono.copyWith(color: c.ink),
                          decoration: const InputDecoration(
                            hintText: r'C:\Projects\my-mission',
                          ),
                          onFieldSubmitted: (String v) => store.updateSettings(
                            s.copyWith(workingDirectory: v.trim()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MpSpace.xl),
                const MpSectionHeader(number: '06', title: 'Autonomy'),
                const SizedBox(height: MpSpace.md),
                MpPanel(
                  accent: s.permissionMode == 'bypassPermissions'
                      ? c.warning
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MpField(
                        label: 'Permission mode',
                        child: DropdownButtonFormField<String>(
                          initialValue: s.permissionMode,
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'bypassPermissions',
                              child: Text('Bypass — fully unattended'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'acceptEdits',
                              child: Text('Accept edits'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'dontAsk',
                              child: Text("Don't ask"),
                            ),
                            DropdownMenuItem<String>(
                              value: 'default',
                              child: Text('Ask every time'),
                            ),
                          ],
                          onChanged: (String? v) => v == null
                              ? null
                              : store.updateSettings(
                                  s.copyWith(permissionMode: v),
                                ),
                        ),
                      ),
                      if (s.permissionMode == 'bypassPermissions') ...<Widget>[
                        const SizedBox(height: MpSpace.sm),
                        Text(
                          'A run can do anything on this machine without '
                          'asking. Its working directory is pinned to the '
                          'project folder and every tool call is written to the '
                          'run transcript, but nothing else constrains it.',
                          style: MpType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                      const SizedBox(height: MpSpace.md),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: s.stepDownOnOpusLimit,
                        onChanged: (bool v) => store.updateSettings(
                          s.copyWith(stepDownOnOpusLimit: v),
                        ),
                        title: Text(
                          'Step down to Sonnet on an Opus limit',
                          style: MpType.body.copyWith(color: c.ink),
                        ),
                        subtitle: Text(
                          'Off by default: the standing policy is to wait for '
                          'the limit to lift rather than quietly change which '
                          'model does the work.',
                          style: MpType.caption.copyWith(color: c.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MpSpace.xl),
                const MpSectionHeader(
                  number: '07',
                  title: 'Report a problem',
                  subtitle:
                      'Copy this and paste it into the chat. It carries the '
                      'build, the mission state and the recent events, '
                      'including anything captured from a crash.',
                ),
                const SizedBox(height: MpSpace.md),
                _DiagnosticsPanel(store: store),
                const SizedBox(height: MpSpace.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticsPanel extends StatefulWidget {
  const _DiagnosticsPanel({required this.store});

  final AppStore store;

  @override
  State<_DiagnosticsPanel> createState() => _DiagnosticsPanelState();
}

class _DiagnosticsPanelState extends State<_DiagnosticsPanel> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    final bool crashed = Diagnostics.instance.hasCrash;

    return MpPanel(
      accent: crashed ? c.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MpField(
            label: 'This build',
            child: Text(
              BuildInfo.label,
              style: MpType.numeric.copyWith(color: c.ink),
            ),
          ),
          const SizedBox(height: MpSpace.xs),
          Text(
            '${BuildInfo.platform} · ${BuildInfo.osVersion}',
            style: MpType.caption.copyWith(color: c.inkFaint),
          ),
          if (!BuildInfo.isCiBuild) ...<Widget>[
            const SizedBox(height: MpSpace.xs),
            Text(
              'Built locally rather than by CI, so it has no build number.',
              style: MpType.caption.copyWith(color: c.inkFaint),
            ),
          ],
          if (crashed) ...<Widget>[
            const SizedBox(height: MpSpace.md),
            Text(
              'A crash was recorded and is included in the report below.',
              style: MpType.body.copyWith(color: c.danger),
            ),
          ],
          const SizedBox(height: MpSpace.md),
          Row(
            children: <Widget>[
              Expanded(
                child: MpButton(
                  label: _copied ? 'Copied' : 'Copy diagnostics',
                  icon: _copied ? Icons.check : Icons.content_copy,
                  kind: MpButtonKind.primary,
                  expand: true,
                  onPressed: () async {
                    final String text = Diagnostics.instance.report(
                      project: widget.store.current,
                      settings: widget.store.settings,
                    );
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    setState(() => _copied = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Diagnostics copied. Paste them in chat.',
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (crashed) ...<Widget>[
                const SizedBox(width: MpSpace.sm),
                MpButton(
                  label: 'Clear crash',
                  onPressed: () async {
                    await Diagnostics.instance.clearLastCrash();
                    if (context.mounted) setState(() {});
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The state of updating, in one line and one button.
///
/// Everything else about it lives in [UpdateSheet]; this only has to say
/// whether anything is waiting and open that.
class _UpdatePanel extends StatelessWidget {
  const _UpdatePanel({required this.updater});

  final Updater updater;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return ListenableBuilder(
      listenable: updater,
      builder: (BuildContext context, _) {
        final UpdateCheck? check = updater.check;
        final bool waiting = updater.hasUpdate;
        return MpPanel(
          accent: waiting ? c.warning : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MpField(
                label: waiting ? 'A newer build is waiting' : 'Latest build',
                child: Text(switch (check?.asset) {
                  final ReleaseAsset a => a.label(BuildInfo.version),
                  _ => updater.busy ? 'Checking…' : 'Not checked yet',
                }, style: MpType.numeric.copyWith(color: c.ink)),
              ),
              const SizedBox(height: MpSpace.xs),
              Text(
                check?.detail ?? 'Opens the check when you ask for it.',
                style: MpType.caption.copyWith(color: c.inkFaint),
              ),
              const SizedBox(height: MpSpace.md),
              MpButton(
                label: waiting ? 'Install the update' : 'Check for updates',
                icon: waiting ? Icons.system_update_alt : Icons.refresh,
                kind: waiting ? MpButtonKind.primary : MpButtonKind.secondary,
                expand: true,
                onPressed: () => UpdateSheet.show(context, updater),
              ),
            ],
          ),
        );
      },
    );
  }
}
