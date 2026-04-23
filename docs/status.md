# Keenetic Deck Project Status

Last updated: 2026-04-23

This document summarizes the current state of the Keenetic Deck codebase.

## Delivery Areas

The project is organized around eight delivery areas:

1. M1. Specification Freeze
2. M2. Shared Core
3. M3. Storage and Secrets
4. M4. App Shell and Router CRUD
5. M5. Clients and Policies
6. M6. WireGuard
7. M7. Capability-Based Features
8. M8. Release Engineering

## Current Status Summary

### Completed

- M1. Specification Freeze
- M2. Shared Core
- M4. App Shell and Router CRUD
- Most of M5. Clients and Policies

### Partially Completed

- M3. Storage and Secrets
- M6. WireGuard
- M7. Capability-Based Features
- M8. Release Engineering

### Not Completed

- Full release packaging/signing/distribution readiness
- CI matrix and automated multi-platform build verification
- Final icon/branding assets
- Localization
- A dedicated Wake-on-LAN workflow in the Flutter UI

## Milestone Review

### D1. Architecture

Status: completed

Implemented:

- Architecture captured in `docs/architecture.md`
- Flutter chosen as the target stack
- Package boundaries established:
  - `apps/keenetic_manager_app`
  - `packages/router_core`
  - `packages/router_storage`
  - `packages/platform_capabilities`

Remaining:

- Nothing blocking in this milestone

### D2. Shared Core

Status: completed

Implemented:

- Dart router models and contracts in `packages/router_core/lib`
- Concrete Keenetic router client in `packages/router_core/lib/src/services/keenetic_router_api.dart`
- Connection resolution in `packages/router_core/lib/src/services/default_connection_resolver.dart`
- Router metadata refresh in `packages/router_core/lib/src/services/default_router_metadata_refresher.dart`
- Unit tests for API and connection resolution in `packages/router_core/test`

Remaining:

- No major milestone blocker
- Future refinement only: broader fixture coverage if new API edge cases are found

### D3. Storage and Secrets

Status: partially completed

Implemented:

- JSON-backed router repository in `packages/router_storage/lib/src/json_router_repository.dart`
- Secure password storage in `packages/platform_capabilities/lib/src/secure_storage_secret_repository.dart`
- Tests for storage and secure storage packages

Remaining:

- Add explicit schema/version handling beyond the current initial shape
- Add backup/restore or export/import strategy if required

### D4. App Shell and Router CRUD

Status: completed

Implemented:

- Adaptive navigation shell in `apps/keenetic_manager_app/lib/main.dart`
- Sectioned UI for:
  - this device
  - clients
  - policies
  - wireguard
  - routers
  - settings
- Router CRUD and onboarding validation in:
  - `apps/keenetic_manager_app/lib/src/router_overview_controller.dart`
  - `apps/keenetic_manager_app/lib/src/router_onboarding_service.dart`
  - `apps/keenetic_manager_app/lib/src/router_editor_dialog.dart`

Remaining:

- Additional onboarding polish such as richer validation hints and recovery flows

### D5. Clients and Policies

Status: mostly completed

Implemented:

- Live client list with search and online/offline sorting
- Policy grouping screen
- Apply default policy
- Apply named policy
- Block client
- Shared action flow reused in both client and local-device views

Remaining:

- Explicit unblock flow if the router API semantics should be surfaced separately from setting default/named policy
- More widget/integration coverage around action menus and error states
- Localization of UI strings

### D6. WireGuard

Status: partially completed

Implemented:

- WireGuard peer list and grouping by interface
- Dedicated WireGuard section in the app shell

Remaining:

- Confirm whether there are peer actions worth exposing
- Add any supported peer actions only if API support exists and they are worth exposing
- Broader verification against real routers, not just parser/service coverage

### D7. Capability-Based Features

Status: partially completed

Implemented:

- Implemented a capability-based `This Device` screen
- Local MAC discovery is used to match the current device against router clients
- Platform capability diagnostics are exposed in Settings
- Traffic inspection is explicitly marked unavailable in the new shell instead of pretending parity

Remaining:

- No per-interface traffic inspection replacement
- No platform-specific mobile degradation copy yet beyond the generic capability messaging
- Wake-on-LAN is represented as a capability, but not as a dedicated UI workflow

### D8. Release Engineering

Status: partially completed

Implemented:

- Flutter platform projects generated for:
  - Android
  - iOS
  - macOS
  - Linux
- Basic target metadata normalized:
  - Android application ID
  - iOS/macOS bundle identifiers
  - Linux application ID
- Settings/About screen now exposes release/build metadata

Remaining:

- Replace default Flutter launcher icons on all generated targets
- Add proper signing and provisioning configuration
- Verify real platform builds, especially:
  - Android build toolchain compatibility
  - iOS/macOS Xcode/CocoaPods readiness
- Add CI matrix for tests and smoke builds
- Add store/distribution metadata and release automation

## Acceptance Criteria Check

### Router Management

Status: mostly satisfied

- Add/edit/delete routers: yes
- Secure password storage: yes
- Selection persistence: yes

Open items:

- Backup/export strategy is not implemented if that becomes a requirement

### Clients

Status: mostly satisfied

- Search by name/IP/MAC: yes
- Online/offline visibility: yes
- Refresh without UI freeze: yes

Open items:

- More integration-level verification against real router responses

### VPN Policies

Status: mostly satisfied

- Default/named/block flows: yes
- Error surfacing: yes
- Refresh after action: yes

Open items:

- Explicit unblock semantics may need a clearer dedicated action depending on expected UX

### WireGuard

Status: partially satisfied

- Peer list loads: yes
- Unsupported actions hidden: yes

Open items:

- No additional actions beyond inspection

### Cross-Platform

Status: partially satisfied

- Shared business logic: yes
- No GTK dependency in the new app: yes
- Platform targets created: yes

Open items:

- Packaging and runtime verification on all target platforms is not finished

## What Is Left

The remaining work is concentrated in five areas:

1. Finish release engineering
   - replace default icons
   - verify native builds
   - add signing/provisioning
   - add CI

2. Complete the remaining storage story
   - harden schema/version handling
   - decide whether backup/export is needed

3. Close the feature parity gaps
   - decide whether unblock needs its own action
   - decide whether Wake-on-LAN gets a dedicated screen or action path
   - confirm whether WireGuard needs more than inspection

4. Improve platform-specific polish
   - mobile-specific copy and degradation behavior
   - localization
   - final error/empty-state wording

5. Validate against real environments
   - real router testing
   - Android/iOS/macOS/Linux smoke builds

## Recommended Next Steps

1. Replace the default launcher/app icons on Android, iOS, macOS, and Linux.
2. Implement a dedicated Wake-on-LAN action path if it is still required for parity.
3. Set up CI to run:
   - `dart test` for `packages/router_core`
   - `dart test` for `packages/router_storage`
   - `flutter test` for `packages/platform_capabilities`
   - `flutter test` and `flutter analyze` for `apps/keenetic_manager_app`
4. Verify native builds on at least one real target per platform family.
