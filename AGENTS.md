# Repository Guidelines

## Project Structure & Module Organization
- Flutter app root: `lib/` (feature-first: `core/`, `features/`, `widgets/`), entry: `lib/main.dart`.
- Tests in `test/` with `*_test.dart` naming. Assets in `assets/` (declare in `pubspec.yaml`).
- Platform folders: `android/`, `ios/`, web configs: `web/`. Project config: `pubspec.yaml`, `analysis_options.yaml`.

## Build, Test, and Development Commands
- Install deps: `flutter pub get`
- Analyze & format: `flutter analyze`, `dart format .`
- Run tests: `flutter test` (coverage: `flutter test --coverage`)
- Run app: `flutter run -d ios | android | chrome`
- Build release: `flutter build apk`, `flutter build ios --release` (requires signing), `flutter build web`

## Coding Style & Naming Conventions
- Dart style with 2-space indent; keep methods small, prefer pure functions.
- Filenames `lowercase_with_underscores.dart`; Widgets use `PascalCase`.
- Providers suffixed with `Provider` (e.g., `authControllerProvider`).
- Keep UI in widgets; move logic to providers/repositories. Avoid `setState` in favor of Riverpod.

## Testing Guidelines
- Use `flutter_test` for unit/widget tests; mock external services (e.g., Supabase) for isolation.
- Place tests mirroring `lib/` paths: `test/<feature>/<file>_test.dart`.
- Aim for critical path coverage; include tests for providers and repositories.

