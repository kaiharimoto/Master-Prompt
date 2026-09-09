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

**Windows cannot execute a `.cmd` directly.** `CreateProcess` refuses one, so
an npm install — `%APPDATA%\npm\claude.cmd`, the most likely install there —
threw `ProcessException`, which `probe` caught and returned null for. It was
reported as *not installed*: a confident, actionable, wrong answer.
`CliLocator.needsShell` runs a `.cmd` or `.bat` through a shell, on Windows
only. The locator also asks the operating system (`where` / `which -a`) before
its hardcoded candidates, because a fixed list cannot cover winget or a manual
install, and every candidate reports a `ProbeOutcome` with detail rather than
just a name. **An explicit path in Settings is a directive, not a hint** — it is
used alone, so a wrong one is reported rather than being silently bypassed by a
working CLI elsewhere.

**A platform check and a layout check are different questions.**
`isDesktop(context)` is a 900px *layout* gate; `DesktopRunner.isSupported` is
the platform. Everything about the CLI keys off the second, or a narrow window
on a PC gets the phone experience and a tablet gets a Run button it cannot use.

**There is one `DesktopRunner` for the whole app**, hoisted into
`_HomeScreenState` and passed to Settings, the Run screen and the flow. Three
probes would be free to disagree about whether Claude Code is installed.

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

**A chat app cuts an oversized paste off without saying so, and splitting it
is not the answer.** The compiled brief is around 20k characters and the
red-team pass carries the brief inside it, so both overflow. Cutting them into
labelled parts made each paste correct and the process no better — the two
together came to eight trips through the app switcher. **A file has no length
limit, so an oversized document leaves as an attachment.** `Handover` carries a
short `note` (the covering instruction, which always fits in a message) and a
`document` (the artifact, which becomes the file); `MpOutbound` offers Save the file
first, then Send, then copying in parts. **Saving leads because a share always
opens a new chat** — the receiving app decides that and an Android share intent
carries no way to name a conversation, so the one-tap route takes the choice
away. A saved file can be attached wherever you like, and goes straight to
Downloads on Android 10 and up. `HandoverSplitter` still cuts at a section heading if one is in reach,
then a paragraph break, then a line ending, never through a fenced block, and
`ResumeCapsule.chunk()` delegates to it. The paste limit is a setting, because
nothing can probe the real ceiling and only the person holding the phone can
find it.

**The Windows data directory is a function of `Runner.rc`.**
`path_provider_windows` builds `getApplicationSupportDirectory()` as
`RoamingAppData\<CompanyName>\<ProductName>`, read out of the running exe's
VERSIONINFO **at runtime**. So editing a resource string silently relocates
every saved mission, and the app starts up empty with nothing saying why.
`DataMigration` brings the old location forward; it copies rather than moves and
never overwrites, so it cannot destroy anything however many times it runs.
Renaming the app again means adding to `previousLocations()`.

**A branch guarded by `Platform.isWindows` has no way in from the runner the
tests run on, so it is not tested — assume it is broken.** This has now bitten
three times in one session: the one-click update path, the command-line length
guard, and the old-data-location lookup were all written behind an ambient
platform check and all had zero coverage the moment they were written. Every one
of them now takes the platform, or the value the platform decides, as a
parameter: `Updater` has `UpdatePlatform`, `CliConversation` has
`commandLineBudget`, `DataMigration.previousLocations` has `onWindows` and
`roaming`. Do the same for the next one. `Platform.isWindows` belongs only where
it *chooses* a default, never where it guards logic worth testing.

**`Process.run` closes the child's stdin; `Process.start` does not.** Streaming
needs `Process.start`, so the close has to be explicit — `unawaited(
process.stdin.close())` — or the CLI waits three seconds for piped input on
*every* turn and every run attempt, then writes a warning about redirecting
stdin into a window belonging to someone who has never seen a shell.
`fake_claude.dart` now waits for stdin to reach EOF and emits the same warning
if it does not, so forgetting the close fails on the Linux runner.

**Never `add` to `_events` directly, and never close it out from under a live
turn.** `CliConversation.dispose()` is called whenever the mission changes; a
turn still streaming at that moment crashed the whole app with *"Bad state:
Cannot add new events after calling close"*. Every emit goes through `_say`,
which checks, and `dispose` kills the child before closing the stream — in that
order, or the child writes into a pipe nobody is holding.

