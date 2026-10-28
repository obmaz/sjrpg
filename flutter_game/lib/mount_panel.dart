import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'game_art.dart';
import 'game_ui.dart';
import 'mount_merchant.dart';
import 'panel_controls.dart';
import 'rpg_widgets.dart';
import 'world_model.dart';

class MountPanel extends StatefulWidget {
  const MountPanel({
    required this.session,
    required this.onClose,
    this.onCheckpoint,
    super.key,
  });
  final Adventure session;
  final VoidCallback onClose;
  final VoidCallback? onCheckpoint;
  @override
  State<MountPanel> createState() => _MountPanelState();
}

class _MountPanelState extends State<MountPanel> {
  final scroll = ScrollController();
  String message = '';
  Adventure get s => widget.session;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void trade(bool Function() action, String success, {bool close = false}) {
    final accepted = action();
    if (!mounted) return;
    setState(() => message = accepted ? success : '골드·주변 공간·탈것 상태를 확인해 주세요.');
    if (accepted) {
      widget.onCheckpoint?.call();
      if (close) widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: s,
    builder: (context, _) {
      final short = MediaQuery.sizeOf(context).height < 500;
      final canTrade =
          s.ready &&
          !s.disposed &&
          !s.defeated &&
          !s.won &&
          s.nearMountMerchant;
      return ColoredBox(
        color: const Color(0xcc040d10),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 570),
                child: FramedSurface(
                  art: s.art,
                  compact: true,
                  child: Column(
                    children: [
                      GamePanelHeader(
                        title: '탈것 상인',
                        subtitle: short ? null : '역할에 맞는 동료를 고르세요',
                        dense: short,
                        onClose: widget.onClose,
                        trailing: Text(
                          '${s.progress.gold} G',
                          style: const TextStyle(
                            color: gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          controller: scroll,
                          thumbVisibility: true,
                          thickness: 3,
                          child: ListView(
                            controller: scroll,
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            children: [
                              if (!canTrade)
                                _note('탈것 상인 가까이에서 구매·보수할 수 있습니다.'),
                              if (message.isNotEmpty) _note(message),
                              for (final def in travelMountDefs.take(4))
                                _card(def, canTrade),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          short ? 6 : 10,
                          14,
                          14,
                        ),
                        child: GameAction(
                          '모험 계속하기',
                          primary: true,
                          onTap: widget.onClose,
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
    },
  );
  Widget _note(String text) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xff1e4940),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(color: cream, fontSize: 13, height: 1.25),
    ),
  );
  Widget _card(TravelMountDef def, bool canTrade) {
    final owned = s.progress.mountProgress.owns(def.id),
        state = owned ? s.progress.mountProgress.stateFor(def.id) : null;
    final repair = state == null
        ? 0
        : state.fallen
        ? 40
        : ((100 - state.durability) * .6).ceil();
    final price = def.price, upgrade = s.motorUpgradeCost;
    final blocked = s.riding != null;
    return Container(
      key: ValueKey('mount-card-${def.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff11352f),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: owned ? gold.withValues(alpha: .65) : const Color(0xff416359),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 76,
                child: CustomPaint(painter: MountPortraitPainter(s.art, def)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.name,
                      style: const TextStyle(
                        color: cream,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      def.description,
                      style: const TextStyle(
                        color: Color(0xffb5cac1),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${def.skillName} · ${def.skillCooldown % 1 == 0 ? def.skillCooldown.toInt() : def.skillCooldown}초',
                      style: const TextStyle(color: gold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            owned
                ? state!.fallen
                      ? '쓰러짐 · 마구간 보수 필요'
                      : def.artKey == 'horse'
                      ? '내구 ${state.durability.ceil()}% · 피격 ${state.hits}/3'
                      : '내구 ${state.durability.ceil()}%'
                : '구매 ${def.price} G · 이동 ${def.speed.round()}',
            style: const TextStyle(color: Color(0xff8de0c3), fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (!owned)
            GameAction(
              '$price G · 구매',
              semanticLabel: '${def.name} 구매 · $price 골드',
              fontSize: 14,
              minHeight: 44,
              primary: true,
              onTap: canTrade && !blocked && s.progress.gold >= price
                  ? () => trade(
                      () => s.buyMount(def.id),
                      '${def.name} 구매 완료 · 가까이 가서 타기를 누르세요.',
                    )
                  : null,
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: GameAction(
                    '부르기',
                    semanticLabel: '${def.name} 부르기',
                    fontSize: 14,
                    minHeight: 44,
                    onTap: canTrade && !blocked && !state!.fallen
                        ? () => trade(
                            () => s.summonMount(def.id),
                            '${def.name}을 가까이 불렀습니다.',
                            close: true,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GameAction(
                    repair > 0 ? '보수 $repair G' : '정상',
                    semanticLabel: '${def.name} 보수 · $repair 골드',
                    fontSize: 14,
                    minHeight: 44,
                    onTap: canTrade && repair > 0 && s.progress.gold >= repair
                        ? () => trade(
                            () => s.repairOwnedMount(def.id),
                            '${def.name} 보수 완료',
                          )
                        : null,
                  ),
                ),
              ],
            ),
            if (def.id == 'motor') ...[
              const SizedBox(height: 8),
              Text(
                '기관포 ${s.progress.mountProgress.motorLevel}/3 · 탄약 ${s.progress.mountProgress.motorAmmo}/12',
                style: const TextStyle(color: cream, fontSize: 12),
              ),
              const SizedBox(height: 7),
              GameAction(
                s.progress.mountProgress.motorLevel >= 3
                    ? '기관포 강화 완료'
                    : '기관포 강화 · $upgrade G',
                semanticLabel: '오토바이 기관포 강화 · $upgrade 골드',
                fontSize: 13,
                minHeight: 44,
                onTap:
                    canTrade &&
                        s.progress.mountProgress.motorLevel < 3 &&
                        s.progress.gold >= upgrade
                    ? () => trade(
                        () => s.motorUpgradeCost == upgrade && s.upgradeMotor(),
                        '기관포 강화 완료',
                      )
                    : null,
              ),
              const SizedBox(height: 7),
              GameAction(
                '탄약 보충 · ${Adventure.motorAmmoPrice} G',
                semanticLabel: '오토바이 탄약 보충',
                fontSize: 13,
                minHeight: 44,
                onTap:
                    canTrade &&
                        s.progress.mountProgress.motorAmmo < 12 &&
                        s.progress.gold >= Adventure.motorAmmoPrice
                    ? () => trade(s.buyMotorAmmo, '탄약 12발 보충 완료')
                    : null,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class MountPortraitPainter extends CustomPainter {
  const MountPortraitPainter(this.art, this.def);
  final GameArt art;
  final TravelMountDef def;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()..color = const Color(0xff0a2825),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()
        ..color = const Color(0xff9b844d)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final hasPortrait = art.images.containsKey('actors-${def.artKey}');
    if (hasPortrait) {
      art.actor(
        canvas,
        def.artKey,
        Offset(size.width / 2, size.height - 8),
        math.pi * .25,
        0,
        66,
      );
    }
    if (!hasPortrait) {
      canvas.save();
      canvas.translate(size.width * .2, size.height * .15);
      MountSkillIconPainter(
        def.artKey,
      ).paint(canvas, Size(size.width * .6, size.height * .6));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MountPortraitPainter oldDelegate) =>
      art != oldDelegate.art || def != oldDelegate.def;
}
