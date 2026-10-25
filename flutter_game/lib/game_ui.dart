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
  const GameHud(this.session, {super.key});
  final Adventure session;
  @override
  Widget build(BuildContext context) {
    final p = session.progress;
    return SizedBox(
      height: 130,
      child: Stack(
        children: [
          Positioned(
            top: 17,
            left: 57,
            right: 104,
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
                child: CustomPaint(painter: _PortraitPainter(session.art)),
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
                '${p.stage}',
                style: const TextStyle(color: cream, fontSize: 14),
              ),
            ),
          ),
          Positioned(
            left: 84,
            top: 60,
            right: 104,
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _stat(Icons.monetization_on_outlined, '${p.gold}', gold),
                _stat(Icons.bolt, '${p.kills}', cream),
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
              child: CustomPaint(painter: MapPainter(session)),
            ),
          ),
          Positioned(
            right: 10,
            top: 98,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
  _PortraitPainter(this.art);
  final GameArt art;
  @override
  void paint(Canvas c, Size s) {
    final image = art.images['ui-reference']!, cell = image.width / 4;
    c.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, cell, cell),
      Offset.zero & s,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter oldDelegate) => false;
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

class MapPainter extends CustomPainter {
  MapPainter(this.session, {this.round = true});
  final Adventure session;
  final bool round;
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.save();
    if (round) c.clipPath(Path()..addOval(rect.deflate(3)));
    c.drawRect(rect, Paint()..color = const Color(0xff7d9656));
    c.save();
    c.scale(s.width / worldSize.width, s.height / worldSize.height);
    for (final wood in session.world.woods) {
      c.drawPath(wood.path, Paint()..color = const Color(0xff315947));
    }
    c.drawPath(
      session.world.sand.path,
      Paint()..color = const Color(0xffc7b579),
    );
    for (final lake in [...session.world.lakes, session.world.river]) {
      c.drawPath(lake.path, Paint()..color = const Color(0xff3b91a0));
    }
    for (final trail in session.world.trails) {
      c.drawPath(
        trail.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 100
          ..color = const Color(0xffdac489),
      );
    }
    c.drawRect(town, Paint()..color = const Color(0xffe3d29a));
    c.restore();
    final hero = Offset(
      session.hero.position.x / worldSize.width * s.width,
      session.hero.position.y / worldSize.height * s.height,
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

class ActionButton extends StatefulWidget {
  const ActionButton({
    required this.art,
    required this.sprite,
    required this.label,
    required this.semanticLabel,
    required this.size,
    required this.onTap,
    this.onHold,
    this.icon,
    this.remaining = 0,
    this.total = 1,
    super.key,
  });
  final GameArt art;
  final String sprite, label, semanticLabel;
  final double size, remaining, total;
  final VoidCallback onTap;
  final ValueChanged<bool>? onHold;
  final IconData? icon;
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  int? pointer;
  bool pressed = false;
  void release() {
    pointer = null;
    if (pressed) {
      widget.onHold?.call(false);
      if (mounted) setState(() => pressed = false);
    }
  }

  @override
  void dispose() {
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
        setState(() => pressed = true);
        widget.onHold?.call(true);
        widget.onTap();
      },
      onPointerUp: (event) {
        if (pointer == event.pointer) release();
      },
      onPointerCancel: (event) {
        if (pointer == event.pointer) release();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size + 22,
        child: Column(
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
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
                  if (widget.icon != null)
                    Icon(widget.icon, size: widget.size * .43, color: cream),
                  if (widget.remaining > 0)
                    CustomPaint(
                      size: Size.square(widget.size),
                      painter: _CooldownPainter(
                        widget.remaining / widget.total,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              widget.label,
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
    super.key,
  });
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 55,
              height: 53,
              child: CustomPaint(painter: ControlPainter(art, sprite)),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: cream,
                shadows: [Shadow(blurRadius: 3, color: Colors.black)],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
