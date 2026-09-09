import 'package:mp_core/mp_core.dart';
import 'package:test/test.dart';

/// A pitch Master Idea actually produced, kept verbatim.
///
/// Written by hand it would drift the moment the other half changed a heading,
/// and the seam between the two programs would then be tested against a format
/// nothing emits. This is the output of a real session run through
/// `mi run` and `mi select`.
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

MissionSpec blank() => MissionSpec(
  id: 'm1',
  taskId: 'untitled',
  title: 'Untitled mission',
  presetId: 'generic',
  createdAt: DateTime.utc(2026),
);

void main() {
  group('reading a pitch from Master Idea', () {
    test('finds the block inside the prose', () {
      final IdeaPitch? pitch = IdeaPitch.read(realPitch);
      expect(pitch, isNotNull);
      expect(pitch!.sessionId, isNotEmpty);
      expect(pitch.medium, 'essay');
      expect(pitch.tier, 'hearing');
      expect(pitch.mission, isNotEmpty);
      expect(pitch.directionIds, isNotEmpty);
    });

    test('keeps the whole document, not just the block', () {
      final IdeaPitch pitch = IdeaPitch.read(realPitch)!;
      expect(pitch.document, contains('The directions that were chosen'));
      expect(
        pitch.document.length,
        greaterThan(pitch.mission.length * 3),
        reason:
            'The block is a summary; the prose carries the reasoning, the '
            'integration and the marked assumptions. An import that kept '
            'only the block would start the mission from four sentences.',
      );
    });

    test('is not confused by ordinary text', () {
      expect(IdeaPitch.read('Just a paste of something else.'), isNull);
      expect(
        IdeaPitch.read('```mi-pitch\nsession=x\n```'),
        isNull,
        reason: 'A block with no version is not a block this build can read.',
      );
    });

    test('survives being cut off by a paste ceiling', () {
      // Line-oriented for exactly this: the tail is lost and the fields before
      // it still arrive. A JSON object cut here would read as nothing at all.
      final int cut = realPitch.indexOf('audience=');
      final IdeaPitch? pitch = IdeaPitch.read(realPitch.substring(0, cut));
      expect(pitch, isNotNull);
      expect(pitch!.mission, isNotEmpty);
      expect(pitch.audience, isEmpty);
      expect(pitch.isUsable, isTrue);
    });
  });

  group('seeding a mission from one', () {
    test('fills what the pitch carries and nothing else', () {
      final IdeaPitch pitch = IdeaPitch.read(realPitch)!;
      final MissionSpec spec = pitch.seed(blank());

      expect(spec.missionStatement.value, pitch.mission);
      expect(spec.definingStory.value, pitch.story);
      expect(spec.audience.value, pitch.audience);
      expect(spec.title, pitch.title);
    });

    test('everything arrives proposed, never confirmed', () {
      final MissionSpec spec = IdeaPitch.read(realPitch)!.seed(blank());
      for (final SpecField<String> f in <SpecField<String>>[
        spec.missionStatement,
        spec.definingStory,
        spec.scale,
        spec.audience,
      ]) {
        if (!f.hasValue) continue;
        expect(
          f.resolution,
          FieldResolution.proposed,
          reason:
              'The council that wrote those sentences is a model, however '
              'carefully its client chose which directions to keep. A value '
              'nobody in this conversation has accepted must not satisfy the '
              'readiness gate.',
        );
        expect(f.resolution.satisfiesGate, isFalse);
      }
      expect(spec.proposedCount, greaterThan(0));
    });

    test('an imported mission still has to pass the same gate', () {
      final MissionSpec spec = IdeaPitch.read(realPitch)!.seed(blank());
      final ReadinessReport report = const ReadinessGate().evaluate(spec);
      expect(
        report.canCompile,
        isFalse,
        reason:
            'Arriving from a program rather than a person changes nothing '
            'about what has to be agreed before an unattended run.',
      );
    });

    test('an empty field in the block leaves the spec field alone', () {
      final IdeaPitch pitch = IdeaPitch.read(realPitch)!;
      const IdeaPitch hollow = IdeaPitch(
        document: 'x',
        sessionId: 's',
        taskId: 't',
        title: '',
        medium: 'essay',
        tier: 'hearing',
        mission: 'Something to build.',
        story: '',
        scale: '',
        audience: '',
        directionIds: <String>[],
      );
      final MissionSpec spec = hollow.seed(blank());
      expect(spec.title, 'Untitled mission');
      expect(spec.definingStory.hasValue, isFalse);
      expect(spec.missionStatement.value, 'Something to build.');
      expect(pitch.provenance, contains('proposed'));
    });
  });
}
