# Status

A living note, updated as part of each change. It is the only thing that tells a
new session where we had got to, because feedback lives in chat rather than in
issues.

_Last updated: the commit that set up the development loop._

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

165 tests across the four packages.

### Not yet proven

- **Neither binary has been launched by a human.** Highest priority.
- **The Android signing config** has not yet produced an install-over-the-top.
  CI asserts the certificate fingerprint, which catches a broken config, but the
  actual update behaviour on a device is unverified.
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

The first smoke pass, in this order:

1. Both apps launch and show the empty state.
2. Create a mission — the readiness meter appears with blocking items listed.
3. Copy the round-one prompt into the Claude app, answer it, paste the reply
   back, and confirm the readiness meter moves.
4. Windows only: the Run tab either finds the Claude Code CLI or says clearly
   that it cannot.
5. Whether the typography and spacing actually look right on a real screen.

Then a second push, to confirm the APK installs over the first without an
uninstall.
