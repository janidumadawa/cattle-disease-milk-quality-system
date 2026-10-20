import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'chat_models.dart';

/// Client for the MedFarm chat server (backend/models/chat_bot/app/server.py).
class ChatApi {
  ChatApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultBaseUrl;

  final http.Client _client;
  final String baseUrl;

  /// Override with `--dart-define=MEDFARM_CHAT_URL=http://192.168.1.10:8000`
  /// when running on a phone.
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('MEDFARM_CHAT_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // The Android emulator reaches the host computer at 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  Future<ServerStatus> status() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/status'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return ServerStatus.offline;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['ollama'] != true) return ServerStatus.ollamaOff;
      if (json['model'] != true) return ServerStatus.modelMissing;
      return ServerStatus.ready;
    } catch (_) {
      return ServerStatus.offline;
    }
  }

  /// Streams the answer: a [MetaEvent], [TokenEvent]s, then a [DoneEvent]
  /// (or an [ErrorEvent]). Throws if the server cannot be reached.
  Stream<ChatEvent> ask(
    String question, {
    AnswerMode mode = AnswerMode.fast,
    String lang = 'auto',
  }) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/api/ask'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'question': question,
        'mode': mode.name,
        'lang': lang,
        'style': 'friendly',
      });
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      yield ErrorEvent('Chat server error (HTTP ${response.statusCode}).');
      return;
    }
    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty)
        .map(
          (line) =>
              ChatEvent.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
  }
}
