# Moneko Mobile - Project Overview

**Moneko Mobile** is the mobile application component of the Moneko platform, a comprehensive financial technology platform. It is a Flutter application designed for iOS and Android.

## Tech Stack
*   **Framework**: Flutter (SDK >=3.1.5 <4.0.0)
*   **Language**: Dart
*   **State Management**: `hooks_riverpod` (^2.4.9)
*   **Dependency Injection**: Riverpod
*   **Backend**: Supabase (`supabase_flutter`) & Firebase (`firebase_core`, `firebase_messaging`)
*   **Routing**: `go_router`
*   **UI Components**: Material 3, Cupertino, `adaptive_platform_ui`, `skeletonizer`
*   **Charts**: `fl_chart`
*   **Code Generation**: `build_runner`, `freezed`, `json_serializable`, `riverpod_generator`

## Codebase Structure
*   `lib/`: Main source code.
    *   `core/`: Core utilities, theme, routing, app setup (`app.dart`).
    *   `features/`: Feature-based modular architecture (e.g., `home`, `households`, `recurring`).
        *   `presentation/`: UI components (pages, widgets), providers, state.
        *   `domain/`: Entities, repositories interfaces.
        *   `data/`: Implementations, services.
    *   `shared/`: Shared widgets and utilities.
*   `assets/`: Images, icons, env files.

## Style and Conventions
*   **Linting**: Strict linting using `flutter_lints` and `custom_lint` (Riverpod lints).
*   **Theming**: Custom semantic color system (`AppColorScheme` extension on `ColorScheme`). "Apple-like" aesthetic.
*   **Async**: Extensive use of `AsyncValue` with Riverpod.

