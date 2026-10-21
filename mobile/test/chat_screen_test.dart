import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medfarm_mobile/features/chatbot/chat_api.dart';
import 'package:medfarm_mobile/features/chatbot/chat_screen.dart';

/// NDJSON reply in the shape server.py streams for an instant answer.
String _ndjson(List<Map<String, Object?>> messages) =>
    messages.map(jsonEncode).join('\n');

final _fmdReply = _ndjson([
  {
    'type': 'meta',
    'lang': 'en',
    'confident': true,
    'topic': 'Foot-and-Mouth Disease',
    'sick': true,
    'suggestions': ['Can people catch it?', 'How can I prevent it?'],
    'diseases': [
      {
        'disease': 'Foot-and-Mouth Disease',
        'label': 'Foot-and-Mouth Disease (FMD)',
        'share': 0.75,
      },
    ],
    'urgent': [],
    'urgent_title': '',
    'evidence': [
      {'id': 'KB-007-LM'},
      {'id': 'KB-202-LM'},
    ],
  },
  {'type': 'token', 'text': 'plain card text'},
  {
    'type': 'done',
    'source': 'kb',
    'card': {
      'intro': "I'm sorry to hear about your cow.",
      'urgent_title': 'Urgent',
      'urgent': [],
      'answer_title': 'What matches your description',
      'answer': [
        {'id': 'KB-007-LM', 'text': 'Blisters form in the mouth.'},
      ],
      'sections': [
        {
          'key': 'care',
          'title': 'Care at home',
          'open': true,
          'items': [
            {'id': 'KB-206-LM', 'text': 'Give soft feed.'},
          ],
        },
      ],
      'closing': 'Please contact your vet.',
    },
    'checks': {
      'behaviour': 'answer',
      'valid_cites': ['KB-007-LM'],
      'invented_cites': [],
      'dose_leak': false,
    },
  },
]);

