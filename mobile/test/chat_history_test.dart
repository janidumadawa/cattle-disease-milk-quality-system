import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medfarm_mobile/features/chatbot/chat_api.dart';
import 'package:medfarm_mobile/features/chatbot/chat_history_api.dart';
import 'package:medfarm_mobile/features/chatbot/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _conversation = '0123456789abcdef0123456789abcdef';

Map<String, Object?> _meta(String topic) => {
  'type': 'meta',
  'lang': 'en',
  'confident': true,
  'evidence': [],
  'topic': topic,
  'sick': true,
  'suggestions': [],
};

Map<String, Object?> _done(String intro) => {
  'type': 'done',
  'source': 'kb',
  'card': {
    'intro': intro,
    'urgent': [],
    'answer': [],
    'sections': [],
    'closing': '',
  },
  'checks': {'behaviour': 'answer'},
};

/// A chatbot server that answers every question about mastitis treatment.
MockClient _chatServer(List<Map<String, dynamic>> asked) =>
    MockClient((request) async {
      if (request.url.path == '/api/status') {
        return http.Response('{"ollama": true, "model": true}', 200);
      }
      asked.add(jsonDecode(request.body) as Map<String, dynamic>);
      final lines = [
        _meta('Mastitis'),
        {'type': 'token', 'text': ''},
        _done('Here is how mastitis is treated.'),
      ].map(jsonEncode).join('\n');
      return http.Response.bytes(utf8.encode(lines), 200);
    });

/// The backend's chat history endpoints, holding one earlier turn.
MockClient _historyServer(List<http.Request> requests) =>
    MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'items': [
                {
                  'id': 7,
                  'question': 'my cow has a swollen udder',
                  'reply': {
                    'mode': 'fast',
                    'meta': _meta('Mastitis'),
                    'text': '',
                    'done': _done('This may be mastitis.'),
                  },
                },
              ],
            }),
          ),
          200,
        );
      }
      return http.Response('{"id": 8}', request.method == 'POST' ? 201 : 204);
    });

Future<void> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> asked,
  List<http.Request> saved,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChatScreen(
        api: ChatApi(client: _chatServer(asked), baseUrl: 'http://chat'),
        history: ChatHistoryApi(
          client: _historyServer(saved),
          baseUrl: 'http://api',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'medfarm_chat_conversation_id': _conversation,
    });
  });

  testWidgets('shows the saved conversation and continues it', (tester) async {
    final asked = <Map<String, dynamic>>[];
    final saved = <http.Request>[];
    await _pump(tester, asked, saved);

    // The earlier turn is back on screen.
    expect(find.text('my cow has a swollen udder'), findsOneWidget);
    expect(find.text('This may be mastitis.'), findsOneWidget);
    expect(
      saved.first.url.path,
      '/api/v1/chat/conversations/$_conversation/messages',
    );

    // A follow-up carries the restored topic, and the new turn is saved.
    await tester.enterText(find.byType(TextField), 'how do I treat it?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(asked.single['history'], [
      {
        'question': 'my cow has a swollen udder',
        'topic': 'Mastitis',
        'sick': true,
        'shown': <String>[],
      },
    ]);
    final post = saved.lastWhere((r) => r.method == 'POST');
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    expect(body['question'], 'how do I treat it?');
    expect(body['topic'], 'Mastitis');
    expect((body['reply'] as Map)['done'], isNotNull);
  });

  testWidgets('New chat clears the screen and starts a new conversation', (
    tester,
  ) async {
    await _pump(tester, [], []);
    expect(find.text('my cow has a swollen udder'), findsOneWidget);

    await tester.tap(find.byTooltip('New chat'));
    await tester.pumpAndSettle();

    expect(find.text('my cow has a swollen udder'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('medfarm_chat_conversation_id'),
      isNot(_conversation),
    );
  });
}
