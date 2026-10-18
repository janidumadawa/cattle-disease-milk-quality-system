import 'package:flutter/material.dart';

import '../../widgets/module_placeholder_screen.dart';

/// Cattle health chatbot.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholderScreen(
      title: 'Chatbot',
      icon: Icons.chat_outlined,
      description: 'Ask questions about cattle health and farm care.',
    );
  }
}
