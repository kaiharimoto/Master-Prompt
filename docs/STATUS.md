# Status

A living note, updated as part of each change. It is the only thing that tells a
new session where we had got to, because feedback lives in chat rather than in
issues.

_Last updated: the commit that made the desktop interview actually work, and
gave Windows a real installer._

The loop itself is live: `docs/workflow.md` describes it, CI publishes a rolling
`dev` prerelease on every green push, and Settings carries a Copy diagnostics
button. The core job runs on plain Dart in about 35 seconds.

## Where things stand

The guided flow has been used on an Android phone for a full interview round,
and two things came back from it. Both are fixed in this build and neither is
confirmed on hardware yet.

**The reply was hard to copy, and then the parser refused it.** The interview
now asks for exactly one fenced `json` block with nothing after it, so the
Claude app's copy button on that block is the whole gesture. The parser was the
worse half of the bug: it accepted only a fenced `mpspec` block, while the
`mpstate` parser beside it had three fallbacks — and the app's copy button
copies a block's *contents*, without the fence, so a correct reply pasted
correctly parsed as nothing. It now reads a ladder: JSON found by brace matching
with or without a fence, then the line grammar fenced, then bare. The exact
paste that failed on the device is a regression test.

**Updates had to be fetched from GitHub by hand.** The app now checks the `dev`
release at launch, silently, and offers the newer build in one tap: download,
then install. On Android that hands the APK to the system package installer
through a `FileProvider`; on Windows it downloads the zip and says plainly that
a running executable cannot replace itself.

Then, from using it in one continuing chat: **every round re-sent the preamble**
— who the model was, everything already settled, and the format rules in full —
to a chat that had worked most of it out itself. `nextTurn` now takes a
`TurnStyle`. The first round of a mission is sent whole; every round after it
carries only the round and its schema, about a third the size, and 70% smaller
by the late stages where the settled list is longest. Settings holds a toggle
for anyone starting a fresh chat each round, and the message preview keeps a
"Copy for a new chat" for the case that actually matters: a session limit
ending the chat mid-interview.

Then, from trying to red-team a brief: **the message was too long to paste and
the chat app cut it off silently.** The red-team pass on the reference mission
is 21,899 characters, because it carries the whole compiled brief inside it.
Every long handover now goes through one `HandoverSplitter`, which cuts at
section headings where it can, never through a fenced block, and labels each
part so the model replies `ok` rather than answering the first third. Paste size
is a setting, since nothing in the app can probe the real ceiling.

The same bug was sitting unhit in two other places: the paste-variant brief is
20,994 characters, so **starting a run on a phone would have handed the agent
half a spec**, and the resume capsule had its own separate line-based splitter —
so the careful mechanism guarded the thing that rarely overflows while the two
that do had none. The capsule delegates now.

Then, from actually using it: **splitting was the wrong fix.** Each part was
correct and the process was no better — the brief and the red-team pass
together came to eight trips through the app switcher, which is not a way to
send a document. Trimming cannot help either; the bulk is genuinely mission
content (`07 / BRIEF` is 6,322 characters, `08 / DELIVERABLES` 3,890), so
dropping every piece of fixed scaffolding still leaves ~19,000.

**A file has no length limit.** An oversized handover now leaves as an
attachment: the document goes in the file and only the covering instruction in
the message. Sharing works — confirmed on the device — but **it always opens a
new chat**, because the receiving app decides that and an Android share intent
carries no way to name a conversation. For the mission brief and the resume
capsule that is exactly right; everywhere else it takes the choice away. So
`Save the file` leads, writing straight into Downloads on Android 10 and up,
and `Send` sits beside it. Copying in parts survives one level down, because it
is the only route that depends on nothing at all.

Then: **the brief was only ever a payload, never a document.** Every screen
showed it as a monospace block with a copy button under it. It now has a
reading view — set in the app's own type scale, tables and fenced blocks laid
out properly, a section index — and exports as a PDF with Inter embedded, for
reading away from the phone or handing to someone.

**And a round's changes are marked in it.** The compiler is deterministic, so
diffing the brief as it stood before an accepted round against the brief now is
an exact account of what that round did: changed passages carry a rule in the
margin, on screen and in the PDF, with a clean copy for sharing. The marks are
for the person reading. Nothing about them reaches the model.

