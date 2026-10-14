import 'package:flutter/material.dart';

import '../../widgets/module_placeholder_screen.dart';

/// Voice-based cattle health analysis.
class VoiceScreen extends StatelessWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholderScreen(
      title: 'Voice-based Analysis',
      icon: Icons.mic_none_outlined,
      description: 'Record audio to support cattle health checks.',
    );
  }
}
