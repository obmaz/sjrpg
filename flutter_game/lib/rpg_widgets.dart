import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'barbarian_icon_art.dart';
import 'cinematic_icon_art.dart';
import 'game_art.dart';
import 'game_ui.dart';
import 'gear_icon_art.dart';
import 'rpg_model.dart';
import 'sorceress_icon_art.dart';

IconData elementIcon(String element) => element == 'ice'
    ? Icons.ac_unit
    : element == 'lightning'
    ? Icons.bolt
    : Icons.local_fire_department;
int skillEffect(String id) =>
    SorceressIconArt.effectFor(id) ??
    BarbarianIconArt.effectFor(id) ??
    switch (id) {
      'rendingEdge' => 14,
      'stormOfSteel' => 15,
      'weaponTempo' => 16,
      'veteranGuard' => 17,
      'secondWind' => 18,
      'resoundingCry' => 19,
      'warDrums' => 20,
      'unyieldingOath' => 21,
      'emberFocus' => 22,
      'cinderReach' => 23,
      'phoenixHeart' => 24,
      'deepFreeze' => 25,
      'frozenAegis' => 26,
      'glacialReserve' => 27,
      'conductivity' => 28,
      'forkedStorm' => 29,
      'arcaneEconomy' => 30,

      'battleFocus' => 8,
      'battleVigor' => 9,
      'rallyingVoice' => 10,
      'warmth' => 11,
      'coldMastery' => 12,
      'lightningMastery' => 13,

      'warcry' || 'ironSkin' => 0,
      'whirlwind' => 1,
      'frostNova' => 2,
      'chainLightning' => 3,
      'meteor' || 'firebolt' => 4,
      'quickCut' => 7,
      'heavyStrike' => 35,
      'iceShard' => 2,
      'sparkBolt' => 3,
      'frenzy' => 5,
      'charge' => 34,
      'battleSprint' => 34,
      'blink' => 3,
      'crushingBlow' => 35,
      'shadowAssault' => 36,
      'iceArmor' => 6,
      _ => 7,
    };
IconData skillIcon(String id) =>
    SorceressIconArt.fallbackFor(id) ??
    BarbarianIconArt.fallbackFor(id) ??
    switch (id) {
      'warmth' => Icons.local_fire_department,
      'coldMastery' => Icons.ac_unit,
      'lightningMastery' => Icons.bolt,
      'battleFocus' => Icons.track_changes,
      'battleVigor' => Icons.favorite,
      'rallyingVoice' => Icons.campaign,
      'warcry' => Icons.campaign,
      'whirlwind' => Icons.cyclone,
      'frenzy' => Icons.flash_on,
      'charge' => Icons.double_arrow,
      'battleSprint' => Icons.directions_run_rounded,
      'blink' => Icons.blur_on_rounded,
      'crushingBlow' => Icons.sports_martial_arts,
      'shadowAssault' => Icons.people_alt_rounded,
      'ironSkin' => Icons.shield,
      'mastery' => Icons.military_tech,
      'frostNova' => Icons.ac_unit,
      'iceArmor' => Icons.security,
      'chainLightning' => Icons.bolt,
      'meteor' => Icons.whatshot,
      'arcaneMastery' => Icons.auto_awesome,
      'firebolt' => Icons.local_fire_department,
      _ => Icons.sports_martial_arts,
    };
Color skillColor(SkillDef s) => SorceressIconArt.effectFor(s.id) != null
    ? SorceressIconArt.color(
        SorceressIconArt.effectFor(s.id)! - SorceressIconArt.firstEffect,
      )
    : BarbarianIconArt.effectFor(s.id) != null
    ? BarbarianIconArt.color(
        BarbarianIconArt.effectFor(s.id)! - BarbarianIconArt.firstEffect,
      )
    : s.branch == '냉기'
    ? const Color(0xffa8e4f0)
    : s.branch == '화염'
    ? const Color(0xfff4ab6f)
    : s.branch == '번개'
    ? const Color(0xffcdb7ff)
    : gold;

