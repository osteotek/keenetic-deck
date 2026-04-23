import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_key_value_store.dart';

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({
    FlutterSecureStorage? storage,
    AndroidOptions? androidOptions,
    IOSOptions? iosOptions,
    MacOsOptions? macOsOptions,
    LinuxOptions? linuxOptions,
    WebOptions? webOptions,
    WindowsOptions? windowsOptions,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _androidOptions = androidOptions ??
            const AndroidOptions(encryptedSharedPreferences: true),
        _iosOptions = iosOptions ?? const IOSOptions(),
        _macOsOptions = macOsOptions ?? const MacOsOptions(),
        _linuxOptions = linuxOptions ?? const LinuxOptions(),
        _webOptions = webOptions ?? const WebOptions(),
        _windowsOptions = windowsOptions ?? const WindowsOptions();

  final FlutterSecureStorage _storage;
  final AndroidOptions _androidOptions;
  final IOSOptions _iosOptions;
  final MacOsOptions _macOsOptions;
  final LinuxOptions _linuxOptions;
  final WebOptions _webOptions;
  final WindowsOptions _windowsOptions;

  @override
  Future<void> delete(String key) {
    return _storage.delete(
      key: key,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
      mOptions: _macOsOptions,
      lOptions: _linuxOptions,
      webOptions: _webOptions,
      wOptions: _windowsOptions,
    );
  }

  @override
  Future<String?> read(String key) {
    return _storage.read(
      key: key,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
      mOptions: _macOsOptions,
      lOptions: _linuxOptions,
      webOptions: _webOptions,
      wOptions: _windowsOptions,
    );
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(
      key: key,
      value: value,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
      mOptions: _macOsOptions,
      lOptions: _linuxOptions,
      webOptions: _webOptions,
      wOptions: _windowsOptions,
    );
  }
}
