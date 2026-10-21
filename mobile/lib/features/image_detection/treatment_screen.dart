import 'package:flutter/material.dart';

import '../chatbot/answer_view.dart';
import '../chatbot/chat_launcher.dart';
import '../chatbot/chat_models.dart';
import 'treatment_guide.dart';

// Dark palette, matching the chat screen.
const _green = Color(0xFF006239);
const _accent = Color(0xFF5BD38A);
const _background = Color(0xFF141414);
const _card = Color(0xFF1E1E1E);
const _line = Color(0xFF2C2C2C);
const _muted = Color(0xFF9A9A9A);
const _red = Color(0xFFE5736B);
const _amber = Color(0xFFE3B448);

/// Treatment and care for a disease found by a photo scan ("See treatment").
class TreatmentScreen extends StatefulWidget {
  const TreatmentScreen({super.key, required this.classId, this.api});

  /// The image model's class, e.g. "Mastitis_High".
  final String classId;

  /// Defaults to the chatbot server, which holds the knowledge base.
  final TreatmentApi? api;

  @override
  State<TreatmentScreen> createState() => _TreatmentScreenState();
}

class _TreatmentScreenState extends State<TreatmentScreen> {
  late final TreatmentApi _api = widget.api ?? TreatmentApi();
  String _lang = 'en';
  late Future<TreatmentGuide> _guide = _load();

  /// "Do this first" steps the farmer has ticked.
  final _done = <String>{};

  Future<TreatmentGuide> _load() => _api.load(widget.classId, lang: _lang);

  void _setLang(String lang) {
    if (lang == _lang) return;
    setState(() {
      _lang = lang;
      _guide = _load();
    });
  }

  void _askAssistant(TreatmentGuide guide) {
    Navigator.of(context).pop();
    chatQuestionRequest.value = guide.ask;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        // Keep the app's fonts (and Sinhala fallback), in white.
        textTheme: Theme.of(context).textTheme
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          brightness: Brightness.dark,
          surface: _background,
        ),
        scaffoldBackgroundColor: _background,
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
        ),
      ),
      child: FutureBuilder<TreatmentGuide>(
        future: _guide,
        builder: (context, snapshot) {
          final guide = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                guide?.title ?? (_lang == 'si' ? 'ප්‍රතිකාර' : 'Treatment'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: [
                _LangSwitch(lang: _lang, onChanged: _setLang),
                const SizedBox(width: 12),
              ],
            ),
            body: switch (snapshot) {
              AsyncSnapshot(hasError: true) => _Error(
                onRetry: () => setState(() => _guide = _load()),
                serverUrl: _api.baseUrl,
              ),
              AsyncSnapshot(:final data?) => _GuideView(
                guide: data,
                done: _done,
                onToggle: (id) => setState(
                  () => _done.contains(id) ? _done.remove(id) : _done.add(id),
                ),
              ),
              _ => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _lang == 'si'
                            ? 'AI මාදිලිය ප්‍රතිකාර මඟපෙන්වීම ලියමින් සිටී. මෙයට මිනිත්තු කිහිපයක් ගත විය හැක.'
                            : 'The AI model is writing the treatment guide. This can take a few minutes.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            },
            bottomNavigationBar: guide == null
                ? null
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: FilledButton.icon(
                        onPressed: () => _askAssistant(guide),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.chat_outlined),
                        label: Text(guide.askButton),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _GuideView extends StatelessWidget {
  const _GuideView({
    required this.guide,
    required this.done,
    required this.onToggle,
  });

  final TreatmentGuide guide;
  final Set<String> done;
  final ValueChanged<String> onToggle;

  TreatmentSection? _section(String key) =>
      guide.sections.where((s) => s.key == key).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final first = _section('first');
    final dont = _section('dont');
    final vet = _section('vet');
    final milk = _section('milk');
    final callVet = _section('call_vet');
    final prevent = _section('prevent');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _Box(
          child: Text(
            guide.heading,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
        if (guide.severe case final severe?) ...[
          const SizedBox(height: 10),
          _Box(
            color: const Color(0xFF3A1E1E),
            border: _red,
            child: _IconLine(
              Icons.warning_amber_rounded,
              severe,
              color: _red,
              bold: true,
            ),
          ),
        ],
        if (guide.stageNote case final note?) ...[
          const SizedBox(height: 10),
          _Box(
            color: const Color(0xFF1A2A20),
            border: const Color(0xFF2F5A3E),
            child: _IconLine(Icons.eco_outlined, note, color: _accent),
          ),
        ],
        if (first != null) ...[
          _Heading(first.title),
          _Steps(items: first.items, done: done, onToggle: onToggle),
        ],
        if (dont != null) ...[
          const SizedBox(height: 18),
          _Box(
            color: const Color(0xFF2A1A1A),
            border: const Color(0xFF6B2E2E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  dont.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                for (final item in dont.items)
                  _IconLine(Icons.cancel_outlined, item.text, color: _red),
              ],
            ),
          ),
        ],
        if (vet != null) ...[
          _Heading(vet.title),
          _Box(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                for (final item in vet.items)
                  _IconLine(
                    Icons.medical_services_outlined,
                    item.text,
                    color: _accent,
                  ),
              ],
            ),
          ),
        ],
        if (guide.medicines.isNotEmpty) ...[
          _Heading(guide.medicinesTitle),
          for (final medicine in guide.medicines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MedicineCard(
                medicine: medicine,
                labels: guide.medicineLabels,
              ),
            ),
        ],
        _Box(
          color: _background,
          child: _IconLine(
            Icons.info_outline,
            guide.noMedicine,
            color: _muted,
            small: true,
          ),
        ),
        if (milk != null) ...[
          _Heading(milk.title),
          _Box(
            color: const Color(0xFF332B17),
            border: const Color(0xFF5C4B1F),
            child: Column(
              spacing: 8,
              children: [
                for (final item in milk.items)
                  _IconLine(Icons.schedule, item.text, color: _amber),
              ],
            ),
          ),
        ],
        if (callVet != null) ...[
          _Heading(callVet.title),
          _Box(
            child: Column(
              spacing: 8,
              children: [
                for (final item in callVet.items)
                  _IconLine(
                    Icons.warning_amber_rounded,
                    item.text,
                    color: _amber,
                  ),
              ],
            ),
          ),
        ],
        if (guide.contacts.isNotEmpty) ...[
          const SizedBox(height: 18),
          VetContactsBox(
            title: guide.contactsTitle,
            contacts: guide.contacts,
            callLabel: guide.callLabel,
          ),
        ],
        if (prevent != null) ...[
          _Heading(prevent.title),
          _Box(
            child: Column(
              spacing: 8,
              children: [
                for (final item in prevent.items)
                  _IconLine(Icons.shield_outlined, item.text, color: _accent),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          '${guide.sourcesTitle}: ${guide.sources.map(_site).toSet().join(', ')}',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    );
  }

  static String _site(String url) {
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
    return switch (host) {
      'merckvetmanual.com' => 'Merck Veterinary Manual',
      'woah.org' => 'WOAH',
      _ => host,
    };
  }
}

/// One medicine: name, type, dose / route / frequency / duration grid and the
/// milk withdrawal bar. Empty fields read "set by your vet".
class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine, required this.labels});

  final TreatmentMedicine medicine;
  final Map<String, String> labels;

  String _label(String key, String fallback) => labels[key] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final byVet = _label('by_vet', 'Set by your vet');
    final setByVet =
        medicine.dose == null &&
        medicine.frequency == null &&
        medicine.duration == null;
    Widget field(String key, String fallback, String? value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          _label(key, fallback).toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.5,
            color: _muted,
          ),
        ),
        Text(
          value ?? byVet,
          style: TextStyle(
            fontSize: 14,
            fontWeight: value == null ? FontWeight.w400 : FontWeight.w700,
            color: value == null ? _muted : Colors.white,
            fontStyle: value == null ? FontStyle.italic : null,
          ),
        ),
      ],
    );

    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            medicine.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (medicine.kind.isNotEmpty) _Tag(medicine.kind, _line),
              if (medicine.prescription)
                _Tag(
                  _label('prescription', 'Prescription: given by a vet'),
                  const Color(0xFF1F3327),
                  color: _accent,
                ),
            ],
          ),
          if (medicine.use.isNotEmpty)
            Text(
              medicine.use,
              style: const TextStyle(fontSize: 13.5, height: 1.35),
            ),
          // When the vet sets everything, say it once instead of in every box.
          if (setByVet) ...[
            if (medicine.route != null)
              field('route', 'How it is given', medicine.route),
            _IconLine(
              Icons.person_search_outlined,
              _label(
                'all_by_vet',
                'Dose, how often and how long: set by your vet',
              ),
              color: _muted,
              small: true,
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Expanded(child: field('dose', 'Dose', medicine.dose)),
                Expanded(
                  child: field('route', 'How it is given', medicine.route),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Expanded(
                  child: field('frequency', 'How often', medicine.frequency),
                ),
                Expanded(
                  child: field('duration', 'How long', medicine.duration),
                ),
              ],
            ),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF332B17),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _IconLine(
              Icons.schedule,
              '${_label('withdrawal', 'Milk and meat withdrawal')}: '
              '${medicine.withdrawal ?? _label('withdrawal_default', 'Ask your vet')}',
              color: _amber,
              small: true,
            ),
          ),
          if (medicine.source.isNotEmpty)
            Text(
              '${_label('source', 'Source')}: '
              '${_GuideView._site(medicine.source)}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.background, {this.color = _muted});

  final String text;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(fontSize: 11.5, color: color)),
  );
}

