// Messages streamed by the MedFarm chat server
// (backend/models/chat_bot/app/server.py, POST /api/ask, one JSON per line).

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) => [
  for (final item in (value as List? ?? const []))
    parse(item as Map<String, dynamic>),
];

List<String> _strings(Object? value) => [
  for (final item in (value as List? ?? const [])) item as String,
];

/// Fast = instant knowledge-base text; model = medfarm-llama via Ollama.
enum AnswerMode { fast, model }

enum ServerStatus { ready, modelMissing, ollamaOff, offline }

/// One knowledge-base sentence with its citation, e.g. `KB-007-LM`.
class CardRow {
  const CardRow({required this.id, required this.text});

  factory CardRow.fromJson(Map<String, dynamic> json) =>
      CardRow(id: json['id'] as String, text: json['text'] as String);

  final String id;
  final String text;
}

class CardSection {
  const CardSection({
    required this.key,
    required this.title,
    required this.open,
    required this.items,
  });

  factory CardSection.fromJson(Map<String, dynamic> json) => CardSection(
    key: json['key'] as String,
    title: json['title'] as String,
    open: json['open'] as bool? ?? false,
    items: _list(json['items'], CardRow.fromJson),
  );

  /// about | signs | treatment | care | prevention
  final String key;
  final String title;
  final bool open;
  final List<CardRow> items;
}

/// A government veterinary office to call ("doctor" and "address" are
/// optional).
class VetContact {
  const VetContact({
    required this.office,
    required this.area,
    required this.phone,
    this.doctor,
    this.address,
  });

  factory VetContact.fromJson(Map<String, dynamic> json) => VetContact(
    office: json['office'] as String,
    area: json['area'] as String? ?? '',
    phone: json['phone'] as String,
    doctor: json['doctor'] as String?,
    address: json['address'] as String?,
  );

  final String office;
  final String area;
  final String phone;
  final String? doctor;
  final String? address;
}

/// Structured answer: intro, direct answer, topic sections, closing.
class AnswerCard {
  const AnswerCard({
    required this.intro,
    required this.urgentTitle,
    required this.urgent,
    required this.answerTitle,
    required this.answer,
    required this.sections,
    required this.closing,
    this.contactsTitle = '',
    this.contacts = const [],
    this.callLabel = 'Call',
  });

  factory AnswerCard.fromJson(Map<String, dynamic> json) => AnswerCard(
    intro: json['intro'] as String? ?? '',
    urgentTitle: json['urgent_title'] as String? ?? '',
    urgent: _list(json['urgent'], CardRow.fromJson),
    answerTitle: json['answer_title'] as String? ?? '',
    answer: _list(json['answer'], CardRow.fromJson),
    sections: _list(json['sections'], CardSection.fromJson),
    closing: json['closing'] as String? ?? '',
    contactsTitle: json['contacts_title'] as String? ?? '',
    contacts: _list(json['contacts'], VetContact.fromJson),
    callLabel: json['call_label'] as String? ?? 'Call',
  );

  final String intro;
  final String urgentTitle;
  final List<CardRow> urgent;
  final String answerTitle;
  final List<CardRow> answer;
  final List<CardSection> sections;
  final String closing;

  /// Vet offices to call, e.g. the one nearest the farmer's town.
  final String contactsTitle;
  final List<VetContact> contacts;

  /// Label of the dial button, in the answer's language.
  final String callLabel;
}

/// A disease the described signs match. Not a diagnosis.
class DiseaseMatch {
  const DiseaseMatch({required this.label, required this.share});

  factory DiseaseMatch.fromJson(Map<String, dynamic> json) => DiseaseMatch(
    label: (json['label'] ?? json['disease']) as String,
    share: (json['share'] as num).toDouble(),
  );

  final String label;

  /// Share of the match score, 0-1.
  final double share;
}

class AskMeta {
  const AskMeta({
    required this.lang,
    required this.confident,
    required this.diseases,
    required this.urgentTitle,
    required this.urgent,
    required this.evidenceIds,
    this.topic,
    this.sick = false,
    this.suggestions = const [],
  });

