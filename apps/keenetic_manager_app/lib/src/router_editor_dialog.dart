import 'package:flutter/material.dart';
import 'package:router_core/router_core.dart';

import 'apple_native_controls.dart';
import 'platform_style.dart';

class RouterEditorDialog extends StatefulWidget {
  const RouterEditorDialog({
    super.key,
    this.existing,
    required this.hasStoredPassword,
  });

  final RouterProfile? existing;
  final bool hasStoredPassword;

  @override
  State<RouterEditorDialog> createState() => _RouterEditorDialogState();
}

class _RouterEditorDialogState extends State<RouterEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _loginController;
  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _addressController =
        TextEditingController(text: widget.existing?.address ?? '');
    _loginController =
        TextEditingController(text: widget.existing?.login ?? 'admin');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final isMacOS = isMacOSDesignTarget;
    final title = isEditing ? 'Edit Router' : 'Add Router';
    final subtitle = isEditing
        ? 'Update connection details and validate the router before saving.'
        : 'Add a router profile and validate connectivity before it is stored.';
    final form = SizedBox(
      width: isMacOS ? 560 : 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isMacOS) ...<Widget>[
            _FormSectionLabel(
              title: 'Identity',
              caption: 'How this router appears in the app.',
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          if (isMacOS) ...<Widget>[
            const SizedBox(height: 4),
            _FormSectionLabel(
              title: 'Connection',
              caption: 'Address and login used for validation.',
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: '192.168.1.1 or https://home.keenetic.link',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loginController,
            decoration: const InputDecoration(
              labelText: 'Login',
            ),
          ),
          const SizedBox(height: 12),
          if (isMacOS) ...<Widget>[
            const SizedBox(height: 4),
            _FormSectionLabel(
              title: 'Credentials',
              caption: 'Passwords are required for validation and stored locally.',
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: isEditing ? 'New password' : 'Password',
              helperText: isEditing
                  ? widget.hasStoredPassword
                      ? 'Leave blank to keep the existing saved password.'
                      : 'Leave blank only if you want to save metadata without a password yet.'
                  : 'Stored in secure platform storage.',
            ),
          ),
          if (_errorText != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );

    if (isMacOS) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                form,
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    AppleNativeButton(
                      onPressed: () => Navigator.of(context).pop(),
                      label: 'Cancel',
                      style: AppleNativeActionStyle.plain,
                    ),
                    const SizedBox(width: 8),
                    AppleNativeButton(
                      onPressed: _submit,
                      label: 'Save',
                      style: AppleNativeActionStyle.prominentGlass,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(title),
      content: form,
      actions: <Widget>[
        AppleNativeButton(
          onPressed: () => Navigator.of(context).pop(),
          label: 'Cancel',
          style: AppleNativeActionStyle.plain,
        ),
        AppleNativeButton(
          onPressed: _submit,
          label: 'Save',
          style: AppleNativeActionStyle.prominentGlass,
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || address.isEmpty || login.isEmpty) {
      setState(() {
        _errorText = 'Name, address, and login are required.';
      });
      return;
    }

    if (widget.existing == null && password.isEmpty) {
      setState(() {
        _errorText = 'Password is required when adding a new router.';
      });
      return;
    }

    Navigator.of(context).pop(
      RouterFormResult(
        name: name,
        address: address,
        login: login,
        password: password.isEmpty ? null : password,
      ),
    );
  }
}

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel({
    required this.title,
    required this.caption,
  });

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class RouterFormResult {
  const RouterFormResult({
    required this.name,
    required this.address,
    required this.login,
    required this.password,
  });

  final String name;
  final String address;
  final String login;
  final String? password;
}

String routerIdFor(
  String name,
  String address,
  Iterable<RouterProfile> routers,
) {
  final source = '$name-$address'.toLowerCase();
  final buffer = StringBuffer();
  var previousWasDash = false;

  for (final rune in source.runes) {
    final isAlphaNumeric =
        (rune >= 97 && rune <= 122) || (rune >= 48 && rune <= 57);
    if (isAlphaNumeric) {
      buffer.writeCharCode(rune);
      previousWasDash = false;
      continue;
    }

    if (!previousWasDash) {
      buffer.write('-');
      previousWasDash = true;
    }
  }

  final normalized = buffer.toString().replaceAll(RegExp(r'^-+|-+$'), '');
  final baseId = normalized.isEmpty
      ? 'router-${DateTime.now().microsecondsSinceEpoch}'
      : normalized;
  final usedIds = routers.map((RouterProfile router) => router.id).toSet();
  var candidate = baseId;
  var suffix = 2;
  while (usedIds.contains(candidate)) {
    candidate = '$baseId-$suffix';
    suffix += 1;
  }
  return candidate;
}
