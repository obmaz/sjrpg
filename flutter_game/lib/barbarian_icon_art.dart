import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Canonical generated sheet order: warcries, masteries, then combat skills.
/// Effect IDs live outside the existing mage/passive sheets (100 through 129).
abstract final class BarbarianIconArt {
  static const imageKey = 'barbarian-skills';
  static const firstEffect = 100;
  static const ids = [
    'howl',
    'findPotion',
    'taunt',
    'shout',
    'findItem',
    'battleCry',
    'battleOrders',
    'grimWard',
    'warcry',
    'battleCommand',
    'swordMastery',
    'axeMastery',
    'maceMastery',
    'polearmMastery',
    'spearMastery',
    'throwingMastery',
    'increasedStamina',
    'ironSkin',
    'increasedSpeed',
    'naturalResistance',
    'bash',
    'leap',
    'doubleSwing',
    'stun',
    'doubleThrow',
    'leapAttack',
    'concentrate',
    'frenzy',
    'whirlwind',
    'berserk',
  ];
  static const _fallbacks = [
    Icons.campaign,
    Icons.science,
    Icons.record_voice_over,
    Icons.volume_up,
    Icons.search,
    Icons.graphic_eq,
    Icons.groups,
    Icons.dangerous,
    Icons.spatial_audio_off,
    Icons.military_tech,
    Icons.gavel,
    Icons.hardware,
    Icons.fitness_center,
    Icons.north,
    Icons.arrow_upward,
    Icons.near_me,
    Icons.battery_charging_full,
    Icons.shield,
    Icons.directions_run,
    Icons.wb_sunny,
    Icons.sports_martial_arts,
    Icons.flight_takeoff,
    Icons.swap_calls,
    Icons.flash_on,
    Icons.double_arrow,
    Icons.keyboard_double_arrow_up,
    Icons.center_focus_strong,
    Icons.electric_bolt,
    Icons.cyclone,
    Icons.whatshot,
  ];
  static int? effectFor(String id) {
    final index = ids.indexOf(id);
    return index < 0 ? null : firstEffect + index;
  }

  static IconData? fallbackFor(String id) {
    final index = ids.indexOf(id);
    return index < 0 ? null : _fallbacks[index];
  }

  static bool containsEffect(int effect) =>
      effect >= firstEffect && effect < firstEffect + ids.length;
  static Color color(int localIndex) => localIndex < 10
      ? const Color(0xffc9b88b)
      : localIndex < 20
      ? const Color(0xffaac0ae)
      : const Color(0xffb8c5cc);

  // Measured frame bounds from barbarian-skills.source.json. The generated
  // columns/rows are not equally spaced; a regular grid cuts several frames.
  static const _bounds = <ui.Rect>[
    ui.Rect.fromLTRB(0.0189228530, 0.0270742358, 0.1710334789, 0.2026200873),
    ui.Rect.fromLTRB(0.1812227074, 0.0270742358, 0.3340611354, 0.2026200873),
    ui.Rect.fromLTRB(0.3435225619, 0.0270742358, 0.4956331878, 0.2026200873),
    ui.Rect.fromLTRB(0.5050946143, 0.0270742358, 0.6572052402, 0.2026200873),
    ui.Rect.fromLTRB(0.6673944687, 0.0270742358, 0.8187772926, 0.2026200873),
    ui.Rect.fromLTRB(0.8296943231, 0.0270742358, 0.9818049491, 0.2026200873),
    ui.Rect.fromLTRB(0.0189228530, 0.2104803493, 0.1710334789, 0.3860262009),
    ui.Rect.fromLTRB(0.1812227074, 0.2104803493, 0.3340611354, 0.3860262009),
    ui.Rect.fromLTRB(0.3435225619, 0.2104803493, 0.4956331878, 0.3860262009),
    ui.Rect.fromLTRB(0.5050946143, 0.2104803493, 0.6572052402, 0.3860262009),
    ui.Rect.fromLTRB(0.6673944687, 0.2104803493, 0.8187772926, 0.3860262009),
    ui.Rect.fromLTRB(0.8296943231, 0.2104803493, 0.9818049491, 0.3860262009),
    ui.Rect.fromLTRB(0.0189228530, 0.3956331878, 0.1710334789, 0.5729257642),
    ui.Rect.fromLTRB(0.1812227074, 0.3956331878, 0.3340611354, 0.5729257642),
    ui.Rect.fromLTRB(0.3435225619, 0.3956331878, 0.4956331878, 0.5729257642),
    ui.Rect.fromLTRB(0.5050946143, 0.3956331878, 0.6572052402, 0.5729257642),
    ui.Rect.fromLTRB(0.6673944687, 0.3956331878, 0.8187772926, 0.5729257642),
    ui.Rect.fromLTRB(0.8296943231, 0.3956331878, 0.9818049491, 0.5729257642),
    ui.Rect.fromLTRB(0.0189228530, 0.5807860262, 0.1710334789, 0.7580786026),
    ui.Rect.fromLTRB(0.1812227074, 0.5807860262, 0.3340611354, 0.7580786026),
    ui.Rect.fromLTRB(0.3435225619, 0.5807860262, 0.4956331878, 0.7580786026),
    ui.Rect.fromLTRB(0.5050946143, 0.5807860262, 0.6572052402, 0.7580786026),
    ui.Rect.fromLTRB(0.6673944687, 0.5807860262, 0.8187772926, 0.7580786026),
    ui.Rect.fromLTRB(0.8296943231, 0.5807860262, 0.9818049491, 0.7580786026),
    ui.Rect.fromLTRB(0.0189228530, 0.7668122271, 0.1710334789, 0.9458515284),
    ui.Rect.fromLTRB(0.1812227074, 0.7668122271, 0.3340611354, 0.9458515284),
    ui.Rect.fromLTRB(0.3435225619, 0.7668122271, 0.4956331878, 0.9458515284),
    ui.Rect.fromLTRB(0.5050946143, 0.7668122271, 0.6572052402, 0.9458515284),
    ui.Rect.fromLTRB(0.6673944687, 0.7668122271, 0.8187772926, 0.9458515284),
    ui.Rect.fromLTRB(0.8296943231, 0.7668122271, 0.9818049491, 0.9458515284),
  ];

  static ui.Rect? source(ui.Image image, int localIndex) {
    if (localIndex < 0 || localIndex >= ids.length) return null;
    final unit = _bounds[localIndex];
    return ui.Rect.fromLTRB(
      unit.left * image.width,
      unit.top * image.height,
      unit.right * image.width,
      unit.bottom * image.height,
    );
  }

  static bool draw(
    ui.Canvas canvas,
    ui.Image? image,
    int localIndex,
    ui.Rect destination,
  ) {
    if (localIndex < 0 || localIndex >= ids.length || destination.isEmpty) {
      return false;
    }
    if (image != null) {
      final crop = source(image, localIndex)!;
      final scale =
          destination.width / crop.width < destination.height / crop.height
          ? destination.width / crop.width
          : destination.height / crop.height;
      final target = ui.Rect.fromCenter(
        center: destination.center,
        width: crop.width * scale,
        height: crop.height * scale,
      );
      canvas.drawImageRect(
        image,
        crop,
        target,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      return true;
    }
    final icon = _fallbacks[localIndex],
        painter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              fontSize: destination.shortestSide * .85,
              color: color(localIndex),
            ),
          ),
        );
    painter.layout();
    painter.paint(
      canvas,
      destination.center - ui.Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
    return true;
  }
}
