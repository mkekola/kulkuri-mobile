import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_drawing/path_drawing.dart';

import 'vehicle_modes.dart';

// Font Awesome Free solid icons (bus, train-tram, train-subway, train,
// ferry), same paths as the web app's stopIcons.ts. Icons are CC BY 4.0 -
// Font Awesome (https://fontawesome.com), credited in the README.
const _iconPaths = <String, ({double viewBoxW, double viewBoxH, String path})>{
  'bus': (
    viewBoxW: 576,
    viewBoxH: 512,
    path:
        'M288 0C422.4 0 512 35.2 512 80l0 16 0 32c17.7 0 32 14.3 32 32l0 64c0 17.7-14.3 32-32 32l0 160c0 17.7-14.3 32-32 32l0 32c0 17.7-14.3 32-32 32l-32 0c-17.7 0-32-14.3-32-32l0-32-192 0 0 32c0 17.7-14.3 32-32 32l-32 0c-17.7 0-32-14.3-32-32l0-32c-17.7 0-32-14.3-32-32l0-160c-17.7 0-32-14.3-32-32l0-64c0-17.7 14.3-32 32-32c0 0 0 0 0 0l0-32s0 0 0 0l0-16C64 35.2 153.6 0 288 0zM128 160l0 96c0 17.7 14.3 32 32 32l112 0 0-160-112 0c-17.7 0-32 14.3-32 32zM304 288l112 0c17.7 0 32-14.3 32-32l0-96c0-17.7-14.3-32-32-32l-112 0 0 160zM144 400a32 32 0 1 0 0-64 32 32 0 1 0 0 64zm288 0a32 32 0 1 0 0-64 32 32 0 1 0 0 64zM384 80c0-8.8-7.2-16-16-16L208 64c-8.8 0-16 7.2-16 16s7.2 16 16 16l160 0c8.8 0 16-7.2 16-16z',
  ),
  'tram': (
    viewBoxW: 448,
    viewBoxH: 512,
    path:
        'M86.8 48c-12.2 0-23.6 5.5-31.2 15L42.7 79C34.5 89.3 19.4 91 9 82.7S-3 59.4 5.3 49L18 33C34.7 12.2 60 0 86.8 0L361.2 0c26.7 0 52 12.2 68.7 33l12.8 16c8.3 10.4 6.6 25.5-3.8 33.7s-25.5 6.6-33.7-3.7L392.5 63c-7.6-9.5-19.1-15-31.2-15L248 48l0 48 40 0c53 0 96 43 96 96l0 160c0 30.6-14.3 57.8-36.6 75.4l65.5 65.5c7.1 7.1 2.1 19.1-7.9 19.1l-39.7 0c-8.5 0-16.6-3.4-22.6-9.4L288 448l-128 0-54.6 54.6c-6 6-14.1 9.4-22.6 9.4L43 512c-10 0-15-12.1-7.9-19.1l65.5-65.5C78.3 409.8 64 382.6 64 352l0-160c0-53 43-96 96-96l40 0 0-48L86.8 48zM160 160c-17.7 0-32 14.3-32 32l0 32c0 17.7 14.3 32 32 32l128 0c17.7 0 32-14.3 32-32l0-32c0-17.7-14.3-32-32-32l-128 0zm32 192a32 32 0 1 0 -64 0 32 32 0 1 0 64 0zm96 32a32 32 0 1 0 0-64 32 32 0 1 0 0 64z',
  ),
  'metro': (
    viewBoxW: 448,
    viewBoxH: 512,
    path:
        'M96 0C43 0 0 43 0 96L0 352c0 48 35.2 87.7 81.1 94.9l-46 46C28.1 499.9 33.1 512 43 512l39.7 0c8.5 0 16.6-3.4 22.6-9.4L160 448l128 0 54.6 54.6c6 6 14.1 9.4 22.6 9.4l39.7 0c10 0 15-12.1 7.9-19.1l-46-46c46-7.1 81.1-46.9 81.1-94.9l0-256c0-53-43-96-96-96L96 0zM64 128c0-17.7 14.3-32 32-32l80 0c17.7 0 32 14.3 32 32l0 96c0 17.7-14.3 32-32 32l-80 0c-17.7 0-32-14.3-32-32l0-96zM272 96l80 0c17.7 0 32 14.3 32 32l0 96c0 17.7-14.3 32-32 32l-80 0c-17.7 0-32-14.3-32-32l0-96c0-17.7 14.3-32 32-32zM64 352a32 32 0 1 1 64 0 32 32 0 1 1 -64 0zm288-32a32 32 0 1 1 0 64 32 32 0 1 1 0-64z',
  ),
  'train': (
    viewBoxW: 448,
    viewBoxH: 512,
    path:
        'M96 0C43 0 0 43 0 96L0 352c0 48 35.2 87.7 81.1 94.9l-46 46C28.1 499.9 33.1 512 43 512l39.7 0c8.5 0 16.6-3.4 22.6-9.4L160 448l128 0 54.6 54.6c6 6 14.1 9.4 22.6 9.4l39.7 0c10 0 15-12.1 7.9-19.1l-46-46c46-7.1 81.1-46.9 81.1-94.9l0-256c0-53-43-96-96-96L96 0zM64 96c0-17.7 14.3-32 32-32l256 0c17.7 0 32 14.3 32 32l0 96c0 17.7-14.3 32-32 32L96 224c-17.7 0-32-14.3-32-32l0-96zM224 288a48 48 0 1 1 0 96 48 48 0 1 1 0-96z',
  ),
  'ferry': (
    viewBoxW: 576,
    viewBoxH: 512,
    path:
        'M224 0L352 0c17.7 0 32 14.3 32 32l75.1 0c20.6 0 31.6 24.3 18.1 39.8L456 96 120 96 98.8 71.8C85.3 56.3 96.3 32 116.9 32L192 32c0-17.7 14.3-32 32-32zM96 128l384 0c17.7 0 32 14.3 32 32l0 123.5c0 13.3-4.2 26.3-11.9 37.2l-51.4 71.9c-1.9 1.1-3.7 2.2-5.5 3.5c-15.5 10.7-34 18-51 19.9l-16.5 0c-17.1-1.8-35-9-50.8-19.9c-22.1-15.5-51.6-15.5-73.7 0c-14.8 10.2-32.5 18-50.6 19.9l-16.6 0c-17-1.8-35.6-9.2-51-19.9c-1.8-1.3-3.7-2.4-5.6-3.5L75.9 320.7C68.2 309.8 64 296.8 64 283.5L64 160c0-17.7 14.3-32 32-32zm32 64l0 96 320 0 0-96-320 0zM306.5 421.9C329 437.4 356.5 448 384 448c26.9 0 55.3-10.8 77.4-26.1c0 0 0 0 0 0c11.9-8.5 28.1-7.8 39.2 1.7c14.4 11.9 32.5 21 50.6 25.2c17.2 4 27.9 21.2 23.9 38.4s-21.2 27.9-38.4 23.9c-24.5-5.7-44.9-16.5-58.2-25C449.5 501.7 417 512 384 512c-31.9 0-60.6-9.9-80.4-18.9c-5.8-2.7-11.1-5.3-15.6-7.7c-4.5 2.4-9.7 5.1-15.6 7.7c-19.8 9-48.5 18.9-80.4 18.9c-33 0-65.5-10.3-94.5-25.8c-13.4 8.4-33.7 19.3-58.2 25c-17.2 4-34.4-6.7-38.4-23.9s6.7-34.4 23.9-38.4c18.1-4.2 36.2-13.3 50.6-25.2c11.1-9.4 27.3-10.1 39.2-1.7c0 0 0 0 0 0C136.7 437.2 165.1 448 192 448c27.5 0 55-10.6 77.5-26.1c11.1-7.9 25.9-7.9 37 0z',
  ),
};

