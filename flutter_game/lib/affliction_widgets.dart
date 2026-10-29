import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'combat_balance.dart';
import 'd1_icon_art.dart';
import 'player_afflictions.dart';

class AfflictionIcons extends StatelessWidget {
  const AfflictionIcons(this.state, {this.session, super.key});
  final PlayerAfflictions state;
  final Adventure? session;
  @override
  Widget build(BuildContext context) => session != null
      ? CombatStatusIcons(session!)
      : IgnorePointer(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final status in state.active)
                Semantics(
                  label:
                      '${status.label} ${CombatBalance.realSeconds(state.remaining(status)).ceil()}초',
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
                        PlayerStatus.moveSlow =>
                          Icons.keyboard_double_arrow_down,
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

typedef _Status = ({String label, int icon, double time, bool bad});

/// Reads authoritative timers; hiding a badge never changes a combat effect.
class CombatStatusIcons extends StatelessWidget {
  const CombatStatusIcons(this.session, {super.key});
  final Adventure session;
  @override
  Widget build(BuildContext context) {
    final hero = session.hero, cries = session.barbarianUtilities;
    final defenses = hero.sorceressCombat.defenses;
    final badges = <_Status>[];
    void buff(String label, int icon, double time) {
      if (time > 0) {
        badges.add((label: label, icon: icon, time: time, bad: false));
      }
    }

    buff('외침', 16, cries.shoutTime);
    buff('전투 지시', 17, cries.ordersTime);
    buff('전투 명령', 18, cries.commandTime);
    buff('광분', 22, hero.frenzyTime);
    buff('질주', 23, hero.sprintTime);
    buff('방어 강화', 16, hero.armorTime);
    buff('냉기 갑옷', 20, defenses.armorTime);
    buff('마력 보호막', 21, defenses.energyShieldTime);
    buff('마법 부여', 19, defenses.enchantTime);
    buff('뇌우', 217, defenses.thunderStormTime);
    buff('불길', 223, hero.sorceressCombat.blazeTime);
    for (final status in session.afflictions.active) {
      badges.add((
        label: status.label,
        icon: 24 + status.index,
        time: session.afflictions.remaining(status),
        bad: true,
      ));
    }
    return IgnorePointer(
      child: SizedBox(
        height: 28,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final badge in badges)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Semantics(
                    label:
                        '${badge.label} ${CombatBalance.realSeconds(badge.time).ceil()}초',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xee171a1b),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: badge.bad
                                    ? const Color(0xff92534b)
                                    : const Color(0xff968565),
                                width: .7,
                              ),
                            ),
                            child: CustomPaint(
                              painter: _StatusSymbol(session, badge.icon),
                            ),
                          ),
                          Text(
                            _time(badge.time),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 7,
                              height: 1.15,
                              color: badge.bad
                                  ? const Color(0xffe4aea0)
                                  : const Color(0xffd5c9ab),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _time(double simulation) {
    final seconds = CombatBalance.realSeconds(simulation).ceil();
    return seconds > 99 ? '${(seconds / 60).ceil()}m' : '${seconds}s';
  }
}

class _StatusSymbol extends CustomPainter {
  _StatusSymbol(this.session, this.icon);
  final Adventure session;
  final int icon;
  @override
  void paint(Canvas canvas, Size size) {
    D1IconArt.draw(
      canvas,
      session.art,
      icon,
      (Offset.zero & size).deflate(1),
      compact: true,
    );
  }

  @override
  bool shouldRepaint(covariant _StatusSymbol old) =>
      old.session != session || old.icon != icon;
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
