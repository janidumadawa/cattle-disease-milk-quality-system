import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'answer_view.dart';
import 'chat_api.dart';
import 'chat_history_api.dart';
import 'chat_launcher.dart';
import 'chat_models.dart';

// Dark chat palette.
const _green = Color(0xFF006239);
const _background = Color(0xFF141414);
const _bubble = Color(0xFF232323);
const _field = Color(0xFF262626);
const _line = Color(0xFF2C2C2C);
const _muted = Color(0xFF9A9A9A);

const _greeting = {
  'en': 'How can I help with your herd today?',
  'si': 'අද ඔබේ ගව රංචුවට මම කොහොමද උදව් කරන්නේ?',
};
const _note = {
  'en':
      'Research prototype, not a substitute for a vet. '
      'I never give medicine names or doses.',
  'si':
      'පර්යේෂණ මූලාකෘතියකි; පශු වෛද්‍යවරයෙකු වෙනුවට නොවේ. '
      'මම බෙහෙත් නම් හෝ මාත්‍රා නොකියමි.',
};
const _hint = {'en': 'Ask a question…', 'si': 'ප්‍රශ්නයක් අහන්න…'};
const _suggestions = {
  'en': [
    'How do I prevent mastitis?',
    'What should I do if I suspect foot-and-mouth disease?',
    'My cow has blisters in its mouth',
    "My cow's udder is swollen and hot",
    'Is lumpy skin disease dangerous to humans?',
  ],
  'si': [
    'Mastitis වළක්වන්නේ කොහොමද?',
    'හරකාගේ කටේ බිබිලි',
    'මගේ හරකාගේ කුරවල තුවාලයක්',
    'හරකාගේ ඇඟ පුරා ගැටිති',
    'හරකාගේ ඇඟේ දද',
  ],
};