Then, from applying a red-team pass with eighty fixes in it and asking a
question with no good answer — *how do I know it actually reached the brief?*
**Partly it had and partly it had not, and the screen could not tell you
which.** A value the pass replaced arrives as `proposed`, and
`confirmProposals()` is called in exactly one place in the app: the interview's
Accept beat. The red-team screen wrote the patch straight in and never
confirmed anything, so list additions took effect immediately while every
replaced value sat outside the readiness gate — reported as "applied" and
counting for nothing. Worse, a replaced value could flip the gate shut, and the
Brief screen answers that by replacing itself with the not-ready notice, taking
the red-team panel with it.

It now holds the parsed result, names every fix rather than counting them, and
changes nothing until accepted — the same three beats the interview has. The
not-ready state offers to accept outstanding proposals, so a mission already
stranded by the old behaviour has a way out.

Then, on the interview itself: **a question with four options and nothing to
choose between them is four unknowns to weigh.** Every question the model asks
now carries a line per option on what choosing it would mean, one option marked
recommended with a reason specific to this mission, and permission to say it has
no basis for a preference. The guard that came with it is that a recommendation
may not be treated as an answer — with a recommended value already written out,
the model is one step from putting it in the patch block unasked, which would
walk straight past the readiness gate. There is no blanket "take all your
recommendations" shortcut, deliberately.

Found while checking the copy button: **every second tap of `Copy for Claude` on
a short document copied nothing.** The stepper cycles back to part one once it has sent
them all, and that handler was reused for the single-part case, so the second
tap reset instead of copying — silently, with the label unchanged to say so.

Then, from the PC: *"it's installed but it's not very intuitive or easy to
figure out how to connect the Claude Code CLI"* — **half of the desktop was
never built.** `mp_runner` drives the CLI for a *run*, and the Run screen shows
it; but `flow_screen.dart` had no idea the CLI existed, so **the interview was
copy-paste on Windows exactly as on the phone**, with a working CLI sitting a
few inches away. The original brief asked for the opposite.

Three things were wrong and each is fixed.

**The CLI could not be found, and the failure said nothing.** On Windows,
`CreateProcess` refuses a `.cmd`, so an npm install — `%APPDATA%\npm\claude.cmd`
— threw `ProcessException`, which `probe` swallowed and reported as *not
found*: the single most likely install was invisible. A `.cmd` or `.bat` now
runs through a shell. The search also asks the operating system first (`where`
on Windows, `which -a` elsewhere) before the hardcoded candidates, which is the
only thing that can cover winget or a manual install. And every candidate now
reports an outcome — not there, could not be run, ran but is not Claude Code,
found — with the detail, so someone who does not remember how they installed it
is told rather than asked.

**Nothing said whether it was connected.** Settings had a bare text field
hinting "Leave blank to search PATH", and the probe ran only on the Run screen,
which is behind the overflow menu and refuses to appear until the brief
compiles. Settings now opens on a Connection panel that probes on arrival and
names the version, the path and which credential is in use, with a Test button
and a disclosure listing every path it tried and what became of each. An
explicit path is now a directive rather than a hint: it is used alone, so a
wrong one is reported instead of being silently bypassed by a working CLI
somewhere else.

**And the interview now happens in the app.** `CliConversation` opens one
session with a pinned id and resumes it on every turn after, which gives the
desktop the *one continuing chat* property the clipboard route asks the user to
maintain by hand. On a connected desktop the round's primary action is **Ask
Claude**; the reply comes back on screen with a box under it, so a
recommendation can be argued with before it becomes a patch, and a reply that
settles something advances to the same Accept beat as a pasted one. It is the
same `SpecPatchParser` and the same readiness gate — a reply that arrived down
a pipe has no more authority than one that was pasted. Copy-paste survives one
level down, because the CLI can be missing, logged out or rate-limited.

Two decisions inside that are worth stating. An interview turn is sent with
`permissionMode: 'default'`, never the user's run setting: `bypassPermissions`
exists so an unattended build need not stop to ask, and a question about what
to build needs no tools at all. And the turn runs in a directory of its own
rather than the mission's working directory, so a `CLAUDE.md` sitting in the
project the mission is *about* does not join the conversation uninvited.

