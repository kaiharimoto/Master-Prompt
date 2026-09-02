/// Desktop process supervision for Master Prompt.
///
/// `dart:io` only — no Flutter — so the supervisor, the limit detector and the
/// resume ladder can all be exercised headlessly in CI against a fake CLI,
/// without an API key and without waiting five hours for a real usage limit.
library;

export 'src/cli/capability_profile.dart';
export 'src/cli/launch_plan.dart';
export 'src/stream/cli_event.dart';
export 'src/supervisor/limit_detector.dart';
export 'src/supervisor/clock.dart';
export 'src/supervisor/run_record.dart';
export 'src/supervisor/run_supervisor.dart';
export 'src/cli/cli_locator.dart';
