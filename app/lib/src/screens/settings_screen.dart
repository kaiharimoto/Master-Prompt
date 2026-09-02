import 'package:flutter/material.dart';
import 'package:mp_design/mp_design.dart';

import '../store/app_store.dart';
import '../store/settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.store, super.key});

  final AppStore store;

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
                const MpSectionHeader(number: '01', title: 'Appearance'),
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
                  number: '02',
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
                  number: '03',
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
                const MpSectionHeader(number: '04', title: 'Autonomy'),
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
                const SizedBox(height: MpSpace.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
