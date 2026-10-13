
import 'package:flutter/material.dart';

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
      home: const MedFarmHomePage(),
    );
  }
}

class MedFarmHomePage extends StatelessWidget {
  const MedFarmHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF006239);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MedFarm'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.agriculture_outlined,
                  size: 64,
                  color: primaryGreen,
                ),
                const SizedBox(height: 20),
                Text(
                  'MedFarm',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cattle Disease Detection and '
                  'Milk Quality Analysis System',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Shared mobile application foundation',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
