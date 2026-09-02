/// Domain core for Master Prompt.
///
/// Pure Dart: no Flutter, no `dart:io`. Everything here is unit-testable
/// without a UI, a process, or a network — which matters because this is the
/// logic that has to be right when a run is nine hours in and unattended.
library;

export 'src/compile/compiled_prompt.dart';
export 'src/compile/prompt_compiler.dart';
export 'src/spec/mission_spec.dart';
export 'src/spec/spec_field.dart';
export 'src/spec/spec_sections.dart';
export 'src/spec/spec_types.dart';
export 'src/continuity/mp_state.dart';
export 'src/continuity/state_parser.dart';
export 'src/continuity/resume_capsule.dart';
export 'src/interview/interview_engine.dart';
export 'src/interview/interview_stage.dart';
export 'src/interview/readiness.dart';
export 'src/interview/spec_patch.dart';
export 'src/continuity/bundle.dart';
