import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Original generated cold, lightning and fire plaques (effect IDs 200–229).
abstract final class SorceressIconArt {
  static const imageKey = 'sorceress-skills';
  static const firstEffect = 200;
  static const ids = [
    'iceBolt',
    'frozenArmor',
    'frostNova',
    'iceBlast',
    'shiverArmor',
    'glacialSpike',
    'blizzard',
    'chillingArmor',
    'frozenOrb',
    'coldMastery',
    'chargedBolt',
    'staticField',
    'telekinesis',
    'nova',
    'lightning',
    'chainLightning',
    'blink',
    'thunderStorm',
    'energyShield',
    'lightningMastery',
    'firebolt',
    'warmth',
    'inferno',
    'blaze',
    'fireball',
    'firewall',
    'enchant',
    'meteor',
    'hydra',
    'fireMastery',
  ];
  static const _fallbacks = [
    Icons.ac_unit,
    Icons.shield,
    Icons.blur_circular,
    Icons.severe_cold,
    Icons.security,
    Icons.terrain,
    Icons.cloudy_snowing,
    Icons.gpp_good,
    Icons.public,
    Icons.diamond,
    Icons.electric_bolt,
    Icons.radar,
    Icons.pan_tool,
    Icons.flare,
    Icons.bolt,
    Icons.polyline,
    Icons.meeting_room,
    Icons.thunderstorm,
    Icons.energy_savings_leaf,
    Icons.offline_bolt,
    Icons.local_fire_department,
    Icons.heat_pump,
    Icons.air,
    Icons.directions_walk,
    Icons.whatshot,
    Icons.fireplace,
    Icons.auto_fix_high,
    Icons.south_east,
    Icons.pest_control,
    Icons.workspace_premium,
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
      ? const Color(0xffa8d9ef)
      : localIndex < 20
      ? const Color(0xffc3b8ed)
      : const Color(0xffedaa74);

  // Exact packed alpha bounds, measured above 16/255. See provenance JSON.
  static const _bounds = <ui.Rect>[
    ui.Rect.fromLTRB(0.0066964286, 0.0142857143, 0.1599702381, 0.1857142857),
    ui.Rect.fromLTRB(0.1733630952, 0.0142857143, 0.3266369048, 0.1848214286),
    ui.Rect.fromLTRB(0.3400297619, 0.0142857143, 0.4933035714, 0.1857142857),
    ui.Rect.fromLTRB(0.5066964286, 0.0151785714, 0.6599702381, 0.1848214286),
    ui.Rect.fromLTRB(0.6733630952, 0.0142857143, 0.8266369048, 0.1848214286),
    ui.Rect.fromLTRB(0.8400297619, 0.0142857143, 0.9933035714, 0.1857142857),
    ui.Rect.fromLTRB(0.0066964286, 0.2133928571, 0.1599702381, 0.3857142857),
    ui.Rect.fromLTRB(0.1733630952, 0.2133928571, 0.3266369048, 0.3857142857),
    ui.Rect.fromLTRB(0.3400297619, 0.2133928571, 0.4933035714, 0.3857142857),
    ui.Rect.fromLTRB(0.5066964286, 0.2142857143, 0.6599702381, 0.3857142857),
    ui.Rect.fromLTRB(0.6733630952, 0.2142857143, 0.8266369048, 0.3857142857),
    ui.Rect.fromLTRB(0.8400297619, 0.2133928571, 0.9933035714, 0.3857142857),
    ui.Rect.fromLTRB(0.0066964286, 0.4133928571, 0.1599702381, 0.5857142857),
    ui.Rect.fromLTRB(0.1733630952, 0.4142857143, 0.3266369048, 0.5848214286),
    ui.Rect.fromLTRB(0.3400297619, 0.4142857143, 0.4933035714, 0.5848214286),
    ui.Rect.fromLTRB(0.5066964286, 0.4142857143, 0.6599702381, 0.5857142857),
    ui.Rect.fromLTRB(0.6733630952, 0.4142857143, 0.8266369048, 0.5857142857),
    ui.Rect.fromLTRB(0.8400297619, 0.4142857143, 0.9933035714, 0.5848214286),
    ui.Rect.fromLTRB(0.0066964286, 0.6169642857, 0.1599702381, 0.7830357143),
    ui.Rect.fromLTRB(0.1733630952, 0.6169642857, 0.3266369048, 0.7821428571),
    ui.Rect.fromLTRB(0.3400297619, 0.6160714286, 0.4933035714, 0.7830357143),
    ui.Rect.fromLTRB(0.5066964286, 0.6169642857, 0.6599702381, 0.7821428571),
    ui.Rect.fromLTRB(0.6733630952, 0.6169642857, 0.8266369048, 0.7821428571),
    ui.Rect.fromLTRB(0.8400297619, 0.6169642857, 0.9933035714, 0.7830357143),
    ui.Rect.fromLTRB(0.0066964286, 0.8142857143, 0.1599702381, 0.9848214286),
    ui.Rect.fromLTRB(0.1733630952, 0.8142857143, 0.3266369048, 0.9839285714),
    ui.Rect.fromLTRB(0.3407738095, 0.8142857143, 0.4925595238, 0.9848214286),
    ui.Rect.fromLTRB(0.5066964286, 0.8160714286, 0.6599702381, 0.9839285714),
    ui.Rect.fromLTRB(0.6726190476, 0.8151785714, 0.8266369048, 0.9839285714),
    ui.Rect.fromLTRB(0.8400297619, 0.8142857143, 0.9933035714, 0.9839285714),
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
    ui.Rect destination, {
    bool framed = true,
  }) {
    if (localIndex < 0 || localIndex >= ids.length || destination.isEmpty) {
      return false;
    }
    if (image != null) {
      final plate = source(image, localIndex)!;
      final crop = framed ? plate : plate.deflate(plate.shortestSide * .09);
      final widthScale = destination.width / crop.width;
      final heightScale = destination.height / crop.height;
      // Plaques have slightly different painted proportions. Preserve the
      // whole frame in the tree, but fill the circle without flat letterboxing.
      final scale = framed
          ? (widthScale < heightScale ? widthScale : heightScale)
          : (widthScale > heightScale ? widthScale : heightScale);
      final target = ui.Rect.fromCenter(
        center: destination.center,
        width: crop.width * scale,
        height: crop.height * scale,
      );
      canvas.save();
      if (!framed) canvas.clipPath(ui.Path()..addOval(destination));
      canvas.drawImageRect(
        image,
        crop,
        target,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      canvas.restore();
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
