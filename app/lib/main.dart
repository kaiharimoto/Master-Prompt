import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/store/build_info.dart';
import 'src/store/diagnostics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Installed before anything else runs, so a failure during startup is still
  // captured and can be reported after the restart.
  await Diagnostics.instance.install();
  Diagnostics.instance.log(
    'Started ${BuildInfo.label} on ${BuildInfo.platform}.',
  );
  runApp(const MasterPromptApp());
}
