import 'package:flutter/widgets.dart';

/// World-only shading: input and Flutter HUD stay above this layer.
class GameVignette extends StatelessWidget {
  const GameVignette({super.key});
  static const ambient = Color(0x4d0a1220);
  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: RepaintBoundary(
      child: DecoratedBox(
        key: ValueKey('game-vignette'),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: .9,
            colors: [Color(0x00000000), Color(0x73000000)],
          ),
        ),
      ),
    ),
  );
}
