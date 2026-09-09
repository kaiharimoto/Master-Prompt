import 'package:flutter_test/flutter_test.dart';
import 'package:master_prompt/src/store/app_store.dart';
import 'package:master_prompt/src/store/project.dart';
import 'package:mp_core/mp_core.dart';

/// A pitch Master Idea actually produced, kept verbatim rather than written by
/// hand — a hand-written fixture drifts the moment the other half changes a
/// heading, and the seam between the two programs would then be tested against
/// a format nothing emits.
const String realPitch = '''
# An essay arguing that unattended machine work is only…

This is a launch document. It is the opening input to a build, not a summary of the deliberation that produced it. Everything below was chosen by the person whose project this is, out of a larger case file; what was not chosen is not here.

## What is being made

One proceeding rather than a pile of options.

The brief the client approved before any of this was explored, which the work still has to hold to:

An essay arguing that unattended machine work is only trustworthy when its reasoning is auditable afterwards by someone who was not there.

## The directions that were chosen

### Give the archive away and charge for the index

Publish every case file and sell only the index that makes one findable.

How it works: The archive is static and mirrored; the index is regenerated per client against their own question.

This is the reckless version of What the thing is for.

## What to do with this

Take the highest version of this that can actually be built, not the safest. Where a choice is not settled above, decide it and say what you decided. Where something above is assumed, treat it as a question you may reopen.

```mi-pitch
v=1
session=hm5a0feyuj
task=an-essay-arguing-that-unattended-machine-work-is-only
title=An essay arguing that unattended machine work is only…
medium=essay
tier=hearing
mission=One proceeding rather than a pile of options.
story=An essay arguing that unattended machine work is only trustworthy when its reasoning is auditable afterwards by someone who was not there.
scale=What the client said about appetite.
audience=What the client said about audience.
directions=d-0001
```
''';

void main() {
  // A plain `test`, not `testWidgets`: file I/O never completes inside the
  // tester's fake-async zone. The store is in memory for the same reason.
  test('a pitch opens a mission with everything still to be accepted', () async {
    final AppStore store = AppStore(inMemory: true);
    await store.load();

    final IdeaPitch? pitch = IdeaPitch.read(realPitch);
    expect(pitch, isNotNull);

    final Project p = await store.importPitch(pitch!);

    expect(store.projects, hasLength(1));
    expect(store.current, same(p));
    expect(p.spec.missionStatement.hasValue, isTrue);
    expect(
      p.spec.missionStatement.resolution,
      FieldResolution.proposed,
      reason:
          'Arriving from a program rather than a person changes nothing about '
          'what has to be agreed before an unattended run.',
    );
    expect(const ReadinessGate().evaluate(p.spec).canCompile, isFalse);
  });

  test('the whole pitch is kept, not only the values read out of it', () async {
    final AppStore store = AppStore(inMemory: true);
    await store.load();
    final Project p = await store.importPitch(IdeaPitch.read(realPitch)!);

    expect(p.transcript, hasLength(1));
    expect(p.transcript.single.direction, TranscriptDirection.received);
    expect(p.transcript.single.text, contains('The directions that were chosen'));
    expect(p.transcript.single.note, contains('Master Idea'));
    expect(
      p.hasAnsweredOnce,
      isTrue,
      reason:
          'A mission opened from a pitch already has something the interview '
          'can build on, so the next turn need not carry the whole framing '
          'again.',
    );
  });

  test('two pitches imported in a tight loop get two missions', () async {
    // The other half of this bug cost a mission on Windows: ids minted from a
    // coarse clock inside one tick collide, and the second import overwrites
    // the first.
    final DateTime frozen = DateTime.utc(2026, 3, 1, 9);
    final AppStore store = AppStore(inMemory: true, now: () => frozen);
    await store.load();
    final IdeaPitch pitch = IdeaPitch.read(realPitch)!;

    final Project a = await store.importPitch(pitch);
    final Project b = await store.importPitch(pitch);

    expect(a.id, isNot(b.id));
    expect(store.projects, hasLength(2));
  });
}
