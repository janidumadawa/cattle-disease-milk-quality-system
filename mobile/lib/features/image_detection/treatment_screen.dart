import 'dart:async';

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
  const TreatmentScreen({
    super.key,
    required this.classId,
    this.api,
    this.loadingDelay = const Duration(seconds: 15),
  });

  /// The image model's class, e.g. "Mastitis_High".
  final String classId;

  /// Defaults to the chatbot server, which holds the knowledge base.
  final TreatmentApi? api;

  /// The loading screen shows at least this long when the guide first opens
  /// (the guide loads meanwhile). Retries and language changes do not wait.
  final Duration loadingDelay;

  @override
  State<TreatmentScreen> createState() => _TreatmentScreenState();
}

class _TreatmentScreenState extends State<TreatmentScreen> {
  late final TreatmentApi _api = widget.api ?? TreatmentApi();
  String _lang = 'en';
  late Future<TreatmentGuide> _guide = Future.wait([
    _load(),
    Future<void>.delayed(widget.loadingDelay),
  ]).then((results) => results.first as TreatmentGuide);

  /// "Do this first" steps the farmer has ticked.
  final _done = <String>{};

  /// The guide types out only the first time it shows; once it has been
  /// shown, a language change shows the new text at once.
  bool _shown = false;
  bool _typeOut = true;

  Future<TreatmentGuide> _load() => _api.load(widget.classId, lang: _lang);

