
import 'dart:convert';

import 'package:http/http.dart' as http;

class MilkSampleApi {
  // Local development address for the FastAPI backend.
  static const String _baseUrl = 'http://127.0.0.1:8000';

  static final Uri _endpoint =
      Uri.parse('$_baseUrl/api/v1/milk-samples');

  static final Uri _latestEndpoint =
      Uri.parse('$_baseUrl/api/v1/milk-samples/latest');

      static final Uri _startEndpoint =
    Uri.parse('$_baseUrl/api/v1/device/start');

static final Uri _progressEndpoint =
    Uri.parse('$_baseUrl/api/v1/device/progress');

  // Existing simulated demonstration.
  Future<Map<String, dynamic>> submitDemoSample({
    String demoScenario = 'PASS',
  }) async {
    if (!['PASS', 'FAIL'].contains(demoScenario)) {
      throw ArgumentError('Demo scenario must be PASS or FAIL.');
    }

    final payload = {
      'sample_id':
          'DEMO-${DateTime.now().millisecondsSinceEpoch}',
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


  Future<void> startDeviceTest() async {
  final response = await http
      .post(
        _startEndpoint,
        headers: {
          'Accept': 'application/json',
        },
      )
      .timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    throw Exception(
      'Could not start device test '
      '(${response.statusCode}): ${response.body}',
    );
  }

  final decoded = jsonDecode(response.body);

  if (decoded is! Map<String, dynamic> ||
      decoded['status'] != 'requested') {
    final message = decoded is Map
        ? decoded['message']?.toString()
        : null;

    throw Exception(message ?? 'The device did not accept the test request.');
  }
}


Future<Map<String, dynamic>> getDeviceProgress() async {
  final response = await http
      .get(
        _progressEndpoint,
        headers: {
          'Accept': 'application/json',
        },
      )
      .timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    throw Exception(
      'Could not retrieve device progress '
      '(${response.statusCode}): ${response.body}',
    );
  }

  final decoded = jsonDecode(response.body);

  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'Unexpected device progress response.',
    );
  }

  return decoded;
}
  // Retrieve the latest sample containing a real DS18B20 reading.
  // Returns null if the backend has no device sample yet.
  Future<Map<String, dynamic>?> getLatestDeviceSample() async {
    final response = await http
        .get(
          _latestEndpoint,
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Latest sample request failed '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Unexpected latest-sample response format.',
      );
    }

    if (decoded['status'] == 'empty') {
      return null;
    }

    final sample = decoded['sample'];

    if (decoded['status'] != 'ok' ||
        sample is! Map<String, dynamic>) {
      throw const FormatException(
        'The API did not return a valid device sample.',
      );
    }

    return sample;
  }
}
