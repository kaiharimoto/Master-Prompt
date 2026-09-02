import 'package:meta/meta.dart';

import 'capability_profile.dart';

/// Why a run is being launched. Determines which resume flags apply.
enum LaunchIntent {
  /// A brand-new session, with a pre-assigned id.
  fresh,

  /// Re-attach to an existing session by id.
  resume,

  /// Re-attach but branch to a new id, preserving the original transcript.
  forkResume,

  /// Continue the most recent session in the working directory.
  continueLast,
}

/// How much telemetry the launch will actually produce.
enum TelemetryTier {
  /// Full event stream. Everything the supervisor wants.
  streamJson,

  /// One JSON result at the end. Progress is invisible until completion.
  json,

  /// Plain text. Session id and usage are not machine-readable.
  text,
}

/// A fully-formed, validated invocation of the `claude` binary.
@immutable
class LaunchPlan {
  const LaunchPlan({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
    required this.telemetry,
    required this.sessionId,
    this.notes = const <String>[],
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;

  /// Variables to set or remove for the child. A null value means unset.
  final Map<String, String?> environment;

  final TelemetryTier telemetry;

  /// The session id this launch will use — pre-assigned for a fresh run, so it
  /// is known and persisted before the process starts.
  final String? sessionId;

  /// Capabilities that were requested but could not be applied, so the UI can
  /// say what was degraded instead of silently doing something different.
  final List<String> notes;

  @override
  String toString() => '$executable ${arguments.join(' ')}';
}

/// Raised when a launch cannot be built safely. Better to refuse at build time
/// than to spawn a process that will produce silence.
class LaunchPlanError implements Exception {
  LaunchPlanError(this.message);

  final String message;

  @override
  String toString() => 'LaunchPlanError: $message';
}

/// What the caller wants, before it is reconciled against what the CLI can do.
@immutable
class LaunchRequest {
  const LaunchRequest({
    required this.prompt,
    required this.workingDirectory,
    this.intent = LaunchIntent.fresh,
    this.sessionId,
    this.resumeSessionId,
    this.model,
    this.effortPreference = const <String>['high', 'medium'],
    this.permissionMode = 'bypassPermissions',
    this.additionalDirectories = const <String>[],
    this.appendSystemPrompt,
    this.settingsPath,
    this.fallbackModel,
    this.maxBudgetUsd,
    this.includePartialMessages = false,
  });

  final String prompt;
  final String workingDirectory;
  final LaunchIntent intent;

  /// Pre-assigned id for a fresh run.
  final String? sessionId;

  /// The session being resumed or forked.
  final String? resumeSessionId;

  final String? model;

  /// Effort levels in order of preference. The first one this CLI accepts wins,
  /// so a build that lacks `max` quietly runs at `high` instead of failing.
  final List<String> effortPreference;

  final String permissionMode;
  final List<String> additionalDirectories;
  final String? appendSystemPrompt;
  final String? settingsPath;
  final String? fallbackModel;
  final double? maxBudgetUsd;
  final bool includePartialMessages;
}

/// Composes a [LaunchPlan] from a [LaunchRequest] and a [CapabilityProfile].
///
/// Every flag is checked against the profile before it is used. Nothing here
/// hardcodes an assumption about what the installed binary supports.
class LaunchPlanBuilder {
  const LaunchPlanBuilder();

  LaunchPlan build({
    required String executable,
    required CapabilityProfile capabilities,
    required LaunchRequest request,
  }) {
    final List<String> args = <String>[];
    final List<String> notes = <String>[];

    // Hard requirement. Without --print the CLI starts an interactive session,
    // which cannot be driven from a GUI and will simply hang.
    if (!capabilities.has('--print')) {
      throw LaunchPlanError(
        'This claude build (${capabilities.version}) has no --print flag, so it '
        'cannot be run non-interactively. Master Prompt cannot drive it.',
      );
    }
    args.add('--print');

    // --- telemetry, with a documented degradation ladder --------------------
    TelemetryTier telemetry;
    if (capabilities.supportsValue('--output-format', 'stream-json') &&
        capabilities.has('--output-format') &&
        capabilities.has('--verbose')) {
      telemetry = TelemetryTier.streamJson;
      args
        ..addAll(<String>['--output-format', 'stream-json'])
        // Verified against the binary: stream-json output is gated on
        // --verbose. Without it the process writes nothing at all, which is
        // indistinguishable from a hang.
        ..add('--verbose');
      if (request.includePartialMessages &&
          capabilities.has('--include-partial-messages')) {
        args.add('--include-partial-messages');
      }
    } else if (capabilities.supportsValue('--output-format', 'json') &&
        capabilities.has('--output-format')) {
      telemetry = TelemetryTier.json;
      args.addAll(<String>['--output-format', 'json']);
      notes.add(
        'This CLI build cannot stream events, so progress is not visible until '
        'the run finishes.',
      );
    } else {
      telemetry = TelemetryTier.text;
      notes.add(
        'This CLI build produces plain text only. The session id and usage '
        'cannot be read, so automatic resume is unavailable.',
      );
    }

    // --- session identity ---------------------------------------------------
    String? sessionId;
    final bool canPin = capabilities.has('--session-id');

    switch (request.intent) {
      case LaunchIntent.fresh:
        if (canPin && request.sessionId != null) {
          sessionId = request.sessionId;
          args.addAll(<String>['--session-id', sessionId!]);
        } else if (!canPin) {
          notes.add(
            'This CLI build cannot be given a session id in advance, so the id '
            'must be read from the first event. A run that dies before that '
            'point cannot be resumed.',
          );
        }

      case LaunchIntent.resume:
      case LaunchIntent.forkResume:
        final String? target = request.resumeSessionId;
        if (target == null) {
          throw LaunchPlanError('Resuming requires a session id.');
        }
        if (!capabilities.has('--resume')) {
          throw LaunchPlanError(
            'This claude build has no --resume flag, so a session cannot be '
            'reattached. Use a cold restart seeded with a resume capsule.',
          );
        }
        args.addAll(<String>['--resume', target]);

        final bool fork = request.intent == LaunchIntent.forkResume;
        if (fork) {
          if (!capabilities.has('--fork-session')) {
            throw LaunchPlanError(
              'This claude build has no --fork-session flag.',
            );
          }
          args.add('--fork-session');
          if (canPin && request.sessionId != null) {
            sessionId = request.sessionId;
            args.addAll(<String>['--session-id', sessionId!]);
          }
        } else if (canPin && request.sessionId != null) {
          // Verified against the binary, verbatim: "--session-id can only be
          // used with --continue or --resume if --fork-session is also
          // specified." Pinning an id on a plain resume is a hard error, so
          // drop the pin rather than build an invocation that cannot run.
          notes.add(
            'Session id not pinned: this CLI rejects a pinned id on a plain '
            'resume unless the session is also forked.',
          );
        }

      case LaunchIntent.continueLast:
        if (!capabilities.has('--continue')) {
          throw LaunchPlanError('This claude build has no --continue flag.');
        }
        args.add('--continue');
    }

    // --- model and effort ---------------------------------------------------
    if (request.model != null && capabilities.has('--model')) {
      args.addAll(<String>['--model', request.model!]);
    }

    if (request.effortPreference.isNotEmpty) {
      final String? effort = capabilities.bestValue(
        '--effort',
        request.effortPreference,
      );
      if (effort != null) {
        args.addAll(<String>['--effort', effort]);
        if (effort != request.effortPreference.first) {
          notes.add(
            'Effort reduced to "$effort": this CLI build does not accept '
            '"${request.effortPreference.first}".',
          );
        }
      } else if (!capabilities.has('--effort')) {
        notes.add('This CLI build has no --effort flag; the default is used.');
      }
    }

    // --- autonomy -----------------------------------------------------------
    if (capabilities.has('--permission-mode') &&
        capabilities.supportsValue(
          '--permission-mode',
          request.permissionMode,
        )) {
      args.addAll(<String>['--permission-mode', request.permissionMode]);
    } else if (request.permissionMode == 'bypassPermissions' &&
        capabilities.has('--dangerously-skip-permissions')) {
      args.add('--dangerously-skip-permissions');
      notes.add(
        'Using --dangerously-skip-permissions: this build does not accept '
        'bypassPermissions as a permission mode.',
      );
    } else if (capabilities.has('--permission-mode')) {
      final String? fallback = capabilities.bestValue(
        '--permission-mode',
        <String>['acceptEdits', 'default'],
      );
      if (fallback != null) {
        args.addAll(<String>['--permission-mode', fallback]);
        notes.add(
          'Permission mode "${request.permissionMode}" is not supported by this '
          'build; using "$fallback". The run may stop to ask for approval.',
        );
      }
    }

    // --- context ------------------------------------------------------------
    for (final String dir in request.additionalDirectories) {
      if (capabilities.has('--add-dir')) {
        args.addAll(<String>['--add-dir', dir]);
      }
    }
    if (request.appendSystemPrompt != null &&
        capabilities.has('--append-system-prompt')) {
      args.addAll(<String>[
        '--append-system-prompt',
        request.appendSystemPrompt!,
      ]);
    }
    if (request.settingsPath != null && capabilities.has('--settings')) {
      args.addAll(<String>['--settings', request.settingsPath!]);
    }
    if (request.fallbackModel != null && capabilities.has('--fallback-model')) {
      args.addAll(<String>['--fallback-model', request.fallbackModel!]);
    }
    if (request.maxBudgetUsd != null && capabilities.has('--max-budget-usd')) {
      args.addAll(<String>[
        '--max-budget-usd',
        request.maxBudgetUsd!.toStringAsFixed(2),
      ]);
    }

    // The prompt goes last, as a positional argument.
    args.add(request.prompt);

    _assertInvariants(args, telemetry);

    return LaunchPlan(
      executable: executable,
      arguments: List<String>.unmodifiable(args),
      workingDirectory: request.workingDirectory,
      environment: const <String, String?>{
        // The CLI refuses to start inside another Claude Code session, keying
        // off these. Master Prompt may itself have been launched from one.
        'CLAUDECODE': null,
        'CLAUDE_CODE_ENTRYPOINT': null,
      },
      telemetry: telemetry,
      sessionId: sessionId,
      notes: List<String>.unmodifiable(notes),
    );
  }

  /// Last line of defence: combinations that are known to fail or to produce
  /// silence must not escape this class.
  void _assertInvariants(List<String> args, TelemetryTier telemetry) {
    final bool streamJson = _hasValue(args, '--output-format', 'stream-json');
    if (streamJson && !args.contains('--verbose')) {
      throw LaunchPlanError(
        'stream-json without --verbose produces no output at all.',
      );
    }
    if (args.contains('--session-id') &&
        (args.contains('--resume') || args.contains('--continue')) &&
        !args.contains('--fork-session')) {
      throw LaunchPlanError(
        '--session-id cannot be combined with --resume or --continue unless '
        '--fork-session is also present.',
      );
    }
    if (telemetry == TelemetryTier.streamJson && !streamJson) {
      throw LaunchPlanError('Telemetry tier does not match the arguments.');
    }
  }

  bool _hasValue(List<String> args, String flag, String value) {
    final int i = args.indexOf(flag);
    return i >= 0 && i + 1 < args.length && args[i + 1] == value;
  }
}