**There is one code path to a process, on purpose.** `CliConversation` used to
take an injectable `ProcessRunner`; every test used it, so `_defaultRunner`,
`needsShell` and the session-id generator had **zero executions in the whole
suite**, and an id of the shape `8-5-4-4-12` reached a real machine behind nine
green tests. Argument composition is now a pure function, `planFor()`, which a
test inspects without spawning anything; `ask()` always spawns; and the
conversation tests run against the compiled `tool/fake_claude.dart`. Do not
reintroduce a seam that lets a test skip the process.

**The fake CLI refuses what the real one refuses.** A non-UUID `--session-id`, a
missing `--print`, an unknown flag, a bad `--model`, `--effort` or
`--permission-mode` — each with the real binary's wording. A double that accepts
everything proves only that the code runs. `tool/probe_cli.dart` answers the
same questions against a real install, and is the thing to run on a machine
where something is wrong.

**`--model` takes an alias or a full dated name**, and enumerates no choices in
`--help`, so the capability probe cannot catch a bad one — it fails at run time,
on every turn. Settings offers `opus`/`sonnet`/`haiku` and defaults to sending
no `--model` at all.

**The desktop interview is a session, not a series of one-shots.**
`CliConversation` opens the first turn with `LaunchIntent.fresh` and a pinned
id, then resumes it on every turn after, which gives the desktop the same *one
continuing chat* property `TurnStyle.continuing` assumes — without the user
maintaining it. Two things inside it are deliberate and easy to undo by
accident: an interview turn is sent with **`permissionMode: 'default'`, never
the user's run setting** (`bypassPermissions` exists so an unattended build need
not stop to ask; a question about what to build needs no tools at all), and the
turn runs in a **directory of its own**, not the mission's working directory, so
a `CLAUDE.md` in the project the mission is *about* does not join the
conversation uninvited. The **session id the CLI reports wins** over the one
that was pinned, because older builds cannot be given one at all.

**The native surface is one channel, `masterprompt/platform`.** It does three
things and no more: hand an APK to the package installer, put a file into the
share sheet, and write one out — into `MediaStore.Downloads` on API 29+, and
through the Storage Access Framework below that or whenever the insert throws. Which file,
what it is called and what is in it are all Dart. None of it can be covered by
a test on a Linux runner, which is the reason it is kept this thin.

**Updating is the only part of the app with a native surface.** `MainActivity`
carries one method channel, `masterprompt/updates`, and it does exactly one
thing: hand a downloaded APK to the package installer. Everything else about
updating — which build is newest, which asset belongs to this platform, whether
a leftover download can be reused — is Dart, because none of the native part can
be tested on a Linux runner. The APK is shared through a `FileProvider` scoped
to `cache/updates/` only; a `file://` URI has been rejected since Android N, and
a provider over the whole of internal storage would expose every saved mission.

**The preview reads the compiled brief; it does not re-render the spec.**
`BriefDocument.parse` is a reader over the artifact itself, so anything on
screen or in the exported PDF is something the agent will read. A preview
driven from the spec would be a second implementation free to drift from the
thing being previewed. `BriefPdf` sets the same blocks, so the two cannot
disagree — one reader, two ways of setting it.

**Change marks come from diffing two compilations, not from the patch.** The
compiler is deterministic, so `BriefDiff.between(before, after)` is an exact
account of a round. `Project.briefBaseline` stores the compiled *body* rather
than the previous spec: a compiler change between builds would make an old
spec compile differently and cover the preview in marks nothing caused.

**Code in the brief must stay ASCII.** The exported PDF sets it in Courier,
which is built into every reader and carries no Unicode, so a middle dot inside
a fence would vanish from the document silently. `brief_preview_test.dart`
holds that as a contract rather than a coincidence.

**A status a screen probes on arrival is a status a screen can destroy.** The
Run pane called `detect` in `initState`, which set the runner to `locating` and
then `idle` — so closing the pane and opening it again mid-run, or switching
missions in the rail, which closes it for you, made `isBusy` false with the
supervisor still running. Stop left the screen, Run came back enabled, and a
second click launched a second agent into the same directory under
`bypassPermissions` with nothing left holding the first. Anything that writes
status now checks `isBusy` first.

**Cancellation has to reach the thing that is actually waiting.** `cancel()`
killed the process, and during a five-hour limit pause there is no process — the
supervisor is inside `clock.waitUntil`, which polled in one-minute slices and
never looked. `paused` counts as busy, so Stop stayed inert and Run stayed
disabled for the length of the pause. `waitUntil` now takes an `interrupted`
future and races it. The paired rule: **a stop is a fact about the user, not a
diagnosis about the run.** A killed process exits non-zero, which the detector
reads as `unknown`, so a deliberate stop was recorded as `stalled` and painted
red with a signal number in it. Check `_cancelled` before consulting a verdict.

