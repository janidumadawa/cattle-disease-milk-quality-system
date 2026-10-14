import 'package:flutter/material.dart';

import 'features/chatbot/chat_screen.dart';
import 'features/home/home_screen.dart';
import 'features/image_detection/scan_screen.dart';
import 'features/milk_quality/milk_quality_screen.dart';
import 'features/more/more_screen.dart';
import 'features/voice/voice_screen.dart';
import 'widgets/medfarm_bottom_nav.dart';

/// Main app layout: one tab per module, switched with the bottom nav bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _scanIndex = 1;

  static const _items = [
    MedFarmNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    MedFarmNavItem(
      label: 'Scan',
      icon: Icons.camera_alt_outlined,
      activeIcon: Icons.camera_alt,
    ),
    MedFarmNavItem(
      label: 'Voice',
      icon: Icons.mic_none_outlined,
      activeIcon: Icons.mic,
    ),
    MedFarmNavItem(
      label: 'Milk',
      icon: Icons.water_drop_outlined,
      activeIcon: Icons.water_drop,
    ),
    MedFarmNavItem(
      label: 'Chat',
      icon: Icons.chat_outlined,
      activeIcon: Icons.chat,
    ),
    MedFarmNavItem(
      label: 'More',
      icon: Icons.more_horiz,
      activeIcon: Icons.more_horiz,
    ),
  ];

  // Same order as _items.
  static const _pages = [
    HomeScreen(),
    ScanScreen(),
    VoiceScreen(),
    MilkQualityScreen(),
    ChatScreen(),
    MoreScreen(),
  ];

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab's state when switching tabs.
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: MedFarmBottomNav(
        items: _items,
        currentIndex: _currentIndex,
        raisedIndex: _scanIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
