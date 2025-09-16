# Repository Guidelines
## 對話風格
- 統一使用繁體中文
- 程式要完整的物件導向
- 每段程式都要有清楚的中文註解註明用途和邏輯以及輸入輸出對應
- 每個檔案都要在前面中文註解說明這個檔案主要負責的功能
## 對應測試環境
- android auto
- pixel 9 xl 模擬器
## Project Structure & Module Organization
- `lib/` holds production Dart code; place shared widgets under `lib/widgets/` and feature logic in dedicated subfolders.
- `test/` contains unit and widget tests mirroring the `lib/` layout for easy discovery.
- Platform integrations live in `android/`, `ios/`, `web/`, `macos/`, `linux/`, and `windows/`; update only when platform-specific code changes.
- Configuration files such as `pubspec.yaml` and `analysis_options.yaml` define dependencies, lints, and build settings—keep them in sync with code updates.

## Build, Test, and Development Commands
- `flutter pub get` — install or update the dependencies declared in `pubspec.yaml`.
- `flutter analyze` — run static analysis using the rules from `analysis_options.yaml`.
- `flutter test` — execute all tests under `test/` with coverage reporting when invoked with `--coverage`.
- `flutter run` — launch the application on the connected device or simulator for iterative development.
- `flutter build apk` / `flutter build ios` — produce release artifacts for Android or iOS (ensure platform prerequisites are installed).

## Coding Style & Naming Conventions
- Follow Dart style: two-space indentation, `lowerCamelCase` for variables/functions, `UpperCamelCase` for classes, and `SCREAMING_SNAKE_CASE` for compile-time constants.
- Use descriptive widget and state class names, e.g., `EpisodeListView` or `PlaybackController`.
- Format code with `dart format .` before committing; the CI expects formatted output.
- Address analyzer warnings promptly; treat new lint issues as build failures.

## Testing Guidelines
- Write unit tests for business logic and widget tests for UI components; mirror test file names with `_test.dart` suffix (e.g., `episode_service_test.dart`).
- Prefer arranging tests with `group` and `setUp` blocks for clarity.
- Run `flutter test --coverage` before submitting significant changes and review `coverage/lcov.info`.

## Commit & Pull Request Guidelines
- Use imperative, present-tense commit messages capped at 72 characters, with optional extended descriptions for context.
- Each PR should include: a concise summary, linked issue (if any), testing evidence (command outputs or screenshots), and notes on platform-specific impacts.
- Rebase on the latest `main` and resolve conflicts locally before requesting review; keep PRs focused on a single feature or fix.
