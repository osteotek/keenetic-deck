import 'dart:convert';
import 'dart:io';

import 'package:router_core/router_core.dart';

class FileSecretRepository implements SecretRepository {
  FileSecretRepository(this._file);

  final File _file;

  @override
  Future<void> deleteRouterPassword(String routerId) async {
    final document = await _readDocument();
    if (!document.passwords.containsKey(routerId)) {
      return;
    }

    final updated = Map<String, String>.from(document.passwords)
      ..remove(routerId);
    await _writeDocument(_SecretDocument(passwords: updated));
  }

  @override
  Future<String?> readRouterPassword(String routerId) async {
    final document = await _readDocument();
    return document.passwords[routerId];
  }

  @override
  Future<void> writeRouterPassword(String routerId, String password) async {
    final document = await _readDocument();
    final updated = Map<String, String>.from(document.passwords)
      ..[routerId] = password;
    await _writeDocument(_SecretDocument(passwords: updated));
  }

  Future<_SecretDocument> _readDocument() async {
    if (!await _file.exists()) {
      return const _SecretDocument(passwords: <String, String>{});
    }

    final contents = await _file.readAsString();
    if (contents.trim().isEmpty) {
      return const _SecretDocument(passwords: <String, String>{});
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Secret storage document must be a JSON object.');
    }

    final payload = decoded['passwords'];
    if (payload is! Map) {
      return const _SecretDocument(passwords: <String, String>{});
    }

    return _SecretDocument(
      passwords: payload.map(
        (Object? key, Object? value) => MapEntry(
          key.toString(),
          value?.toString() ?? '',
        ),
      ),
    );
  }

  Future<void> _writeDocument(_SecretDocument document) async {
    await _file.parent.create(recursive: true);
    final encoded = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'version': 1,
        'passwords': document.passwords,
      },
    );
    await _file.writeAsString('$encoded\n');
  }
}

class _SecretDocument {
  const _SecretDocument({
    required this.passwords,
  });

  final Map<String, String> passwords;
}