**A wire format nothing parses is a wire format that does not exist.** The
compiled brief demands an `mpstate` heartbeat on every reply and says twice why
it matters on the CLI transport. `StateParser` had exactly one call site in the
app, behind the manual paste button, so during a desktop run the block scrolled
past in the log unread and the Progress panel said "nothing recorded yet" for
twelve hours. `RunHeartbeat` lives in `mp_core` rather than as a method on
`DesktopRunner` for the usual reason: the runner cannot be driven without a real
process, so a reader living inside it is a reader no test can reach.

**`completed` from the supervisor means the process exited zero.** It is not a
claim about the mission, and painting it green was a silently wrong answer,
which is worse than a missing one. `MissionCheck` compares the brief's own
commitments — the named evidence set, the exit threshold, the minimum cycles —
against what the run reported and what is on disk. Two judgements in it are
deliberate: a run that never reported a score cannot pass, because nothing
checked; and a mission that fixed no gates is not judged at all.

**Writing a file nothing reads back is the same as not writing it.**
`RunStore` wrote a record after every transition and `pendingResumes` carried a
comment saying it was called on every app launch. It had no caller. Separately,
`RunRecord.fromJson` dropped `attempts` and `lastVerdict`, so the attempt
ceiling that stops a pathological loop reset to zero on every reload. If a field
is persisted, something must read it, and a test must prove the round trip.

**Sleep inhibition leaks, and a leak here is a real harm** — a laptop that never
sleeps again because the app crashed holding the lock. `KeepAwake` derives the
hold from `isBusy` inside `notifyListeners` rather than taking it at the places
a run starts and ends, so a throw or an early return cannot strand it; the calls
are serialised, so a release cannot overtake a hold; a failed hold is not
remembered as held; and the run panel shows whether it is actually held, because
a hold nobody can see is a leak nobody notices. The native half is one method on
`masterprompt/platform` and decides nothing.

**Closing the window needed no native code.** The Windows embedder consumes the
first `WM_CLOSE` precisely so the framework can answer, but only when something
has registered for `didRequestAppExit`. Nothing had, so quitting mid-run was a
one-click unconfirmed kill. An `AppLifecycleListener` in `_HomeScreenState` is
the whole fix. `AppExitResponse` is a `dart:ui` type and Flutter does not
re-export it.

**Two screens talk to the CLI, and there is one opener.** `openConversation`
in `cli_session.dart` is it. A second copy would be free to disagree about a
directory of its own (so a `CLAUDE.md` in the project the mission is *about*
does not join uninvited), `permissionMode: default` regardless of the run
setting, and effort that degrades downward only. The red-team pass runs in a
session named `review` rather than the interview's: it carries the whole
compiled brief, and sending twenty-two thousand characters into the chat
conducting the interview would bury the round-to-round context that interview
depends on. On a `.cmd` install the command-line budget is 7,800 characters, so
the pass refuses the pipe there — which is why the clipboard route is demoted
one level rather than removed.

**`MpField` uppercases its label**, which is right for `NEXT ACTION` and
unreadable for a sentence. A line of prose is a `Text`, not a field label.

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

**A `ListTile` does not belong inside an `MpPanel`.** It paints its ink on the
nearest Material, which inside a panel is the page *behind* it, so the splash
lands under an opaque box and Flutter asserts; and inside an *accented* panel
the `IntrinsicHeight` cannot measure it, which overflowed the Autonomy panel by
18px — accented by default, because the default permission mode is
`bypassPermissions`. That is the third layout crash this accent bar has caused.
`_SettingSwitch` in `settings_screen.dart` is the replacement.

**On desktop the destinations open in the content pane, not as pushed routes.**
A push covers the rail too, so opening Settings blanked a 1600px window into a
phone page and took the mission list with it. `_panel` in `_HomeScreenState`
holds which one; the narrow layout still pushes, which is right when there is
only one column.

**Widget tests default to 800×600, which is below the 900px desktop gate.** So
every test in this repository exercised the phone layout, and the entire wide
branch of `home.dart` went uncovered until a fresh desktop install turned out to
have no menu — and so no way to reach Settings and connect the CLI. Desktop
behaviour needs `tester.view.physicalSize`; `desktop_layout_test.dart` is the
group that does it.

