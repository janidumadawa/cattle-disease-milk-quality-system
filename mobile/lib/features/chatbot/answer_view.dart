import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_models.dart';

/// One chatbot answer, filled in as its stream arrives.
class BotReply {
  BotReply(this.mode);

  final AnswerMode mode;
  final DateTime startedAt = DateTime.now();
  AskMeta? meta;
  String text = '';
  DoneEvent? done;
  String? error;
  bool finished = false;

  /// The slower AI-model answer requested under an instant one.
  BotReply? modelReply;

  /// The answer as saved in the chat history (see [BotReply.fromJson]).
  Map<String, Object?> toJson() => {
    'mode': mode.name,
    if (_metaJson != null) 'meta': _metaJson,
    'text': text,
    if (_doneJson != null) 'done': _doneJson,
    if (error != null) 'error': error,
    if (modelReply != null) 'model': modelReply!.toJson(),
  };

  /// A finished answer from the saved chat history.
  factory BotReply.fromJson(Map<String, dynamic> json) {
    final reply = BotReply(
      json['mode'] == AnswerMode.model.name
          ? AnswerMode.model
          : AnswerMode.fast,
    );
    for (final key in ['meta', 'done']) {
      if (json[key] case final Map<String, dynamic> event) {
        reply.apply(ChatEvent.fromJson(event));
      }
    }
    reply
      ..text = json['text'] as String? ?? ''
      ..error = json['error'] as String?
      ..finished = true;
    if (json['model'] case final Map<String, dynamic> model) {
      reply.modelReply = BotReply.fromJson(model);
    }
    return reply;
  }

  Map<String, dynamic>? _metaJson;
  Map<String, dynamic>? _doneJson;

  void apply(ChatEvent event) {
    switch (event) {
      case MetaEvent(:final meta, :final raw):
        this.meta = meta;
        _metaJson = raw;
      case TokenEvent(:final text):
        this.text += text;
      case DoneEvent():
        done = event;
        _doneJson = event.raw;
      case ErrorEvent(:final message):
        error = message;
    }
  }

  List<String> get evidenceIds => meta?.evidenceIds ?? const [];
}

/// Renders a [BotReply]: disease match, urgent warnings, the answer text or
/// topic card, and the server's safety checks.
class AnswerView extends StatelessWidget {
  const AnswerView({
    super.key,
    required this.reply,
    this.withCard = true,
    this.onAskModel,
    this.canAskModel = false,
  });

  final BotReply reply;

  /// False for the AI-model answer shown under an instant one: its topic
  /// sections are already on screen.
  final bool withCard;

  /// Null hides the "Ask the AI model" button.
  final VoidCallback? onAskModel;
  final bool canAskModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = reply.meta;
    final card = reply.done?.card;
    final ids = reply.evidenceIds;
    final isModel = reply.mode == AnswerMode.model;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        if (withCard && meta != null && meta.diseases.isNotEmpty)
          _DiseaseMatchBox(meta: meta),
        // Warnings must not wait for a slow model answer.
        if (withCard && isModel && meta != null && meta.urgent.isNotEmpty)
          _UrgentBox(title: meta.urgentTitle, rows: meta.urgent, ids: ids),
        if (reply.error != null)
          Text(reply.error!, style: TextStyle(color: theme.colorScheme.error))
        else if (!isModel && card != null)
          _CardView(card: card, ids: ids, withUrgent: true)
        else if (reply.text.isEmpty && !reply.finished)
          _Pending(reply: reply)
        else
          CitedText(reply.text.trim(), evidenceIds: ids),
        if (withCard && isModel && card != null)
          _CardView(card: card, ids: ids, withUrgent: false),
        if (reply.done != null) _Checks(done: reply.done!),
        if (onAskModel != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: canAskModel ? onAskModel : null,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Ask the AI model'),
            ),
          ),
        if (reply.modelReply != null) ...[
          const Divider(height: 8),
          Text(
            'AI model answer (medfarm-llama)',
            style: theme.textTheme.labelLarge,
          ),
          AnswerView(reply: reply.modelReply!, withCard: false),
        ],
      ],
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending({required this.reply});

  final BotReply reply;

  @override
  Widget build(BuildContext context) {
    final seconds = DateTime.now().difference(reply.startedAt).inSeconds;
    final label = reply.mode == AnswerMode.model
        ? 'AI model is reading the evidence… ${seconds}s'
        : 'Searching…';
    return Row(
      spacing: 10,
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        Flexible(child: Text(label)),
      ],
    );
  }
}

