import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_ui.dart';
import 'world_model.dart';

class ExpandedWorldMap extends StatefulWidget {
  const ExpandedWorldMap({
    required this.session,
    required this.onClose,
    super.key,
  });
  final Adventure session;
  final VoidCallback onClose;
  @override
  State<ExpandedWorldMap> createState() => _ExpandedWorldMapState();
}

class _ExpandedWorldMapState extends State<ExpandedWorldMap> {
  final transform = TransformationController();
  Size viewport = Size.zero;
  static const canvas = Size(1200, 900);
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  void center({bool overview = false}) {
    final hero = widget.session.hero.body.center;
    final scale = overview
        ? math.min(
                viewport.width / canvas.width,
                viewport.height / canvas.height,
              ) *
              .95
        : 1.1;
    final focus = overview
        ? canvas.center(Offset.zero)
        : Offset(
            hero.dx / worldSize.width * canvas.width,
            hero.dy / worldSize.height * canvas.height,
          );
    transform.value = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - focus.dx * scale,
        viewport.height / 2 - focus.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void zoom(double factor) {
    final old = transform.value, current = old.getMaxScaleOnAxis();
    final next = (current * factor).clamp(.15, 6.0), ratio = next / current;
    transform.value = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - (viewport.width / 2 - old.storage[12]) * ratio,
        viewport.height / 2 - (viewport.height / 2 - old.storage[13]) * ratio,
        0,
        1,
      )
      ..scaleByDouble(next, next, 1, 1);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff0b2022),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '모험 지도',
                    style: TextStyle(
                      color: cream,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '지도 닫기',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: cream),
                ),
              ],
            ),
          ),
          Text(
            widget.session.region,
            style: const TextStyle(color: gold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final size = Size(box.maxWidth, box.maxHeight);
                if (viewport != size) {
                  viewport = size;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) center();
                  });
                }
                return ClipRect(
                  child: InteractiveViewer(
                    transformationController: transform,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(1200),
                    minScale: .15,
                    maxScale: 6,
                    child: SizedBox(
                      width: canvas.width,
                      height: canvas.height,
                      child: CustomPaint(
                        painter: MapPainter(widget.session, round: false),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              '두 손가락으로 확대 · 드래그로 이동',
              style: TextStyle(color: Color(0xffa9c5b9), fontSize: 13),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => center(),
                icon: const Icon(Icons.my_location),
                label: const Text('내 위치'),
              ),
              TextButton.icon(
                onPressed: () => center(overview: true),
                icon: const Icon(Icons.public),
                label: const Text('전체 지도'),
              ),
              IconButton(
                tooltip: '지도 축소',
                onPressed: () => zoom(1 / 1.5),
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                tooltip: '지도 확대하기',
                onPressed: () => zoom(1.5),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: widget.onClose,
                child: const Text('모험 계속하기'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
