import 'package:flutter/material.dart';

import '../../widgets/module_placeholder_screen.dart';

/// Settings, profile and app information.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholderScreen(
      title: 'More',
      icon: Icons.more_horiz,
      description: 'Settings, profile and app information.',
    );
  }
}
