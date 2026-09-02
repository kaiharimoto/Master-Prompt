# The method

This project is a tool built around a method that already worked once, at scale: a twelve-hour,
~100M-token autonomous build that produced a complete photorealistic environment with no human
intervention. The people behind that run were explicit about what actually did the work, and it was
not model wrangling. It was the prompt — and, before the prompt, the discussion.

Three claims from that account shape everything here.

**Ask what before how.** Several rounds of discussion happened before a word of the brief was
written, on the principle that thoroughly establishing *what* is wanted lets the model end up
understanding the goal better than the author did. In this app that is the interview: a staged
conversation where runtime and build mechanics come deliberately last, because deciding them early
anchors the whole brief to an implementation before anyone has agreed what good means.

**Describe the result, not the procedure.** The reference brief spends far more of its length on
what a good outcome looks like than on how to produce one, and its authors said this mattered more
than modelling instructions. Hence the Quality stage, the palette and material vocabulary, the
detail standard — and the *avoid* list, which does as much work as any positive instruction because
it closes off the cliché the model would otherwise drift toward.

**Make the brief complete enough that nobody is needed.** An agent running for twelve hours cannot
ask a question. Every ambiguity becomes a guess, and nobody finds out until the run ends. That is
what the readiness gate is for: it refuses to compile while anything required is unresolved, and it
states the *consequence* of each omission rather than merely naming it.

---

## The anatomy

Every compiled brief has the same ten sections. The order is not cosmetic — it moves from the
machine, through the goal, to the work, to how the work is judged, and only then to the domain
content.

| Section | What it settles |
|---|---|
| `00 / RUNTIME` | The machine, the tools, the budget, the autonomy |
| `01 / TASK` | The mission, the through-line, the anti-goals |
| `02 / PROTOCOL` | Do the work; assume nobody is available; keep working documents; how to resume |
| `03 / BUILD ORDER` | Structure before detail, with cheap evidence captured early |
| `04 / REVIEW LOOP` | N cycles judged on captured evidence by fresh-context critics |
| `05 / RUBRIC` | Weighted categories to 100, an exit threshold, per-category floors |
| `06 / VALIDATION` | Reopen it cold, prove it works, report limitations honestly |
| `07 / BRIEF` | Required parts, component families with counts, quality language |
| `08 / DELIVERABLES` | The fixed numbered evidence set, and the file structure |
| `09 / FAILURE CONDITIONS` | What makes the result unacceptable |

### What was generalised

The reference brief is about a 3D scene. The concepts underneath it are not.

| In the reference | Here |
|---|---|
| Sixteen fixed camera renders | **Evidence set** — a numbered set of named artifacts, fixed before the build starts |
| Asset families with quantities | **Component families** — named groups with explicit minimum counts and a variation rule |
| Material and lighting language | **Quality language** — the vocabulary of good, plus the avoid list |
| Six fresh-context critics | **Critic roster** — reviewers with one judging brief each |
| Blender, Cycles, GPU | **Runtime** — tools, harness, budget, autonomy |

The essential property of the evidence set is not that it contains images. It is that the set is
**fixed in advance**, **numbered**, and **collectively proves coverage** — so every review cycle
re-captures identical evidence and a regression is visible by comparison rather than by memory.

### Two rules that carry most of the weight

**A part may never exist only as a label.** In the reference brief: no required room may exist only
as lettering on a closed door. Generalised: a required part may be compact, but its interior, its
boundaries and its relationship to the rest must be legible in the final evidence. Without this,
an agent under time pressure builds facades toward the hero view.

**Criticism is based on captured evidence, never on the builder's account of its own work.** A
critic that reads the code, the object tree, or the builder's summary inherits the builder's
rationalisations. Critics get the mission goal, the artifacts, and the rubric — nothing else.

---

## Continuity

A Claude Pro plan will hit its limits partway through a long mission. That is treated as a normal
condition, not an error path. Four layers, because no single one is sufficient.

**In the prompt.** Every brief mandates `TASK_STATE.md`, the working documents, checkpoints after
each stable stage, and an explicit resume clause. This is what makes an interrupted run resumable
*at all* — it works even if this app is uninstalled.

**The heartbeat.** Every reply must end with a small fenced `mpstate` block: phase, step, cycle,
score, next action, blockers. On a phone it is the only channel there is. On the desktop it does a
second job: micro-compaction is not reported to the event stream, so a divergence between what the
model claims and what the app recorded is the only available signal that context thinned silently.

The format is line-oriented `key=value`, not JSON, and that is a deliberate trade. Text that goes
through a chat UI and a system clipboard acquires smart quotes, reflowed lines, stripped fences and
markdown emphasis. JSON fails all-or-nothing under any of those; a restricted line grammar degrades
field by field, and a human can repair it by eye. Recoverability beats expressiveness in a channel
whose dominant failure is truncation.

**The supervisor** (desktop). Detects the limit, works out when it lifts, persists a resume that
survives closing the app and rebooting the machine, and reattaches to the same session. The
important detail is where it looks: the human-readable limit text **cannot** appear in the CLI's
JSON event stream, because `Error.message` is a non-enumerable property and the CLI serialises with
a plain `JSON.stringify`. stderr is therefore a first-class signal channel. See
[`cli-contract.md`](cli-contract.md).

**The resume capsule.** A self-contained block that carries the mission digest, the invariants, the
artifact ledger and the single next action into a brand-new conversation. Under a tight budget it
drops whole sections in priority order rather than summarising, because a capsule that paraphrases
the rubric produces a run that scores itself against a rubric that does not exist. Windows
cold-reseed and Android new-chat continuity use the same generator.

---

## Where the mechanism is proven

`packages/mp_runner/test/end_to_end_test.dart` runs the whole thing headlessly: a discussion patch
becomes a spec, the gate lets it compile, the brief is written to disk, a run is launched against a
fake CLI, a session limit interrupts it, the supervisor waits and resumes on the same session, the
run completes, the reported state is parsed back, and a capsule is built that could carry the
mission into a fresh conversation.

No API key, no real CLI, and no five-hour wait — which is the only way the recovery paths get
exercised at all.
