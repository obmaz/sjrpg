import 'dart:math' as math;
import 'dart:ui' as ui;

import 'effect_atlas.dart';

enum CombatIllustration { blade, cold, lightning, fire }

/// Generated keyframes enrich the live weapon paths and elemental particles.
/// At most two texture samples are blended; this never owns a gameplay clock.
abstract final class IllustratedCombatArt {
  static const imageKey = 'combat-illustrations';
  static final _body = ui.RRect.fromRectAndRadius(
    const ui.Rect.fromLTRB(-15, -64, 15, -8),
    const ui.Radius.circular(10),
  );
  static final _clip = ui.Path();

  static CombatIllustration family(String id) {
    if (const {
      'iceBolt',
      'frozenArmor',
      'frostNova',
      'iceBlast',
      'shiverArmor',
      'glacialSpike',
      'blizzard',
      'chillingArmor',
      'frozenOrb',
    }.contains(id)) {
      return CombatIllustration.cold;
    }
    if (const {
      'chargedBolt',
      'staticField',
      'telekinesis',
      'nova',
      'lightning',
      'chainLightning',
      'blink',
      'thunderStorm',
      'energyShield',
    }.contains(id)) {
      return CombatIllustration.lightning;
    }
    if (const {
      'firebolt',
      'fireball',
      'inferno',
      'meteor',
      'firewall',
      'blaze',
      'hydra',
      'enchant',
    }.contains(id)) {
      return CombatIllustration.fire;
    }
    return CombatIllustration.blade;
  }

  static bool sequence(
    EffectAtlas atlas,
    ui.Canvas canvas,
    CombatIllustration family,
    ui.Offset center, {
    required double progress,
    double radius = 72,
    double bearing = 0,
    double opacity = .88,
    bool steel = false,
    bool protectBody = false,
  }) {
    if (!progress.isFinite ||
        progress < 0 ||
        progress >= 1 ||
        !radius.isFinite ||
        radius <= 0 ||
        !bearing.isFinite ||
        !center.dx.isFinite ||
        !center.dy.isFinite ||
        !opacity.isFinite ||
        !atlas.images.containsKey(imageKey)) {
      return false;
    }
    final r = radius.clamp(16.0, 160.0), t = progress;
    final alpha =
        opacity.clamp(0.0, 1.0) *
        math.min(1.0, t * 14) *
        math.min(1.0, (1 - t) / .25);
    // An authored effect expands without rotating its ground projection.
    // Two closely spaced scales form a short luminous afterimage.
    final growth = .55 + .5 * (1 - math.pow(1 - t, 2));
    final side = r * 3.15 * growth;
    canvas.save();
    try {
      canvas.translate(center.dx, center.dy);
      if (protectBody) {
        _clip
          ..reset()
          ..fillType = ui.PathFillType.evenOdd
          ..addRect(ui.Rect.fromCircle(center: ui.Offset.zero, radius: side))
          ..addRRect(_body);
        canvas.clipPath(_clip);
      }
      // These authored ellipses already carry the camera's ground projection.
      // Turning the image by the facing angle would make the ground ring stand up.
      final rect = ui.Rect.fromCenter(
        center: ui.Offset.zero,
        width: side,
        height: side,
      );
      atlas.draw(
        canvas,
        imageKey,
        family.index,
        rect.inflate(side * .025),
        columns: 2,
        rows: 2,
        inset: 0,
        opacity: alpha * .18,
      );
      atlas.draw(
        canvas,
        imageKey,
        family.index,
        rect,
        columns: 2,
        rows: 2,
        inset: 0,
        opacity: alpha * .86,
      );
    } finally {
      canvas.restore();
    }
    return true;
  }

  static bool contact(
    EffectAtlas atlas,
    ui.Canvas canvas,
    ui.Offset center,
    double progress, {
    double radius = 42,
  }) {
    if (!progress.isFinite ||
        progress <= 0 ||
        progress >= 1 ||
        !radius.isFinite ||
        radius <= 0 ||
        !center.dx.isFinite ||
        !center.dy.isFinite) {
      return false;
    }
    final image = atlas.images[imageKey];
    if (image == null) return false;
    final r = radius.clamp(12.0, 100.0) * (.65 + progress * .35);
    return atlas.draw(
      canvas,
      imageKey,
      CombatIllustration.fire.index,
      ui.Rect.fromCircle(center: center, radius: r),
      columns: 2,
      rows: 2,
      inset: 0,
      opacity: math.sin(progress * math.pi) * .85,
    );
  }
}
