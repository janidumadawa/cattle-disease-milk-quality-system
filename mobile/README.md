# MedFarm Mobile

Shared Flutter and Dart application foundation for research group J26-IT-413.

This application provides the common mobile interface for the MedFarm cattle disease and milk quality research system.

## Technologies

- Flutter

- Dart

- Material Design 3

## Supported Development Platforms

- Android

- Web (Chrome)

## Setup

Open a terminal in the `mobile` directory and run:

- `flutter pub get` - install dependencies.

- `flutter analyze` - check the code.

- `flutter test` - run automated tests.

To launch the application in Chrome, run `flutter run -d chrome`.

Android platform files are included. Android Studio and an emulator are not required for web development.

## Shared Foundation Scope

This package currently contains only the common MedFarm application shell.

Disease detection, milk quality analysis, treatment recommendations, chatbot functionality, and voice-based inquiry will be developed in separate feature branches and integrated through reviewed changes.

## Team Conventions

- Coordinate shared navigation and application configuration across the group.

- Place feature-specific screens and services in separate files.

- Document API contracts before integrating the mobile application with the Python backend.
