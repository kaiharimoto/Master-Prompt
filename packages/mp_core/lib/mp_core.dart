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
