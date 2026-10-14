import 'package:flutter/material.dart';

import '../../widgets/module_placeholder_screen.dart';

/// Image-based cattle disease detection.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholderScreen(
      title: 'Image-based Detection',
      icon: Icons.camera_alt_outlined,
      description: 'Take or upload a photo of the animal or the affected '
          'area to identify possible diseases.',
    );
  }
}
