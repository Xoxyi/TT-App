// Draws the app icon from the Emblem logo (lib/widgets/common.dart):
//
//   flutter test tool/make_icons_test.dart
//   dart run flutter_launcher_icons
//
// Writes assets/icon/icon.png (emblem on black, for iOS, web and Play) and
// assets/icon/icon_foreground.png (emblem only, for Android adaptive icons).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_tennis_app/theme/app_theme.dart';
import 'package:table_tennis_app/widgets/common.dart';

const int size = 1024;

void main() {
  testWidgets('make app icons', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(size * 1.0, size * 1.0);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(Center(
      child: RepaintBoundary(key: key, child: const Emblem(size: size * 1.0)),
    ));

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final emblem = await boundary.toImage();
      final bounds = await _contentBounds(emblem);

      // Full icon: emblem on the app background, 70% wide.
      await _write('assets/icon/icon.png', emblem, bounds, fraction: 0.70, background: AppColors.bg);
      // Adaptive foreground: launchers crop to a circle ~61% wide, so stay inside it.
      await _write('assets/icon/icon_foreground.png', emblem, bounds, fraction: 0.46);
    });
  });
}

/// Smallest rectangle holding the visible pixels of [image].
Future<Rect> _contentBounds(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  var left = image.width, top = image.height, right = 0, bottom = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (data.getUint8((y * image.width + x) * 4 + 3) == 0) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  return Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0);
}

Future<void> _write(String path, ui.Image emblem, Rect src,
    {required double fraction, Color? background}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (background != null) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, size * 1.0, size * 1.0), Paint()..color = background);
  }
  final w = size * fraction;
  final h = w * src.height / src.width;
  final dst = Rect.fromCenter(center: const Offset(size / 2, size / 2), width: w, height: h);
  canvas.drawImageRect(emblem, src, dst, Paint()..filterQuality = FilterQuality.high);
  final image = await recorder.endRecording().toImage(size, size);
  final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(Uint8List.view(png.buffer));
}
