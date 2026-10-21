import 'dart:convert';

import 'package:http/http.dart' as http;

import '../chatbot/chat_api.dart';
import '../chatbot/chat_models.dart';

/// One section of the guide, e.g. "Do this first" or "Do not".
class TreatmentSection {
  const TreatmentSection({
    required this.key,
    required this.title,
    required this.items,
  });

  factory TreatmentSection.fromJson(Map<String, dynamic> json) =>
      TreatmentSection(
        key: json['key'] as String,
        title: json['title'] as String,
        items: [
          for (final item in json['items'] as List)
            CardRow.fromJson(item as Map<String, dynamic>),
        ],
      );

  /// first | dont | vet | milk | call_vet | prevent
  final String key;
  final String title;

  /// Knowledge-base entries with their citation ids.
  final List<CardRow> items;
}

/// A medicine vets use for the disease. Dose, frequency, duration and
/// withdrawal are null unless a source gives them ("set by your vet").
class TreatmentMedicine {
  const TreatmentMedicine({
    required this.name,
    required this.kind,
    required this.use,
    required this.prescription,
    required this.source,
    this.route,
    this.dose,
    this.frequency,
    this.duration,
    this.withdrawal,
  });

  factory TreatmentMedicine.fromJson(Map<String, dynamic> json) =>
      TreatmentMedicine(
        name: json['name'] as String,
        kind: json['kind'] as String? ?? '',
        use: json['use'] as String? ?? '',
        prescription: json['prescription'] as bool? ?? true,
        source: json['source'] as String? ?? '',
        route: json['route'] as String?,
        dose: json['dose'] as String?,
        frequency: json['frequency'] as String?,
        duration: json['duration'] as String?,
        withdrawal: json['withdrawal'] as String?,
      );

  final String name;
  final String kind;
  final String use;

  /// Only a vet can prescribe and give it.
  final bool prescription;
  final String source;
  final String? route;
  final String? dose;
  final String? frequency;
  final String? duration;
  final String? withdrawal;
}

/// Treatment and care for a detected disease, from the chatbot server's
/// knowledge base (`GET /api/treatment`).
class TreatmentGuide {
  const TreatmentGuide({
    required this.disease,
    required this.title,
    required this.heading,
    required this.stage,
    required this.severe,
    this.stageNote,
    required this.noMedicine,
    required this.sections,
    required this.medicinesTitle,
    required this.medicineLabels,
    required this.medicines,
    required this.contactsTitle,
    required this.contacts,
    required this.callLabel,
    required this.sourcesTitle,
    required this.sources,
    required this.ask,
    required this.askButton,
  });

  factory TreatmentGuide.fromJson(Map<String, dynamic> json) => TreatmentGuide(
    disease: json['disease'] as String,
    title: json['title'] as String,
    heading: json['heading'] as String,
    stage: json['stage'] as String?,
    severe: json['severe'] as String?,
    stageNote: json['stage_note'] as String?,
    noMedicine: json['no_medicine'] as String,
    sections: [
      for (final s in json['sections'] as List)
        TreatmentSection.fromJson(s as Map<String, dynamic>),
    ],
    medicinesTitle: json['medicines_title'] as String? ?? 'Medicines',
    medicineLabels: {
      for (final MapEntry(:key, :value)
          in (json['medicine_labels'] as Map? ?? const {}).entries)
        key as String: value as String,
    },
    medicines: [
      for (final m in json['medicines'] as List? ?? const [])
        TreatmentMedicine.fromJson(m as Map<String, dynamic>),
    ],
    contactsTitle: json['contacts_title'] as String? ?? '',
    contacts: [
      for (final c in json['contacts'] as List? ?? const [])
        VetContact.fromJson(c as Map<String, dynamic>),
    ],
    callLabel: json['call_label'] as String? ?? 'Call',
    sourcesTitle: json['sources_title'] as String? ?? 'Sources',
    sources: [
      for (final s in json['sources'] as List? ?? const []) s as String,
    ],
    ask: json['ask'] as String,
    askButton: json['ask_button'] as String,
  );

  final String disease;
  final String title;
  final String heading;

  /// "High" or null.
  final String? stage;

  /// A "call your vet today" warning for the high stage.
  final String? severe;

  /// A note for the early (low) stage.
  final String? stageNote;

  /// Why the guide has no medicines or doses.
  final String noMedicine;
  final List<TreatmentSection> sections;
  final String medicinesTitle;

  /// Field names in the guide's language: dose, route, by_vet ...
  final Map<String, String> medicineLabels;
  final List<TreatmentMedicine> medicines;
  final String contactsTitle;
  final List<VetContact> contacts;
  final String callLabel;
  final String sourcesTitle;

  /// Source pages (Merck Veterinary Manual, WOAH ...).
  final List<String> sources;

  /// Question to ask the chatbot about this disease.
  final String ask;
  final String askButton;
}

/// Loads treatment guides from the chatbot server.
class TreatmentApi {
  TreatmentApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? ChatApi.defaultBaseUrl;

  final http.Client _client;
  final String baseUrl;

  /// [classId] is the image model's class, e.g. "Mastitis_High".
  Future<TreatmentGuide> load(String classId, {String lang = 'en'}) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/api/treatment')
              .replace(queryParameters: {'disease': classId, 'lang': lang}),
        )
        // The local model writes each section on first load (minutes in Sinhala on CPU).
        .timeout(const Duration(minutes: 10));
    if (response.statusCode != 200) {
      throw Exception('No treatment guide (HTTP ${response.statusCode}).');
    }
    return TreatmentGuide.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
