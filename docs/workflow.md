# How we work on this together

## Getting a build

Everything lives at one URL, which never changes:

**https://github.com/kaiharimoto/Master-Prompt/releases/tag/dev**

That tag always points at the newest green commit on the default branch. Bookmark
it on both devices.

### Android

Download the `.apk` and open it. The first time, Android will ask you to allow
installs from your browser — that permission is per-app and only needs granting
once.

Later builds install straight over the top and **your saved missions survive**,
because every build is signed with the same committed key. If Android ever
refuses an install with a signature error, something is wrong with the signing
config; tell me rather than uninstalling, because uninstalling deletes the
missions on that device.

### Windows

Download the `.zip`, extract it anywhere, run `master_prompt.exe`. SmartScreen
will warn that the publisher is unknown, because the binary is unsigned: *More
info* → *Run anyway*.

Nothing is installed, so a new build is just a fresh extract. Settings and
missions live in your user profile, not in the extracted folder, so replacing the
folder does not lose them.

## Reporting something

Just say it in chat. Rough is fine — "the readiness thing looks wrong on my
phone" is a perfectly good report.

If the app misbehaved, also open **Settings → Report a problem → Copy
diagnostics** and paste that in. It carries the build number and commit, the
current mission's state, the recent events, and anything captured from a crash.
On Android there is no log you can reach otherwise, so a crash without this is
invisible to both of us.

Screenshots are worth a great deal for anything visual. Tests cannot check
whether the typography feels right on a real screen, which is much of why this
loop exists at all.

## What happens next

**I fix without asking:** crashes, build failures, CI breakage, obvious bugs,
anything that is plainly not working as intended.

**We discuss first:** anything that changes how the app behaves or how it looks.
I will put the options to you rather than quietly redesigning something you
didn't ask about.

Either way I push, CI runs (about eight minutes, mostly the Android build), and
the `dev` release refreshes. Pull the same bookmark and you have it.

## Knowing which build you have

Settings shows `0.1.0+42 · a1b2c3d` — the version, the CI build number, and the
commit. Quote that if something seems off, or just paste the diagnostics, which
include it. Without it we can waste a round trip establishing whether you are
even testing the fix.

## When a session ends

I lose the conversation entirely. What survives is the repository: `CLAUDE.md`
for how the project works and the traps in it, and `docs/STATUS.md` for where we
had got to. I update `STATUS.md` as part of each change, so a new session starts
knowing what works, what is in flight, and what you were about to test.

That means it is worth telling me when something is **done and good**, not only
when it is broken — otherwise the next session sees an open question that was
actually settled.
