import 'dart:math' as math;

import 'package:flutter/material.dart';

const entryCanvasSize = Size(1672, 941);

/// Artwork, highlights and input regions share one reference canvas.
class LandscapeEntry extends StatelessWidget {
  const LandscapeEntry({required this.builder, this.fill = false, super.key});
  final bool fill;
  final Widget Function(double scale) builder;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111b18),
    body: SafeArea(
      top: !fill,
      bottom: !fill,
      left: !fill,
      right: !fill,
      child: LayoutBuilder(
        builder: (context, box) {
          final rotated = box.maxHeight > box.maxWidth;
          final width = rotated ? box.maxHeight : box.maxWidth;
          final height = rotated ? box.maxWidth : box.maxHeight;
          final scale = (fill ? math.max : math.min)(
            width / entryCanvasSize.width,
            height / entryCanvasSize.height,
          );
          final canvas = SizedBox.expand(
            child: FittedBox(
              clipBehavior: Clip.hardEdge,
              fit: fill ? BoxFit.cover : BoxFit.contain,
              child: SizedBox.fromSize(
                size: entryCanvasSize,
                child: builder(scale),
              ),
            ),
          );
          return rotated ? RotatedBox(quarterTurns: 1, child: canvas) : canvas;
        },
      ),
    ),
  );
}

/// The image retains its authored rectangle while the touch target grows to 44px.
class EntryHotspot extends StatelessWidget {
  const EntryHotspot({
    required this.rect,
    required this.scale,
    required this.label,
    required this.artwork,
    required this.onTap,
    this.selected,
    this.hint,
    super.key,
  });
  final Rect rect;
  final double scale;
  final String label;
  final String? hint;
  final bool? selected;
  final Widget artwork;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final minimum = 44 / math.max(.01, scale);
    final width = math.min(
      entryCanvasSize.width,
      math.max(rect.width, minimum),
    );
    final height = math.min(
      entryCanvasSize.height,
      math.max(rect.height, minimum),
    );
    final left = (rect.center.dx - width / 2).clamp(
      0.0,
      entryCanvasSize.width - width,
    );
    final top = (rect.center.dy - height / 2).clamp(
      0.0,
      entryCanvasSize.height - height,
    );
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        label: label,
        hint: hint,
        selected: selected,
        enabled: onTap != null,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: rect.left - left,
                  top: rect.top - top,
                  width: rect.width,
                  height: rect.height,
                  child: Opacity(
                    opacity: onTap == null ? .38 : 1,
                    child: artwork,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget entryImage(String name) => Image.asset(
  'assets/images/$name.png',
  fit: BoxFit.fill,
  excludeFromSemantics: true,
);

class EntryPlaque extends StatelessWidget {
  const EntryPlaque(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: const Color(0xe6172923),
      shape: BeveledRectangleBorder(
        side: const BorderSide(color: Color(0xffbfac7d), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    child: Center(
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xffefe5d1),
          fontSize: 30,
          letterSpacing: 2,
        ),
      ),
    ),
  );
}