Then, from the PC, one line: **"invalid session ID. Must be a valid UUID."**

**The desktop interview had never worked, and it shipped behind nine green
tests.** `microsecondsSinceEpoch` is thirteen hex digits; the generator assumed
twelve, so it built `8-5-4-4-12`. Deterministic — every machine, every first
turn. Twenty lines away in the same package, `RunSupervisor` had a correct
generator. Third time this repo has carried two implementations of one idea and
load-beared the wrong one.

**Why the tests passed is the part worth keeping.** Every conversation test
injected both the process runner and the session id, so `_defaultRunner`,
`needsShell` and the generator had *zero executions in the entire suite*. The id
the tests pinned — `fixed-id-0000-4000-8000-000000000000` — is six groups and
not hex. They proved the value was plumbed through correctly and never once
asked whether it was valid.

So the seam is gone. Argument composition is a pure function, `planFor()`, that
a test reads without spawning anything; `ask()` always spawns; and the
conversation tests drive the compiled fake CLI the way the supervisor tests
always have. And the fake now **refuses what the real binary refuses**, in its
words: a non-UUID session id, a missing `--print`, an unknown flag, a bad
`--model`, `--effort` or `--permission-mode`. A double that accepts everything
proves only that the code runs.

That immediately caught the failure already queued behind the first one:
**Settings sent `--model claude-opus-5` on every turn and every run.** The flag
takes an alias (`opus`) or a full dated name (`claude-sonnet-4-5-20250929`), and
because it enumerates no choices in `--help` the capability probe waves anything
through — it fails at run time, every time. Settings now offers the aliases and
defaults to sending no `--model` at all.

An audit found four more, none of which had a test:

- **No timeout, no cancel, no progress.** `Process.run` blocked until exit, so a
  multi-minute turn was a static window with every button disabled; a wedged CLI
  looked exactly like a working one, and the only way out orphaned the child. It
  streams now — text as it arrives, an elapsed count, the tool in use, a **Stop**
  button, and a ceiling that kills.
- **A failed turn corrupted the retry.** The user's turn stayed in the
  transcript, so `hasExchange` went true and the retry sent the short
  *continuing* round into a session that had never existed. Retrying after the
  error made it quietly worse.
- **A non-zero exit with partial text was stored as a complete answer**, and
  stderr was discarded whenever any text came back — the one channel a limit or
  auth reason travels on.
- **An answer beginning with `-`** was read as a flag. The prompt goes after
  `--` now, and the invariant guards stopped scanning the user's prose.

The same `.cmd` bug the interview had was still in the **run** path:
`Process.start` without `runInShell` refuses a batch file, so an npm-installed
`claude.cmd` would have thrown on the path that does the twelve-hour work.

**And `tool/probe_cli.dart` finally exists.** `docs/cli-contract.md` has said to
run it since the day it was written, and the file had never been created — a
contract that claims to be verifiable and is not. It reports version, flags,
enumerated choices, whether a v4 session id is accepted, which model aliases
resolve, whether the prompt can go on stdin, and whether `--` is honoured. One
command answers what this repository has been guessing at.

Then, separately: **the program was called `master_prompt`.** In the title bar,
the taskbar, Alt-Tab, Task Manager, the exe name and every version string. It
shipped as a zip you extract by hand, and "Install" opened Explorer with the
file selected and left five manual steps.

It is **Master Prompt** now, `MasterPrompt.exe`, and it installs. A per-user
Inno Setup installer — `%LOCALAPPDATA%\Programs`, so no administrator prompt —
with a Start-menu entry and an uninstaller in Add/Remove Programs. Updates are
one click: the app writes down which build it is reaching for, spawns the
installer silently with `/relaunch=1`, and leaves, because an installer cannot
overwrite an executable that is still running. It comes back updated. If it does
not, the next launch compares the build it wanted against the build it is and
says so — a silent installer that fails is otherwise indistinguishable from an
update nobody took.

**The rename moved the user's data**, which is the sharp edge of all of this.
`path_provider_windows` derives the support directory from the exe's
`CompanyName` and `ProductName` *at runtime*, so editing a resource string
relocates every saved mission and the app starts up empty with nothing saying
why. `DataMigration` brings the old location forward: it copies rather than
moves, never overwrites, and writes its marker last, so it cannot destroy
anything however many times it runs or wherever it is interrupted.

