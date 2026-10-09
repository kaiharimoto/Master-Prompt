# Voice

How a Master UI app talks. Quiet, exact, a little dry; written by someone who respects the reader's time and assumes they are competent. Every example below is a real string from Music Master.

## 1. Rules

1. **Sentence case** for everything: titles, buttons, tabs, menu items, dialog titles, column headers. `Train a sound`, not `Train A Sound`. Micro caps are a typographic treatment applied by `.t-micro`; the source string stays sentence case.
2. **No exclamation marks.** Not in toasts, not in empty states, not in onboarding. The only `!` in the app is a glyph in a checklist's mono column meaning "check failed".
3. **No emoji.** Text glyphs (`→ ✓ ✕ ○ ● ★ ♥ ≈ ·`) do the work.
4. **British spelling**: randomise, normalised, licence, colour, grey, favourite.
5. **No filler.** No "Oops", "Awesome", "Let's", "Please", "Successfully", "Welcome to". No "…" except the literal `compiling…` while compiling.
6. **Numbers first.** `4 songs queued`, `128 songs · 12 liked`, `≈ 3 GB · 5 min`.
7. **Say what happened or what will happen**, not how the user should feel.
8. **The app never names itself in a sentence.** The name lives in the wordmark and the window title.

## 2. Buttons and links

Verb first; one or two words; the count if there is one. Forward motion ends with `→`; going back starts with `←`.

`Create` · `Create 4` · `Write it` · `Write with Claude` · `Fix sections` · `Enhance` · `Adapt` · `Suggest` · `Recent` · `Compare` · `Clear finished` · `Unload model` · `Load YuE2-3B` · `Train a sound` · `Use in Create` · `Choose file` · `Change` · `Transcribe →` · `Use previous transcription →` · `Choose a style →` · `Render cover →` · `← Back` · `Render` · `Derive` · `From narrative` · `Reset` · `Start over` · `Begin →` · `Install →` · `Start creating →` · `Run again` · `Cancel` · `Delete` · `Save` · `Save draft` · `Preview` · `Pause` · `Strip chords` · `Revert` · `Detect gaps` · `Split into 3` · `Add file` · `Refresh` · `Re-check` · `Check now` · `Open` · `Open setup` · `Restart engine` · `Logs` · `Switch to B` · `Randomise`

Micro links (`.t-micro .link`): `Switch to custom` · `Back to description` · `Open in custom` · `All songs →` · `Show log` / `Hide log` · `Skip for now` · `Continue with the stand-in model` · `Get Claude Code →` · `Open setup →` · `Score ready — show`

Segmented labels are nouns or numbers: `Simple | Custom`, `Grid | List`, `Both | Notation | ABC`, `1 | 2 | 4 | 8`.

## 3. Titles and labels

- Page titles are one noun: `Create`, `Covers`, `Structure`, `Library`, `Queue`, `Sounds`, `Settings`, `Setup`. Numbered `01`–`08`.
- Section titles are nouns or short noun phrases: `System`, `Engine`, `Export`, `What gets set up`, `Transcribed melody`, `Lyrics for the cover`.
- Field labels are nouns: `Planning`, `Quality`, `Max length`, `Seed`, `Presets`, `Variations`, `GPU memory budget`. A label may carry a right-aligned mono hint with the current value: `12 steps`, `3:00`.
- Stat labels: `GPU`, `Runtime`, `Model`, `VRAM`.
- Kickers (micro caps above content): `Latest`, `Up next`, `Active`, `History`, `Engine`, `Cover`, `Re-render`, `Structure`, `Plan`, `Done`.

## 4. Empty states

A short sentence with a full stop, then one explanatory line that tells the user what to do or what this place is for.

| Title | Line |
|---|---|
| `Nothing yet.` | `Describe a song on the left, or write the lyrics and a style, then create.` |
| `Empty.` | `Everything you create is kept here.` |
| `No matches.` | `Try a different search or filter.` |
| `No sounds yet.` | `Pick 5–30 recordings with a consistent character (a voice, an instrument, a production style), give the sound a trigger word, and train. Expect 20–60 minutes on this GPU for 800 steps.` |
| `Drop a song.` | `MP3, WAV, FLAC, M4A. Best results with a clear lead vocal or melody.` |

Small inline empties are micro caps without a full stop: `Nothing running` · `Nothing playing` · `Queue is empty` · `Nothing compiled yet` · `Instrumental — no lyrics.` (a sentence, so it keeps its full stop).

## 5. Status and progress

Micro-caps words: `Engine ready` · `Engine offline` · `Engine stopped` · `Queued` · `Working` · `Waiting` · `Checking` · `Inspecting` · `Loading settings` · `Loading model parameters` · `✕ Failed` · `Playing` · `Paused` · `up to date` · `optional` · `edited` · `custom` · `cut at length cap` · `render time learned after first song` · `Draft — edit anything, then create`.

Progress lines are mono: `57% · 1m 20s left` · `0:42 so far` · `120/400 tokens · 8.3/s` · `3/7` · `45s`.

Install-state headlines are one word with a full stop in `.t-display`: `Installing.` · `Paused.` · `Stopped.` · `Ready.`

## 6. Toasts

A state or a past-tense fact; optionally an em-dash clause or a second sentence with the next step. Action label is a single noun.

