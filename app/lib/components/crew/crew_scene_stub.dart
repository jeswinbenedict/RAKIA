import 'package:flutter/widgets.dart';

import 'crew_scene.dart';

/// Native platforms have no WebGL scene: a still deep-space panel.
Widget buildCrewScene(BuildContext context, {required bool compact}) =>
    CrewBackdrop(
      key: const Key('crew-fallback'),
      message: compact ? null : 'The 3D crew appears in the RAKIA web app.',
    );