CI changed with it. The Windows job now runs `flutter analyze` and the full test
suite — it ran **neither**, while the Android job ran both. It stamps the build
number into `pubspec.yaml` so it reaches the exe's version resource and
Android's `versionCode`, which was pinned at `1` for every build ever shipped.
It checks for Inno Setup rather than assuming it. And `release.yml` produced
`MasterPrompt-windows-x64.zip` and an unrenamed `app-release.apk`, **neither of
which matches the updater's filename patterns** — a tagged release was invisible
to every installed copy. Fixed before it was needed.

Then the desktop interface itself, which had been serving a phone layout to a
widescreen window.

**Settings and Update were unreachable on a wide window with no mission
open** — the header was built inside `if (p != null)`, so a fresh desktop
install had no menu at all, and therefore no way to reach the panel that
connects the Claude Code CLI. That is the first thing a desktop user has to do.
Nothing caught it because `isDesktop(context)` is a 900px gate and **every
widget test in the repository ran at 800×600**, including `desktop_flow_test`,
despite its name. The entire wide branch had zero coverage. It has a test group
of its own now, at 1600×1000.

**There was no keyboard support anywhere**: zero `Shortcuts`, zero `FocusNode`s,
and the one `autofocus` in the app was set to `false`. The desktop chat's
follow-up box — the only way into the conversation — could be submitted with
the mouse and nothing else, once per turn, for the whole interview. Ctrl+Enter
sends now, Enter still starts a new line, Escape closes a pushed screen, and the
field each beat is about takes the caret on arrival — on a desktop only, since
on a phone that throws the keyboard over the question you are meant to read. The
seed field's `onSubmitted` had been dead code since it was written: with
`maxLines` above one, Flutter routes Enter to a newline and never calls it.

**And the window had no minimum size**, so it could be dragged below 900px and
silently become the phone layout on the way past.

**And it shipped the stock Flutter template icon on both platforms** — the blue
swatch, untouched since the first commit. It has a mark of its own now: the
wordmark's initial in the app's own type and ink, over the hairline rule the
design system is built on. `tool/make_icon.py` is committed beside it so the
thing is reproducible rather than a binary nobody can regenerate.

**Opening Settings blanked the window.** On a phone a pushed route is right —
one column, a back arrow, done. On a desktop it covers the rail as well, so
Settings erased a 1600px display into a phone page and took the mission list
with it. The four screen destinations open in the content pane now, with the
rail intact and Escape closing them exactly as it closes a pushed route.

Writing the test for that found a bug nothing had ever reached: **the Autonomy
panel in Settings overflowed by 18 pixels**, because an accented `MpPanel` wraps
its child in `IntrinsicHeight` and a `SwitchListTile` cannot be measured inside
one — and that panel is accented by default, since the default permission mode
is `bypassPermissions`. The same tiles were also painting their ink on the page
behind the panel, which Flutter asserts on. Both switches are built from the
design system now. Third layout crash traceable to that accent bar.

Then the rest of the phone shape. **Progress, Missions and Update were modal
bottom sheets on both platforms** — a thumb gesture from the bottom edge of a
phone, which on a mouse-driven window is a panel that has slid in from
off-screen and has to be dismissed by aiming above it. They are dialogs on a
wide window now. The desktop conversation had the same 620px reading column as
a single question, with a reply, its notices and a composer all sharing it, so
that beat has a measure of its own. The run log was capped at 220px whatever the
window height and could not be selected — it is the first thing anyone asks for
when a run goes wrong. And **the working directory silently discarded whatever
you typed unless you pressed Enter**, which meant the next run went somewhere
else entirely with no indication.

Then, from the desktop, with the interview finally working: **every turn opened
with three seconds of nothing**, and this as the app's own status line —
*"Warning: no stdin data received in 3s, proceeding without it. If piping from a
slow command, redirect stdin explicitly: `< /dev/null` to skip."*

`Process.run` closes the child's stdin. `Process.start` does not. The rewrite to
streaming — so text could arrive as it was written instead of the window sitting
frozen — moved to `Process.start` and lost the close, in **two** places: the
interview, and the supervisor, where every launch and every resume of a
twelve-hour run paid the same three seconds and wrote the same warning into the
run log. `grep stdin` over both files returned nothing.

