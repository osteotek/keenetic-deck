# Keenetic Deck Architecture

## Goal

Maintain one shared router-management app for:

- Android
- iOS
- macOS
- Linux

The codebase is organized around a single Flutter application with shared Dart packages for router logic, storage, and platform services.

## Stack

- UI/runtime: Flutter
- Language: Dart
- Workspace shape: monorepo with one app and shared packages
- State management: lightweight application layer with explicit use cases and async state
- Persistence: local app documents storage for metadata
- Secrets: OS-backed secure storage where available

## Platform Expectations

Router-management features are expected to work across all four target platforms.

Device-local networking features vary by platform:

- Linux/macOS: broader local network visibility
- Android: partial local network visibility
- iOS: more restricted local network visibility

As a result, `This Device` is a capability-driven feature and may expose different levels of detail depending on the platform.

## Workspace Structure

### App

- `apps/keenetic_manager_app`
  - Flutter UI
  - Navigation
  - Screen-level state orchestration

### Shared Packages

- `packages/router_core`
  - Domain entities
  - Repository contracts
  - Router API contracts
  - Application use case primitives

- `packages/router_storage`
  - Local router metadata persistence
  - Secret storage wiring

- `packages/platform_capabilities`
  - Local network capability abstraction
  - Platform capability flags
  - Device/network information interfaces

## Product Scope

### Core Features

- Multiple router profiles
- Keenetic authentication flow
- Router address selection and fallback rules
- Client listing
- Search and filtering
- Policy listing and policy assignment
- Block/unblock client state changes
- Wake-on-LAN trigger
- WireGuard peer listing
- Localized UI support

### Capability-Driven Features

- KeenDNS metadata refresh
- Local-network-based preferred router resolution
- Local-device matching for `This Device`

### Platform Rules

- No GTK dependency
- No GSettings or GResource dependency
- No Meson or Flatpak build path
- No desktop-file-specific UI assumptions

## Data Model

### RouterProfile

- `id`
- `name`
- `address`
- `login`
- `networkIp`
- `keendnsUrls`
- `createdAt`
- `updatedAt`

### ConnectionTarget

- `kind`
- `uri`

Kinds:

- direct
- localNetwork
- keendns

### ClientDevice

- `name`
- `macAddress`
- `ipAddress`
- `policyName`
- `access`
- `isDenied`
- `isPermitted`
- `priority`
- `connectionState`

### VpnPolicy

- `name`
- `description`

### WireGuardPeer

- `interfaceName`
- `peerName`
- `allowedIps`
- `endpoint`
- `isEnabled`

## Delivery Areas

### Application Shell

- Adaptive navigation
- Router list and selection
- Add/edit/delete router flows
- Section-based navigation for routers, clients, policies, WireGuard, this device, and settings

### Shared Core

- Router auth and requests in Dart
- Connection resolution rules
- Typed models and explicit error handling
- Unit-tested service behavior

### Storage and Secrets

- Router metadata repository
- Password storage abstraction
- Versionable stored metadata format

### Feature Areas

- Clients screen
- Policy management
- WireGuard inspection
- Capability-based `This Device`
- Settings and diagnostics

### Release Engineering

- Android packaging
- iOS packaging
- macOS packaging
- Linux packaging
- CI matrix

## Acceptance Criteria

### Router Management

- User can add, edit, and delete routers
- Passwords are stored outside plain metadata JSON
- Router selection restores correctly on restart

### Clients

- Search works by name, IP, and MAC
- Online/offline state is visible
- Refresh never blocks the UI
- Stale refreshes do not overwrite newer selection state

### VPN Policies

- User can set blocked, default, and named policy states
- Failed actions are surfaced clearly
- Screen refresh reflects the final router state

### WireGuard

- Peer list loads without freezing the UI
- Unsupported actions are hidden rather than shown as dead buttons

### Cross-Platform

- Same shared business logic is used on Android, iOS, macOS, and Linux

## Risks

- Mobile OS restrictions reduce local-device introspection
- Wake-on-LAN behavior may vary by platform and network topology
- Router firmware/API variations can surface new parsing edge cases
