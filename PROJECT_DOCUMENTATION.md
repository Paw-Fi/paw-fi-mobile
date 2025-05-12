# Stock Invest Edu App - Project Documentation

## Project Overview
This is a Flutter application that provides stock investment education. The app uses Flutter for the frontend, Riverpod for state management, and Supabase as the Backend as a Service (BaaS).

## Tech Stack
- **Frontend**: Flutter
- **State Management**: Riverpod (with Hooks and Annotations)
- **Backend as a Service**: Supabase
- **Routing**: Go Router
- **Environment**: Flutter dotenv

### Android Build Configuration
- **Android Gradle Plugin**: Version 8.1.0
- **Kotlin Version**: 1.8.10
- **Gradle Version**: 8.0
- **Java Compatibility**: Java 17
- **NDK Version**: 21.4.7075529

## Project Structure

### Root Structure
```
/stock-invest-edu-app
├── .dart_tool
├── .env                  # Environment variables (private)
├── .env.example          # Example environment variables
├── .flutter-plugins
├── .flutter-plugins-dependencies
├── .gitignore
├── .metadata
├── .vscode
├── .windsurfrules        # Project rules and guidelines
├── README.md
├── analysis_options.yaml
├── android               # Android platform code
├── custom_lint.log
├── ios                   # iOS platform code
├── lib                   # Main Dart code
├── pubspec.lock
└── pubspec.yaml          # Project dependencies
```

### `lib` Directory (Main Code)
```
/lib
├── core                  # Core application functionality
│   ├── app
│   │   ├── app.dart      # Main app widget
│   │   ├── init.dart     # App initialization
│   │   ├── router.dart   # App routing
│   │   └── router.g.dart # Generated router code
│   ├── core.dart         # Core exports
│   ├── resources         # Resources like assets, constants
│   ├── ui                # Common UI components
│   │   ├── pages         # Shared page components
│   │   │   └── error_page.dart   # Error page for route errors
│   │   ├── widgets       # Shared UI widgets
│   │   └── ui.dart       # UI exports
│   └── util              # Utility functions
├── features              # Feature modules
│   ├── auth              # Authentication feature
│   │   ├── auth.dart     # Authentication exports
│   │   ├── domain        # Business logic for auth
│   │   │   ├── app_user.dart            # User model
│   │   │   ├── app_user.freezed.dart    # Generated code
│   │   │   ├── app_user.g.dart          # Generated code
│   │   │   └── domain.dart              # Domain exports
│   │   └── presentation  # UI components for auth
│   │       ├── pages
│   │       │   └── login_page.dart      # Login screen
│   │       ├── presentation.dart        # Presentation exports
│   │       └── states                   # State management
│   └── home              # Home feature
│       ├── home.dart     # Home exports
│       └── presentation  # UI components for home
│           ├── pages     # Home pages
│           └── presentation.dart # Presentation exports
└── main.dart             # Application entry point
```

## Initialization Process
The app initializes by:
1. Loading environment variables from `.env` file
2. Initializing Supabase (BaaS)
3. Setting up Riverpod for state management
4. Configuring GoRouter for navigation

## Authentication Flow
The app implements authentication using Supabase. The router redirects unauthenticated users to the login page and authenticated users to the home page.

## App Routing
- `/login` - Login page (initial route)
- `/` - Home page (requires authentication)

## Naming Conventions
- **Files:** snake_case (e.g., login_page.dart)
- **Classes:** PascalCase (e.g., LoginPage)
- **Variables/Functions:** camelCase

## Project Structure Guidelines
The project follows clean architecture principles with separation of:
- **Domain:** Business logic and models
- **Presentation:** UI components (pages, widgets)
- **Data:** Data sources and repositories (when implemented)

## Coding Patterns
- Uses Riverpod for state management
- Uses freezed for immutable models
- Uses GoRouter for declarative routing
- Follows Flutter best practices

## Supabase Integration
Supabase is initialized in the `init.dart` file and is used for:
- Authentication
- Database storage
- File storage (potential future use)

## Pending Features / Future Development
- Additional authentication methods
- Stock information screens
- Educational content
- User profile management
- Investment tracking

## Development Guidelines
- Follow clean architecture principles
- Maintain feature isolation
- Maintain separation of concerns
- Adhere to the single responsibility principle
- Keep code DRY (Don't Repeat Yourself)
- Prioritize feature-level placement