Nothing could have caught it, which is the familiar half: `fake_claude` never
read stdin, so the double did not behave like the binary. It waits for EOF now
and emits the same warning if it never comes — and reproducing the stall on the
Linux runner, at 291ms instead of 3s, is what turned it into a failing test
before it was a fix.

**And the screen made it look worse than it was.** The first line of stderr set
the activity string and nothing ever cleared it, so a CLI warning replaced the
elapsed counter for the rest of the turn: the one moment you most need "still
working, 42s" was the moment it disappeared. Rounds take 33 to 76 seconds
against the real binary, so that counter is not decoration. The elapsed time is
always shown now, and raw stderr is not treated as the app's status at all — it
reaches the diagnostics log, and the reason for a *failed* turn still reaches
the screen through `error`.

The same diagnostics carried a crash nobody had reported: **"Bad state: Cannot
add new events after calling close"**, twice. `CliConversation.dispose()` closes
the event stream, the app calls it whenever the mission changes, and a turn
still streaming at that moment took the process down. Six unguarded `add` calls,
any one of which was enough. Every emit is guarded now, and `dispose` kills the
child *before* closing the stream rather than leaving it writing into a pipe
nobody holds.

### Works, and is verified

- **The compiler.** A `MissionSpec` renders to a ten-section brief. The
  acceptance test reconstructs the reference Blender brief and asserts the
  output carries every section, the 100-point rubric with its floors, all
  sixteen numbered artifacts, six critics and every failure condition.
- **The interview and readiness gate.** Staged discussion, patches accumulating
  across rounds, compilation refused while anything required is unresolved. The
  prompt asks for numbered options with one recommended, so a reply can be a
  list of numbers, and for one JSON block so bringing it back is one tap.
- **Handing over a long document.** That the covering note and the artifact
  separate cleanly and both survive into the copy fallback; that a task id is
  made safe before it becomes a file name; that the red-team instruction fits
  in a message on its own while the brief it attacks does not. In the app: that
  a document which fits keeps its plain one-tap copy, that an oversized one
  offers Send with Save beside it, that Save alone is offered where there is no
  share sheet, and that a failed share points at the route that cannot fail.
- **Splitting a long handover.** That every part fits the limit across four
  different limits, that nothing is lost between the parts, that cuts land on
  section headings, that a fenced block is never left open and a fence longer
  than a part is closed and reopened in kind — and, against the real reference
  mission, that the red-team pass and the paste brief both overflow and both
  split cleanly.
- **The two turn styles.** That a continuing turn keeps the round, its gaps and
  its schema and drops everything the chat already holds; that the standalone
  turn is what a caller gets without asking, since it is the one that is merely
  wasteful rather than broken when it lands in the wrong chat.
- **The parser ladder.** JSON fenced, unfenced or alone; trailing commas, `//`
  comments and smart quotes; the old line grammar either way; braces inside
  values. Prose is rejected rather than half-applied, and a reply that settles
  nothing says what it saw instead.
- **Updating.** Reading the release, picking this platform's newest asset,
  refusing to compare against a locally built copy, adopting a complete download
  from a previous launch, sweeping the last build out of the cache, and every
  failure path — all against a fake transport, since a real check needs a
  network and a real install needs a phone.
- **Continuity.** The `mpstate` parser survives deliberately mangled input and
  never discards a paste; resume capsules degrade by dropping sections rather
  than summarising; mission bundles round-trip and reject truncation.
- **The supervisor.** Limit detection, the reset-time ladder, persisted resumes
  and the resume ladder, all driven against a fake CLI so the recovery paths are
  exercised without an API key or a five-hour wait.
- **Finding the CLI.** That a `.cmd` is run through a shell on Windows and
  nowhere else; that the search asks the operating system before guessing; that
  an explicit path that fails does not quietly fall through to a working CLI
  somewhere else; and that a total failure names every candidate with a reason
  attached, which is the output to send when it still cannot be found.
- **The desktop conversation.** That the first turn opens a session and every
  turn after resumes it, that a pinned id never rides a plain `--resume`, that
  the id the CLI reports wins over the one that was asked for, that an
  interview turn is sent at `default` permissions rather than the run setting,
  and that a plain-text build still yields a reply.
