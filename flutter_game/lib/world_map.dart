import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_ui.dart';
import 'world_model.dart';
import 'panel_controls.dart';
import 'rpg_widgets.dart';

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

  void center({bool overview = false, Offset? at}) {
    final hero = at ?? widget.session.hero.body.center;
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
    final old = transform.value, current = old.storage[0].abs();
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
    color: const Color(0xcc040d10),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: FramedSurface(
              art: widget.session.art,
              compact: true,
              child: Column(
                children: [
                  GamePanelHeader(
                    title: '모험 지도',
                    subtitle: widget.session.world.stage.title,
                    closeLabel: '지도 닫기',
                    onClose: widget.onClose,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size = Size(box.maxWidth, box.maxHeight);
                        if (viewport != size) {
                          viewport = size;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) center(overview: true);
                          });
                        }
                        return ClipRect(
                          child: InteractiveViewer(
                            transformationController: transform,
                            constrained: false,
                            boundaryMargin: const EdgeInsets.all(
                              double.infinity,
                            ),
                            alignment: Alignment.topLeft,
                            minScale: .15,
                            maxScale: 6,
                            child: SizedBox(
                              width: canvas.width,
                              height: canvas.height,
                              child: ValueListenableBuilder<Matrix4>(
                                valueListenable: transform,
                                builder: (context, matrix, _) => CustomPaint(
                                  painter: MapPainter(
                                    widget.session,
                                    round: false,
                                    markerScale: 1 / matrix.storage[0].abs(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (widget.session.visibleSites.isNotEmpty)
                    SizedBox(
                      height: 46,
                      child: LayoutBuilder(
                        builder: (context, box) => ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3,
                          ),
                          itemCount: widget.session.visibleSites.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final site = widget.session.visibleSites[index];
                            final done = widget.session.cleansedSites.contains(
                              site.id,
                            );
                            return SizedBox(
                              width: widget.session.visibleSites.length <= 3
                                  ? (box.maxWidth -
                                            24 -
                                            (widget
                                                        .session
                                                        .visibleSites
                                                        .length -
                                                    1) *
                                                6) /
                                        widget.session.visibleSites.length
                                  : 120,
                              child: GameAction(
                                '${done ? '✓ ' : ''}${site.name}',
                                fontSize: box.maxWidth < 340 ? 13 : 14,
                                semanticLabel: '지도 목표 · ${site.name}',
                                onTap: () => center(at: site.at),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                    child: Text(
                      '◆ 의뢰   ⌂ 거점   ● 내 위치 · 끌어서 이동',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xffa9c5b9), fontSize: 13),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: GameAction('내 위치', onTap: () => center()),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GameAction(
                            '전체 지도',
                            onTap: () => center(overview: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _zoomButton(Icons.remove, '지도 축소', () => zoom(1 / 1.5)),
                        const SizedBox(width: 6),
                        _zoomButton(Icons.add, '지도 확대하기', () => zoom(1.5)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: GameAction(
                        '모험 계속하기',
                        primary: true,
                        icon: Icons.play_arrow_rounded,
                        onTap: widget.onClose,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _zoomButton(IconData icon, String label, VoidCallback action) =>
      GameIconButton(label: label, icon: icon, onTap: action, size: 48);
}
