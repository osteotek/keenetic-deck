import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

import 'platform_style.dart';

enum AppleNativeActionStyle {
  plain,
  glass,
  prominentGlass,
  bordered,
}

CNButtonStyle _cnButtonStyleFor(AppleNativeActionStyle style) {
  switch (style) {
    case AppleNativeActionStyle.plain:
      return CNButtonStyle.plain;
    case AppleNativeActionStyle.glass:
      return CNButtonStyle.glass;
    case AppleNativeActionStyle.prominentGlass:
      return CNButtonStyle.prominentGlass;
    case AppleNativeActionStyle.bordered:
      return CNButtonStyle.bordered;
  }
}

bool get _isWidgetTestBinding =>
    WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );

class AppleNativeSymbolIcon extends StatelessWidget {
  const AppleNativeSymbolIcon({
    super.key,
    required this.appleSymbol,
    required this.fallbackIcon,
    this.size = 18,
    this.color,
  });

  final String appleSymbol;
  final IconData fallbackIcon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!isAppleNativeTarget) {
      return Icon(fallbackIcon, size: size, color: color);
    }

    return CNIcon(
      symbol: CNSymbol(
        appleSymbol,
        size: size,
        color: color,
      ),
      size: size,
      color: color,
      height: size,
    );
  }
}

class AppleNativeButton extends StatelessWidget {
  const AppleNativeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppleNativeActionStyle.glass,
    this.height = 32,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppleNativeActionStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!isAppleNativeTarget) {
      switch (style) {
        case AppleNativeActionStyle.prominentGlass:
          return FilledButton(
            onPressed: onPressed,
            child: Text(label),
          );
        case AppleNativeActionStyle.bordered:
          return OutlinedButton(
            onPressed: onPressed,
            child: Text(label),
          );
        case AppleNativeActionStyle.glass:
        case AppleNativeActionStyle.plain:
          return TextButton(
            onPressed: onPressed,
            child: Text(label),
          );
      }
    }

    return CNButton(
      label: label,
      onPressed: onPressed,
      style: _cnButtonStyleFor(style),
      height: height,
      shrinkWrap: true,
    );
  }
}

class AppleNativeIconButton extends StatelessWidget {
  const AppleNativeIconButton({
    super.key,
    required this.appleSymbol,
    required this.fallbackIcon,
    required this.onPressed,
    this.tooltip,
    this.style = AppleNativeActionStyle.glass,
    this.size = 36,
  });

  final String appleSymbol;
  final IconData fallbackIcon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AppleNativeActionStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (!isAppleNativeTarget) {
      child = IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(fallbackIcon),
      );
    } else {
      child = CNButton.icon(
        icon: CNSymbol(appleSymbol, size: size * 0.45),
        onPressed: onPressed,
        size: size,
        style: _cnButtonStyleFor(style),
      );
    }

    if (tooltip == null || tooltip!.isEmpty) {
      return child;
    }
    return Tooltip(message: tooltip!, child: child);
  }
}

class AppleNativeMenuItem<T> {
  const AppleNativeMenuItem({
    required this.label,
    required this.value,
    this.appleSymbol,
    this.fallbackIcon,
  });

  final String label;
  final T value;
  final String? appleSymbol;
  final IconData? fallbackIcon;
}

class AppleNativeTabBarItem {
  const AppleNativeTabBarItem({
    required this.label,
    required this.appleSymbol,
    required this.fallbackIcon,
  });

  final String label;
  final String appleSymbol;
  final IconData fallbackIcon;
}

class AppleNativePopupMenuButton<T> extends StatelessWidget {
  const AppleNativePopupMenuButton.icon({
    super.key,
    required this.items,
    required this.onSelected,
    required this.appleSymbol,
    required this.fallbackIcon,
    this.tooltip,
  }) : label = null;

  final List<AppleNativeMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final String? label;
  final String appleSymbol;
  final IconData fallbackIcon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    if (!isAppleNativeTarget) {
      return PopupMenuButton<T>(
        tooltip: tooltip,
        onSelected: onSelected,
        itemBuilder: (BuildContext context) {
          return items
              .map(
                (AppleNativeMenuItem<T> item) => PopupMenuItem<T>(
                  value: item.value,
                  child: Row(
                    children: <Widget>[
                      if (item.fallbackIcon != null) ...<Widget>[
                        Icon(item.fallbackIcon, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: Text(item.label)),
                    ],
                  ),
                ),
              )
              .toList(growable: false);
        },
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.more_horiz),
        ),
      );
    }

    Widget button = CNPopupMenuButton.icon(
      buttonIcon: CNSymbol(appleSymbol, size: 16),
      items: items
          .map(
            (AppleNativeMenuItem<T> item) => CNPopupMenuItem(
              label: item.label,
              icon: item.appleSymbol == null
                  ? null
                  : CNSymbol(item.appleSymbol!, size: 16),
            ),
          )
          .toList(growable: false),
      onSelected: (int index) {
        if (index >= 0 && index < items.length) {
          onSelected(items[index].value);
        }
      },
      buttonStyle: CNButtonStyle.glass,
      size: 36,
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

class AppleNativeTabBar extends StatelessWidget {
  const AppleNativeTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.split = false,
    this.rightCount = 1,
  });

  final List<AppleNativeTabBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool split;
  final int rightCount;

  @override
  Widget build(BuildContext context) {
    if (!isAppleNativeTarget || _isWidgetTestBinding) {
      return NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        destinations: items
            .map(
              (AppleNativeTabBarItem item) => NavigationDestination(
                icon: Icon(item.fallbackIcon),
                label: item.label,
              ),
            )
            .toList(growable: false),
      );
    }

    final bottomInset = isMacOSDesignTarget ? 14.0 : 10.0;
    final barHeight = isMacOSDesignTarget ? 56.0 : 52.0;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: barHeight + bottomInset,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            bottomInset,
          ),
          child: Center(
            child: CNTabBar(
              items: items
                  .map(
                    (AppleNativeTabBarItem item) => CNTabBarItem(
                      label: item.label,
                      icon: CNSymbol(item.appleSymbol),
                    ),
                  )
                  .toList(growable: false),
            currentIndex: currentIndex,
            onTap: onTap,
            backgroundColor: Colors.transparent,
            split: split,
            rightCount: rightCount,
            shrinkCentered: true,
              splitSpacing: 12,
              height: barHeight,
            ),
          ),
        ),
      ),
    );
  }
}

class AppleNativeSwitchRow extends StatelessWidget {
  const AppleNativeSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!isAppleNativeTarget) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: CNSwitch(
            value: value,
            onChanged: onChanged,
            height: 28,
          ),
        ),
      ],
    );
  }
}