- **The desktop interview, in the app.** That a connected CLI turns the round
  into something it can send while keeping the clipboard route one level down;
  that a reply of questions is shown with a box to answer in rather than the
  clipboard route's "nothing settled" warning; that an answer goes back into
  the same session; that a patch from the CLI still has to be accepted before
  it counts; that a failed turn says so instead of looking like a quiet answer;
  that the first round is written for a session that knows nothing and later
  rounds are not; that a turn in flight cannot be sent twice; and that with no
  CLI the desktop behaves exactly as the phone does.
- **The session id.** Against the RFC pattern, the version and variant nibbles,
  and 20,000 rapid calls with no repeat — the contract, not the implementation.
- **The conversation, against a real process.** No injected runner and no
  injected id, so the three functions that only exist on a desktop actually
  execute: the id is one the CLI accepts, the second turn resumes the first, a
  prompt beginning with `-` survives, a subagent is not mistaken for the
  assistant, a partial answer that ends in failure is not an answer and leaves
  no transcript behind, a warning on a successful turn is kept, a build with no
  session id says so, a turn that never answers is stopped, a turn in flight can
  be cancelled, and progress is visible while it runs.
- **The data migration.** Missions and the crash log arrive; the originals stay
  put; running it twice does nothing the second time; an interrupted copy is
  finished on the next launch; nothing already in the new location is ever
  overwritten; and a first install on a clean machine is not given a marker for
  a migration that never happened.
- **The one-click update.** That the app leaves so the installer can replace the
  files it is holding, that it records which build it was reaching for, that a
  silent install which failed is reported on the next launch and only once, and
  that one which worked says nothing. The installer preferred over the zip in
  the same build; the zip still recognised alone; the build number deciding
  before the kind.
- **End to end, headlessly:** discussion patch → spec → gate → compile → write to
  disk → launch → session limit → wait → resume on the same session → complete →
  parse state back → build a capsule. `packages/mp_runner/test/end_to_end_test.dart`.

360 tests: 151 in `mp_core`, 103 in `mp_runner`, 106 in the app.

### Not yet proven

- **The one-tap copy.** Whether the Claude app really does put a copy button on
  the block, and whether the block really is the last thing in the reply, is
  only answerable by pasting a real reply back.
- **The updater on a device.** None of the native half has run: the permission
  bounce on first install, the `FileProvider` authority, the installer intent.
  A wrong authority or a missing path entry fails at the moment of install with
  a bare "app not installed", so this is the first thing to try on the next
  build.
- **The Android signing config** has not yet produced an install-over-the-top.
  CI asserts the certificate fingerprint, which catches a broken config, but the
  actual update behaviour on a device is unverified. The updater makes this
  matter twice over: an install that will not go over the top loses the saved
  missions.
- **Anything Windows-specific.** `where`, running a `.cmd` through a shell, the
  installer itself, the silent update, and whether `cmd.exe` mangles a
  multi-line prompt. The Linux runner covers decisions and shapes; the PC is the
  only oracle. `tool/probe_cli.dart` exists to make that one round trip instead
  of several.
- **The rename, on a machine with existing missions.** The migration is tested
  against real directories, but not against a real `path_provider` on a real
  Windows profile. It copies rather than moves, so the worst case is recoverable
  by hand.
- **The desktop runner and the desktop interview against a real `claude`
  binary.** Everything is proven against the fake CLI; the real one has never
  been driven from the app. A `--print` turn also costs tokens per round where
  copy-paste did not, though a continuing round is around a thousand
  characters.
- **The copy-paste loop with the real Claude app.** The formats are heavily
  tested against mangled input, but no reply from the actual app has been pasted
  back.

### Known gaps, deliberately deferred

- The `.mpx` bundle round-trips and is fully tested but is not wired to a file
  picker in the UI.
- Windows sleep inhibition, tray presence and launch-at-login are designed but
  unimplemented. A scheduled resume currently relies on the app being open, or
  is re-armed at next launch.
- Support for API keys other than Anthropic's is scaffolded by the transport
  seam but not built.

## Next

This build has to be installed the old way, by hand, because the copy on the
phone predates the updater. Then, in this order:

