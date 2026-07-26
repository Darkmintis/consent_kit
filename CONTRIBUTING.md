# Contributing to ConsentKit

Thanks for helping improve ConsentKit!

## Development setup

```bash
git clone https://github.com/darkmintis/consent_kit.git
cd consent_kit
flutter pub get
flutter test
flutter analyze
```

Run the example:

```bash
cd example
flutter pub get
flutter run
```

## Guidelines

- Keep the public API small and documented with dartdoc
- Prefer tests for every behavior change
- Do not add analytics, network, or unnecessary dependencies
- Match existing code style (`flutter_lints`)

## Pull requests

1. Create a focused branch
2. Add/update tests
3. Ensure `flutter analyze` and `flutter test` pass
4. Open a PR with a short summary of *why* the change helps users
