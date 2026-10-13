import 'package:flutter/material.dart';

void main() {
  runApp(const MedFarmApp());
}

class MedFarmApp extends StatelessWidget {
  const MedFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF006239);
    const foreground = Color(0xFFDDE8E3);

    return MaterialApp(
      title: 'MedFarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: foreground,
          brightness: Brightness.dark,
          surface: const Color(0xFF084F35),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: foreground,
          centerTitle: false,
        ),
      ),
      home: const MilkQualityHomePage(),
    );
  }
}

class MilkQualityHomePage extends StatelessWidget {
  const MilkQualityHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xFFDDE8E3);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MedFarm'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.agriculture_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Milk Quality',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Raw milk pre-screening overview',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: foreground.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF084F35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: foreground.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: foreground),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Starter UI only. No device is connected and no live readings are available yet.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Expanded(
                child: _ReadingCard(
                  title: 'Temperature',
                  unit: '°C',
                  icon: Icons.thermostat,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ReadingCard(
                  title: 'pH',
                  unit: '',
                  icon: Icons.science_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _ReadingCard(
                  title: 'Conductivity',
                  unit: 'µS/cm',
                  icon: Icons.electrical_services_outlined,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ReadingCard(
                  title: 'Turbidity',
                  unit: 'NTU',
                  icon: Icons.water_drop_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Screening records and verified thresholds will be added in a later iteration.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foreground.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.title,
    required this.unit,
    required this.icon,
  });

  final String title;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xFFDDE8E3);

    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF084F35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            unit.isEmpty ? '--' : '-- $unit',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
