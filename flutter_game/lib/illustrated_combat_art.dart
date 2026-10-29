import 'dart:math' as math;
import 'dart:ui' as ui;

import 'effect_atlas.dart';

enum CombatIllustration { blade, cold, lightning }

/// Generated keyframes enrich the live weapon paths and elemental particles.
/// At most two texture samples are blended; this never owns a gameplay clock.
abstract final class IllustratedCombatArt {
  static const imageKey = 'combat-illustrations';
  static final _body = ui.RRect.fromRectAndRadius(
    const ui.Rect.fromLTRB(-30, -117, 30, -5),
    const ui.Radius.circular(11),
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
    final phase = t * 3, index = phase.floor(), blend = phase - phase.floor();
    final alpha =
        opacity.clamp(0.0, 1.0) *
        math.min(1.0, t * 14) *
        math.min(1.0, (1 - t) / .25);
    final row = family.index * 4;
    final side = r * 2.5;
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
      final inset = atlas.images[imageKey]!.width / 4 * .04;
      atlas.draw(
        canvas,
        imageKey,
        row + index,
        rect,
        inset: inset,
        opacity: alpha * (1 - blend),
        colorFilter: null,
      );
      if (blend > 0 && index < 3) {
        atlas.draw(
          canvas,
          imageKey,
          row + index + 1,
          rect,
          inset: inset,
          opacity: alpha * blend,
          colorFilter: null,
        );
      }
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
      14,
      ui.Rect.fromCircle(center: center, radius: r),
      inset: image.width / 4 * .12,
      opacity: math.sin(progress * math.pi) * .85,
    );
  }
}
