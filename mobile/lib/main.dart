import 'package:flutter/material.dart';

import 'services/milk_sample_api.dart';

const _background = Color(0xFF0D0F0E);
const _surface = Color(0xFF151816);
const _surfaceRaised = Color(0xFF1B201D);
const _border = Color(0xFF292F2B);
const _green = Color(0xFF08784D);
const _greenBright = Color(0xFF19A66D);
const _textPrimary = Color(0xFFF2F5F3);
const _textSecondary = Color(0xFFA0AAA4);
const _danger = Color(0xFFFF554D);

void main() {
  runApp(const MedFarmApp());
}

class MedFarmApp extends StatelessWidget {
  const MedFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _greenBright,
      secondary: _greenBright,
      surface: _surface,
      error: _danger,
      onSurface: _textPrimary,
    );

    return MaterialApp(
      title: 'MedFarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: _background,
        dividerColor: _border,
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 68,
          titleTextStyle: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
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

    final rawValue = reading['value'];
    final formattedValue = rawValue is num && rawValue % 1 == 0
        ? rawValue.toInt().toString()
        : rawValue.toString();

    return unit.isEmpty ? formattedValue : '$formattedValue $unit';
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
    final classification = _sample?['classification'];
    final result = classification is Map
        ? classification['result']?.toString()
        : null;
    final isPass = result == 'PASS';
    final resultColor = isPass ? _greenBright : _danger;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.water_drop_rounded, color: _greenBright, size: 22),
            SizedBox(width: 10),
            Text('Milk quality'),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: _Pill(
              label: 'PP1 DEMO',
              color: _greenBright,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Milk quality pre-screening',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Monitor sample readings during a 15-second test cycle.',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Device status is intentionally labelled as a simulation.
                  _DarkPanel(
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.19),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.water_drop_outlined,
                            color: _greenBright,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MedFarm MQ-01',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: _greenBright,
                                    size: 8,
                                  ),
                                  SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      'Software simulation • device not connected',
                                      style: TextStyle(
                                        color: _textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  _DarkPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionHeading(
                          title: 'Test a sample',
                          subtitle:
                              'Choose an outcome to demonstrate the app flow.',
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading) ...[
                          Center(
                            child: SizedBox(
                              width: 130,
                              height: 130,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 116,
                                    height: 116,
                                    child: CircularProgressIndicator(
                                      value: _countdownSeconds > 0
                                          ? _countdownSeconds / 15
                                          : null,
                                      strokeWidth: 7,
                                      backgroundColor: _border,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            _greenBright,
                                          ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _countdownSeconds > 0
                                            ? '$_countdownSeconds'
                                            : '…',
                                        style: const TextStyle(
                                          fontSize: 35,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Text(
                                        'seconds',
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              _countdownSeconds > 0
                                  ? 'Reading simulated sensors…'
                                  : 'Sending sample to the API…',
                              style: const TextStyle(
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _submitDemo('PASS'),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Start PASS demo'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _green,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _surfaceRaised,
                                disabledForegroundColor: _textSecondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 17,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _submitDemo('FAIL'),
                              icon: const Icon(Icons.error_outline),
                              label: const Text('Start FAIL demo'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _danger,
                                side: const BorderSide(color: _danger),
                                disabledForegroundColor: _textSecondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 17,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  Row(
                    children: [
                      const Expanded(
                        child: _SectionHeading(
                          title: 'Sensor readings',
                          subtitle: 'Values appear as the sample cycle progresses.',
                        ),
                      ),
                      _Pill(
                        label: _isLoading ? 'READING' : '4 SENSORS',
                        color: _isLoading ? _greenBright : _textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DarkPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _SensorReadingRow(
                          icon: Icons.device_thermostat_outlined,
                          label: 'Temperature',
                          value: _readingValue('temperature_c', '°C'),
                          source: _readingSource('temperature_c'),
                        ),
                        const _PanelDivider(),
                        _SensorReadingRow(
                          icon: Icons.bolt_outlined,
                          label: 'Conductivity',
                          value: _readingValue('conductivity_us_cm', 'µS/cm'),
                          source: _readingSource('conductivity_us_cm'),
                        ),
                        const _PanelDivider(),
                        _SensorReadingRow(
                          icon: Icons.waves_outlined,
                          label: 'Turbidity',
                          value: _readingValue('turbidity_ntu', 'NTU'),
                          source: _readingSource('turbidity_ntu'),
                        ),
                        const _PanelDivider(),
                        _SensorReadingRow(
                          icon: Icons.opacity_outlined,
                          label: 'pH',
                          value: _readingValue('ph', ''),
                          source: _readingSource('ph'),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    _DarkPanel(
                      backgroundColor: const Color(0xFF291614),
                      borderColor: const Color(0xFF63302B),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: _danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'API request failed: ' + _error!,
                              style: const TextStyle(color: _textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_sample != null && !_isLoading) ...[
                    const SizedBox(height: 22),
                    _DarkPanel(
                      backgroundColor: isPass
                          ? const Color(0xFF10241A)
                          : const Color(0xFF291614),
                      borderColor: isPass
                          ? const Color(0xFF24543C)
                          : const Color(0xFF63302B),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isPass
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                                color: resultColor,
                                size: 26,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Latest demo result',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _Pill(
                                label: 'DEMO ONLY',
                                color: resultColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            result ?? 'No result returned',
                            style: TextStyle(
                              color: resultColor,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Sample ID: ' +
                                (_sample!['sample_id']?.toString() ?? 'Unknown'),
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'This outcome was selected for the software demonstration. '
                            'It is not an ML prediction or a validated milk-quality decision.',
                            style: TextStyle(
                              color: _textSecondary,
                              height: 1.45,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.science_outlined,
                                size: 16,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Research validated: ' +
                                    ((classification is Map &&
                                            classification['research_validated'] ==
                                                true)
                                        ? 'Yes'
                                        : 'No'),
                                style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),
                  const Center(
                    child: Text(
                      'SIMULATION MODE • NO PHYSICAL SENSOR DATA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkPanel extends StatelessWidget {
  const _DarkPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.backgroundColor = _surface,
    this.borderColor = _border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w750,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SensorReadingRow extends StatelessWidget {
  const _SensorReadingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.source,
  });

  final IconData icon;
  final String label;
  final String value;
  final String source;

  @override
  Widget build(BuildContext context) {
    final hasReading = value != '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: _surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: _textSecondary,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasReading ? 'SIMULATED' : 'Waiting for reading',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (hasReading)
            const Padding(
              padding: EdgeInsets.only(right: 7),
              child: Icon(
                Icons.check_circle,
                color: _greenBright,
                size: 17,
              ),
            ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: hasReading ? _textPrimary : _textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: _border);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}
