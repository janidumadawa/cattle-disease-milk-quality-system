# MedFarm Mobile

Shared Flutter and Dart application foundation for research group **J26-IT-413**.

This application provides the common mobile interface for the MedFarm Cattle Disease Detection and Milk Quality Analysis System.

## Technologies

- Flutter
- Dart
- Material Design 3

## Supported Platforms

- Android
- Web (Chrome)

## Getting Started

Make sure Flutter SDK is installed and configured.

Navigate to the `mobile` directory and run:

```bash
flutter pub get
```

## Run the Application

To launch the application in Chrome:

```bash
flutter run -d chrome
```

## Code Quality and Testing

Analyze the project for potential issues:

```bash
flutter analyze
```

Run the automated tests:

```bash
flutter test
```

## Shared Foundation

This package contains the common MedFarm mobile application shell and shared configuration.

The following features will be developed separately by the research team:

- IoT-based milk quality pre-screening
- AI-based treatment recommendations and RAG chatbot
- Image-based cattle disease detection
- Voice-based cattle disease inquiry

Feature implementations should be developed on dedicated feature branches and integrated through reviewed changes.

## Team Guidelines

- Coordinate changes to shared navigation and application configuration.
- Keep feature-specific screens and services in separate files.
- Document API request and response contracts before backend integration.
- Avoid committing secrets, credentials, or restricted research datasets.
