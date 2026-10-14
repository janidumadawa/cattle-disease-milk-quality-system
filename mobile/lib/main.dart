
import 'package:flutter/material.dart';

import 'app_shell.dart';

void main() {
  runApp(const MedFarmApp());
}

class MedFarmApp extends StatelessWidget {
  const MedFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF006239);

    return MaterialApp(
      title: 'MedFarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
        ),
      ),
      home: const AppShell(),
    );
  }
}
