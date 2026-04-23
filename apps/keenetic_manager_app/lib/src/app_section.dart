import 'package:flutter/material.dart';

enum AppSection {
  localDevice,
  clients,
  policies,
  wireguard,
  routers,
  settings,
}

extension AppSectionPresentation on AppSection {
  String get label {
    switch (this) {
      case AppSection.localDevice:
        return 'This Device';
      case AppSection.clients:
        return 'Clients';
      case AppSection.policies:
        return 'Policies';
      case AppSection.wireguard:
        return 'WireGuard';
      case AppSection.routers:
        return 'Routers';
      case AppSection.settings:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case AppSection.localDevice:
        return Icons.phone_android_outlined;
      case AppSection.clients:
        return Icons.devices_outlined;
      case AppSection.policies:
        return Icons.shield_outlined;
      case AppSection.wireguard:
        return Icons.vpn_key_outlined;
      case AppSection.routers:
        return Icons.router_outlined;
      case AppSection.settings:
        return Icons.settings_outlined;
    }
  }

  String get appleSymbol {
    switch (this) {
      case AppSection.localDevice:
        return 'iphone';
      case AppSection.clients:
        return 'desktopcomputer';
      case AppSection.policies:
        return 'shield';
      case AppSection.wireguard:
        return 'lock.shield';
      case AppSection.routers:
        return 'wifi.router';
      case AppSection.settings:
        return 'gearshape';
    }
  }
}