1. **A full round with the new prompt.** The reply should end in one `json`
   block; copy it with the block's own button, paste, and Apply should report
   what it settled rather than nothing.
2. **Save on the red-team pass.** Expect no dialog at all and a message naming
   Downloads, then attach the file in Claude in whichever chat you want. The
   MediaStore write is new untestable native code; if a picker appears instead,
   the insert was refused and it fell through, which still works but is worth
   reporting.
3. **Whether Claude's attach picker opens on Downloads.** Straight-to-Downloads
   trades a dialog for a little navigation, and only the device says whether
   that was the right trade. Whether Claude reads an attached `.md` as well as
   pasted text is the other open question; if it prefers `.txt` that is a
   one-line change.
4. **The reading view and the PDF.** Whether the brief is actually pleasant to
   read at twenty thousand characters on a phone, whether the tables survive
   the width, and whether the marks after a round land on the right passages
   and are few enough to be worth looking at. The PDF is generated on-device
   and saved to Downloads like any other export.
5. **Whether the recommendations are worth reading.** One that restates the
   option, or that would fit any mission, is worse than none — it means the
   prompt is not pushing hard enough on grounding them in what is settled. The
   early stages are where the model knows least about your intent and so where
   an invented preference is most likely; watch whether it ever says it has no
   basis, because a model that recommends confidently in every round is not
   being honest in all of them. And watch for anything landing in the JSON
   block that you did not pick — that is the failure this change risks.
6. **Whether the shorter rounds still land.** From round two on, the copied
   message is about a third the size. The thing to watch is whether the model
   keeps offering numbered options and keeps ending on the json block without
   being told at length each time — the reminder survives as one sentence, and
   if that turns out not to be enough it needs to grow back.
7. **The updater, from the menu.** With this build installed, the *next* CI
   build should surface a mark on the menu by itself. Download, install, and
   watch for the permission bounce — the first install is the one that asks.
8. **That it installs over the top without an uninstall**, keeping the saved
   missions. This is the first real test of the committed signing key, and the
   updater is worthless without it.
9. Whether the flow still feels guided now that the reply is a code block.

**On the PC, which is the only place the real question is answered:**

0. **`dart run tool/probe_cli.dart`** in `packages/mp_runner`, before anything
   else. It says what your install actually accepts — the session id, the model
   aliases, whether the prompt can go on stdin. Paste the output; it answers in
   one round trip what this project has otherwise had to guess at.
0b. **Install from `MasterPromptSetup-*.exe`.** Expect no administrator prompt,
   a Start-menu entry, an uninstall entry, and — the thing to check — your
   existing missions still there. If they are gone, the data migration is what
   went wrong and the old copy is still at
   `%APPDATA%\com.masterprompt\master_prompt`.

10. **Settings → Claude Code.** It should name the version, the path and the
    credential, or list every path it tried and why each failed. That list is
    the thing to send if it still cannot find it — it is written to say which
    install method is actually on the machine.
11. **A full interview round with no clipboard.** Ask Claude, read the reply,
    push back on a recommendation that is wrong, accept. Watch whether the
    round takes about as long as it would in the chat app, and whether the
    reply is as good — a `--print` turn is the same model but not the same
    surface.
12. **That the run still works as it did**, since it now shares one connection
    with Settings and the flow rather than probing separately.

### Lessons worth keeping

- Real file I/O cannot complete inside `testWidgets`. The widget tests now run
  against `AppStore(inMemory: true)`; persistence is tested separately outside
  that zone. A test that races on machine load is worse than no test.
- `AnimatedCrossFade` builds both branches, so a "collapsed" disclosure was
  still laying out its contents and still announcing them to a screen reader.
  Disclosures build lazily now.
- `MpTheme.colorsOf` no longer asserts. Modal routes are built from the
  Navigator, which can sit above wherever the theme was inserted, so asserting
  there turned a layout detail into a crash in dialogs and sheets.
- **Two parsers for two formats drifted apart, and the stricter one was the one
  the user hit.** `StateParser` had three fallbacks and `SpecPatchParser` had
  none, which nobody noticed because the tests for each only fed it what it
  already accepted. Where two things read the same kind of mangled input, they
  need the same tolerance and a test that proves it.
