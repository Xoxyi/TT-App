// Play Store images, written to ../store_listing (outside the repo):
//
//   flutter test tool/make_store_images_test.dart
//
// - feature_graphic.png: 1024x500, the Emblem logo + app name.
// - screenshot_*.png: every PNG in ../store_listing/raw (phone screenshots,
//   e.g. 1080x2400) cropped to at most 2:1, as Play requires, by removing
//   the status and navigation bars.
// All files are written as 24-bit PNG (no alpha), as Play asks.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_tennis_app/theme/app_theme.dart';
import 'package:table_tennis_app/widgets/common.dart';

const String outDir = '../store_listing';

void main() {
  testWidgets('feature graphic', (tester) async {
    await _loadFont('Roboto', <String>['roboto-black.ttf', 'roboto-bold.ttf']);
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1024, 500);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(key: key, child: const _FeatureGraphic()),
    ));
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await _writeRgbPng('$outDir/feature_graphic.png', await boundary.toImage());
    });
  });

  testWidgets('screenshots', (tester) async {
    final raw = Directory('$outDir/raw');
    if (!raw.existsSync()) return;
    await tester.runAsync(() async {
      final files = raw.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in files) {
        final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
        final shot = (await codec.getNextFrame()).image;
        // Drop the status bar, keep at most twice as tall as wide (Play's
        // limit). A file name like "2_standings@1700.png" ends the crop at
        // y=1700 instead, to leave out the rest of the screen.
        const top = 100;
        final end = RegExp(r'@(\d+)\.png$').firstMatch(f.path)?.group(1);
        var height = end != null ? int.parse(end) - top : shot.height - top;
        if (height > shot.width * 2) height = shot.width * 2;
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImageRect(
          shot,
          Rect.fromLTWH(0, top.toDouble(), shot.width.toDouble(), height.toDouble()),
          Rect.fromLTWH(0, 0, shot.width.toDouble(), height.toDouble()),
          Paint(),
        );
        final name = f.uri.pathSegments.last.replaceFirst(RegExp(r'@\d+'), '');
        await _writeRgbPng('$outDir/screenshot_$name', await recorder.endRecording().toImage(shot.width, height));
      }
    });
  });
}

class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic();

  @override
  Widget build(BuildContext context) {
    const title = TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, fontSize: 92, height: 1, letterSpacing: -1.5);
    return Container(
      width: 1024,
      height: 500,
      color: AppColors.bg,
      child: Stack(
        children: <Widget>[
          // Soft orange glow behind the logo.
          Positioned(
            left: -120,
            top: -110,
            child: Container(
              width: 720,
              height: 720,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: <Color>[Color(0x33FF5A1F), Color(0x00FF5A1F)]),
              ),
            ),
          ),
          const Positioned(left: 96, top: 110, child: Emblem(size: 280)),
          Positioned(
            left: 440,
            top: 0,
            bottom: 0,
            right: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                RichText(
                  text: const TextSpan(style: title, children: <TextSpan>[
                    TextSpan(text: 'TT ', style: TextStyle(color: AppColors.accent)),
                    TextSpan(text: 'Piciulin', style: TextStyle(color: AppColors.text)),
                  ]),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Table tennis results,\nstandings and stats',
                  style: TextStyle(
                      fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 36, height: 1.2, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _loadFont(String family, List<String> files) async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/dev/flutter'}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File('$dir/$f').readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

/// Writes [image] as an RGB PNG (colour type 2, no alpha channel).
Future<void> _writeRgbPng(String path, ui.Image image) async {
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final w = image.width, h = image.height;
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // no filter
    final row = Uint8List(w * 3);
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      row[x * 3] = rgba.getUint8(i);
      row[x * 3 + 1] = rgba.getUint8(i + 1);
      row[x * 3 + 2] = rgba.getUint8(i + 2);
    }
    raw.add(row);
  }
  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2); // colour type: RGB
  final out = BytesBuilder()
    ..add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(_chunk('IHDR', ihdr.buffer.asUint8List()))
    ..add(_chunk('IDAT', ZLibCodec(level: 9).encode(raw.takeBytes())))
    ..add(_chunk('IEND', Uint8List(0)));
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(out.takeBytes());
}

List<int> _chunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final head = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32(<int>[...typeBytes, ...data]));
  return <int>[...head.buffer.asUint8List(), ...typeBytes, ...data, ...crc.buffer.asUint8List()];
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
