import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';

/// One saved question with the chatbot's answer.
class SavedTurn {
  const SavedTurn({
    required this.id,
    required this.question,
    required this.reply,
  });

  factory SavedTurn.fromJson(Map<String, dynamic> json) => SavedTurn(
    id: json['id'] as int,
    question: json['question'] as String,
    reply: json['reply'] as Map<String, dynamic>,
  );

  final int id;
  final String question;
  final Map<String, dynamic> reply;
}

/// Keeps the chat in the MedFarm backend database (/api/v1/chat), so the
/// conversation and its context continue after the app restarts.
///
/// Every call fails quietly: without the backend or its database the chat
/// still works, it just is not saved.
class ChatHistoryApi {
  ChatHistoryApi({http.Client? client, this.baseUrl})
    : _client = client ?? http.Client(),
      enabled = true;

  /// Saves nothing (for tests and previews).
  ChatHistoryApi.disabled()
    : _client = http.Client(),
      baseUrl = null,
      enabled = false;

  static const _idKey = 'medfarm_chat_conversation_id';
  static const _timeout = Duration(seconds: 10);

  final http.Client _client;

  /// Defaults to [ApiConfig.baseUrl].
  final String? baseUrl;
  final bool enabled;

  String _url(String conversationId, [String path = '']) =>
      '${baseUrl ?? ApiConfig.baseUrl}/api/v1/chat/conversations/'
      '$conversationId$path';

  /// This device's conversation, created on first use.
  Future<String?> conversationId() async {
    if (!enabled) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_idKey);
      if (saved != null) return saved;
      final id = _newId();
      await prefs.setString(_idKey, id);
      return id;
    } catch (_) {
      return null;
    }
  }

  /// Starts a fresh conversation; the old one stays in the database.
  Future<String?> startNewConversation() async {
    if (!enabled) return null;
    try {
      final id = _newId();
      await (await SharedPreferences.getInstance()).setString(_idKey, id);
      return id;
    } catch (_) {
      return null;
    }
  }

  Future<List<SavedTurn>> load(String conversationId) async {
    try {
      final response = await _client
          .get(Uri.parse(_url(conversationId, '/messages?limit=50')))
          .timeout(_timeout);
      if (response.statusCode != 200) return const [];
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      return [
        for (final item in json['items'] as List)
          SavedTurn.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Saves a question and its answer; returns the message id, or null.
  Future<int?> save(
    String conversationId, {
    required String question,
    required Map<String, Object?> reply,
    String? lang,
    String? topic,
    bool sick = false,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(_url(conversationId, '/messages')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'question': question,
              'lang': lang,
              'topic': topic,
              'sick': sick,
              'reply': reply,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode != 201) return null;
      return (jsonDecode(response.body) as Map)['id'] as int;
    } catch (_) {
      return null;
    }
  }

  /// Replaces a saved answer, e.g. after the AI-model answer was added.
  Future<void> update(
    String conversationId,
    int messageId,
    Map<String, Object?> reply,
  ) async {
    try {
      await _client
          .put(
            Uri.parse(_url(conversationId, '/messages/$messageId')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'reply': reply}),
          )
          .timeout(_timeout);
    } catch (_) {
      // Not saved; the chat itself is unaffected.
    }
  }

  static String _newId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}
