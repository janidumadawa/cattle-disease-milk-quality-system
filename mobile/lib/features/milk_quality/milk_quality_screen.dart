import 'package:flutter/material.dart';

import '../../widgets/module_placeholder_screen.dart';

/// Raw milk quality pre-screening.
class MilkQualityScreen extends StatelessWidget {
  const MilkQualityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholderScreen(
      title: 'Milk Quality Check',
      icon: Icons.water_drop_outlined,
      description: 'Pre-screen raw milk quality using sensor readings.',
    );
  }
}
