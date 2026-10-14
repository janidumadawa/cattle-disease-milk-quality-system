import 'package:flutter/material.dart';

import 'services/milk_sample_api.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: primaryGreen),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MedFarmHomePage(),
    );
  }
}

class MedFarmHomePage extends StatefulWidget {
  const MedFarmHomePage({super.key});

  @override
  State<MedFarmHomePage> createState() => _MedFarmHomePageState();
}

class _MedFarmHomePageState extends State<MedFarmHomePage> {
  final MilkSampleApi _api = MilkSampleApi();

  bool _isLoading = false;
  Map<String, dynamic>? _sample;
  Map<String, dynamic>? _previewReadings;
  String? _error;
  int _countdownSeconds = 0;


Future<void> _submitDemo(String scenario) async {
  final demoReadings = <String, Map<String, dynamic>>{
    'temperature_c': {
      'value': 4.8,
      'source': 'SIMULATED',
    },
    'conductivity_us_cm': {
      'value': 850.0,
      'source': 'SIMULATED',
    },
    'turbidity_ntu': {
      'value': 11.0,
      'source': 'SIMULATED',
    },
    'ph': {
      'value': 6.65,
      'source': 'SIMULATED',
    },
  };

  setState(() {
    _isLoading = true;
    _countdownSeconds = 15;
    _previewReadings = <String, dynamic>{};
    _sample = null;
    _error = null;
  });

  try {
    // Reveal one simulated reading at each stage of the 15-second cycle.
    for (int remaining = 15; remaining > 0; remaining--) {
      if (!mounted) return;

      setState(() {
        _countdownSeconds = remaining;

        if (remaining == 12) {
          _previewReadings!['temperature_c'] =
              demoReadings['temperature_c']!;
        } else if (remaining == 9) {
          _previewReadings!['conductivity_us_cm'] =
              demoReadings['conductivity_us_cm']!;
        } else if (remaining == 6) {
          _previewReadings!['turbidity_ntu'] =
              demoReadings['turbidity_ntu']!;
        } else if (remaining == 3) {
          _previewReadings!['ph'] = demoReadings['ph']!;
        }
      });

      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    setState(() {
      _countdownSeconds = 0;
    });

    // Submit the sample only after the countdown finishes.
    final response = await _api.submitDemoSample(
      demoScenario: scenario,
    );

    if (!mounted) return;

    setState(() {
      _sample = response;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _error = e.toString();
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _countdownSeconds = 0;
      });
    }
  }
}


  String _readingValue(String key, String unit) {
    final readings = _sample?['readings'] ?? _previewReadings;

    if (readings is! Map) return '—';

    final reading = readings[key];

    if (reading is! Map || reading['value'] == null) {
      return '—';
    }

    return '${reading['value']} $unit';
  }

  String _readingSource(String key) {
    final readings = _sample?['readings'] ?? _previewReadings;

    if (readings is! Map) return 'No result yet';

    final reading = readings[key];

    if (reading is! Map) return 'No result yet';

    return reading['source']?.toString() ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF006239);

    final classification = _sample?['classification'];
    final result = classification is Map
        ? classification['result']?.toString()
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('MedFarm')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.agriculture_outlined,
                  color: primaryGreen,
                  size: 54,
                ),
                const SizedBox(height: 12),
                Text(
                  'Milk Quality Pre-Screening',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cattle Disease Detection and Milk Quality Analysis System',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'PP1 software demonstration — all four readings below '
                  'are simulated.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                Text(
                  'Sample measurements',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MeasurementCard(
                      label: 'Temperature',
                      value: _readingValue('temperature_c', '°C'),
                      source: _readingSource('temperature_c'),
                    ),
                    _MeasurementCard(
                      label: 'pH',
                      value: _readingValue('ph', ''),
                      source: _readingSource('ph'),
                    ),
                    _MeasurementCard(
                      label: 'Conductivity',
                      value: _readingValue('conductivity_us_cm', 'µS/cm'),
                      source: _readingSource('conductivity_us_cm'),
                    ),
                    _MeasurementCard(
                      label: 'Turbidity',
                      value: _readingValue('turbidity_ntu', 'NTU'),
                      source: _readingSource('turbidity_ntu'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Text(
                  '15-second sample cycle',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'These buttons select a demonstration outcome. '
                  'They do not run the research ML model.',
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _isLoading ? null : () => _submitDemo('PASS'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Start PASS Demo'),
                    ),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : () => _submitDemo('FAIL'),
                      icon: const Icon(Icons.error_outline),
                      label: const Text('Start FAIL Demo'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),

                if (_isLoading) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  Text(
                    _countdownSeconds > 0
                        ? 'Simulated sample in progress: '
                              '$_countdownSeconds seconds remaining'
                        : 'Sending sample to FastAPI...',
                    textAlign: TextAlign.center,
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('API request failed: $_error'),
                    ),
                  ),
                ],

                if (_sample != null && !_isLoading) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'API response',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text('Sample ID: ${_sample!['sample_id']}'),
                          const SizedBox(height: 8),
                          Text(
                            'Result: ${result ?? 'Not returned'}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: result == 'PASS'
                                      ? primaryGreen
                                      : result == 'FAIL'
                                      ? Colors.red.shade700
                                      : null,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Status: ${classification is Map ? classification['status'] : 'Unknown'}',
                          ),
                          Text(
                            'Research validated: '
                            '${classification is Map ? classification['research_validated'] : 'Unknown'}',
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'DEMO ONLY — this result was selected for '
                            'the presentation flow, not predicted by an ML model.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

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

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({
    required this.label,
    required this.value,
    required this.source,
  });

  final String label;
  final String value;
  final String source;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(source, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