class FramedSurface extends StatelessWidget {
  const FramedSurface({
    required this.art,
    required this.child,
    this.compact = false,
    super.key,
  });
  final GameArt art;
  final Widget child;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final body = compact
        ? child
        : Padding(padding: const EdgeInsets.all(10), child: child);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CustomPaint(painter: _FramePainter(art), child: body),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.art);
  final GameArt art;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(1.2);
    final shape = RRect.fromRectAndRadius(bounds, const Radius.circular(18));
    canvas.drawRRect(shape, Paint()..color = const Color(0xf5103032));
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = gameMetal.withValues(alpha: .9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(3), const Radius.circular(15)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0x88679b8d),
    );
    canvas.drawLine(
      Offset(23, 5),
      Offset(math.max(23, size.width - 23), 5),
      Paint()
        ..strokeWidth = .8
        ..color = const Color(0x99d6c59e),
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.art != art;
}

class PotionBelt extends StatelessWidget {
  const PotionBelt(this.session, {this.onUse, super.key});
  final Adventure session;
  final VoidCallback? onUse;

  void _use(VoidCallback action) {
    action();
    onUse?.call();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _potion(
        Icons.science,
        const Color(0xffffa49a),
        session.progress.healingPotions,
        '치유 물약',
        () => session.potion(),
      ),
      const SizedBox(width: 6),
      _potion(
        Icons.science,
        const Color(0xffa2caff),
        session.progress.energyPotions,
        '${session.progress.heroClass.resource} 물약',
        () => session.potion(energy: true),
      ),
    ],
  );
  Widget _potion(
    IconData icon,
    Color color,
    int count,
    String label,
    VoidCallback action,
  ) => Semantics(
    button: true,
    label: '$label $count개',
    excludeSemantics: true,
    onTap: () => _use(action),
    child: InkWell(
      onTap: () => _use(action),
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ink.withValues(alpha: .9),
                  border: Border.all(color: gold.withValues(alpha: .65)),
                ),
                child: CustomPaint(
                  painter: color == const Color(0xffa2caff)
                      ? PotionPainter(session.art, blue: true)
                      : CinematicIconPainter(session.art, 5),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(color: cream, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class GearGlyph extends CustomPainter {
  GearGlyph(this.item, this.art);
  final Gear item;
  final GameArt art;
  @override
  void paint(Canvas canvas, Size size) {
    if (GearIconArt.paintExpanded(canvas, Offset.zero & size, item.base)) {
      return;
    }
    final image = art.images['gear-icons'];
    if (image == null) return;
    final source = GearIconArt.source(image, item.base);
    if (source == null) return;
    final side = math.min(size.width, size.height);
    canvas.drawImageRect(
      image,
      source,
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: side,
        height: side,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant GearGlyph oldDelegate) =>
      oldDelegate.item != item || oldDelegate.art != art;
}

class PotionPainter extends CustomPainter {
  PotionPainter(this.art, {this.blue = false});
  final GameArt art;
  final bool blue;
  @override
  void paint(Canvas canvas, Size size) {
    final image = art.images['atlas'];
    if (image == null) return;
    final cell = image.width / 4;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (blue) {
      paint.colorFilter = const ColorFilter.matrix([
        .3,
        .25,
        .45,
        0,
        0,
        .3,
        .4,
        .3,
        0,
        0,
        .7,
        .2,
        .1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(cell * 3, cell, cell, cell),
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant PotionPainter oldDelegate) =>
      oldDelegate.blue != blue || oldDelegate.art != art;
}

class BossHealth extends StatelessWidget {
  const BossHealth(this.enemy, {super.key});
  final HuntEnemy enemy;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
      decoration: BoxDecoration(
        color: const Color(0xdd182b26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gold.withValues(alpha: .75)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            enemy.windup > 0 ? '숲의 파수꾼 · 강타 준비' : '숲의 파수꾼',
            style: const TextStyle(
              color: cream,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (enemy.life.value / enemy.life.max).clamp(0, 1),
              minHeight: 7,
              color: const Color(0xffd76d4d),
              backgroundColor: const Color(0xff382923),
            ),
          ),
        ],
      ),
    ),
  );
}
