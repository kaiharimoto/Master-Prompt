# Status

A living note, updated as part of each change. It is the only thing that tells a
new session where we had got to, because feedback lives in chat rather than in
issues.

_Last updated: the commit that made the reply one JSON block and added the
in-app updater._

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

### Works, and is verified

- **The compiler.** A `MissionSpec` renders to a ten-section brief. The
  acceptance test reconstructs the reference Blender brief and asserts the
  output carries every section, the 100-point rubric with its floors, all
  sixteen numbered artifacts, six critics and every failure condition.
- **The interview and readiness gate.** Staged discussion, patches accumulating
  across rounds, compilation refused while anything required is unresolved. The
  prompt asks for numbered options so a reply can be a list of numbers, and for
  one JSON block so bringing it back is one tap.
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

223 tests: 112 in `mp_core`, 71 in `mp_runner`, 40 in the app.

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
2. **The updater, from the menu.** With this build installed, the *next* CI
   build should surface a mark on the menu by itself. Download, install, and
   watch for the permission bounce — the first install is the one that asks.
3. **That it installs over the top without an uninstall**, keeping the saved
   missions. This is the first real test of the committed signing key, and the
   updater is worthless without it.
4. Whether the flow still feels guided now that the reply is a code block.

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
- A `Row` in a `PopupMenuItem` has no room to grow: the menu is 256 wide, so a
  long label overflows rather than wrapping. Found because the test font makes
  every glyph a full em square, which is a good reason to trust the overflow
  errors widget tests throw rather than treating them as artefacts.
