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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The guide has loaded, but the loading screen stays for 15 seconds.
    expect(find.text('Loading the treatment guide...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 13));
    expect(find.text('Loading the treatment guide...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Loading the treatment guide...'), findsNothing);

    // The guide types itself out: part of the heading with a cursor, the
    // rest of the guide not shown yet.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('▍'), findsOneWidget);
    expect(find.text('Do this first'), findsNothing);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('▍'), findsNothing);

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
    // Everything set by the vet: said once, not in every box.
    expect(
      find.text('Dose, how often and how long: set by your vet'),
      findsOneWidget,
    );
    expect(find.text('Set by your vet'), findsNothing);
    expect(find.text('Into the teat'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();

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

  testWidgets('switching to Sinhala loads again and types the Sinhala guide', (
    tester,
  ) async {
    const siSevere = 'උග්‍ර අවස්ථාව: අදම ඔබේ පශු වෛද්‍යවරයාට කතා කරන්න.';
    final client = MockClient((request) async {
      final si = request.url.queryParameters['lang'] == 'si';
      final body = si ? {..._guide, 'severe': siSevere} : _guide;
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: TreatmentScreen(
          classId: 'Mastitis_High',
          api: TreatmentApi(client: client, baseUrl: 'http://chat'),
          loadingDelay: Duration.zero,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1)); // loads and starts typing
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(
      find.text('Severe stage: please call your vet today.'),
      findsOneWidget,
    );

    await tester.tap(find.text('සි'));
    await tester.pump();
    // The English guide goes; the Sinhala one loads and types out.
    expect(find.text('ප්‍රතිකාර මඟපෙන්වීම පූරණය වෙමින්...'), findsOneWidget);
    expect(
      find.text('Severe stage: please call your vet today.'),
      findsNothing,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('▍'), findsOneWidget);
    expect(find.text(siSevere), findsNothing);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(find.text(siSevere), findsOneWidget);
    expect(find.textContaining('▍'), findsNothing);

    // And back to English: it types out again too.
    await tester.tap(find.text('EN'));
    await tester.pump();
    expect(find.text('Loading the treatment guide...'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('▍'), findsOneWidget);
    expect(
      find.text('Severe stage: please call your vet today.'),
      findsNothing,
    );
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(
      find.text('Severe stage: please call your vet today.'),
      findsOneWidget,
    );
  });
}
