# Working on Master Prompt

Read this first. It exists because feedback arrives as conversation rather than
as tickets, so nothing about where we were survives a session boundary except
what is written down here and in `docs/STATUS.md`.

## What this is

A studio for writing prompts complete enough to run unattended for hours. It
interviews the user into a typed `MissionSpec`, compiles that into a numbered
brief (`00 / RUNTIME` … `09 / FAILURE CONDITIONS`), and then either drives the
Claude Code CLI on the desktop or hands the user copy-paste blocks for the
Claude app on a phone. `docs/method.md` explains why the brief is shaped the way
it is.

## Layout

```
packages/mp_core/     Spec, compiler, interview, continuity protocol, bundles.
                      Pure Dart. No Flutter, no dart:io.
packages/mp_runner/   CLI discovery, capability probe, stream-json, supervisor.
                      dart:io only. No Flutter.
packages/mp_design/   Tokens, theme, widget primitives. Flutter.
app/                  The Flutter app for Android and Windows.
```

**There is no pub workspace, deliberately.** The packages use path dependencies
so `mp_core` and `mp_runner` resolve and test with plain Dart. A workspace that
included the Flutter packages meant `dart pub get` needed the Flutter SDK, which
broke CI and quietly destroyed the property those packages exist to have. Do not
reintroduce one.

## Commands

```bash
cd packages/mp_core   && dart pub get && dart analyze && dart test   # no Flutter
cd packages/mp_runner && dart pub get && dart analyze && dart test   # no Flutter
cd app                && flutter pub get && flutter analyze && flutter test
```

`dart format` is a CI gate on both pure-Dart packages. Run it before pushing.

## Traps, all of them found the hard way

**The CLI contract is not what the documentation says.** `docs/cli-contract.md`
records what was verified against the shipped binary. The three that matter:

- `Error.message` is non-enumerable and the CLI serialises with a plain
  `JSON.stringify`, so **limit text can never appear in the stdout JSON stream**.
  stderr is the only channel carrying it. Any detector that greps stdout JSON
  will match nothing, forever, and present as a hang.
- `--output-format stream-json` writes **nothing at all** without `--verbose`.
- `--effort` accepted only `low, medium, high` in the build that was tested,
  not the documented `xhigh`/`max`. Never hardcode a flag or a flag value; the
  capability probe reads `--help` and degrades.

**`--session-id` cannot be combined with `--resume`** unless `--fork-session` is
also present. The binary rejects it outright. Encoded as an invariant in
`LaunchPlanBuilder`.

**File I/O never completes inside `testWidgets`.** The widget tester runs a
fake-async zone, so an `await store.create(...)` in a test body hangs forever.
Use a plain `test()` for storage, or `tester.runAsync()`.

**`CrossAxisAlignment.stretch` in a Row demands a bounded height**, so it throws
inside any scroll view. This broke every screen once via `MpPanel`.

**Widget tests must not touch the filesystem.** Use `AppStore(inMemory: true)`.
Real writes cannot complete in the tester's fake-async zone, so a test that
persists either hangs or races depending on machine load.

**`AnimatedCrossFade` builds both branches.** A collapsed disclosure built with
it still lays out its contents and still announces them to a screen reader, so
"hidden" is only true visually. Build the child conditionally inside an
`AnimatedSize` instead.

**The Windows binary can only be built on Windows.** It exists solely as a CI
job on `windows-latest`. That is why the supervisor lives in a plain `dart:io`
package: nearly all of it is provable on Linux first.

## The interface

One thing on screen at a time. The flow is a three-beat loop per stage — hand the
question over, bring the answer back, accept what it settled — and it advances
itself; `FlowController` holds only what the spec cannot know (whether this round
has been handed over, whether a reply is waiting). Everything else is derived
from `ReadinessGate`, so the interface cannot drift out of step with the mission.

Nothing is deleted to make a screen calm, only deferred: the full readiness list
lives behind **Progress**, the generated message behind a disclosure. If you find
yourself adding a second panel to a flow screen, it belongs in a disclosure or
the menu.

## Conventions

- A value the model proposed is `proposed`, never `confirmed`. Only a confirmed
  or explicitly waived field satisfies the readiness gate. This is what stops a
  hallucinated requirement reaching an unattended run.
- The compiler is pure and deterministic. Same spec, same bytes. That is what
  makes the prompt hash meaningful and spec edits diffable.
- Wire formats between the app and the model (`mpstate`, `mpspec`) are
  line-oriented `key=value`, never JSON. They travel through a chat UI and a
  clipboard, which mangles JSON all-or-nothing; a line grammar degrades field by
  field and a human can repair it by eye.
- A paste is never discarded. Every parse outcome keeps the raw text.
- Tests assert behaviour and say why in the `reason:`, rather than restating the
  assertion.

## Signing

`app/android/dev-keystore.jks` is committed on purpose so consecutive builds are
signed identically and install over each other instead of forcing an uninstall
that would delete the user's saved missions. **It is public and must never sign
a Play Store release.** CI asserts the certificate fingerprint after every build.

## The loop

The user tests real builds and reports in chat. Fix breakage, crashes and
obvious bugs directly; discuss anything that changes behaviour or appearance
first. Keep `docs/STATUS.md` current as part of the change — it is the only
thing that tells the next session where we were. Full description in
`docs/workflow.md`.
