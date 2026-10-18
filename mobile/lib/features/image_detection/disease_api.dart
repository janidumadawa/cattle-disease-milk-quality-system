import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import 'disease_result.dart';
import 'scan_history.dart';

/// An error with a message that can be shown to the user.
class DiseaseApiException implements Exception {
  const DiseaseApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the backend's cattle disease identification endpoints.
class DiseaseApi {
  DiseaseApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // The first request after the backend starts can be slow.
  static const _timeout = Duration(seconds: 60);

  static const _base = '/api/v1/disease';

  /// Full URL of a path returned by the API, such as a stored photo.
  static Uri url(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<DiseaseResult> predict(XFile image) async {
    final request = http.MultipartRequest('POST', url('$_base/predict'))
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          await image.readAsBytes(),
          filename: image.name,
        ),
      );
    return DiseaseResult.fromJson(_json(await _send(request)));
  }

  /// Saved scans, newest first.
  Future<ScanHistoryPage> history({int limit = 20, int offset = 0}) async {
    final request = http.Request(
      'GET',
      url('$_base/history?limit=$limit&offset=$offset'),
    );
    return ScanHistoryPage.fromJson(_json(await _send(request)));
  }

  Future<ScanDetail> scan(int id) async {
    final request = http.Request('GET', url('$_base/history/$id'));
    return ScanDetail.fromJson(_json(await _send(request)));
  }

  Future<void> deleteScan(int id) async {
    await _send(http.Request('DELETE', url('$_base/history/$id')));
  }

  /// Downloads a stored image, given its path from the API.
  Future<Uint8List> image(String path) async {
    return (await _send(http.Request('GET', url(path)))).bodyBytes;
  }

  /// Sends the request and returns the response, or throws a
  /// [DiseaseApiException] with a message for the user.
  Future<http.Response> _send(http.BaseRequest request) async {
    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const DiseaseApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw DiseaseApiException(
        'Could not reach the MedFarm server at ${ApiConfig.baseUrl}. '
        'Check that the backend is running.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    // FastAPI errors look like {"detail": "message"}.
    Object? detail;
    try {
      final body = jsonDecode(response.body);
      detail = body is Map<String, dynamic> ? body['detail'] : null;
    } on FormatException {
      detail = null;
    }
    throw DiseaseApiException(
      detail is String
          ? detail
          : 'The server returned an error (${response.statusCode}).',
    );
  }

  Map<String, dynamic> _json(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw DiseaseApiException(
        'Unexpected response from the server (${response.statusCode}).',
      );
    }
  }

  void close() => _client.close();
}
