# Status

A living note, updated as part of each change. It is the only thing that tells a
new session where we had got to, because feedback lives in chat rather than in
issues.

_Last updated: the commit that gave every question a recommendation._

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
- **End to end, headlessly:** discussion patch → spec → gate → compile → write to
  disk → launch → session limit → wait → resume on the same session → complete →
  parse state back → build a capsule. `packages/mp_runner/test/end_to_end_test.dart`.

267 tests: 139 in `mp_core`, 71 in `mp_runner`, 57 in the app.

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
- **The desktop runner against a real `claude` binary.** Everything is proven
  against the fake CLI; the real one has never been driven from the app.
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
4. **Whether the recommendations are worth reading.** One that restates the
   option, or that would fit any mission, is worse than none — it means the
   prompt is not pushing hard enough on grounding them in what is settled. The
   early stages are where the model knows least about your intent and so where
   an invented preference is most likely; watch whether it ever says it has no
   basis, because a model that recommends confidently in every round is not
   being honest in all of them. And watch for anything landing in the JSON
   block that you did not pick — that is the failure this change risks.
5. **Whether the shorter rounds still land.** From round two on, the copied
   message is about a third the size. The thing to watch is whether the model
   keeps offering numbered options and keeps ending on the json block without
   being told at length each time — the reminder survives as one sentence, and
   if that turns out not to be enough it needs to grow back.
6. **The updater, from the menu.** With this build installed, the *next* CI
   build should surface a mark on the menu by itself. Download, install, and
   watch for the permission bounce — the first install is the one that asks.
7. **That it installs over the top without an uninstall**, keeping the saved
   missions. This is the first real test of the committed signing key, and the
   updater is worthless without it.
8. Whether the flow still feels guided now that the reply is a code block.

Windows separately: the Run destination either finds the Claude Code CLI or says
clearly that it cannot.

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
- A `Row` in a `PopupMenuItem` has no room to grow: the menu is 256 wide, so a
  long label overflows rather than wrapping. Found because the test font makes
  every glyph a full em square, which is a good reason to trust the overflow
  errors widget tests throw rather than treating them as artefacts.
