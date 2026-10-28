import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'game_ui.dart';
import 'panel_controls.dart';
import 'rpg_widgets.dart';
import 'travel_journal.dart';
import 'world_model.dart';

class TravelPanel extends StatelessWidget {
  const TravelPanel({
    required this.session,
    required this.onClose,
    required this.onTravel,
    super.key,
  });
  final Adventure session;
  final VoidCallback onClose;
  final void Function(WorldStage stage, String wellId)? onTravel;

  @override
  Widget build(BuildContext context) {
    final source = session.travelJournal.nearbyWell(
      session.world,
      session.hero.body.center,
    );
    final wells = session.travelJournal.wells.toList();
    final usable = source != null && session.riding == null && onTravel != null;
    final short = MediaQuery.sizeOf(context).height < 500;
    return ColoredBox(
      color: const Color(0xcc040d10),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: FramedSurface(
                art: session.art,
                compact: true,
                child: Column(
                  children: [
                    GamePanelHeader(
                      title: '우물 워프',
                      subtitle: '발견한 우물 ${wells.length}곳',
                      onClose: onClose,
                      dense: short,
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, short ? 6 : 12),
                      child: Row(
                        children: [
                          Icon(
                            source == null
                                ? Icons.explore_outlined
                                : Icons.my_location,
                            color: gold,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              session.riding != null
                                  ? '탈것에서 내린 뒤 우물을 이용하세요.'
                                  : source == null
                                  ? '발견한 우물 가까이에서 연결하세요.'
                                  : '${source.site.name}에서 연결 중',
                              style: const TextStyle(
                                color: cream,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        child: ListView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            if (!short)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 14),
                                child: Text(
                                  '한 번 발견한 우물은 다른 스테이지에서도 이어집니다.',
                                  style: TextStyle(
                                    color: Color(0xffa4bcb6),
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            if (session.saveFailed)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  '저장하지 못했습니다. 연결을 다시 시도하세요.',
                                  style: TextStyle(
                                    color: Color(0xffffaa8b),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            if (wells.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  '우물에 가까이 가면 포탈이 깨어납니다.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: cream, fontSize: 15),
                                ),
                              ),
                            for (final stage in WorldStage.values)
                              if (wells.any((well) => well.stage == stage)) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    10,
                                    4,
                                    8,
                                  ),
                                  child: Text(
                                    stage.title,
                                    style: TextStyle(
                                      color: stage.sanctuaryColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                for (final well in wells.where(
                                  (well) => well.stage == stage,
                                ))
                                  _wellCard(
                                    well,
                                    current:
                                        source?.stage == well.stage &&
                                        source?.id == well.id,
                                    usable: usable,
                                  ),
                              ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: GameAction(
                        '모험 계속하기',
                        icon: Icons.play_arrow,
                        primary: true,
                        onTap: onClose,
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
  }

  Widget _wellCard(
    DiscoveredWell well, {
    required bool current,
    required bool usable,
  }) {
    final enabled = usable && !current;
    final site = well.site;
    void travel() => onTravel?.call(well.stage, well.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: current ? '${site.name} · 현재 위치' : '${site.name}로 워프',
        onTap: enabled ? travel : null,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: gameButtonDecoration(enabled: enabled || current),
            child: InkWell(
              onTap: enabled ? travel : null,
              borderRadius: BorderRadius.circular(7),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 46,
                      child: CustomPaint(
                        painter: _PortalThumbnail(
                          session.art.images['well-portal'],
                          site.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site.name,
                            style: const TextStyle(
                              color: cream,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            current ? '현재 위치' : '연결된 우물',
                            style: TextStyle(
                              color: current ? gold : const Color(0xffa4bcb6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      current ? Icons.my_location : Icons.chevron_right,
                      color: enabled || current
                          ? gold
                          : const Color(0xff718b83),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalThumbnail extends CustomPainter {
  const _PortalThumbnail(this.image, this.color);
  final ui.Image? image;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * .46,
      Paint()..color = color.withValues(alpha: .12),
    );
    if (image != null) {
      canvas.drawImageRect(
        image!,
        const Rect.fromLTWH(0, 0, 313, 313),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      canvas.drawOval(
        Rect.fromLTWH(size.width * .25, 4, size.width * .5, size.height - 8),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_PortalThumbnail oldDelegate) =>
      oldDelegate.image != image || oldDelegate.color != color;
}
