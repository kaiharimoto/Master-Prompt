# Master Prompt

A studio for writing the kind of prompt that can run unattended for twelve hours.

Master Prompt does two things. First it holds a **structured discussion** with an LLM to work out
what you actually want — the "what" before the "how" — and turns that discussion into a typed
mission spec. Then it **compiles that spec into a master prompt**: a numbered brief with a weighted
rubric, an evidence-based review loop with fresh-context critics, mandated working documents, and a
cold-start validation. The prompt is complete enough that the build needs no human.

It runs on **Windows**, where it drives the Claude Code CLI directly, and on **Android**, where it
generates prompts you paste into the Claude app and parses the replies you paste back. Both
platforms share one core and ship from one release.

## Why it exists

It is modelled on a real run: a twelve-hour, ~100M-token autonomous Blender build that produced a
complete restaurant environment with no human intervention. The people behind it were explicit that
the prompt — not the model wrangling — was the work, and that several rounds of discussion before
writing it mattered more than any modelling instruction. This project turns that method into a tool,
generalised past 3D so it works for software, analysis, documents and anything else.

## Structure

```
packages/mp_core/     Spec model, prompt compiler, interview engine, continuity protocol.
                      Pure Dart — no Flutter, no dart:io, fully unit-testable.
packages/mp_runner/   Claude Code CLI discovery, capability probing, stream-json ingestion,
                      limit detection and durable auto-resume. dart:io only.
packages/mp_design/   Design system and typography.
app/                  The Flutter app for Android and Windows.
docs/                 Verified CLI contract and the method behind the prompt anatomy.
```

`mp_core` and `mp_runner` carry the logic that has to be right when a run is nine hours in and
unattended, so neither depends on Flutter and both are testable headlessly in CI.

## The prompt anatomy

Every compiled prompt has the same ten sections:

| Section | Purpose |
|---|---|
| `00 / RUNTIME` | The machine, the tools, the budget, and how much autonomy the agent has |
| `01 / TASK` | The mission, the defining story, and the explicit anti-goals |
| `02 / PROTOCOL` | Do the work; assume the user is unavailable; keep working documents; how to resume |
| `03 / BUILD ORDER` | Structure before detail, with cheap evidence captured early |
| `04 / REVIEW LOOP` | N cycles judged on captured evidence by fresh-context critics |
| `05 / RUBRIC` | Weighted categories to 100 with an exit threshold and per-category floors |
| `06 / VALIDATION` | Reopen it cold, prove it still works, report limitations honestly |
| `07 / BRIEF` | The domain content: required parts, families with counts, quality language |
| `08 / DELIVERABLES` | The fixed, numbered evidence set and the file structure |
| `09 / FAILURE CONDITIONS` | What makes the result unacceptable |

## Continuity

A Claude Pro plan will hit its limits partway through a long run. That is treated as a normal
condition, not an error:

- Every compiled prompt mandates `TASK_STATE.md`, checkpoints, and a resume clause, so an
  interrupted run is resumable even without this app.
- Every reply must end with a small `mpstate` heartbeat block, which the app parses to track
  progress — and which doubles as a compaction detector on the desktop.
- On Windows a supervisor detects the limit, schedules a resume that survives a reboot, and
  re-attaches to the same CLI session automatically.
- On Android a **resume capsule** carries everything a brand-new chat needs to continue mid-flight.

## Status

Under active development. See `docs/` for the verified CLI contract that the runner is built
against.