  void _setLang(String lang) {
    if (lang == _lang) return;
    setState(() {
      _lang = lang;
      _typeOut = !_shown;
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
          final guide = snapshot.connectionState == ConnectionState.done
              ? snapshot.data
              : null;
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
              // A language change loads afresh, then shows without typing.
              AsyncSnapshot(:final data?)
                  when snapshot.connectionState == ConnectionState.done =>
                _GuideView(
                  guide: data,
                  typeOut: _typeOut,
                  onShown: () => _shown = true,
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
                            ? 'ප්‍රතිකාර මඟපෙන්වීම පූරණය වෙමින්...'
                            : 'Loading the treatment guide...',
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

/// How fast the guide types itself out, like a chat answer being written.
const _typeEvery = Duration(
  milliseconds: 60,
); // one character: about 17 per second
const _cursor = '▍';

/// The number of characters typed so far; texts and blocks below read it.
class _TypingClock extends InheritedNotifier<ValueNotifier<int>> {
  const _TypingClock({required super.notifier, required super.child});

  /// Without a clock everything shows at once.
  static int of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_TypingClock>()
          ?.notifier
          ?.value ??
      1 << 30;
}

/// Gives each text its place in the typing order, top to bottom.
class _TypeOrder {
  int _next = 0;

  /// Where [text] starts; it types out over its length.
  int text(String text) {
    final start = _next;
    _next += text.characters.length;
    return start;
  }

  /// A block with no typed text: it appears, then typing waits a moment.
  int block([int pause = 10]) {
    final start = _next;
    _next += pause;
    return start;
  }

  int get total => _next;
}

/// [text] typed out from character [from] of the guide, with a cursor.
class _Typed extends StatelessWidget {
  const _Typed(this.text, {required this.from, this.style});

  final String text;
  final int from;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final shown = _TypingClock.of(context) - from;
    final chars = text.characters;
    return Text(
      shown >= chars.length
          ? text
          : '${chars.take(shown < 0 ? 0 : shown)}$_cursor',
      style: style,
    );
  }
}

/// Shows [child] once typing reaches [from].
class _Reveal extends StatelessWidget {
  const _Reveal({required this.from, required this.child});

  final int from;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _TypingClock.of(context) >= from ? child : const SizedBox.shrink();
}

class _GuideView extends StatefulWidget {
  const _GuideView({
    required this.guide,
    required this.typeOut,
    required this.onShown,
    required this.done,
    required this.onToggle,
  });

  final TreatmentGuide guide;

  /// Type the guide out; otherwise show it all at once.
  final bool typeOut;

  /// Called once the guide is fully on screen.
  final VoidCallback onShown;
  final Set<String> done;
  final ValueChanged<String> onToggle;

  @override
  State<_GuideView> createState() => _GuideViewState();

  /// What the guide names as its source, instead of each site.
  static const _database = 'Veterinary database';
}

class _GuideViewState extends State<_GuideView> {
  final _typed = ValueNotifier<int>(0);
  Timer? _timer;
  int _total = 0;

  TreatmentGuide get guide => widget.guide;

  TreatmentSection? _section(String key) =>
      guide.sections.where((s) => s.key == key).firstOrNull;

  @override
  void initState() {
    super.initState();
    _type();
  }

  @override
  void didUpdateWidget(_GuideView old) {
    super.didUpdateWidget(old);
    // A new guide (another language) shows at once; ticking a step does not.
    if (!identical(old.guide, widget.guide)) _type();
  }

  void _type() {
    _timer?.cancel();
    if (!widget.typeOut) {
      _typed.value = 1 << 30;
      widget.onShown();
      return;
    }
    _typed.value = 0;
    _timer = Timer.periodic(_typeEvery, (timer) {
      if (_typed.value >= _total) {
        widget.onShown();
        return timer.cancel();
      }
      _typed.value++;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = _section('first');
    final dont = _section('dont');
    final vet = _section('vet');
    final milk = _section('milk');
    final callVet = _section('call_vet');
    final prevent = _section('prevent');

    // Every text gets its start in reading order before the widgets are built.
    final order = _TypeOrder();
    final heading = order.text(guide.heading);
    final severe = guide.severe == null ? 0 : order.text(guide.severe!);
    final note = guide.stageNote == null ? 0 : order.text(guide.stageNote!);
    List<int> items(TreatmentSection? section) => [
      for (final item in section?.items ?? const <CardRow>[])
        order.text(item.text),
    ];
    final firstAt = items(first);
    final dontAt = items(dont);
    final vetAt = items(vet);
    final medicinesAt = [
      for (final medicine in guide.medicines)
        (
          card: order.block(),
          name: order.text(medicine.name),
          use: order.text(medicine.use),
        ),
    ];
    final noMedicine = order.text(guide.noMedicine);
    final milkAt = items(milk);
    final callVetAt = items(callVet);
    final contacts = order.block(20);
    final preventAt = items(prevent);
    final sources = order.block();
    _total = order.total;

    return _TypingClock(
      notifier: _typed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Box(
            child: _Typed(
              guide.heading,
              from: heading,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
          if (guide.severe case final text?)
            _Reveal(
              from: severe,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _Box(
                  color: const Color(0xFF3A1E1E),
                  border: _red,
                  child: _IconLine(
                    Icons.warning_amber_rounded,
                    text,
                    from: severe,
                    color: _red,
                    bold: true,
                  ),
                ),
              ),
            ),
          if (guide.stageNote case final text?)
            _Reveal(
              from: note,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _Box(
                  color: const Color(0xFF1A2A20),
                  border: const Color(0xFF2F5A3E),
                  child: _IconLine(
                    Icons.eco_outlined,
                    text,
                    from: note,
                    color: _accent,
                  ),
                ),
              ),
            ),
          if (first != null)
            _Reveal(
              from: firstAt.first,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Heading(first.title),
                  _Steps(
                    items: first.items,
                    from: firstAt,
                    done: widget.done,
                    onToggle: widget.onToggle,
                  ),
                ],
              ),
            ),
          if (dont != null)
            _Reveal(
              from: dontAt.first,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _Box(
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
                      for (final (i, item) in dont.items.indexed)
                        _IconLine(
                          Icons.cancel_outlined,
                          item.text,
                          from: dontAt[i],
                          color: _red,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (vet != null)
            _Section(
              title: vet.title,
              from: vetAt.first,
              spacing: 10,
              children: [
                for (final (i, item) in vet.items.indexed)
                  _IconLine(
                    Icons.medical_services_outlined,
                    item.text,
                    from: vetAt[i],
                    color: _accent,
                  ),
              ],
            ),
          if (guide.medicines.isNotEmpty)
            _Reveal(
              from: medicinesAt.first.card,
              child: _Heading(guide.medicinesTitle),
            ),
          for (final (i, medicine) in guide.medicines.indexed)
            _Reveal(
              from: medicinesAt[i].card,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MedicineCard(
                  medicine: medicine,
                  labels: guide.medicineLabels,
                  nameFrom: medicinesAt[i].name,
                  useFrom: medicinesAt[i].use,
                ),
              ),
            ),
          _Reveal(
            from: noMedicine,
            child: _Box(
              color: _background,
              child: _IconLine(
                Icons.info_outline,
                guide.noMedicine,
                from: noMedicine,
                color: _muted,
                small: true,
              ),
            ),
          ),
          if (milk != null)
            _Section(
              title: milk.title,
              from: milkAt.first,
              color: const Color(0xFF332B17),
              border: const Color(0xFF5C4B1F),
              children: [
                for (final (i, item) in milk.items.indexed)
                  _IconLine(
                    Icons.schedule,
                    item.text,
                    from: milkAt[i],
                    color: _amber,
                  ),
              ],
            ),
          if (callVet != null)
            _Section(
              title: callVet.title,
              from: callVetAt.first,
              children: [
                for (final (i, item) in callVet.items.indexed)
                  _IconLine(
                    Icons.warning_amber_rounded,
                    item.text,
                    from: callVetAt[i],
                    color: _amber,
                  ),
              ],
            ),
          if (guide.contacts.isNotEmpty)
            _Reveal(
              from: contacts,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: VetContactsBox(
                  title: guide.contactsTitle,
                  contacts: guide.contacts,
                  callLabel: guide.callLabel,
                ),
              ),
            ),
          if (prevent != null)
            _Section(
              title: prevent.title,
              from: preventAt.first,
              children: [
                for (final (i, item) in prevent.items.indexed)
                  _IconLine(
                    Icons.shield_outlined,
                    item.text,
                    from: preventAt[i],
                    color: _accent,
                  ),
              ],
            ),
          _Reveal(
            from: sources,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                '${guide.sourcesTitle}: ${_GuideView._database}',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A heading and a box of lines, shown once its first line starts typing.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.from,
    required this.children,
    this.spacing = 8,
    this.color = _card,
    this.border = _line,
  });

  final String title;
  final int from;
  final List<Widget> children;
  final double spacing;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) => _Reveal(
    from: from,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(title),
        _Box(
          color: color,
          border: border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing,
            children: children,
          ),
        ),
      ],
    ),
  );
}

/// One medicine: name, type, dose / route / frequency / duration grid and the
/// milk withdrawal bar. Empty fields read "set by your vet".
class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.labels,
    required this.nameFrom,
    required this.useFrom,
  });

  final TreatmentMedicine medicine;
  final Map<String, String> labels;

  /// Where the name and the use start typing.
  final int nameFrom;
  final int useFrom;

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
          _Typed(
            medicine.name,
            from: nameFrom,
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
            _Typed(
              medicine.use,
              from: useFrom,
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
              '${_label('source', 'Source')}: ${_GuideView._database}',
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
    required this.from,
    required this.done,
    required this.onToggle,
  });

  final List<CardRow> items;

  /// Where each step starts typing.
  final List<int> from;
  final Set<String> done;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, item) in items.indexed)
          _Reveal(
            from: from[i],
            child: IntrinsicHeight(
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
                      child: _Typed(
                        item.text,
                        from: from[i],
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
    this.from,
    this.bold = false,
    this.small = false,
  });

  final IconData icon;
  final String text;
  final Color color;

  /// Where this line starts typing; null shows it as it is.
  final int? from;
  final bool bold;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: small ? 12.5 : 14,
      height: 1.35,
      color: small ? _muted : Colors.white,
      fontWeight: bold ? FontWeight.w600 : null,
    );
    final line = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: small ? 16 : 18, color: color),
        ),
        Expanded(
          child: switch (from) {
            final from? => _Typed(text, from: from, style: style),
            null => Text(text, style: style),
          },
        ),
      ],
    );
    return switch (from) {
      final from? => _Reveal(from: from, child: line),
      null => line,
    };
  }
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