`Queued` · `4 songs queued` · `Cover queued` · `Render queued` · `4 variations queued` · `Stem separation queued` · `Loading model` · `YuE2 is ready` · `Prompt copied` · `Song deleted` · `Preset saved` · `Score draft saved` · `Exporting MP3` · `Ranking 4 candidates` · `Scoring this song` · `3 clips found` · `Melody transcribed. Review it before rendering.` · `Score loaded into Create. Adjust the style, then create.` · `Structure derived — check the bars against your target, then render.` · `Training queued — follow it on this page or in the queue.` · `Token saved — MuScriptor will download its weights on first use.` · `Using “Clip 2” as the melody source` · `Transcribing 0:12–0:48 only` · `No gaps found — add splits by double-clicking the waveform` · `Update 1.2.0 available` + `Download it from the title bar when convenient.` · `A job is running` + `Wait for it to finish (or cancel it) before restarting.`

Errors: the system's message verbatim, or a short prefix: `Playback failed: …` · `Update check failed: …`.

## 7. Help and descriptions

One or two plain sentences that state what the thing does and the trade-off. No "This option allows you to".

`Upper bound the model may allocate. Leave 1–2 GB for the display.` · `Skips moving the 3B model to system RAM before the VAE runs. Much faster; needs ~4 GB free VRAM (falls back automatically).` · `Runs a short dummy decode when the model loads so the first song is not slow.` · `FP8 lowers VRAM use for the autoregressive stages at a small quality cost. NVIDIA Ada/Hopper only.` · `Never contact Hugging Face; fail if weights are missing locally.` · `Where exported files are copied. Empty keeps them inside the library.` · `EBU R128 loudnorm on export. The library master is untouched.` · `Seconds.` · `Auto-detected. Override to use a specific build.` · `A click on Create and a two-note chime when a song finishes.` · `Environments, models and your library.` · `Changing backend, device, budget, quantization or repositories reloads the model on the next job.`

Option help inside a select: `Composes an editable score before rendering. Most controllable.` · `Fastest when it works` · `No graph capture; most compatible` · `Very slow; for testing the UI`.

Page subtitles: `One job at a time on the GPU. Drag queued jobs to reorder.` · `Train a timbre / production style from your recordings and apply it to any render. Melody and lyrics stay untouched.` · `Plan an instrumental section by section; the theme comes from a transcribed clip. Compiled into a real YuE2 score.`

Welcome line: `Songs from words. Composed, sung and mixed on your GPU.`

## 8. Tooltips

A sentence without a full stop unless there are two; or a shortcut. Tooltips explain disabled buttons.

`Ctrl + Enter` · `Seed locked — same seed every run. Click to randomise.` · `Random seed each run. Click to lock the next seed.` · `Add or repair section labels without changing the words` · `Rewrite this into a richer, more precise style prompt with Claude` · `Transpose down a semitone` · `Remove chord symbols so the accompaniment is composed freely` · `Save current settings as a preset` · `Reset to model defaults` · `Find silent gaps and put a split in each one` · `Name, trigger and at least one source` · `Queue the training job` · `Add a style prompt first` · `Let YuE2 write this section` · `Cancel` · `Remove` · `Like` / `Unlike` · `Shuffle` · `Repeat off` / `Repeat all` / `Repeat one` · `Claude is working — show the panel`.

## 9. Confirmations and danger

Only destruction gets a dialog. Title is the action; body says what is removed and that it cannot be undone; buttons are ghost `Cancel` then `Delete`.

> **Delete song**
> “Midnight Freight” and its files will be removed. This cannot be undone.
> `Cancel` `Delete`

Danger in a menu: `✕ Delete` in `font-medium`. No red anywhere.

## 10. Numbers, units, time, keys

| Kind | Format | Examples |
|---|---|---|
| duration | `m:ss`, unknown `--:--`, clip `m:ss.s` | `2:34`, `1:03.4` |
| ETA / elapsed | `Ns`, `Mm SSs`, `Hh Mm` | `45s`, `3m 05s`, `1h 12m` |
| relative time | `just now`, `Nm ago`, `Nh ago`, `Nd ago`, then locale date | `5m ago` |
| estimate | `≈ ` prefix | `≈ 2:40`, `≈ 3 GB · 5 min` |
| range | en dash | `10–20 min`, `1–2 GB`, `5–30 recordings`, `0:12–0:48` |
| separator | ` · ` | `3:42 · Melody + chords · seed 12345 · 2h ago` |
| units | space before | `16 GB`, `120 BPM`, `44100 Hz`, `-14 LUFS`, `800 steps`, `12 s`, `rank 32` |
| percent | no space | `57%` |
| multiples | `×` | `×4`, `Compare “Batch” ×4` |
| thousands | `toLocaleString()` | `1,204 / 12,000` |
| index | two digits | `01`, `02` |
| rank / score | `#1`, two decimals | `#1`, `0.71` |
| version | plain | `Update 1.2.0 available` |
| shortcut in a Kbd | space, no plus | `Ctrl K`, `Esc`, `Ctrl J` |
| shortcut in prose | plus with spaces | `Ctrl + Enter` |
| shortcut hint line | ` · ` list | `Space play · Tab switch · 1–5 rate`, `1–5 rate · L like` |
| never | | `⌘`, `CMD`, `Ctrl+K` in a Kbd |

Quotes in copy are curly: `“Clip 2”`. Dashes are em dashes with spaces (`Seed locked — same seed every run`) except in ranges.

## 11. Theme and system words

Themes are `Paper` (light) and `Ink` (dark); the command is `Switch to ink (dark)` / `Switch to paper (light)`. The rail's toggle says the destination: `Dark` / `Light`. The engine is `Engine`; models by their name (`YuE2-3B`); the assistant by its name (`Claude`) with the actions `Let Claude take over`, `Toggle Claude panel`.
