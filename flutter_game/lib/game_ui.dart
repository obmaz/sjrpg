import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_art.dart';
import 'world_model.dart';

const gold = Color(0xffd5b772),
    ink = Color(0xff102f2d),
    cream = Color(0xfff0e5c8);
String gameTime(double seconds) =>
    '${seconds ~/ 60}:${(seconds.toInt() % 60).toString().padLeft(2, '0')}';

class GameHud extends StatelessWidget {
  const GameHud(this.session, {this.onMap, super.key});
  final Adventure session;
  final VoidCallback? onMap;
  @override
  Widget build(BuildContext context) {
    final p = session.progress;
    final width = MediaQuery.sizeOf(context).width;
    final short = MediaQuery.sizeOf(context).height < 520;
    final statusRight = math.max(104.0, width - 360);
    return SizedBox(
      height: 130,
      child: Stack(
        children: [
          Positioned(
            top: 17,
            left: 57,
            right: statusRight,
            child: ClipPath(
              clipper: _BarClipper(),
              child: Container(
                height: 33,
                decoration: BoxDecoration(
                  color: const Color(0xff351b1c),
                  border: Border.all(color: gold, width: 2),
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: (p.hp / p.maxHp).clamp(0, 1),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xffe66545), Color(0xffa62b28)],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${p.hp.ceil()} / ${p.maxHp.ceil()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 77,
            right: statusRight + 6,
            top: 52,
            child: Semantics(
              label:
                  '${p.heroClass.resource} ${p.energy.floor()} / ${p.maxEnergy.round()}',
              child: SizedBox(
                height: 15,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: p.energy / p.maxEnergy,
                        minHeight: 15,
                        color: p.heroClass == HeroClass.mage
                            ? const Color(0xff529bdf)
                            : const Color(0xffd49d40),
                        backgroundColor: const Color(0xdd102425),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${p.heroClass.resource} ${p.energy.floor()}',
                        style: const TextStyle(
                          color: cream,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 77,
            right: statusRight + 6,
            top: 69,
            child: LinearProgressIndicator(
              value: p.xp / p.nextLevelXp,
              minHeight: 3,
              color: gold,
              backgroundColor: const Color(0x99102425),
            ),
          ),
          Positioned(
            left: 10,
            top: 7,
            child: Container(
              width: 63,
              height: 72,
              decoration: BoxDecoration(
                color: ink,
                border: Border.all(color: gold, width: 2),
                borderRadius: BorderRadius.circular(35),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: CustomPaint(
                  painter: _PortraitPainter(session.art, p.heroClass),
                ),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 10,
            child: Container(
              width: 27,
              height: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ink,
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 1.5),
              ),
              child: Text(
                '${p.level}',
                style: const TextStyle(color: cream, fontSize: 14),
              ),
            ),
          ),
          Positioned(
            left: 84,
            top: 72,
            right: statusRight,
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _stat(Icons.monetization_on_outlined, '${p.gold}', gold),
                _stat(Icons.bolt, '${p.kills}', cream),
                if (width >= 360)
                  _stat(
                    Icons.wb_sunny_outlined,
                    gameTime(session.elapsed),
                    const Color(0xffdfce94),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 7,
            child: SizedBox(
              width: 85,
              height: 85,
              child: Semantics(
                button: true,
                label: '지도 확대',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onMap,
                  child: CustomPaint(painter: MapPainter(session)),
                ),
              ),
            ),
          ),
          if (!short)
            Positioned(
              right: 10,
              top: 98,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: .8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  session.region,
                  style: const TextStyle(color: cream, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, Color color) => Semantics(
    label:
        '${icon == Icons.monetization_on_outlined
            ? '골드'
            : icon == Icons.bolt
            ? '처치'
            : '모험 시간'} $value',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(s.width - 17, 0)
    ..lineTo(s.width, s.height / 2)
    ..lineTo(s.width - 17, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.art, this.heroClass);
  final GameArt art;
  final HeroClass heroClass;
  @override
  void paint(Canvas c, Size s) {
    if (heroClass == HeroClass.mage) {
      final image = art.images['actors-mage']!,
          frame = art.actors['mage']['frames'][0] as List;
      final w = (frame[2] as num).toDouble(), h = (frame[3] as num).toDouble();
      c.drawImageRect(
        image,
        Rect.fromLTWH(
          (frame[0] as num).toDouble() + w * .18,
          (frame[1] as num).toDouble(),
          w * .65,
          h * .52,
        ),
        Offset.zero & s,
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    final record = art.actors['hero']['frames'][0] as List;
    final image = art.images['actors-hero']!;
    final w = (record[2] as num).toDouble(), h = (record[3] as num).toDouble();
    c.drawImageRect(
      image,
      Rect.fromLTWH(
        (record[0] as num).toDouble() + w * .2,
        (record[1] as num).toDouble(),
        w * .6,
        h * .48,
      ),
      Offset.zero & s,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter oldDelegate) =>
      oldDelegate.heroClass != heroClass;
}

class ControlPainter extends CustomPainter {
  ControlPainter(this.art, this.sprite);
  final GameArt art;
  final String sprite;
  @override
  void paint(Canvas canvas, Size size) =>
      art.control(canvas, sprite, Offset.zero & size);
  @override
  bool shouldRepaint(covariant ControlPainter oldDelegate) =>
      oldDelegate.sprite != sprite;
}

class AbilityPicturePainter extends CustomPainter {
  AbilityPicturePainter(this.art, this.name);
  final GameArt art;
  final String name;
  @override
  void paint(Canvas canvas, Size size) {
    final picture = art.images[name];
    if (picture == null) return;
    canvas.drawImageRect(
      picture,
      Rect.fromLTWH(0, 0, picture.width.toDouble(), picture.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant AbilityPicturePainter old) =>
      old.art != art || old.name != name;
}

class MapPainter extends CustomPainter {
  MapPainter(this.session, {this.round = true});
  final Adventure session;
  final bool round;
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.save();
    if (round) c.clipPath(Path()..addOval(rect.deflate(3)));
    c.drawRect(rect, Paint()..color = const Color(0xff102a29));
    c.save();
    final view = round
        ? localMapBounds(session.hero.body.center)
        : Offset.zero & worldSize;
    c.scale(s.width / view.width, s.height / view.height);
    c.translate(-view.left, -view.top);
    c.drawRect(
      Offset.zero & worldSize,
      Paint()..color = const Color(0xff7d9656),
    );
    for (final wood in session.world.woods) {
      c.drawPath(wood.path, Paint()..color = const Color(0xff315947));
    }
    for (final clearing in session.world.clearings) {
      c.drawPath(clearing.path, Paint()..color = const Color(0xff8ca564));
    }
    for (final sand in session.world.sandFields) {
      c.drawPath(sand.path, Paint()..color = const Color(0xffc7b579));
    }
    for (final lake in [...session.world.lakes, session.world.river]) {
      c.drawPath(lake.path, Paint()..color = const Color(0xff3b91a0));
    }
    for (final trail in session.world.trails) {
      c.drawPath(
        trail.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = trail.width
          ..color = const Color(0xffdac489),
      );
    }
    c.drawRect(town, Paint()..color = const Color(0xffe3d29a));
    for (final exit in stageExits) {
      c.drawCircle(
        Offset(exit.x, exit.y),
        round ? 100 : 65,
        Paint()
          ..color = session.progress.bossDefeated
              ? const Color(0xff82dfe0)
              : const Color(0xff594234),
      );
    }
    if (round) {
      for (final mob in session.mobs) {
        if (!mob.combatReady || mob.isDead || mob.isRemoving) continue;
        c.drawCircle(
          mob.body.center,
          mob.boss
              ? 65
              : mob.isElite
              ? 42
              : 30,
          Paint()
            ..color = mob.isElite ? mob.trait.color : const Color(0xffef785e),
        );
      }
      for (var i = 0; i < Adventure.chestLocations.length; i++) {
        if (session.openedChests.contains(i)) continue;
        c.drawCircle(Adventure.chestLocations[i], 42, Paint()..color = gold);
      }
    }
    c.restore();
    final hero = Offset(
      (session.hero.body.center.dx - view.left) / view.width * s.width,
      (session.hero.body.center.dy - view.top) / view.height * s.height,
    );
    c.drawCircle(hero, round ? 3 : 5, Paint()..color = const Color(0xff9df3ee));
    c.drawCircle(
      hero,
      round ? 3 : 5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white,
    );
    if (!round) {
      for (final exit in stageExits) {
        final x = (exit.x / worldSize.width * s.width).clamp(
              27.0,
              s.width - 27,
            ),
            y = (exit.y / worldSize.height * s.height).clamp(
              15.0,
              s.height - 15,
            );
        session.art.text(c, exit.direction, Offset(x, y - 9), size: 13);
      }
    }
    c.restore();
    if (round) {
      c.drawOval(
        rect.deflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = gold,
      );
      c.drawOval(
        rect.deflate(6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) => true;
}

class EffectIconPainter extends CustomPainter {
  EffectIconPainter(this.art, this.index);
  final GameArt art;
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final image = art.images['combat-fx'];
    if (image == null) return;
    final cell = image.width / 4;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH((index % 4) * cell, (index ~/ 4) * cell, cell, cell),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant EffectIconPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.art != art;
}

class ActionButton extends StatefulWidget {
  const ActionButton({
    required this.art,
    required this.sprite,
    required this.label,
    required this.semanticLabel,
    required this.size,
    required this.onTap,
    this.onHold,
    this.onAimStart,
    this.onAimMove,
    this.onAimEnd,
    this.icon,
    this.effect,
    this.artwork,
    this.showLabel = true,
    this.remaining = 0,
    this.total = 1,
    super.key,
  });
  final GameArt art;
  final String sprite, label, semanticLabel;
  final double size, remaining, total;
  final VoidCallback onTap;
  final ValueChanged<bool>? onHold;
  final VoidCallback? onAimStart;
  final ValueChanged<Offset>? onAimMove;
  final ValueChanged<bool>? onAimEnd;
  final IconData? icon;
  final int? effect;
  final Widget? artwork;
  final bool showLabel;
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  int? pointer;
  bool pressed = false;
  Offset origin = Offset.zero, aimDelta = Offset.zero;
  void release({bool cancelled = false}) {
    if (pointer != null) widget.onAimEnd?.call(cancelled);
    pointer = null;
    if (pressed) {
      widget.onHold?.call(false);
      if (mounted) setState(() => pressed = false);
    }
  }

  @override
  void dispose() {
    if (pointer != null) widget.onAimEnd?.call(true);
    widget.onHold?.call(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.semanticLabel,
    onTap: widget.onTap,
    excludeSemantics: true,
    child: Listener(
      onPointerDown: (event) {
        if (pointer != null) return;
        pointer = event.pointer;
        origin = event.position;
        aimDelta = Offset.zero;
        setState(() => pressed = true);
        if (widget.onAimStart != null) {
          widget.onAimStart!();
        } else {
          widget.onHold?.call(true);
          widget.onTap();
        }
      },
      onPointerMove: (event) {
        if (pointer != event.pointer || widget.onAimMove == null) return;
        setState(() => aimDelta = event.position - origin);
        widget.onAimMove!(aimDelta);
      },
      onPointerUp: (event) {
        if (pointer == event.pointer) release();
      },
      onPointerCancel: (event) {
        if (pointer == event.pointer) release(cancelled: true);
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size + (widget.showLabel ? 22 : 0),
        child: Column(
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      scale: pressed ? .94 : 1,
                      duration: const Duration(milliseconds: 70),
                      child: CustomPaint(
                        size: Size.square(widget.size),
                        painter: ControlPainter(widget.art, widget.sprite),
                      ),
                    ),
                    if (widget.artwork != null)
                      widget.artwork!
                    else if (widget.effect != null)
                      CustomPaint(
                        size: Size.square(widget.size * .74),
                        painter: EffectIconPainter(widget.art, widget.effect!),
                      )
                    else if (widget.icon != null)
                      Icon(widget.icon, size: widget.size * .43, color: cream),
                    if (pressed && widget.onAimStart != null)
                      Positioned.fill(
                        child: ColoredBox(
                          color: aimDelta.distance > 156
                              ? const Color(0x99a12929)
                              : const Color(0x334bd8c2),
                          child: aimDelta.distance > 156
                              ? const Icon(Icons.close, color: Colors.white)
                              : Center(
                                  child: Transform.translate(
                                    offset:
                                        aimDelta.distance > widget.size * .28
                                        ? aimDelta /
                                              aimDelta.distance *
                                              widget.size *
                                              .28
                                        : aimDelta,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xaa9deee4),
                                        border: Border.all(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    if (widget.remaining > 0)
                      CustomPaint(
                        size: Size.square(widget.size),
                        painter: _CooldownPainter(
                          widget.remaining / widget.total,
                        ),
                      ),
                    if (!widget.showLabel && widget.remaining > 0)
                      Text(
                        '${widget.remaining.ceil()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.showLabel)
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: cream,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _CooldownPainter extends CustomPainter {
  _CooldownPainter(this.ratio);
  final double ratio;
  @override
  void paint(Canvas c, Size s) => c.drawArc(
    (Offset.zero & s).deflate(5),
    -math.pi / 2,
    math.pi * 2 * ratio.clamp(0, 1),
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xaaebd293),
  );
  @override
  bool shouldRepaint(covariant _CooldownPainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}

class GameStick extends StatefulWidget {
  const GameStick({
    required this.art,
    required this.size,
    required this.onChange,
    super.key,
  });
  final GameArt art;
  final double size;
  final void Function(double, double) onChange;
  @override
  State<GameStick> createState() => _GameStickState();
}

class _GameStickState extends State<GameStick> {
  int? pointer;
  Offset knob = Offset.zero;
  void move(PointerEvent event) {
    if (pointer != event.pointer) return;
    final raw = event.localPosition - Offset(widget.size / 2, widget.size / 2),
        maximum = widget.size * .27,
        d = raw.distance;
    final delta = d > maximum ? raw / d * maximum : raw;
    setState(() => knob = delta);
    final intensity = (d / maximum).clamp(0.0, 1.0);
    widget.onChange(
      math.atan2(delta.dy, delta.dx),
      intensity < .18 ? 0 : (intensity - .18) / .82,
    );
  }

  void release() {
    pointer = null;
    if (mounted) setState(() => knob = Offset.zero);
    widget.onChange(0, 0);
  }

  @override
  void dispose() {
    widget.onChange(0, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '이동 조이스틱',
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (pointer != null) return;
        pointer = event.pointer;
        move(event);
      },
      onPointerMove: move,
      onPointerUp: (event) {
        if (pointer == event.pointer) release();
      },
      onPointerCancel: (event) {
        if (pointer == event.pointer) release();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: .7,
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: ControlPainter(widget.art, 'touchJoystick'),
              ),
            ),
            Transform.translate(
              offset: knob,
              child: CustomPaint(
                size: Size.square(widget.size * .36),
                painter: ControlPainter(widget.art, 'touchThumb'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class MenuButton extends StatelessWidget {
  const MenuButton({
    required this.art,
    required this.sprite,
    required this.label,
    required this.onTap,
    this.badge = 0,
    super.key,
  });
  final int badge;
  final GameArt art;
  final String sprite, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: ControlPainter(art, sprite)),
              ),
              if (badge > 0)
                Positioned(
                  right: -4,
                  top: -5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 23,
                      minHeight: 23,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xffc74c35),
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: 1.5),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
