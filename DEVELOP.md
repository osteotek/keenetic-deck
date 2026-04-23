# Development

This repository is Flutter/Dart only.

## Main Commands

Application:

```bash
cd apps/keenetic_manager_app
flutter pub get
flutter analyze
flutter test
flutter build macos
```

Shared packages:

```bash
cd packages/router_core && dart test
cd packages/router_storage && dart test
cd packages/platform_capabilities && flutter test
```

## Repo Areas

- `apps/keenetic_manager_app`: Flutter UI and platform runners
- `packages/router_core`: shared router logic and models
- `packages/router_storage`: router metadata persistence
- `packages/platform_capabilities`: secure storage and local device helpers
- `docs`: architecture and project status notes

## Notes

- The SVG icon source in `data/icons/icon.svg` is used to generate platform icons.
