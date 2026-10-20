import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medfarm_mobile/features/chatbot/chat_launcher.dart';
import 'package:medfarm_mobile/features/image_detection/treatment_guide.dart';
import 'package:medfarm_mobile/features/image_detection/treatment_screen.dart';

Map<String, Object?> _section(String key, String title, List<String> texts) => {
  'key': key,
  'title': title,
  'items': [
    for (final (i, text) in texts.indexed)
      {'id': 'KB-2$key$i-HI', 'text': text},
  ],
};

final _guide = {
  'disease': 'mastitis (udder infection)',
  'title': 'Treatment',
  'heading': 'Treatment and care for mastitis (udder infection)',
  'stage': 'High',
  'severe': 'Severe stage: please call your vet today.',
  'no_medicine':
      'Only a vet who examines the animal can choose medicines and doses.',
  'sections': [
    _section('first', 'Do this first', [
      'Milk out abnormal milk',
      'Use a clean towel',
    ]),
    _section('dont', 'Do not', ['Do not give leftover medicines']),
    _section('vet', 'What the vet will do', ['The vet tests the milk']),
    _section('milk', 'Milk and meat safety', [
      'Wait until the vet says milk is safe',
    ]),
    _section('call_vet', 'Call a vet at once if', ['Fever or not eating']),
    _section('prevent', 'Prevention', ['Dip teats after milking']),
  ],
  'medicines_title': 'Medicines',
  'medicine_labels': {'dose': 'Dose', 'by_vet': 'Set by your vet'},
  'medicines': [
    {
      'name': 'Intramammary antibiotic',
      'kind': 'Tube into the teat',
      'use': 'Treats the infection in the affected quarter.',
      'prescription': true,
      'source': 'https://www.merckvetmanual.com/x',
      'route': 'Into the teat',
      'dose': null,
    },
  ],
  'contacts_title': 'Government vet offices',
  'contacts': [
    {
      'office': "Government Veterinary Surgeon's Office - Buttala",
      'area': 'Buttala',
      'phone': '+94 55 227 3360',
    },
  ],
  'call_label': 'Call',
  'sources_title': 'Sources',
  'sources': ['https://www.merckvetmanual.com/x'],
  'ask': 'How is mastitis (udder infection) treated?',
  'ask_button': 'Ask the assistant about this',
};

void main() {
  testWidgets('shows the treatment guide for the scanned disease', (
    tester,
  ) async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response.bytes(utf8.encode(jsonEncode(_guide)), 200);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TreatmentScreen(
                  classId: 'Mastitis_High',
                  api: TreatmentApi(client: client, baseUrl: 'http://chat'),
                ),
              ),
            ),
            child: const Text('See treatment'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('See treatment'));
    await tester.pumpAndSettle();

    expect(requested.path, '/api/treatment');
    expect(requested.queryParameters['disease'], 'Mastitis_High');
    expect(
      find.text('Severe stage: please call your vet today.'),
      findsOneWidget,
    );
    for (final title in ['Do this first', 'Do not', 'What the vet will do']) {
      expect(find.text(title), findsOneWidget);
    }
    // Medicines: names from the source, doses left to the vet.
    await tester.dragUntilVisible(
      find.text('Intramammary antibiotic'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Medicines'), findsOneWidget);
    expect(find.text('Set by your vet'), findsWidgets);
    expect(find.text('Into the teat'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Do this first'),
      find.byType(ListView),
      const Offset(0, 300),
    );

    // Steps can be ticked off.
    await tester.tap(find.byTooltip('Done').first);
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // "Ask the assistant" closes the guide and hands the question to the chat.
    String? asked;
    void listen() => asked ??= chatQuestionRequest.value;
    chatQuestionRequest.addListener(listen);
    addTearDown(() {
      chatQuestionRequest.removeListener(listen);
      chatQuestionRequest.value = null;
    });
    await tester.tap(find.text('Ask the assistant about this'));
    await tester.pumpAndSettle();
    expect(asked, 'How is mastitis (udder infection) treated?');
    expect(find.text('See treatment'), findsOneWidget);
  });
}
