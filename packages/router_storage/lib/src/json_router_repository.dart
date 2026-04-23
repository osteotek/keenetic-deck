import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:router_core/router_core.dart';

class JsonRouterRepository implements RouterRepository {
  JsonRouterRepository(this._file);

  final File _file;

  @override
  Future<void> deleteRouter(String id) async {
    final document = await _readDocument();
    final routers = document.routers
        .where((profile) => profile.id != id)
        .toList(growable: false);

    final selectedRouterId =
        document.selectedRouterId == id ? null : document.selectedRouterId;

    await _writeDocument(
      _StorageDocument(
        routers: routers,
        selectedRouterId: selectedRouterId,
      ),
    );
  }

  @override
  Future<RouterProfile?> getRouterById(String id) async {
    final document = await _readDocument();
    for (final profile in document.routers) {
      if (profile.id == id) {
        return profile;
      }
    }
    return null;
  }

  @override
  Future<List<RouterProfile>> getRouters() async {
    final document = await _readDocument();
    return document.routers;
  }

  @override
  Future<String?> getSelectedRouterId() async {
    final document = await _readDocument();
    return document.selectedRouterId;
  }

  @override
  Future<void> saveRouter(RouterProfile profile) async {
    final document = await _readDocument();
    final routers = document.routers.toList(growable: true);
    final index = routers.indexWhere((item) => item.id == profile.id);

    if (index == -1) {
      routers.add(profile);
    } else {
      routers[index] = profile;
    }

    await _writeDocument(
      _StorageDocument(
        routers: routers,
        selectedRouterId: document.selectedRouterId,
      ),
    );
  }

  @override
  Future<void> setSelectedRouterId(String? id) async {
    final document = await _readDocument();
    final selectedRouterId = id == null || id.isEmpty ? null : id;

    await _writeDocument(
      _StorageDocument(
        routers: document.routers,
        selectedRouterId: selectedRouterId,
      ),
    );
  }

  Future<void> importRouters(
    List<RouterProfile> profiles, {
    String? selectedRouterId,
    bool replaceExisting = false,
  }) async {
    final document = await _readDocument();
    final routers = replaceExisting
        ? profiles.toList(growable: true)
        : document.routers.toList(growable: true);

    if (!replaceExisting) {
      for (final profile in profiles) {
        final existingIndex =
            routers.indexWhere((item) => item.id == profile.id);
        if (existingIndex == -1) {
          routers.add(profile);
        } else {
          routers[existingIndex] = profile;
        }
      }
    }

    await _writeDocument(
      _StorageDocument(
        routers: routers,
        selectedRouterId: selectedRouterId ?? document.selectedRouterId,
      ),
    );
  }

  Future<_StorageDocument> _readDocument() async {
    if (!await _file.exists()) {
      return const _StorageDocument(
        routers: <RouterProfile>[],
        selectedRouterId: null,
      );
    }

    final contents = await _file.readAsString();
    if (contents.trim().isEmpty) {
      return const _StorageDocument(
        routers: <RouterProfile>[],
        selectedRouterId: null,
      );
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Router storage document must be a JSON object.');
    }

    final routersPayload = decoded['routers'];
    if (routersPayload is! List) {
      throw const FormatException('Router storage document must contain a routers list.');
    }

    final routers = routersPayload.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Router entries must be JSON objects.');
      }
      return _routerProfileFromJson(item);
    }).toList(growable: false);

    return _StorageDocument(
      routers: routers,
      selectedRouterId: decoded['selected_router_id'] as String?,
    );
  }

  Future<void> _writeDocument(_StorageDocument document) async {
    await _file.parent.create(recursive: true);
    final encoded = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'version': 1,
        'selected_router_id': document.selectedRouterId,
        'routers': document.routers.map(_routerProfileToJson).toList(growable: false),
      },
    );
    await _file.writeAsString('$encoded\n');
  }
}

Map<String, Object?> _routerProfileToJson(RouterProfile profile) {
  return <String, Object?>{
    'id': profile.id,
    'name': profile.name,
    'address': profile.address,
    'login': profile.login,
    'network_ip': profile.networkIp,
    'keendns_urls': profile.keendnsUrls,
    'created_at': profile.createdAt.toUtc().toIso8601String(),
    'updated_at': profile.updatedAt.toUtc().toIso8601String(),
  };
}

RouterProfile _routerProfileFromJson(Map<String, dynamic> json) {
  final keendnsUrls = json['keendns_urls'];
  return RouterProfile(
    id: _readString(json, 'id'),
    name: _readString(json, 'name'),
    address: _readString(json, 'address'),
    login: _readString(json, 'login'),
    networkIp: json['network_ip'] as String?,
    keendnsUrls: keendnsUrls is List
        ? keendnsUrls.whereType<String>().toList(growable: false)
        : const <String>[],
    createdAt: DateTime.parse(_readString(json, 'created_at')),
    updatedAt: DateTime.parse(_readString(json, 'updated_at')),
  );
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing or invalid "$key" in router storage.');
  }
  return value;
}

class _StorageDocument {
  const _StorageDocument({
    required this.routers,
    required this.selectedRouterId,
  });

  final List<RouterProfile> routers;
  final String? selectedRouterId;
}

File defaultRouterStorageFile(Directory baseDirectory) {
  return File(p.join(baseDirectory.path, 'routers.v1.json'));
}
