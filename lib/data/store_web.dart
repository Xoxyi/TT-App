import 'package:web/web.dart' as web;

import 'store.dart';

/// Browser: keeps each key in localStorage (per site, survives reloads).
class LocalStorageStore implements Store {
  static const String _prefix = 'tt_piciulin.';

  @override
  Future<String?> read(String key) async => web.window.localStorage.getItem('$_prefix$key');

  @override
  Future<void> write(String key, String value) async => web.window.localStorage.setItem('$_prefix$key', value);
}

Future<Store> openPlatformStore() async {
  // Throws when storage is blocked (e.g. some private windows).
  web.window.localStorage.getItem('${LocalStorageStore._prefix}probe');
  return LocalStorageStore();
}