final _citation = RegExp(r'\[(KB-\d{3}-(?:LM|HI))\]');

/// Text with each `[KB-xxx-LM]` drawn as a chip; red when the ID was not in
/// the retrieved evidence (an invented citation).
class CitedText extends StatelessWidget {
  const CitedText(
    this.text, {
    super.key,
    required this.evidenceIds,
    this.style,
  });

  final String text;
  final List<String> evidenceIds;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _citation.allMatches(text)) {
      spans.addAll(_withBold(text.substring(last, match.start)));
      final id = match.group(1)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: CiteChip(id: id, valid: evidenceIds.contains(id)),
        ),
      );
      last = match.end;
    }
    spans.addAll(_withBold(text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: style);
  }

  /// `**Section heading**` from the detailed model answer, drawn in bold.
  static List<TextSpan> _withBold(String text) {
    final parts = text.split('**');
    return [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty)
          TextSpan(
            text: parts[i],
            style: i.isOdd
                ? const TextStyle(fontWeight: FontWeight.bold)
                : null,
          ),
    ];
  }
}

class CiteChip extends StatelessWidget {
  const CiteChip({super.key, required this.id, required this.valid});

  final String id;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: valid ? colors.primaryContainer : colors.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        id,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: valid ? colors.onPrimaryContainer : colors.onErrorContainer,
        ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.rows, required this.ids, this.style});

  final List<CardRow> rows;
  final List<String> ids;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        for (final row in rows)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text('•', style: style),
              Expanded(
                child: CitedText(
                  '${row.text} [${row.id}]',
                  evidenceIds: ids,
                  style: style,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _UrgentBox extends StatelessWidget {
  const _UrgentBox({
    required this.title,
    required this.rows,
    required this.ids,
  });

  final String title;
  final List<CardRow> rows;
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(color: colors.onErrorContainer);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: colors.onErrorContainer,
              ),
              Text(title, style: style.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          _Bullets(rows: rows, ids: ids, style: style),
        ],
      ),
    );
  }
}

const _dxText = {
  'en': (
    match: 'Signs match:',
    strong: 'strong match',
    likely: 'likely',
    possible: 'possible',
    also: 'Also consider:',
    note: 'Based on knowledge-base facts only; a vet must confirm.',
  ),
  'si': (
    match: 'ලක්ෂණ ගැළපෙන රෝගය:',
    strong: 'ප්‍රබල ගැළපීමක්',
    likely: 'ගැළපිය හැක',
    possible: 'විය හැක',
    also: 'මේවාත් සලකා බලන්න:',
    note: 'දැනුම් පදනමේ තොරතුරු මත පමණි; පශු වෛද්‍යවරයා තහවුරු කළ යුතුය.',
  ),
};

class _DiseaseMatchBox extends StatelessWidget {
  const _DiseaseMatchBox({required this.meta});

  final AskMeta meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final t = _dxText[meta.lang] ?? _dxText['en']!;
    final top = meta.diseases.first;
    final others = meta.diseases
        .skip(1)
        .where((d) => d.share >= 0.15)
        .map((d) => d.label);
    final confidence = top.share >= 0.6
        ? t.strong
        : top.share >= 0.4
        ? t.likely
        : t.possible;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onPrimaryContainer.withValues(alpha: 0.75),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${t.match} '),
                TextSpan(
                  text: top.label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' ($confidence)', style: muted),
              ],
            ),
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: top.share,
              minHeight: 5,
              backgroundColor: colors.surface,
            ),
          ),
          if (others.isNotEmpty)
            Text('${t.also} ${others.join(', ')}', style: muted),
          Text(t.note, style: muted),
        ],
      ),
    );
  }
}

const _sectionIcons = {
  'about': Icons.coronavirus_outlined,
  'signs': Icons.search,
  'treatment': Icons.medical_services_outlined,
  'care': Icons.home_outlined,
  'prevention': Icons.shield_outlined,
};

/// Topic card: intro, highlighted answer, collapsible sections, closing.
class _CardView extends StatelessWidget {
  const _CardView({
    required this.card,
    required this.ids,
    required this.withUrgent,
  });