**Enter cannot be the send key.** Every writing field here is multi-line, and
with `maxLines` above one Flutter routes Enter to a newline and never calls
`onSubmitted` — which is why the seed field's submit handler was dead code for
months. `MpSubmit` binds Ctrl+Enter (and Cmd+Enter), which is what the fields
use.

**The same three beats serve both routes.** On a connected desktop the ASK beat
sends the round into the CLI session and the waiting beat becomes the reply plus
a box to answer in; on a phone, or a desktop with no CLI, they are Copy and
Paste. What comes back is read by the same `SpecPatchParser` and stopped by the
same accept step either way — **a reply that arrived down a pipe has no more
authority than one that was pasted.** Copy-paste is never removed, only demoted
one level, because the CLI can be missing, logged out or rate-limited.

## Conventions

- A value the model proposed is `proposed`, never `confirmed`. Only a confirmed
  or explicitly waived field satisfies the readiness gate. This is what stops a
  hallucinated requirement reaching an unattended run. **Every screen that takes
  a patch therefore needs its own accept step** — `confirmProposals()` is the
  only thing that makes a replaced value count, and a screen that writes the
  patch in without calling it reports "applied" for changes that are outside the
  gate. The red-team pass did exactly that for a while. It now holds the result
  and applies nothing until accepted, which also stops a proposed value flipping
  the gate shut and replacing the screen with the not-ready notice.
- **What changed is named, not counted.** Every `applied` line carries its
  value, truncated — thirty lines reading "Failure condition recorded." tell you
  no more than the number thirty did.
- The compiler is pure and deterministic. Same spec, same bytes. That is what
  makes the prompt hash meaningful and spec edits diffable.
- Wire formats between the app and the model are read by a **ladder**, not by
  one grammar. The interview now *asks* for a single fenced `json` block,
  because the Claude app puts a copy button on a code block and one tap beating
  a text selection on a phone is worth more than anything else about the format.
  The parser still accepts the older line-oriented `key=value` grammar, fenced
  or bare, and JSON with trailing commas, smart quotes or no fence at all —
  every one of those is something a real paste turned out to be. `mpstate`
  stays line-oriented: it is written *by* the model mid-run, where a truncated
  JSON object would lose the whole heartbeat and a truncated line grammar loses
  one field.
- A paste is never discarded. Every parse outcome keeps the raw text, and a
  parse that finds nothing returns a `diagnostic` saying what it saw instead.
- **Every question the model asks comes with options and a recommendation.**
  Two to four numbered options, a line each on what choosing it would mean, one
  marked recommended with a reason grounded in what this mission has already
  settled, and explicit permission to have no opinion — a model asked for a
  recommendation invents one otherwise, and false confidence in a brief that
  runs unattended is worse than none. The paired rule is that **a recommendation
  is not an answer**: it may not enter the patch block until the user picks it,
  which is presumption rather than invention and needed saying separately. There
  is deliberately no "just take all your recommendations" shortcut.
- **The questions a round asks are read, not just displayed.** A round comes
  back at four or five thousand characters, and reading it then typing
  "1, 2, 3" into a box was the slowest part of the interview and the part with
  no thinking left in it. The prompt asks for an `mpask` block indexing the
  questions; `AskedRoundParser` reads it and the app renders buttons. **The
  block is line-oriented and must never become JSON** — `SpecPatchParser`
  brace-matches with no fence at all, so a JSON questions block would be
  applied as a patch of answers nobody had given. Same reasoning that keeps
  `mpstate` line-oriented. The block is an index into the prose, not a
  replacement: the reasoning stays above it, and the free-text box stays for a
  reply that had no block at all.
- **A recommendation is marked, never pre-selected, and there is no "take all
  the recommendations" button.** The saving is in not typing, not in not
  deciding. "You choose" exists as an explicit per-question option because the
  *user* electing to defer is a different act from the model assuming — and the
  value still arrives `proposed` and still has to be accepted either way.
- **The interview assumes one continuing chat.** `nextTurn` takes a
  `TurnStyle`: `standalone` carries the framing, everything settled and the
  format rules; `continuing` carries only the round and its schema, roughly a
  third the size. The default is `standalone`, because a standalone turn in a
  running chat is merely wasteful while a continuing turn in a fresh chat is
  unusable. The app sends `standalone` until a reply has come back
  (`Project.hasAnsweredOnce`), and offers it again under the message preview,
  because a session limit ending the chat is the case this app exists for.
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
