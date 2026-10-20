import 'package:flutter/foundation.dart';

/// A question for the chatbot from another screen, e.g. "Ask the assistant
/// about this" on the treatment guide. The app shell switches to the Chat tab
/// and the chat screen asks it, then sets this back to null.
final chatQuestionRequest = ValueNotifier<String?>(null);
