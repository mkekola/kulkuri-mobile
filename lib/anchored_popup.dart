import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart' as theme;

const _preferredCardWidth = 280.0;
const _margin = 8.0;
const _cornerRadius = 14.0;
const _tailWidth = 20.0;
const _tailHeight = 9.0;
const _borderWidth = 1.0;

// Positions [child] in a card anchored to a screen point, with a triangular
// notch pointing back at it - same idea as the web app's StopDetail.vue/
// VehicleDetail.vue anchored popups, but drawn as a single continuous shape
// (_BubblePainter) instead of a separately rotated square overlapping the
// card's edge: two aligned elements were fiddly to get pixel-perfect and
// kept rendering as a visibly detached diamond instead of an attached tail.
class AnchoredPopup extends StatelessWidget {
  final Offset anchor;
  final Size screenSize;
  final Widget child;

  const AnchoredPopup({super.key, required this.anchor, required this.screenSize, required this.child});

  @override
  Widget build(BuildContext context) {
    final cardWidth = math.min(_preferredCardWidth, screenSize.width - _margin * 2);
    final spaceAbove = anchor.dy;
    final spaceBelow = screenSize.height - anchor.dy;
    final placeAbove = spaceAbove > spaceBelow;

    final left = (anchor.dx - cardWidth / 2).clamp(_margin, screenSize.width - cardWidth - _margin);
    final tailCenterX = (anchor.dx - left).clamp(_tailWidth, cardWidth - _tailWidth);

    final bubble = CustomPaint(
      painter: _BubblePainter(tailCenterX: tailCenterX, tailOnBottom: placeAbove),
      child: ClipPath(
        clipper: _BubbleClipper(tailCenterX: tailCenterX, tailOnBottom: placeAbove),
        child: Padding(
          padding: EdgeInsets.only(top: placeAbove ? 0 : _tailHeight, bottom: placeAbove ? _tailHeight : 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: child,
          ),
        ),
      ),
    );

    return Positioned(
      left: left,
      top: placeAbove ? null : anchor.dy,
      bottom: placeAbove ? screenSize.height - anchor.dy : null,
      child: SizedBox(width: cardWidth, child: bubble),
    );
  }
}

Path _bubblePath(Size size, {required double tailCenterX, required bool tailOnBottom}) {
  final cardTop = tailOnBottom ? 0.0 : _tailHeight;
  final cardBottom = tailOnBottom ? size.height - _tailHeight : size.height;
  final rect = RRect.fromLTRBR(0, cardTop, size.width, cardBottom, const Radius.circular(_cornerRadius));

  final path = Path()..addRRect(rect);
  final tail = Path()
    ..moveTo(tailCenterX - _tailWidth / 2, tailOnBottom ? cardBottom : cardTop)
    ..lineTo(tailCenterX, tailOnBottom ? cardBottom + _tailHeight : cardTop - _tailHeight)
    ..lineTo(tailCenterX + _tailWidth / 2, tailOnBottom ? cardBottom : cardTop)
    ..close();

  return Path.combine(PathOperation.union, path, tail);
}

class _BubblePainter extends CustomPainter {
  final double tailCenterX;
  final bool tailOnBottom;

  _BubblePainter({required this.tailCenterX, required this.tailOnBottom});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _bubblePath(size, tailCenterX: tailCenterX, tailOnBottom: tailOnBottom);
    canvas.drawShadow(path, Colors.black, 8, false);
    canvas.drawPath(path, Paint()..color = theme.surfaceTranslucent);
    canvas.drawPath(
      path,
      Paint()
        ..color = theme.lineStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.tailCenterX != tailCenterX || oldDelegate.tailOnBottom != tailOnBottom;
}

class _BubbleClipper extends CustomClipper<Path> {
  final double tailCenterX;
  final bool tailOnBottom;

  _BubbleClipper({required this.tailCenterX, required this.tailOnBottom});

  @override
  Path getClip(Size size) => _bubblePath(size, tailCenterX: tailCenterX, tailOnBottom: tailOnBottom);

  @override
  bool shouldReclip(covariant _BubbleClipper oldClipper) =>
      oldClipper.tailCenterX != tailCenterX || oldClipper.tailOnBottom != tailOnBottom;
}