- **A negative margin is not available on `Container`** — it asserts. Pulling a
  change bar into the gutter needs every block to carry the same gutter and
  only the marked one to colour it, which keeps the text on one left edge
  anyway.
- **An accept step is not a UI detail, it is where the invariant is enforced.**
  The proposed/confirmed rule lives in `mp_core` and is thoroughly tested there,
  and it still failed in practice, because one of the two screens that take a
  patch never called the thing that promotes it. A rule enforced by a type is
  only enforced where something calls it.
- **`MpPanel` with an accent wraps its child in `IntrinsicHeight`**, which
  cannot measure a lazy viewport — a `ListView` inside an accented panel throws
  on layout. This is the second time that accent bar has caused a layout crash.
  The review panel renders a plain column instead, which is better anyway: a
  scroll area inside a scrolling page is miserable on a phone.
- **A branch behind `Platform.isWindows` is a branch with no test, and this
  session wrote three of them while fixing the first one.** The one-click
  update, the command-line length guard and the old-data-location lookup were
  all written behind an ambient platform check on a Linux runner, which means
  none of them could be executed by anything. They take the deciding value as a
  parameter now. The rule that came out of it: `Platform.isX` may *choose a
  default*, but must never *guard logic* — because the logic it guards is
  exactly the logic that cannot be reached.
- **A test that injects everything tests nothing.** Every `CliConversation`
  test injected the process runner and the session id, so the three functions
  that only exist against a real binary had zero executions while nine tests
  reported green. The fix was not more tests, it was removing the seam: argument
  composition became a pure function that can be inspected without a process,
  and the send path now always spawns.
- **A test double that accepts everything proves only that the code runs.**
  `fake_claude` validated exactly one argument combination, so it happily
  echoed back a session id of the shape `8-5-4-4-12`. It refuses what the real
  binary refuses now, in the real binary's words, and that single change turns
  the bug that reached a user into a failing test on a Linux runner.
- **A `sed`-style replace that does not match is silent.** Two edits this
  session were no-ops because `dart format` had reflowed the lines being
  matched, and both were caught only by a failing test rather than by the edit
  reporting anything. Replace by position, or check the result.
- **A correct fix to the wrong problem is still the wrong fix.** Splitting the
  oversized handover was carefully done — good seams, no lost text, no broken
  fences — and it did not help, because the cost was never the parts, it was
  the app switches. The measurement to take first was how many times the user
  has to move between apps, not how many characters fit in one.
- **A toast sits exactly where the next button is.** Confirming each copied
  part covered the control needed for the next one, seven times out of eight.
  Found by a widget test whose tap kept landing on the snackbar.
- **Two implementations of one idea meant the wrong one was load-bearing.**
  The resume capsule had careful paste-splitting; the brief and the red-team
  pass, which are longer and overflow first, had none. This is the second time
  the same shape of bug has surfaced — the first was two paste parsers with
  different tolerances. Where two things solve the same problem, one of them is
  being maintained and the other is being trusted.
- **A platform check and a layout check are not the same question.** The app
  has `isDesktop(context)`, which is a 900px width gate, and
  `DesktopRunner.isSupported`, which is the platform. A CLI feature keyed off
  the first would give a narrow window on a PC the phone experience and a
  tablet a Run button it cannot use. Everything about the CLI keys off the
  second.
- **Half-built is worse than not built, because it looks finished.** The run
  went through the CLI and the interview did not, and nothing on screen said
  so — the desktop simply behaved like the phone, which reads as a missing
  feature rather than a missing half. The tell was in the file: `flow_screen.dart`
  contained no reference to `DesktopRunner` at all.
- **A swallowed exception becomes a wrong answer, not a missing one.** `probe`
  caught `ProcessException` and returned null, so "Windows cannot execute a
  `.cmd`" was reported as "the CLI is not installed" — a confident,
  actionable, wrong answer that sends the user to reinstall something they
  already have. Catching an error and returning the same value as *absent*
  erases the difference between the two.
- A `Row` in a `PopupMenuItem` has no room to grow: the menu is 256 wide, so a
  long label overflows rather than wrapping. Found because the test font makes
  every glyph a full em square, which is a good reason to trust the overflow
  errors widget tests throw rather than treating them as artefacts.