  final AnswerCard card;
  final List<String> ids;
  final bool withUrgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sectionShape = RoundedRectangleBorder(
      side: BorderSide(color: colors.outlineVariant),
      borderRadius: BorderRadius.circular(10),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (withUrgent && card.urgent.isNotEmpty)
          _UrgentBox(title: card.urgentTitle, rows: card.urgent, ids: ids),
        if (card.intro.isNotEmpty) Text(card.intro),
        if (card.answer.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(
                  card.answerTitle.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
                _Bullets(rows: card.answer, ids: ids),
              ],
            ),
          ),
        for (final section in card.sections)
          ExpansionTile(
            initiallyExpanded: section.open,
            shape: sectionShape,
            collapsedShape: sectionShape,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading: Icon(
              _sectionIcons[section.key] ?? Icons.info_outline,
              color: colors.primary,
            ),
            title: Text(
              '${section.title}  (${section.items.length})',
              style: theme.textTheme.titleSmall,
            ),
            children: [_Bullets(rows: section.items, ids: ids)],
          ),
        if (card.contacts.isNotEmpty)
          VetContactsBox(
            title: card.contactsTitle,
            contacts: card.contacts,
            callLabel: card.callLabel,
          ),
        if (card.closing.isNotEmpty)
          Text(card.closing, style: TextStyle(color: colors.onSurfaceVariant)),
      ],
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine(this.icon, this.text, this.style);

  final IconData icon;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: style.color),
        ),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// Vet offices with a button that dials the number.
class VetContactsBox extends StatelessWidget {
  const VetContactsBox({
    super.key,
    required this.title,
    required this.contacts,
    required this.callLabel,
  });

  final String title;
  final List<VetContact> contacts;
  final String callLabel;

  Future<void> _call(BuildContext context, String phone) async {
    final dialled = await launchUrl(
      Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), '')),
    );
    if (!dialled && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Call $phone')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = TextStyle(color: colors.onSurfaceVariant, fontSize: 13);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(Icons.local_hospital_outlined, color: colors.primary),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          for (final vet in contacts)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        vet.office,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (vet.doctor case final doctor?)
                        _ContactLine(Icons.person_outline, doctor, muted),
                      if (vet.address case final address?)
                        _ContactLine(Icons.place_outlined, address, muted),
                      _ContactLine(Icons.phone_outlined, vet.phone, muted),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _call(context, vet.phone),
                  icon: const Icon(Icons.call, size: 18),
                  label: Text(callLabel),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

const _behaviourLabels = {
  'answer': 'Answered',
  'abstain': 'Not in knowledge base',
  'refuse': 'Refused (medicine/dose)',
  'chat': 'Chat',
};
const _sourceLabels = {
  'kb': 'Instant · knowledge base',
  'vet': 'Vet office contacts',
  'guard': 'Instant · safety filter',
  'retrieval': 'Instant · no matching fact',
  'chat': 'Instant',
  'model': 'AI model',
};

/// The server's checks on the answer, as small chips.
class _Checks extends StatelessWidget {
  const _Checks({required this.done});

  final DoneEvent done;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final checks = done.checks;
    final ok = (colors.primaryContainer, colors.onPrimaryContainer);
    final plain = (colors.surfaceContainerHighest, colors.onSurfaceVariant);
    final bad = (colors.errorContainer, colors.onErrorContainer);
    final answered = checks.behaviour == 'answer' || checks.behaviour == 'chat';

    final chips = [
      (
        _behaviourLabels[checks.behaviour] ?? checks.behaviour,
        answered ? ok : plain,
      ),
      if (_sourceLabels[done.source] case final source?) (source, plain),
      // Vet office contacts are not health facts, so they need no citation.
      if (checks.behaviour == 'answer' &&
          checks.validCites.isEmpty &&
          done.source != 'vet')
        ('No citation', bad),
      if (checks.inventedCites.isNotEmpty)
        ('Invented citation: ${checks.inventedCites.join(', ')}', bad),
      if (checks.doseLeak) ('Possible dose in answer', bad),
      if (done.truncated) ('Cut off at token limit', bad),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (label, (background, foreground)) in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: foreground),
            ),
          ),
      ],
    );
  }
}
