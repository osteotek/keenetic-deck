# Keenetic Deck

Keenetic Deck is a Flutter app for:

- Android
- iOS
- macOS
- Linux

## Workspace Layout

- `apps/keenetic_manager_app`
  Flutter application shell and platform targets
- `packages/router_core`
  Router API, entities, and shared application logic
- `packages/router_storage`
  Router metadata persistence
- `packages/platform_capabilities`
  Secure storage and local device/platform helpers
- `docs`
  Architecture and project status documents

## Development

Install Flutter and Dart, then work from the Flutter app directory:

```bash
cd apps/keenetic_manager_app
flutter pub get
flutter analyze
flutter test
```

For the shared packages:

```bash
cd packages/router_core && dart test
cd packages/router_storage && dart test
cd packages/platform_capabilities && flutter test
```

## macOS Build

```bash
cd apps/keenetic_manager_app
flutter build macos
```

## Icons

The app icon set is generated from:

- `data/icons/icon.svg`

Regenerate platform icons with:

```bash
./scripts/generate_flutter_icons.sh
```