const unknownStopMode = 'unknown';
const _raster = 96.0;
// Same dark surface as the app's chrome (--surface in style.css), so the
// badge ring reads as "part of the app" rather than a random outline.
const _badgeStroke = Color(0xff121a2c);

String stopIconId(String mode) => 'stop-icon-$mode';

Future<Uint8List> _renderBadge(Color background, String mode) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(_raster / 2, _raster / 2);

  canvas.drawCircle(center, _raster / 2 - 3, Paint()..color = background);
  canvas.drawCircle(
    center,
    _raster / 2 - 3,
    Paint()
      ..color = _badgeStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );

  final icon = _iconPaths[mode];
  if (icon != null) {
    final glyphHeight = _raster * 0.52;
    final scale = glyphHeight / icon.viewBoxH;
    final w = icon.viewBoxW * scale;
    final h = icon.viewBoxH * scale;
    canvas.save();
    canvas.translate((_raster - w) / 2, (_raster - h) / 2);
    canvas.scale(scale);
    canvas.drawPath(parseSvgPathData(icon.path), Paint()..color = const Color(0xffffffff));
    canvas.restore();
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(_raster.round(), _raster.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

Color _colorFromHex(String hex) => Color(int.parse(hex.substring(1), radix: 16) + 0xff000000);

// One badge image per mode, registered with the map so stops can use them as
// `iconImage` in a symbol layer instead of a plain circle.
Future<void> registerStopIcons(MapLibreMapController controller) async {
  for (final mode in [...modeColors.keys, unknownStopMode]) {
    final bytes = await _renderBadge(_colorFromHex(modeColor(mode)), mode);
    await controller.addImage(stopIconId(mode), bytes);
  }
}
