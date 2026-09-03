# Status

A living note, updated as part of each change. It is the only thing that tells a
new session where we had got to, because feedback lives in chat rather than in
issues.

_Last updated: the commit that set up the development loop._

The loop itself is live: `docs/workflow.md` describes it, CI publishes a rolling
`dev` prerelease on every green push, and Settings carries a Copy diagnostics
button. The core job runs on plain Dart in about 35 seconds.

## Where things stand

The app is built end to end and both platforms compile on CI. **Nothing has yet
been run on real hardware** — everything so far is CI output, headless tests and
widget tests. The first real test is the first thing to do.

### Works, and is verified

- **The compiler.** A `MissionSpec` renders to a ten-section brief. The
  acceptance test reconstructs the reference Blender brief and asserts the
  output carries every section, the 100-point rubric with its floors, all
  sixteen numbered artifacts, six critics and every failure condition.
- **The interview and readiness gate.** Staged discussion, `mpspec` patches
  accumulating across rounds, compilation refused while anything required is
  unresolved.
- **Continuity.** The `mpstate` parser survives deliberately mangled input and
  never discards a paste; resume capsules degrade by dropping sections rather
  than summarising; mission bundles round-trip and reject truncation.
- **The supervisor.** Limit detection, the reset-time ladder, persisted resumes
  and the resume ladder, all driven against a fake CLI so the recovery paths are
  exercised without an API key or a five-hour wait.
- **End to end, headlessly:** discussion patch → spec → gate → compile → write to
  disk → launch → session limit → wait → resume on the same session → complete →
  parse state back → build a capsule. `packages/mp_runner/test/end_to_end_test.dart`.

170 tests across the four packages.

### Not yet proven

- **The redesign has not been seen on a device.** Whether it actually feels
  guided rather than dense is the open question, and only a phone can answer it.
- **The Android signing config** has not yet produced an install-over-the-top.
  CI asserts the certificate fingerprint, which catches a broken config, but the
  actual update behaviour on a device is unverified — the redesign build is the
  first chance to confirm it.
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

Judging the redesign, in this order:

1. The app opens on one question, not a checklist.
2. A full round: copy, paste into Claude, bring the reply back, accept — and
   whether it feels like being carried rather than driving.
3. Whether the type is large and heavy enough at arm's length.
4. That everything from the old screens is still findable in the menu.
5. **That this APK installs over the previous one without an uninstall.** This
   is the first real test of the committed signing key.

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
