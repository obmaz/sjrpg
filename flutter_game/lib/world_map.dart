import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'game_ui.dart';
import 'panel_controls.dart';
import 'rpg_widgets.dart';
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
  String? trackingMessage;
  String get trackingLabel =>
      trackingMessage ?? '◆ 의뢰   ⌂ 거점   ● 내 위치 · 목표 선택: 방향 추적';
  static const canvas = Size(1200, 900);
  bool constraining = false;
  @override
  void initState() {
    super.initState();
    transform.addListener(constrain);
  }

  void constrain() {
    if (constraining || viewport.isEmpty) return;
    final matrix = transform.value, scale = matrix.storage[0].abs();
    double axis(double offset, double content, double extent) =>
        content <= extent
        ? (extent - content) / 2
        : offset.clamp(extent - content - 12, 12).toDouble();
    final x = axis(matrix.storage[12], canvas.width * scale, viewport.width),
        y = axis(matrix.storage[13], canvas.height * scale, viewport.height);
    if (x == matrix.storage[12] && y == matrix.storage[13]) return;
    constraining = true;
    transform.value = Matrix4.copy(matrix)
      ..setTranslationRaw(x, y, matrix.storage[14]);
    constraining = false;
  }

  @override
  void dispose() {
    transform.removeListener(constrain);
    transform.dispose();
    super.dispose();
  }

  double get overviewScale =>
      math.min(viewport.width / canvas.width, viewport.height / canvas.height) *
      .95;
  double get minimumScale => math.min(.15, overviewScale).clamp(.001, .15);
  void center({bool overview = false, Offset? at}) {
    final hero = at ?? widget.session.hero.body.center;
    final scale = overview ? overviewScale : 1.1;
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
    final next = (current * factor).clamp(minimumScale, 6.0),
        ratio = next / current;
    transform.value = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - (viewport.width / 2 - old.storage[12]) * ratio,
        viewport.height / 2 - (viewport.height / 2 - old.storage[13]) * ratio,
        0,
        1,
      )
      ..scaleByDouble(next, next, 1, 1);
  }

  void selectGoal(QuestSite site) {
    final session = widget.session;
    final changed = session.toggleTrackedSite(site);
    setState(() {
      if (!changed) {
        trackingMessage = session.cleansedSites.contains(site.id)
            ? '이미 완료한 의뢰입니다'
            : '먼저 현재 의뢰를 진행하세요';
      } else if (session.trackedSite == null) {
        trackingMessage = '목표 추적 해제';
      } else {
        trackingMessage = '${site.name} 추적 · 다시 누르면 해제';
      }
    });
    center(at: site.at);
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
                            minScale: minimumScale,
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
                            final tracked =
                                widget.session.trackedSite?.id == site.id;
                            final done = widget.session.cleansedSites.contains(
                              site.id,
                            );
                            final count = widget.session.visibleSites.length;
                            return SizedBox(
                              width: count <= 3
                                  ? (box.maxWidth - 24 - (count - 1) * 6) /
                                        count
                                  : 120,
                              child: Semantics(
                                selected: tracked,
                                child: GameAction(
                                  '${done ? '✓ ' : ''}${site.name}',
                                  primary: tracked,
                                  fontSize: box.maxWidth < 340 ? 13 : 14,
                                  semanticLabel: '지도 목표 · ${site.name}',
                                  onTap: () => selectGoal(site),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 12,
                    ),
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      label: trackingLabel,
                      excludeSemantics: true,
                      child: Text(
                        trackingLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xffa9c5b9),
                          fontSize: 13,
                        ),
                      ),
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