/// Cattle health chatbot, backed by the MedFarm chat server
/// (backend/models/chat_bot/app/server.py).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.api, this.history, this.onBack});

  /// The chat's dark background, for the app shell around it.
  static const backgroundColor = _background;

  /// Defaults to a [ChatApi] at [ChatApi.defaultBaseUrl].
  final ChatApi? api;

  /// Where the conversation is saved; defaults to the backend database.
  final ChatHistoryApi? history;

  /// Back arrow action; without it the arrow only shows when the route can pop.
  final VoidCallback? onBack;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _Turn {
  _Turn(this.question, this.reply, {this.savedId});

  final String question;
  final BotReply reply;

  /// Id of this turn in the saved chat history.
  int? savedId;

  /// Lets the list scroll this question to the top.
  final key = GlobalKey();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatApi _api = widget.api ?? ChatApi();
  late final ChatHistoryApi _saved = widget.history ?? ChatHistoryApi();
  String? _conversationId;
  final _turns = <_Turn>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  ServerStatus? _status;

  /// Answer language; also the language of the greeting and suggestions.
  String _lang = 'en';
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _loadConversation();
    chatQuestionRequest.addListener(_askRequested);
  }

  /// A question from another screen ("Ask the assistant about this").
  void _askRequested() {
    final question = chatQuestionRequest.value;
    if (question == null) return;
    chatQuestionRequest.value = null;
    if (RegExp('[඀-෿]').hasMatch(question)) {
      setState(() => _lang = 'si');
    }
    _send(question);
  }

  /// Shows this device's earlier conversation, so the chat (and follow-ups
  /// such as "how do I treat it?") continue after the app restarts.
  Future<void> _loadConversation() async {
    final id = await _saved.conversationId();
    if (id == null) return;
    _conversationId = id;
    final saved = await _saved.load(id);
    if (!mounted || saved.isEmpty || _turns.isNotEmpty) return;
    setState(() {
      _turns.addAll([
        for (final turn in saved)
          _Turn(turn.question, BotReply.fromJson(turn.reply), savedId: turn.id),
      ]);
      // Continue in the language the conversation was in.
      final lang = _turns.last.reply.meta?.lang;
      if (lang == 'en' || lang == 'si') _lang = lang!;
    });
    _scrollToEnd();
  }

  Future<void> _saveTurn(_Turn turn) async {
    final id = _conversationId;
    final meta = turn.reply.meta;
    if (id == null || meta == null || turn.reply.error != null) return;
    if (turn.savedId case final savedId?) {
      await _saved.update(id, savedId, turn.reply.toJson());
      return;
    }
    turn.savedId = await _saved.save(
      id,
      question: turn.question,
      reply: turn.reply.toJson(),
      lang: meta.lang,
      topic: meta.topic,
      sick: meta.sick,
    );
  }

  Future<void> _newChat() async {
    if (_busy) return;
    final id = await _saved.startNewConversation();
    if (!mounted) return;
    setState(() {
      _conversationId = id ?? _conversationId;
      _turns.clear();
    });
  }

  @override
  void dispose() {
    chatQuestionRequest.removeListener(_askRequested);
    _ticker?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final status = await _api.status();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _send(String question) async {
    question = question.trim();
    if (_busy || question.isEmpty) return;
    _input.clear();
    // Every answer comes from the local Ollama model, never fixed KB text.
    final turn = _Turn(question, BotReply(AnswerMode.model));
    setState(() => _turns.add(turn));
    await _stream(question, turn.reply, _historyBefore(turn), showFrom: turn);
    await _saveTurn(turn);
  }

  Future<void> _askModel(_Turn turn) async {
    if (_busy) return;
    final reply = BotReply(AnswerMode.model);
    setState(() => turn.reply.modelReply = reply);
    await _stream(turn.question, reply, _historyBefore(turn));
    if (reply.error == null) await _saveTurn(turn);
  }

  /// Questions suggested under the latest answer, minus ones already asked.
  List<String> get _nextQuestions {
    if (_busy || _turns.isEmpty) return const [];
    final reply = _turns.last.reply;
    if (!reply.finished || reply.error != null) return const [];
    final asked = {for (final t in _turns) t.question.trim().toLowerCase()};
    return [
      for (final q in reply.meta?.suggestions ?? const <String>[])
        if (!asked.contains(q.trim().toLowerCase())) q,
    ];
  }

  /// Earlier questions and their topics, so the server can answer follow-ups
  /// such as "how do I treat it?" or "she also has a fever".
  List<ChatTurn> _historyBefore(_Turn turn) => [
    for (final earlier in _turns.takeWhile((t) => t != turn))
      if (earlier.reply.meta case final meta?)
        ChatTurn(
          question: earlier.question,
          topic: meta.topic,
          sick: meta.sick,
        ),
  ];

  /// [showFrom]: keep that question at the top so the answer is read from
  /// its start; otherwise follow the newest text.
  Future<void> _stream(
    String question,
    BotReply reply,
    List<ChatTurn> history, {
    _Turn? showFrom,
  }) async {
    setState(() => _busy = true);
    void reveal() =>
        showFrom != null ? _scrollToTurn(showFrom) : _scrollToEnd();
    reveal();
    if (reply.mode == AnswerMode.model) {
      // Redraw the waiting time until the first word arrives.
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && reply.text.isEmpty) setState(() {});
      });
    }
    try {
      await for (final event in _api.ask(
        question,
        mode: reply.mode,
        lang: _lang,
        history: history,
      )) {
        if (!mounted) return;
        setState(() => reply.apply(event));
        if (event is DoneEvent || reply.mode == AnswerMode.model) reveal();
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => reply.error =
            'Could not reach the MedFarm chat server at ${_api.baseUrl}. '
            'Start it with backend/models/chat_bot/start.bat and try again.',
      );
    } finally {
      _ticker?.cancel();
      _ticker = null;
      if (mounted) {
        setState(() {
          reply.finished = true;
          _busy = false;
        });
      }
    }
    if (reply.error != null) _checkStatus();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _scrollToTurn(_Turn turn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = turn.key.currentContext;
      if (context == null || !context.mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String get _statusText => switch (_status) {
    null => 'Checking the chat server…',
    ServerStatus.ready => 'Chat server and AI model are ready.',
    ServerStatus.modelMissing =>
      'Chat server online. AI model not created yet: run start.bat. '
          'Knowledge-base answers still work.',
    ServerStatus.ollamaOff =>
      'Chat server online. Ollama is not running, so only '
          'knowledge-base answers work.',
    ServerStatus.offline => 'Chat server offline (${_api.baseUrl}).',
  };

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  ThemeData _darkTheme(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.dark,
      surface: _background,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _background,
      textTheme: Theme.of(context).textTheme
          .apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = widget.onBack != null || Navigator.canPop(context);

    return Theme(
      data: _darkTheme(context),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: canGoBack ? 0 : 16,
          leading: canGoBack
              ? IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                )
              : null,
          title: _Header(
            status: _status,
            statusText: _statusText,
            onTapStatus: () {
              _checkStatus();
              _snack(_statusText);
            },
          ),
          actions: [
            IconButton(
              tooltip: _lang == 'si' ? 'නව කතාබහක්' : 'New chat',
              onPressed: _busy || _turns.isEmpty ? null : _newChat,
              icon: const Icon(Icons.add_comment_outlined),
            ),
            _LanguageToggle(
              lang: _lang,
              onChanged: (lang) => setState(() => _lang = lang),
            ),
            const SizedBox(width: 12),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: _line),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _Padded(
                    _BotBubble(
                      maxWidthFactor: 0.8,
                      child: Text(
                        _greeting[_lang]!,
                        style: const TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ),
                  ),
                  _Padded(
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        _note[_lang]!,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                  ),
                  if (_status == ServerStatus.offline)
                    _Padded(
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _BotBubble(
                          maxWidthFactor: 0.8,
                          child: Text(
                            "I can't reach the MedFarm server at "
                            '${_api.baseUrl}. Start it with '
                            'backend/models/chat_bot/start.bat.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_turns.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _Suggestions(
                        questions: _suggestions[_lang]!,
                        onTap: _send,
                      ),
                    ),
                  for (final turn in _turns)
                    _Padded(
                      Padding(
                        key: turn.key,
                        padding: const EdgeInsets.only(top: 20),
                        child: _TurnView(
                          turn: turn,
                          busy: _busy,
                          onAskModel: () => _askModel(turn),
                        ),
                      ),
                    ),
                  if (_nextQuestions case final next when next.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _Suggestions(questions: next, onTap: _send),
                    ),
                ],
              ),
            ),
            _InputBar(
              controller: _input,
              hint: _hint[_lang]!,
              busy: _busy,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  );
}

/// Avatar with a server-status dot, title and subtitle.
class _Header extends StatelessWidget {
  const _Header({
    required this.status,
    required this.statusText,
    required this.onTapStatus,
  });

  final ServerStatus? status;
  final String statusText;
  final VoidCallback onTapStatus;

  @override
  Widget build(BuildContext context) {
    final dot = switch (status) {
      null => _muted,
      ServerStatus.offline => Theme.of(context).colorScheme.error,
      ServerStatus.ready => const Color(0xFF5BD38A),
      _ => const Color(0xFFE3B448), // online, AI model unavailable
    };

    return Tooltip(
      message: statusText,
      child: InkWell(
        onTap: onTapStatus,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          spacing: 10,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: _green,
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      border: Border.all(color: _background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MedFarm Assistant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Cattle health knowledge base',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// සි / EN pill.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.lang, required this.onChanged});

  final String lang;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String value, String label, String name) {
      final selected = lang == value;
      return Semantics(
        button: true,
        selected: selected,
        label: name,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? _green : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option('si', 'සි', 'Sinhala'),
          option('en', 'EN', 'English'),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.questions, required this.onTap});

  final List<String> questions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: questions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(
          label: Text(questions[i]),
          onPressed: () => onTap(questions[i]),
          backgroundColor: _background,
          side: const BorderSide(color: Color(0xFF3A3A3A)),
          shape: const StadiumBorder(),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  const _BotBubble({required this.child, this.maxWidthFactor = 1});

  final Widget child;
  final double maxWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * maxWidthFactor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: _bubble,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({
    required this.turn,
    required this.busy,
    required this.onAskModel,
  });

  final _Turn turn;
  final bool busy;
  final VoidCallback onAskModel;

  @override
  Widget build(BuildContext context) {
    final reply = turn.reply;
    // Offer the slower generated answer under a confident instant one.
    final offerModel =
        reply.mode == AnswerMode.fast &&
        reply.finished &&
        reply.error == null &&
        reply.meta?.confident == true &&
        reply.modelReply == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              turn.question,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
        _BotBubble(
          child: AnswerView(
            reply: reply,
            onAskModel: offerModel ? onAskModel : null,
            canAskModel: !busy,
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.hint,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final bool busy;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: const Color(0xFF5BD38A),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: _muted),
                filled: true,
                fillColor: _field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              ),
            ),
          ),
          SizedBox.square(
            dimension: 52,
            child: IconButton.filled(
              tooltip: 'Send',
              onPressed: busy ? null : () => onSend(controller.text),
              style: IconButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _green.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white54,
              ),
              icon: Transform.rotate(
                angle: -math.pi / 4,
                child: const Icon(Icons.send_outlined, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
