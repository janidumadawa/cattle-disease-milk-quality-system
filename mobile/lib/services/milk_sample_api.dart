import 'dart:convert';

import 'package:http/http.dart' as http;

class MilkSampleApi {
  // Local development address for the shared FastAPI backend.
  static const String _baseUrl = 'http://127.0.0.1:8000';

  static final Uri _endpoint =
      Uri.parse('$_baseUrl/api/v1/milk-samples');

  Future<Map<String, dynamic>> submitDemoSample({
    String demoScenario = 'PASS',
  }) async {
    if (!['PASS', 'FAIL'].contains(demoScenario)) {
      throw ArgumentError('Demo scenario must be PASS or FAIL.');
    }

    // All readings are simulated for this software-only test.
    // The temperature will be marked as DS18B20 only after we
    // connect and verify the real hardware measurement.
    final payload = {
      'sample_id': 'DEMO-${DateTime.now().millisecondsSinceEpoch}',
      'measurement_duration_seconds': 15,
      'data_mode': 'SIMULATED',
      'demo_scenario': demoScenario,
      'readings': {
        'temperature_c': {
          'value': 4.8,
          'source': 'SIMULATED',
        },
        'ph': {
          'value': 6.65,
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
      },
    };

    final response = await http
        .post(
          _endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Milk sample request failed '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'The API returned an unexpected response format.',
      );
    }

    return decoded;
  }
}