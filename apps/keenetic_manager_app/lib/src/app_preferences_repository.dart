import 'dart:convert';
import 'dart:io';

class AppPreferences {
  const AppPreferences({
    this.autoRefreshEnabled = false,
  });

  final bool autoRefreshEnabled;

  AppPreferences copyWith({
    bool? autoRefreshEnabled,
  }) {
    return AppPreferences(
      autoRefreshEnabled: autoRefreshEnabled ?? this.autoRefreshEnabled,
    );
  }
}

class AppPreferencesRepository {
  AppPreferencesRepository(this._file);

  final File _file;

  Future<AppPreferences> read() async {
    if (!await _file.exists()) {
      return const AppPreferences();
    }

    final contents = await _file.readAsString();
    if (contents.trim().isEmpty) {
      return const AppPreferences();
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('App preferences document must be a JSON object.');
    }

    return AppPreferences(
      autoRefreshEnabled: decoded['auto_refresh_enabled'] == true,
    );
  }

  Future<void> write(AppPreferences preferences) async {
    await _file.parent.create(recursive: true);
    final encoded = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'version': 1,
        'auto_refresh_enabled': preferences.autoRefreshEnabled,
      },
    );
    await _file.writeAsString('$encoded\n');
  }
}
