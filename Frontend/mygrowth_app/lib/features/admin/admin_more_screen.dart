import 'package:flutter/material.dart';

import '../../app/area_shell.dart';
import '../more/more_screen.dart';

/// Admin "More" tab.
///
/// Reuses the shared menu screen with the admin item set so the admin and
/// member areas stay visually consistent.
class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context) => const MoreScreen(area: AppArea.admin);
}
