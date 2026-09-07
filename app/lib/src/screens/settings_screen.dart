import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mp_design/mp_design.dart';

import '../store/app_store.dart';
import '../store/build_info.dart';
import '../store/diagnostics.dart';
import '../store/settings.dart';
import '../store/desktop_runner.dart';
import '../update/release.dart';
import '../update/updater.dart';
import '../widgets/connection_panel.dart';
import 'update_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.store,
    required this.updater,
    required this.runner,
    super.key,
  });

  final AppStore store;
  final Updater updater;

  /// Shared with the Run screen so a connection tested here is the one a run
  /// uses, rather than two probes disagreeing.
  final DesktopRunner runner;

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
                  child: _SettingSwitch(
                    value: s.standaloneTurns,
                    onChanged: (bool v) =>
                        store.updateSettings(s.copyWith(standaloneTurns: v)),
                    title: 'Every message stands alone',
                    detail:
                        'Off by default: the interview is meant to run in one '
                        'continuing chat, which already holds the framing and '
                        'everything settled, so each round only carries what '
                        'that round adds. Turn this on if you start a fresh '
                        'chat every round.',
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
                      'Leave the model alone unless you want to override it. '
                      'Effort is degraded automatically if the installed CLI '
                      'does not accept it, rather than failing the launch.',
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
                            // Aliases, not versioned names. `--model` takes an
                            // alias or a full dated name and refuses anything
                            // else, and it enumerates no choices in --help so
                            // the capability probe cannot catch a bad one. An
                            // alias also stays correct when a new model ships.
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text('Whatever the CLI is set to'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'opus',
                              child: Text('Opus'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'sonnet',
                              child: Text('Sonnet'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'haiku',
                              child: Text('Haiku'),
                            ),
                          ],
                          onChanged: (String? v) => v == null
                              ? null
                              : store.updateSettings(s.copyWith(model: v)),
                        ),
                      ),
                      const SizedBox(height: MpSpace.xs),
                      Text(
                        s.model.isEmpty
                            ? 'No --model flag is sent, so Claude Code stays on '
                                  'whatever you last chose with /model.'
                            : 'Every turn and every run asks for ${s.model}.',
                        style: MpType.caption.copyWith(color: c.inkMuted),
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
                  title: 'Claude Code',
                  subtitle:
                      'On a desktop the interview and the run both go through '
                      'the CLI, so there is nothing to copy or paste.',
                ),
                const SizedBox(height: MpSpace.md),
                ConnectionPanel(store: store, runner: runner),
                const SizedBox(height: MpSpace.md),
                MpPanel(
                  child: MpField(
                    label: 'Working directory',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _PathField(
                          initial: s.workingDirectory ?? '',
                          hint: 'Leave blank for a folder per mission',
                          onSettled: (String v) => store.updateSettings(
                            s.copyWith(workingDirectory: v),
                          ),
                        ),
                        const SizedBox(height: MpSpace.xs),
                        Text(
                          'Where a run works and where its brief is written. '
                          'Left blank, each mission gets its own folder.',
                          style: MpType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
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
                      _SettingSwitch(
                        value: s.stepDownOnOpusLimit,
                        onChanged: (bool v) => store.updateSettings(
                          s.copyWith(stepDownOnOpusLimit: v),
                        ),
                        title: 'Step down to Sonnet on an Opus limit',
                        detail:
                            'Off by default: the standing policy is to wait '
                            'for the limit to lift rather than quietly change '
                            'which model does the work.',
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

/// A path you type, kept when you look away.
///
/// The working directory used to save only on `onFieldSubmitted`, so typing a
/// path and clicking anywhere else discarded it without a word — and the next
/// run went somewhere else entirely. There is no obvious moment to save a path
/// except the moment you stop editing it.
class _PathField extends StatefulWidget {
  const _PathField({
    required this.initial,
    required this.hint,
    required this.onSettled,
  });

  final String initial;
  final String hint;
  final ValueChanged<String> onSettled;

  @override
  State<_PathField> createState() => _PathFieldState();
}

class _PathFieldState extends State<_PathField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);

  void _onFocusChange() {
    if (!_focus.hasFocus) _settle();
  }

  void _settle() {
    final String v = _text.text.trim();
    if (v != widget.initial) widget.onSettled(v);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return TextField(
      controller: _text,
      focusNode: _focus,
      style: MpType.mono.copyWith(color: c.ink),
      decoration: InputDecoration(hintText: widget.hint),
      onSubmitted: (_) => _settle(),
    );
  }
}

/// A switch with a title and an explanation, built out of the design system
/// rather than out of `SwitchListTile`.
///
/// Two reasons, both found the hard way. A `ListTile` paints its ink on the
/// nearest Material, which inside an `MpPanel` is the page *behind* the
/// panel — so the splash lands under an opaque box and Flutter asserts. And an
/// accented `MpPanel` wraps its child in `IntrinsicHeight`, which a `ListTile`
/// does not measure reliably inside: the result was an 18px overflow in the
/// Autonomy panel, which is accented by default because the default permission
/// mode is `bypassPermissions`. That is the third layout crash this accent bar
/// has caused.
class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.detail,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final MpColors c = MpTheme.colorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: MpType.body.copyWith(color: c.ink)),
              const SizedBox(height: 2),
              Text(detail, style: MpType.caption.copyWith(color: c.inkMuted)),
            ],
          ),
        ),
        const SizedBox(width: MpSpace.md),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}