Future<void> _pumpChat(WidgetTester tester, http.Client client) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChatScreen(
        api: ChatApi(client: client, baseUrl: 'http://test'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a streamed knowledge-base answer as a topic card', (
    tester,
  ) async {
    late Map<String, dynamic> sent;
    final client = MockClient((request) async {
      if (request.url.path == '/api/status') {
        return http.Response('{"ollama": true, "model": true}', 200);
      }
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response.bytes(utf8.encode(_fmdReply), 200);
    });
    await _pumpChat(tester, client);

    await tester.tap(find.text('How do I prevent mastitis?'));
    await tester.pumpAndSettle();

    expect(sent['question'], 'How do I prevent mastitis?');
    expect(sent['mode'], 'fast');
    expect(sent['lang'], 'en');
    expect(
      find.textContaining(
        'Signs match: Foot-and-Mouth Disease (FMD) (strong match)',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text("I'm sorry to hear about your cow."), findsOneWidget);
    expect(find.text('KB-007-LM'), findsOneWidget);
    // Open sections show their items; the plain token text is replaced.
    expect(find.text('KB-206-LM'), findsOneWidget);
    expect(find.text('plain card text', findRichText: true), findsNothing);
    expect(find.text('Ask the AI model'), findsOneWidget);
  });

  testWidgets('language toggle switches the greeting and answer language', (
    tester,
  ) async {
    late Map<String, dynamic> sent;
    final client = MockClient((request) async {
      if (request.url.path == '/api/status') {
        return http.Response('{"ollama": true, "model": true}', 200);
      }
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response.bytes(utf8.encode(_fmdReply), 200);
    });
    await _pumpChat(tester, client);
    expect(find.text('How can I help with your herd today?'), findsOneWidget);

    await tester.tap(find.text('සි'));
    await tester.pumpAndSettle();
    expect(find.text('How can I help with your herd today?'), findsNothing);

    await tester.tap(find.text('Mastitis වළක්වන්නේ කොහොමද?'));
    await tester.pumpAndSettle();
    expect(sent['lang'], 'si');
  });

  testWidgets('follow-up questions send the earlier topic as history', (
    tester,
  ) async {
    final asked = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path == '/api/status') {
        return http.Response('{"ollama": true, "model": true}', 200);
      }
      asked.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response.bytes(utf8.encode(_fmdReply), 200);
    });
    await _pumpChat(tester, client);

    await tester.enterText(find.byType(TextField), 'my cow has blisters');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'how do I treat it?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(asked.first['history'], isEmpty);
    expect(asked.last['history'], [
      {
        'question': 'my cow has blisters',
        'topic': 'Foot-and-Mouth Disease',
        'sick': true,
        'shown': ['KB-007-LM', 'KB-202-LM'],
      },
    ]);
  });

  testWidgets('suggested next questions can be tapped and are not repeated', (
    tester,
  ) async {
    final asked = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path == '/api/status') {
        return http.Response('{"ollama": true, "model": true}', 200);
      }
      asked.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response.bytes(utf8.encode(_fmdReply), 200);
    });
    await _pumpChat(tester, client);

    await tester.enterText(find.byType(TextField), 'my cow has blisters');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    // The chips sit under the (long) answer.
    final chat = find.byType(ListView).first;
    await tester.dragUntilVisible(
      find.text('Can people catch it?'),
      chat,
      const Offset(0, -300),
    );
    await tester.tap(find.text('Can people catch it?'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('How can I prevent it?'),
      chat,
      const Offset(0, -300),
    );

    expect(asked.last['question'], 'Can people catch it?');
    expect(asked.last['history'], hasLength(1));
    // Already asked: only the other suggestion is offered now.
    expect(
      find.widgetWithText(ActionChip, 'Can people catch it?'),
      findsNothing,
    );
    expect(
      find.widgetWithText(ActionChip, 'How can I prevent it?'),
      findsOneWidget,
    );
  });

  testWidgets('shows the nearest vet office with a call button', (
    tester,
  ) async {
    final vetReply = _ndjson([
      {
        'type': 'meta',
        'lang': 'en',
        'confident': false,
        'evidence': [],
        'topic': null,
        'suggestions': [],
      },
      {'type': 'token', 'text': 'plain text'},
      {
        'type': 'done',
        'source': 'vet',
        'card': {
          'intro':
              'Here is the nearest government veterinary office for Buttala:',
          'urgent': [],
          'answer': [],
          'sections': [],
          'closing': 'Please call before you go.',
          'contacts_title': 'Nearest vet office',
          'contacts': [
            {
              'office': "Government Veterinary Surgeon's Office, Buttala",
              'area': 'Buttala',
              'phone': '+94 55 227 3360',
              'doctor': 'Dr. D.P. Amarasiri (Veterinary Surgeon)',
              'address': 'Moneragala Road, Buttala',
            },
          ],
          'call_label': 'Call',
        },
        'checks': {'behaviour': 'answer'},
      },
    ]);
    final client = MockClient((request) async {
      if (request.url.path == '/api/status') {
        return http.Response('{"ollama": true, "model": true}', 200);
      }
      return http.Response.bytes(utf8.encode(vetReply), 200);
    });
    await _pumpChat(tester, client);

    await tester.enterText(find.byType(TextField), 'nearest vet in Buttala');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('Nearest vet office'), findsOneWidget);
    expect(
      find.text("Government Veterinary Surgeon's Office, Buttala"),
      findsOneWidget,
    );
    expect(find.text('+94 55 227 3360'), findsOneWidget);
    expect(
      find.text('Dr. D.P. Amarasiri (Veterinary Surgeon)'),
      findsOneWidget,
    );
    expect(find.text('Moneragala Road, Buttala'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Call'), findsOneWidget);
  });

  testWidgets('explains how to start the server when it is offline', (
    tester,
  ) async {
    final client = MockClient((_) async => throw http.ClientException('down'));
    await _pumpChat(tester, client);

    expect(
      find.textContaining("can't reach the MedFarm server at http://test"),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not reach the MedFarm chat server'),
      findsOneWidget,
    );
  });
}
