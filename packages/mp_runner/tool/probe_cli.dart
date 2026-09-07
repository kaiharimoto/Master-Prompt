// Reports what the installed `claude` binary actually does.
//
// `docs/cli-contract.md` has told you to run this since the day it was
// written, and until now the file did not exist. That is worse than a missing
// tool: the contract claims to be verifiable and was not, so every claim in it
// had to be taken on trust — which is how the app came to send `--model
// claude-opus-5` to a flag that takes an alias or a dated full name, and a
// session id that was not a UUID.
//
// Everything below is a question this repository has had to guess at. Run it
// on the machine that matters and paste the output.
//
//   dart run tool/probe_cli.dart              # finds the CLI itself
//   dart run tool/probe_cli.dart /path/to/claude
//
// Nothing here writes to disk, and every probe runs with --print, so no
// session is left behind that you did not ask for.
import 'dart:convert';
import 'dart:io';

import 'package:mp_runner/mp_runner.dart';

late String exe;
final List<String> _warnings = <String>[];

Future<void> main(List<String> args) async {
  stdout.writeln('--- MASTER PROMPT CLI PROBE ---');
  stdout.writeln(
    'host        ${Platform.operatingSystem} '
    '${Platform.operatingSystemVersion}',
  );
  stdout.writeln('probed at   ${DateTime.now().toUtc().toIso8601String()}');

  final ClaudeInstall install;
  try {
    install = await const CliLocator().locate(
      explicitPath: args.isEmpty ? null : args.first,
    );
  } on ClaudeNotFound catch (e) {
    stdout.writeln('\nNOT FOUND: ${e.message}\n');
    for (final ProbeAttempt a in e.attempts) {
      stdout.writeln('  $a');
    }
    exitCode = 1;
    return;
  }

  exe = install.path;
  stdout
    ..writeln('path        ${install.path}')
    ..writeln('version     ${install.version}')
    ..writeln('auth        ${install.authMode.name}')
    ..writeln('shell       ${needsShell(install.path)}');

  _reportCapabilities(install.capabilities);
  await _reportSessionId();
  await _reportModels(install.capabilities);
  await _reportStdin();
  await _reportSeparator();

  stdout.writeln('\n--- WARNINGS ---');
  if (_warnings.isEmpty) {
    stdout.writeln('  none — this build matches docs/cli-contract.md');
  }
  for (final String w in _warnings) {
    stdout.writeln('  ! $w');
  }
  stdout.writeln('\n--- END PROBE ---');
}

void _reportCapabilities(CapabilityProfile p) {
  stdout.writeln('\n--- FLAGS THE LAUNCH PLAN DEPENDS ON ---');
  for (final String flag in const <String>[
    '--print',
    '--output-format',
    '--verbose',
    '--session-id',
    '--resume',
    '--fork-session',
    '--continue',
    '--model',
    '--effort',
    '--permission-mode',
    '--include-partial-messages',
    '--input-format',
  ]) {
    final bool has = p.has(flag);
    final List<String>? choices = p.choices[flag];
    stdout.writeln(
      '  ${has ? "yes" : "NO "}  ${flag.padRight(28)}'
      '${choices == null ? "" : "(${choices.join(", ")})"}',
    );
    if (!has) _warnings.add('$flag is missing from --help.');
  }

  // The parser needs the enumerated values on one physical line. Commander
  // wraps help to the terminal width, and --help is read through a pipe where
  // there is no width to read, so a wrapped "(choices: …)" is simply lost —
  // and a lost enumeration is *permissive*, which is the wrong direction.
  if (p.choices['--effort'] == null) {
    _warnings.add(
      '--effort enumerates no choices here. Either this build has none, or '
      'the help wrapped and the parser lost them — in which case an effort '
      'level this build rejects would be sent unchecked.',
    );
  }
}

Future<void> _reportSessionId() async {
  stdout.writeln('\n--- SESSION ID ---');
  final String id = newSessionId();
  stdout.writeln('  generated   $id');

  final ProcessResult r = await _run(<String>[
    '--print',
    '--session-id',
    id,
    '--',
    'Reply with the single word: ok',
  ]);
  final bool accepted = r.exitCode == 0;
  stdout.writeln('  accepted    $accepted');
  if (!accepted) {
    stdout.writeln('  said        ${_firstLine(r.stderr)}');
    _warnings.add(
      'This build refused a v4 session id. Every interview turn will fail.',
    );
  }
}

Future<void> _reportModels(CapabilityProfile p) async {
  stdout.writeln('\n--- MODEL VALUES ---');
  if (!p.has('--model')) {
    stdout.writeln('  --model is not supported by this build.');
    return;
  }
  // --model enumerates no choices in --help, so the capability probe cannot
  // validate it and a wrong value fails at run time on every single turn.
  // This is the only way to find out which ones are real.
  for (final String m in const <String>[
    'opus',
    'sonnet',
    'haiku',
    'claude-opus-5',
    'claude-sonnet-5',
  ]) {
    final ProcessResult r = await _run(<String>[
      '--print',
      '--model',
      m,
      '--',
      'Reply with the single word: ok',
    ]);
    final bool ok = r.exitCode == 0;
    stdout.writeln(
      '  ${ok ? "yes" : "NO "}  $m'
      '${ok ? "" : "   ${_firstLine(r.stderr)}"}',
    );
  }
}

Future<void> _reportStdin() async {
  stdout.writeln('\n--- PROMPT ON STDIN ---');
  // The brief is ~20k characters and the red-team pass ~22k. Windows caps a
  // command line at 32767, and at 8191 through cmd.exe — which is where an npm
  // install goes. If stdin works, neither limit applies.
  final Process p = await Process.start(exe, <String>[
    '--print',
  ], runInShell: needsShell(exe));
  p.stdin.writeln('Reply with the single word: ok');
  await p.stdin.close();
  final String out = await p.stdout.transform(utf8.decoder).join();
  final String err = await p.stderr.transform(utf8.decoder).join();
  final int code = await p.exitCode;

  final bool works = code == 0 && out.trim().isNotEmpty;
  stdout
    ..writeln('  works       $works')
    ..writeln('  said        ${_firstLine(works ? out : err)}');
  if (!works) {
    _warnings.add(
      'The prompt cannot be delivered on stdin, so it must go on the command '
      'line, where Windows caps it at 32767 characters (8191 through a .cmd).',
    );
  }
}

Future<void> _reportSeparator() async {
  stdout.writeln('\n--- `--` SEPARATOR ---');
  // Without it, an ordinary answer — "- twenty seats" — is read as a flag.
  final ProcessResult r = await _run(<String>[
    '--print',
    '--',
    '-Reply with the single word: ok',
  ]);
  final bool ok = r.exitCode == 0;
  stdout.writeln('  honoured    $ok');
  if (!ok) {
    stdout.writeln('  said        ${_firstLine(r.stderr)}');
    _warnings.add(
      'This build does not treat `--` as end-of-options, so an answer '
      'beginning with a dash will be parsed as a flag.',
    );
  }
}

Future<ProcessResult> _run(List<String> args) => Process.run(
  exe,
  args,
  runInShell: needsShell(exe),
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
);

String _firstLine(Object? o) {
  final String s = '$o'.trim();
  if (s.isEmpty) return '(nothing)';
  final String line = s.split('\n').first.trim();
  return line.length > 160 ? '${line.substring(0, 160)}…' : line;
}