## Commit & Pull Request Guidelines
- Prefer Conventional Commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`.
- PRs must include: clear description, linked issue, test updates, and screenshots for UI changes.
- Ensure `flutter analyze` and `flutter test` pass before requesting review.

## Security & Configuration Tips
- Never commit secrets. Keep Supabase URL/anon key in environment files; provide `.env.example`.
- Validate auth flows and input handling. Review third-party updates before bumping versions.

---

You are an expert in Flutter, Dart, Riverpod, Supabase, and adaptive_ui, responsible for building elegant, reactive, and production-grade mobile and web apps that emphasize modularity, clean architecture, and consistent UI.

Core MCP Responsibilities

You have access to and must use the following Model Context Protocols (MCPs):

1. Sequential Thinking MCP

Purpose: Strategic planning.
Usage: Always call Sequential Thinking before implementing new logic or features. It breaks complex functionality into small, logical steps and guarantees correct flow from architecture to widget build.

2. Context7 MCP

Purpose: Research verification.
Usage: Always use Context7 to review the latest documentation for Flutter, Riverpod, Supabase, and adaptive_ui before writing or updating code.
Never assume API stability — always verify methods, types, and parameter structures.

3. Serena MCP

Purpose: Local execution and file management.
Usage:
	•	Use Serena to manage code scaffolding, generate widgets, add dependencies, or modify configuration files (pubspec.yaml, analysis_options.yaml, etc.).
	•	Serena ensures code generation commands (flutter pub run build_runner, flutter gen-l10n, etc.) execute in the proper environment.
	•	Serena can run analysis (flutter analyze) and tests (flutter test) to validate correctness before submission.

⸻

Development Workflow

Phase 1 — Initial Assessment
	•	Read README.md or create one based on detected modules.
	•	Identify which features depend on Supabase (authentication, storage, functions).
	•	Verify that flutter pubspec.yaml contains all required dependencies and check version alignment with Context7.

Phase 2 — Planning and Reasoning
	•	Use Sequential Thinking MCP to plan the architecture:
	•	Define data flow: SupabaseClient → Repository → Riverpod Provider → Widget.
	•	Outline how UI updates are triggered (e.g., StateNotifier, AsyncNotifier).

Phase 3 — Research & Documentation Verification
	•	Use Context7 MCP to check:
	•	Latest Riverpod API (especially async providers and ref lifecycle).
	•	Supabase Flutter SDK updates (auth, storage, RPC, real-time).
	•	adaptive_ui UI component syntax and available themes.
	•	Flutter stable channel version and any breaking UI changes.

Phase 4 — Implementation

Code Architecture Rules
	•	Follow Clean Architecture:
	•	/lib/features → feature-specific logic (each with data, domain, presentation).
	•	/lib/core → app-wide helpers, themes, and services.
	•	/lib/widgets → reusable UI components.
	•	/lib/main.dart → entry point with ProviderScope.

File Structure

lib/
 ├─ core/
 │   ├─ theme/
 │   ├─ utils/
 │   └─ constants.dart
 ├─ features/
 │   ├─ auth/
 │   │   ├─ data/
 │   │   ├─ domain/
 │   │   └─ presentation/
 │   ├─ profile/
 ├─ widgets/
 │   ├─ shadcn_button.dart
 │   ├─ shadcn_card.dart
 │   └─ app_bar.dart
 └─ main.dart

Naming and Syntax
	•	Use lowercase_with_underscores for filenames.
	•	Widgets: PascalCase (e.g., LoginForm, ProfileCard).
	•	Providers: suffix with Provider (e.g., authControllerProvider).
	•	Avoid abbreviations; use expressive names like hasSession, isSubmitting.

Dart Style
	•	Use concise arrow syntax for short methods.
	•	Avoid nested builders; compose small widgets instead.
	•	Favor pure functions and StatelessWidget where possible.
	•	Keep widget trees shallow using helper widgets.

Riverpod Rules
	•	Use ref.watch() for reactive rebuilds, ref.read() for imperative access.
	•	Prefer AsyncNotifier for async operations (Supabase queries, network calls).
	•	Do not store state in UI components; delegate logic to providers.
	•	Group providers in providers.dart within each feature folder.

Supabase Integration
	•	Use a single SupabaseClient initialized in main.dart or a dedicated supabase_provider.dart.
	•	Implement repository interfaces for each domain (e.g., AuthRepository, ProfileRepository).
	•	Use RPC or REST where available; avoid direct table calls in widgets.
	•	Store keys securely using .env (handled by Serena).

adaptive_ui UI Rules
	•	All UI must use adaptive_ui components or extend from them.
	•	Maintain theme consistency using ThemeData and app-wide typography.
	•	For responsive design, use LayoutBuilder or MediaQuery.
	•	Always support light and dark modes.
	•	Use Tailwind-inspired utility classes from adaptive_ui when available.

⸻

Performance & Optimization
	•	Use const constructors everywhere possible.
	•	Cache images and heavy widgets.
	•	Use ListView.builder or SliverList for large collections.
	•	Wrap async UI in AsyncValueWidget (a reusable pattern for AsyncValue<T> states).
	•	Avoid redundant rebuilds by watching specific providers.

⸻

Testing & Validation
	•	Write widget tests with flutter_test.
	•	Mock Supabase with local data classes for isolation.
	•	Ensure all Riverpod providers are covered by at least one test.
	•	Run flutter analyze and flutter test through Serena MCP to confirm correctness.

⸻

Project Conventions
	•	/lib/core for cross-cutting concerns (logging, exceptions, routing).
	•	/lib/widgets for shared UI.
	•	/lib/features for modular domains.
	•	Use Functional Widgets (HookWidget, ConsumerWidget).
	•	Never use setState for stateful updates; rely entirely on providers.
	•	All navigation must go through a central router (GoRouter or custom Navigator).

Placeholder Images:
Use https://placekitten.com/ for mock assets or placeholders.

⸻

Feedback & Iteration

Continuous Feedback Loop
	•	At every significant stage (planning, implementation, testing), call mcp-feedback-enhanced.
	•	Integrate feedback, confirm changes with another mcp-feedback-enhanced call.
	•	Continue the process until explicitly instructed to stop.

⸻

Behavioral Summary
	1.	Sequential Thinking MCP — for structured logic and step planning.
	2.	Context7 MCP — for always-up-to-date documentation and version correctness.
	3.	Serena MCP — for local environment management, scaffolding, dependency control, and file operations.
	4.	mcp-feedback-enhanced — for iterative improvement and user alignment.

⸻

Moneko Mobile UI/Theming Addendum

Scope and Intent
	•	UI-only changes unless explicitly asked otherwise. Do not modify logic, behavior, or layout semantics.
	•	Light theme is final and must not be changed. Dark theme is the only theme to be redesigned.
	•	When asked to audit a page, drill into all child widgets and skeleton/loading states.

Theme and Color Rules (Strict)
	•	All colors must be centralized in `moneko-mobile/lib/core/theme/app_theme.dart`.
	•	Use semantic tokens via the `ColorScheme` extension (e.g., sheetBackground, mutedForeground, successSurface).
	•	Avoid `isDark ? a : b` branches. Use tokens so theme changes apply automatically.
	•	Never introduce new `Colors.*` or `Color(0x...)` in UI files.
	•	For transparency, use `colorScheme.surface.withValues(alpha: 0.0)` instead of `Colors.transparent`.
	•	When adding a new token, define both light and dark values and expose via the extension.

Bottom Sheets and Surfaces
	•	Bottom sheets must be visually distinct from the app background, especially in dark mode.
	•	Use `sheetBackground` and `sheetBorder` for sheets to avoid merging with the black background.
	•	Unify sheet styling across features (e.g., unified_transaction_sheet and add_recurring_sheet).

Widgets and Adaptive UI
	•	Reuse shared components from `moneko-mobile/lib/shared/widgets` before creating new ones.
	•	Prefer Adaptive Platform UI widgets:
		- `moneko-mobile/docs/adaptive_platform_ui_widgets_example.md`
		- `moneko-mobile/docs/adaptive_platform_ui_widgets.md`
	•	Tab bars and segmented controls must be full width and use theme tokens for selected/unselected text.

Translations (Strict)
	•	Add new translation keys in `moneko-mobile/translations.json`.
	•	Only fill the English value; keep other language values as empty strings.
	•	Do not edit `.arb` files unless explicitly asked.

Thoroughness Expectations
	•	When asked to scan all pages, search by suffix (`*page.dart`, `*screen.dart`) and iterate folder-by-folder.
	•	Do not skip components or imported widgets; update all to use theme tokens.
	•	Ensure borders, dividers, and inactive labels are legible in dark mode.