  factory AskMeta.fromJson(Map<String, dynamic> json) => AskMeta(
    lang: json['lang'] as String? ?? 'en',
    confident: json['confident'] as bool? ?? false,
    diseases: _list(json['diseases'], DiseaseMatch.fromJson),
    urgentTitle: json['urgent_title'] as String? ?? '',
    urgent: _list(json['urgent'], CardRow.fromJson),
    evidenceIds: [
      for (final e in (json['evidence'] as List? ?? const []))
        (e as Map<String, dynamic>)['id'] as String,
    ],
    topic: json['topic'] as String?,
    sick: json['sick'] as bool? ?? false,
    suggestions: _strings(json['suggestions']),
  );

  final String lang;

  /// The knowledge base explains the question well enough to answer.
  final bool confident;
  final List<DiseaseMatch> diseases;
  final String urgentTitle;
  final List<CardRow> urgent;

  /// Citations the answer may use; anything else is an invented citation.
  final List<String> evidenceIds;

  /// The topic the answer was about, sent back with follow-up questions.
  final String? topic;

  /// The question described a sick animal.
  final bool sick;

  /// Next questions to offer as chips under the answer.
  final List<String> suggestions;
}

/// An earlier question and the topic it was answered with, so the server can
/// answer follow-ups such as "how do I treat it?".
class ChatTurn {
  const ChatTurn({required this.question, this.topic, this.sick = false});

  final String question;
  final String? topic;
  final bool sick;

  Map<String, Object?> toJson() => {
    'question': question,
    'topic': topic,
    'sick': sick,
  };
}

/// The server's checks on the final answer (same as the held-out eval).
class AnswerChecks {
  const AnswerChecks({
    required this.behaviour,
    required this.validCites,
    required this.inventedCites,
    required this.doseLeak,
  });

  factory AnswerChecks.fromJson(Map<String, dynamic> json) => AnswerChecks(
    behaviour: json['behaviour'] as String? ?? 'answer',
    validCites: _strings(json['valid_cites']),
    inventedCites: _strings(json['invented_cites']),
    doseLeak: json['dose_leak'] as bool? ?? false,
  );

  /// answer | abstain | refuse | chat
  final String behaviour;
  final List<String> validCites;
  final List<String> inventedCites;
  final bool doseLeak;
}

sealed class ChatEvent {
  const ChatEvent();

  factory ChatEvent.fromJson(Map<String, dynamic> json) =>
      switch (json['type']) {
        'meta' => MetaEvent(AskMeta.fromJson(json), raw: json),
        'token' => TokenEvent(json['text'] as String? ?? ''),
        'done' => DoneEvent(
          source: json['source'] as String? ?? '',
          card: json['card'] == null
              ? null
              : AnswerCard.fromJson(json['card'] as Map<String, dynamic>),
          checks: AnswerChecks.fromJson(
            json['checks'] as Map<String, dynamic>? ?? const {},
          ),
          truncated: json['truncated'] == true,
          raw: json,
        ),
        'error' => ErrorEvent(json['message'] as String? ?? 'Unknown error'),
        final type => ErrorEvent('Unexpected message from server: $type'),
      };
}

class MetaEvent extends ChatEvent {
  const MetaEvent(this.meta, {this.raw = const {}});

  final AskMeta meta;

  /// The message as received, kept for the saved chat history.
  final Map<String, dynamic> raw;
}

class TokenEvent extends ChatEvent {
  const TokenEvent(this.text);

  final String text;
}

class DoneEvent extends ChatEvent {
  const DoneEvent({
    required this.source,
    required this.card,
    required this.checks,
    required this.truncated,
    this.raw = const {},
  });

  /// kb | guard | retrieval | chat | model
  final String source;
  final AnswerCard? card;
  final AnswerChecks checks;

  /// The model hit its token limit before finishing.
  final bool truncated;

  /// The message as received, kept for the saved chat history.
  final Map<String, dynamic> raw;
}

class ErrorEvent extends ChatEvent {
  const ErrorEvent(this.message);

  final String message;
}
