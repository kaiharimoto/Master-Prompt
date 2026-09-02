# Claude Code CLI contract

Everything here was **verified by inspection and execution** against a real install, not taken
from documentation. Documentation for this CLI drifts; several widely-repeated claims turned out
to be wrong for the build we tested. Re-run `tool/probe_cli.dart` against any new version before
trusting this file.

**Verified against:** `@anthropic-ai/claude-code` **v2.1.42** (`cli.js`, 11.5 MB).

---

## 1. The finding that shapes the whole supervisor

`Error.message` and `Error.stack` are **non-enumerable** JavaScript properties, and the CLI
serialises stream events with a plain `JSON.stringify` and no replacer. Therefore:

```js
JSON.stringify(new Error("You've hit your session limit"))  // => {}
```

**Human-readable limit text can never appear in the `stream-json` stdout stream.** Any design that
greps stdout JSON for "you've hit your session limit" will match nothing, forever, and will present
as a silent hang rather than a detected limit.

Consequence: **stderr is a first-class signal channel**, captured and scanned separately from
stdout. stdout gives structured retry *timing*; stderr gives the *reason*. The supervisor needs
both and treats neither as sufficient alone.

## 2. `stream-json` is gated on `--verbose`

```js
else if ($.outputFormat === "stream-json" && $.verbose) await O.write(k)
```

Without `--verbose`, `--output-format stream-json` writes **nothing at all**. Silence is
indistinguishable from a hang. `LaunchPlanBuilder` asserts `stream-json ⇒ verbose` at build time so
this combination cannot be constructed.

## 3. `system` event subtypes that actually exist

Confirmed present in the binary:

| Subtype | Notes |
|---|---|
| `init` | First event. Carries `session_id`, model, tools. |
| `api_error` | **This is the retry/error event.** |
| `compact_boundary` | Carries `{trigger, pre_tokens}`. |
| `microcompact_boundary` | Exists internally. |

There is **no `api_retry` subtype**. Documentation claiming one is wrong; `tengu_api_retry` is an
internal telemetry counter, not a wire event. Detect on `api_error`.

## 4. Closed enums

**`rateLimitType`** — exactly five values:

```
five_hour   seven_day   seven_day_opus   seven_day_sonnet   overage
```

`five_hour` and the `seven_day*` family need different handling. A weekly limit is **account-scoped,
not device-scoped** — telling the user to switch to their phone does not help, and the UI must not
imply it does.

**`result` subtypes** — exactly five:

```
success   error_during_execution   error_max_turns
error_max_budget_usd   error_max_structured_output_retries
```

## 5. Session identity: pre-assign, don't capture

`--session-id <uuid>` lets the caller **choose** the session id before spawning. This is strictly
better than reading `session_id` out of the `init` event, because a process that dies before `init`
(bad auth, missing cwd, instant rejection) would otherwise leave a run with no resumable identity.

Mutual exclusion, verified verbatim from the binary:

```
--session-id can only be used with --continue or --resume if --fork-session is also specified.
```

Encoded as an invariant in `LaunchPlanBuilder`.

## 6. Flag surface (v2.1.42)

Present and used by the runner:

```
-p, --print                    --output-format <text|json|stream-json>
--verbose                      --include-partial-messages
--session-id <uuid>            --fork-session
-r, --resume [value]           -c, --continue
--model <model>                --effort <level>
--permission-mode <mode>       --dangerously-skip-permissions
--allowedTools / --disallowedTools
--add-dir <dirs...>            --append-system-prompt <prompt>
--settings <file-or-json>      --fallback-model <model>
--max-budget-usd <amount>      --no-session-persistence
--json-schema <schema>         --input-format <text|stream-json>
```

Two corrections to commonly-cited documentation:

- **`--effort` accepts only `low, medium, high`** in this build. `xhigh`, `max` and `ultracode`
  are *not* valid here. The probe reads the allowed values out of the `(choices: ...)` fragment in
  `--help` rather than assuming them.
- **There is no `--autocompact` flag**, and no `--bare` flag, in this build.

`--permission-mode` choices: `acceptEdits, bypassPermissions, default, delegate, dontAsk, plan`.

## 7. Why the capability probe exists

The two corrections above are exactly the failure this project must not have: a flag composed from
documentation that the installed binary rejects, discovered nine hours into an unattended run.

`CliCapabilityProbe` parses `--help` into a `CapabilityProfile` — flag names *and* their enumerated
choices — cached against a fingerprint of the binary. The CLI auto-updates, so the fingerprint is
re-checked before every launch and the profile is rebuilt when it changes. Nothing in the launch
path hardcodes a flag or a flag value.

## 8. Nested-session guard

The CLI refuses to start inside another Claude Code session:

```
Error: Claude Code cannot be launched inside another Claude Code session.
```

It keys off the `CLAUDECODE` environment variable. The runner strips `CLAUDECODE` and
`CLAUDE_CODE_ENTRYPOINT` from the child environment so Master Prompt can drive the CLI even when
Master Prompt itself was launched from one.
