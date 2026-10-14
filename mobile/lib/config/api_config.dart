import 'package:flutter/foundation.dart';

/// Where the app finds the MedFarm backend.
///
/// Override when running the app, for example to reach the backend from a
/// real phone on the same Wi-Fi:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000`
class ApiConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) {
      return _override;
    }
    // The Android emulator reaches the host computer at 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}
