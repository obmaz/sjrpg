import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'player_afflictions.dart';

class AfflictionIcons extends StatelessWidget {
  const AfflictionIcons(this.state, {super.key});
  final PlayerAfflictions state;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final status in state.active)
          Semantics(
            label: '${status.label} ${state.remaining(status).ceil()}초',
            excludeSemantics: true,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xee102f2d),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                switch (status) {
                  PlayerStatus.root => Icons.grid_4x4,
                  PlayerStatus.freeze => Icons.ac_unit,
                  PlayerStatus.poison => Icons.science_outlined,
                  PlayerStatus.blind => Icons.visibility_off_outlined,
                  PlayerStatus.attackSlow => Icons.hourglass_bottom,
                  PlayerStatus.moveSlow => Icons.keyboard_double_arrow_down,
                },
                size: 14,
                color: switch (status) {
                  PlayerStatus.root => const Color(0xffd7bc8b),
                  PlayerStatus.freeze => const Color(0xff9cdeff),
                  PlayerStatus.poison => const Color(0xffb7e67c),
                  PlayerStatus.blind => const Color(0xffc9b6ff),
                  PlayerStatus.attackSlow => const Color(0xffc9a4ff),
                  PlayerStatus.moveSlow => const Color(0xffe3bb74),
                },
              ),
            ),
          ),
      ],
    ),
  );
}

/// A single cached radial shader darkens the world while all controls stay above.
class NarrowVisionCurtain extends StatefulWidget {
  const NarrowVisionCurtain({this.cameraOffsetY = 0, super.key});
  final double cameraOffsetY;
  @override
  State<NarrowVisionCurtain> createState() => _NarrowVisionCurtainState();
}

class _NarrowVisionCurtainState extends State<NarrowVisionCurtain> {
  late final painter = _VisionPainter(widget.cameraOffsetY);
  @override
  void didUpdateWidget(covariant NarrowVisionCurtain oldWidget) {
    super.didUpdateWidget(oldWidget);
    painter.offset = widget.cameraOffsetY;
  }

  @override
  void dispose() {
    painter.shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: CustomPaint(painter: painter, size: Size.infinite),
    ),
  );
}

class _VisionPainter extends CustomPainter {
  _VisionPainter(this.offset);
  double offset, cachedOffset = double.nan;
  Size cachedSize = Size.zero;
  ui.Shader? shader;
  final brush = Paint();
  @override
  void paint(Canvas canvas, Size size) {
    if (cachedSize != size || cachedOffset != offset) {
      shader?.dispose();
      shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2 - offset),
        size.shortestSide * .58,
        const [Color(0x00071013), Color(0x00071013), Color(0xf2071013)],
        const [0, .35, 1],
      );
      cachedSize = size;
      cachedOffset = offset;
      brush.shader = shader;
    }
    canvas.drawRect(Offset.zero & size, brush);
  }

  @override
  bool shouldRepaint(covariant _VisionPainter oldDelegate) => true;
}
