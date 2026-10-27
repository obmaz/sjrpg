import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/boss_attacks.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/spell_vfx.dart';
import 'package:guardian_new/stage_content.dart';

Future<Uint8List> raster(ui.Rect bounds, void Function(ui.Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.translate(128, 128);
  canvas.scale(232 / math.max(bounds.width, bounds.height));
  canvas.translate(-bounds.center.dx, -bounds.center.dy);
  paint(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  picture.dispose();
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
}

Iterable<BossAttack> patterns() sync* {
  for (final stage in WorldStage.values) {
    for (var sequence = 0; sequence < BossPower.values.length; sequence++) {
      for (final enraged in [false, true]) {
        final angle = [0.0, .63, 2.31][(stage.index + sequence) % 3];
        const origin = ui.Offset(6000.125, 4200.375);
        yield BossAttack.forStage(
          stage,
          origin,
          origin + ui.Offset(math.cos(angle), math.sin(angle)) * 180,
          sequence: sequence,
          enraged: enraged,
        );
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'boss zone snapshots stay immutable and culling keeps every original shape',
    () {
      final session = Adventure(GameArt());
      addTearDown(session.dispose);
      final source = HuntEnemy(
        session,
        'golem',
        const ui.Offset(6000, 4200),
        boss: true,
      );
      for (final attack in patterns()) {
        expect(() => attack.zones.clear(), throwsUnsupportedError);
        final originalBounds = attack.zones
            .map((zone) => zone.path.getBounds())
            .reduce((a, b) => a.expandToInclude(b));
        expect(attack.dangerBounds, originalBounds);
        final visual = BossAttackVisual(session, source, attack, impact: true);
        expect(
          visual.effectBounds,
          originalBounds
              .inflate(90)
              .expandToInclude(
                ui.Rect.fromCenter(
                  center: attack.target - const ui.Offset(0, 120),
                  width: 170,
                  height: 28,
                ),
              ),
        );
        visual.onRemove();
        for (final zone in attack.zones) {
          final before = zone.path.getBounds();
          final hit = zone.contains(zone.center);
          zone.path.reset();
          expect(zone.path.getBounds(), before);
          expect(zone.contains(zone.center), hit);
        }
        expect(attack.dangerBounds, originalBounds);
      }
    },
  );

  test(
    'boss cached warning and impact are independent of other phases and attacks',
    () async {
      final all = patterns().toList();
      for (var i = 0; i < all.length; i++) {
        final attack = all[i], other = all[(i + 1) % all.length];
        final bounds = attack.dangerBounds.inflate(100);
        final warning = await raster(
          bounds,
          (c) => attack.paintWarning(c, .37),
        );
        final impact = await raster(bounds, (c) => attack.paintImpact(c, .63));
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        other.paintWarning(canvas, .83);
        attack.paintWarning(canvas, 1);
        other.paintImpact(canvas, .19);
        attack.paintImpact(canvas, 0);
        recorder.endRecording().dispose();
        for (final zone in attack.zones) {
          zone.path
            ..reset()
            ..addRect(const ui.Rect.fromLTWH(-100000, -100000, 1, 1));
        }
        expect(
          listEquals(
            await raster(bounds, (c) => attack.paintWarning(c, .37)),
            warning,
          ),
          true,
        );
        expect(
          listEquals(
            await raster(bounds, (c) => attack.paintImpact(c, .63)),
            impact,
          ),
          true,
        );
        expect(listEquals(impact, warning), false);
      }
    },
  );

  test(
    'boss warning and impact pixels stay inside the original visual cull bounds',
    () async {
      final session = Adventure(GameArt());
      addTearDown(session.dispose);
      final source = HuntEnemy(
        session,
        'golem',
        const ui.Offset(6000, 4200),
        boss: true,
      );
      for (final attack in patterns()) {
        final visual = BossAttackVisual(session, source, attack, impact: true);
        for (final impact in [false, true]) {
          final bytes = await raster(visual.effectBounds, (canvas) {
            if (impact) {
              attack.paintImpact(canvas, .31);
            } else {
              attack.paintWarning(canvas, .87);
            }
          });
          // raster() leaves at least 12 pixels outside the supplied bounds.
          // The outermost margin detects paint that would be wrongly culled.
          for (var y = 0; y < 256; y++) {
            for (var x = 0; x < 256; x++) {
              if (x < 9 || x > 246 || y < 9 || y > 246) {
                expect(bytes[(y * 256 + x) * 4 + 3], 0);
              }
            }
          }
        }
        visual.onRemove();
      }
    },
  );

  test(
    'shared ice geometry preserves ranks, phases and per-draw transforms',
    () async {
      const bounds = ui.Rect.fromLTWH(-80, -80, 160, 160);
      Future<Uint8List> shield(int rank, double time, double angle) =>
          raster(bounds, (canvas) {
            canvas.rotate(angle);
            paintIceShield(
              canvas,
              const ui.Offset(.125, -.375),
              time,
              rank: rank,
            );
          });
      for (var rank = 1; rank <= 5; rank++) {
        for (final time in [0.0, .19, .73, 2.17]) {
          for (final angle in [0.0, .63, 2.31]) {
            final before = await shield(rank, time, angle);
            await shield(6 - rank, time + .27, angle + .41);
            expect(listEquals(await shield(rank, time, angle), before), true);
          }
        }
      }
      expect(
        listEquals(await shield(1, .19, .63), await shield(5, .19, .63)),
        false,
      );
      expect(
        listEquals(await shield(5, .19, .63), await shield(5, .73, .63)),
        false,
      );
    },
  );
}
