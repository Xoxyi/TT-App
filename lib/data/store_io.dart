import 'dart:io';

import 'store.dart';

/// Saves each key as a small JSON file in the app's private folder.
///
/// Pure Dart (no plugin), so nothing can break on the Android/iOS side.
class FileStore implements Store {
  FileStore._(this._dir);

  final Directory _dir;

  /// Finds a private, writable folder for the app and returns a store in it.
  static Future<FileStore> open() async {
    Object? lastError;
    for (final path in await _candidateFolders()) {
      try {
        final dir = Directory(path);
        await dir.create(recursive: true);
        final probe = File('${dir.path}/.probe');
        await probe.writeAsString('ok', flush: true);
        await probe.delete();
        return FileStore._(dir);
      } catch (e) {
        lastError = e;
      }
    }
    throw StateError('No writable folder found: $lastError');
  }

  static Future<List<String>> _candidateFolders() async {
    final folders = <String>[];
    if (Platform.isAndroid) {
      // The app's private folder is /data/data/<package name>/files.
      try {
        final cmdline = await File('/proc/self/cmdline').readAsString();
        final package = cmdline.split('\u0000').first.split(':').first.trim();
        if (package.isNotEmpty) {
          folders.add('/data/user/0/$package/files/tt_piciulin');
          folders.add('/data/data/$package/files/tt_piciulin');
        }
      } catch (_) {}
      folders.add('${Directory.systemTemp.parent.path}/files/tt_piciulin');
    } else if (Platform.isIOS || Platform.isMacOS) {
      // The temp folder sits inside the app sandbox, next to Documents.
      folders.add('${Directory.systemTemp.parent.path}/Documents/tt_piciulin');
    } else {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) folders.add('$home/.tt_piciulin');
    }
    return folders;
  }

  File _file(String key) => File('${_dir.path}/$key.json');

  @override
  Future<String?> read(String key) async {
    final f = _file(key);
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> write(String key, String value) async {
    // Write to a temporary file first, then swap it in, so a crash while
    // saving can never leave a half-written file behind.
    final tmp = File('${_dir.path}/$key.json.tmp');
    await tmp.writeAsString(value, flush: true);
    await tmp.rename(_file(key).path);
  }
}

Future<Store> openPlatformStore() => FileStore.open();