/// "Do this first": numbered steps the farmer can tick off.
class _Steps extends StatelessWidget {
  const _Steps({
    required this.items,
    required this.done,
    required this.onToggle,
  });

  final List<CardRow> items;
  final Set<String> done;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, item) in items.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1F3327),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (i < items.length - 1)
                      const Expanded(
                        child: VerticalDivider(width: 2, color: _line),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 16),
                    child: Text(
                      item.text,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: done.contains(item.id) ? _muted : Colors.white,
                        decoration: done.contains(item.id)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Done',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onToggle(item.id),
                  icon: Icon(
                    done.contains(item.id)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: done.contains(item.id) ? _accent : _muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  );
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.color = _card, this.border = _line});

  final Widget child;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _IconLine extends StatelessWidget {
  const _IconLine(
    this.icon,
    this.text, {
    required this.color,
    this.bold = false,
    this.small = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool bold;
  final bool small;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 10,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: small ? 16 : 18, color: color),
      ),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: small ? 12.5 : 14,
            height: 1.35,
            color: small ? _muted : Colors.white,
            fontWeight: bold ? FontWeight.w600 : null,
          ),
        ),
      ),
    ],
  );
}

class _LangSwitch extends StatelessWidget {
  const _LangSwitch({required this.lang, required this.onChanged});

  final String lang;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String value, String label) => GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: lang == value ? _green : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: lang == value ? Colors.white : _muted,
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('si', 'සි'), option('en', 'EN')],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry, required this.serverUrl});

  final VoidCallback onRetry;
  final String serverUrl;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: _muted),
          Text(
            'Could not load the treatment guide from $serverUrl. '
            'Start the backend with backend\\start.bat and try again.',
            textAlign: TextAlign.center,
          ),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
