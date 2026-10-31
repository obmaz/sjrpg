import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'effect_visibility.dart';
import 'natural_object_art.dart';

class DestructibleChest extends GameComponent {
  DestructibleChest(this.session, this.index) {
    final body = session.world.chestBody(index);
    position = Vector2(body.left, body.top);
    size = Vector2(body.width, body.height);
    session.registerChest(this);
  }
  final Adventure session;
  final int index;
  RectangleHitbox? _hitbox;
  ui.Picture? _closedPicture, _brokenPicture;
  bool get broken => session.openedChests.contains(index);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (!broken) {
      _hitbox = RectangleHitbox(
        size: size,
        collisionType: CollisionType.passive,
      );
      await add(_hitbox!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (broken && _hitbox != null) {
      _hitbox!.removeFromParent();
      _hitbox = null;
    }
  }

  @override
  bool get isVisible =>
      !hasGameRef ||
      gameRef.camera.visibleWorldRect.overlaps(
        session.world.chestBody(index).inflate(70),
      );

  ui.Picture _record(bool opened) {
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    final at = session.stageChestLocations[index] - position.toOffset();
    canvas.translate(at.dx, at.dy);
    final paint = ui.Paint();
    canvas.drawOval(
      const ui.Rect.fromLTWH(-25, 3, 50, 14),
      paint..color = const ui.Color(0x550a201a),
    );
    final image = session.art.images['quarter-props'];
    if (image != null) {
      NaturalObjectArt.draw(
        canvas,
        image,
        opened ? 1 : 0,
        const ui.Offset(0, 12),
        opened ? 36 : 58,
        maxWidth: 76,
      );
    }
    return recorder.endRecording();
  }

  @override
  void render(ui.Canvas canvas) {
    if (session.disposed || isRemoving || !isVisible) return;
    super.render(canvas);
    if (broken) {
      canvas.drawPicture(_brokenPicture ??= _record(true));
    } else {
      canvas.drawPicture(_closedPicture ??= _record(false));
    }
  }

  void releasePictures() {
    _closedPicture?.dispose();
    _brokenPicture?.dispose();
    _closedPicture = null;
    _brokenPicture = null;
  }

  @override
  void onRemove() {
    releasePictures();
    session.unregisterChest(this);
    super.onRemove();
  }
}

class ChestFragments extends GameComponent with EffectVisibility {
  ChestFragments(this.session, ui.Offset at) {
    position = Vector2(at.dx - 90, at.dy - 90);
    size = Vector2.all(180);
  }
  final Adventure session;
  final _paint = ui.Paint();
  double age = 0;
  @override
  ui.Rect get effectBounds => position.toOffset() & const ui.Size(180, 180);

  @override
  void update(double dt) {
    if (!session.active) return;
    age += math.min(dt, .05);
    if (age >= .55) removeFromParent();
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final t = (age / .55).clamp(0.0, 1.0);
    final center = const ui.Offset(90, 90);
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi * 2 / 10 + .3;
      final spread = 65 * t * (1.4 - t);
      final at =
          center +
          ui.Offset(
            math.cos(angle) * spread,
            math.sin(angle) * spread * .5 - math.sin(t * math.pi) * 32,
          );
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle + t * 5);
      canvas.drawRect(
        ui.Rect.fromCenter(
          center: ui.Offset.zero,
          width: i.isEven ? 12 : 7,
          height: i.isEven ? 5 : 4,
        ),
        _paint
          ..color =
              (i.isEven
                      ? const ui.Color(0xffb48a4a)
                      : const ui.Color(0xffffd477))
                  .withValues(alpha: 1 - t),
      );
      canvas.restore();
    }
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: center,
        width: 18 + t * 90,
        height: 8 + t * 35,
      ),
      _paint
        ..color = const ui.Color(0xfff6d998).withValues(alpha: (1 - t) * .3)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - t) + 1,
    );
    _paint.style = ui.PaintingStyle.fill;
  }
}
