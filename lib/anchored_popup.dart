import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart' as theme;

const _preferredCardWidth = 280.0;
const _tailSize = 14.0;
const _margin = 8.0;

// Positions [child] in a card anchored to a screen point, with a tail
// pointing back at it - same idea as the web app's StopDetail.vue/
// VehicleDetail.vue anchored popups (anchoredPopup.ts), translated to
// Flutter's Positioned/Stack model instead of CSS left/top/transform.
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
    final tailOffset = (anchor.dx - left).clamp(_tailSize, cardWidth - _tailSize);

    final card = Container(
      width: cardWidth,
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        color: theme.surfaceTranslucent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.lineStrong),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    // A rotated square, half tucked under the card's edge - the classic
    // tooltip-tail trick, same as the web version's .tail element.
    final tail = Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: _tailSize,
        height: _tailSize,
        decoration: BoxDecoration(
          color: theme.surfaceTranslucent,
          border: Border(
            right: placeAbove ? const BorderSide(color: theme.lineStrong) : BorderSide.none,
            bottom: placeAbove ? const BorderSide(color: theme.lineStrong) : BorderSide.none,
            left: !placeAbove ? const BorderSide(color: theme.lineStrong) : BorderSide.none,
            top: !placeAbove ? const BorderSide(color: theme.lineStrong) : BorderSide.none,
          ),
        ),
      ),
    );
    final tailRow = Padding(
      padding: EdgeInsets.only(left: tailOffset - _tailSize / 2),
      child: tail,
    );

    // The card's height isn't known ahead of layout, so instead of the web
    // version's translateY(-100%) trick, "above" is anchored from the
    // screen's bottom edge and grows upward from there.
    return Positioned(
      left: left,
      top: placeAbove ? null : anchor.dy + _tailSize / 2,
      bottom: placeAbove ? screenSize.height - anchor.dy + _tailSize / 2 : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: placeAbove ? [card, tailRow] : [tailRow, card],
      ),
    );
  }
}
