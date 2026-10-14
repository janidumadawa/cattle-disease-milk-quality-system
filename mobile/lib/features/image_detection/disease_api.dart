import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import 'disease_result.dart';

/// An error with a message that can be shown to the user.
class DiseaseApiException implements Exception {
  const DiseaseApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the backend's cattle disease identification endpoint.
class DiseaseApi {
  DiseaseApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // The first request after the backend starts can be slow.
  static const _timeout = Duration(seconds: 60);

  Future<DiseaseResult> predict(XFile image) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/disease/predict');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          await image.readAsBytes(),
          filename: image.name,
        ),
      );

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

    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw DiseaseApiException(
        'Unexpected response from the server (${response.statusCode}).',
      );
    }

    if (response.statusCode != 200) {
      // FastAPI errors look like {"detail": "message"}.
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw DiseaseApiException(
        detail is String
            ? detail
            : 'The server returned an error (${response.statusCode}).',
      );
    }

    return DiseaseResult.fromJson(body as Map<String, dynamic>);
  }

  void close() => _client.close();
}
