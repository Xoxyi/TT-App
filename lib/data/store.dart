import 'store_io.dart' if (dart.library.js_interop) 'store_web.dart' as platform;

/// Simple key/value storage so the app data survives restarts.
abstract class Store {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Opens the app's persistent storage: files on Android/iOS, the browser's
/// localStorage on the web.
Future<Store> openStore() => platform.openPlatformStore();

/// Keeps data in memory only (used by tests and as a fallback).
class MemoryStore implements Store {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }
}
