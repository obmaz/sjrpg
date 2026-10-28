import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/combat_feedback.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/mage_combat_art.dart';
import 'package:guardian_new/melee_weapon_art.dart';
import 'package:guardian_new/ranked_vfx.dart';
import 'package:guardian_new/spell_vfx.dart';
import 'package:guardian_new/weapon_profiles.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'skill silhouettes keep a bounded footprint without stacked bloom',
    () async {
      final art = GameArt();
      for (final key in [
        'fx-steel-whirlwind',
        'fx-warcry',
        'fx-ice-nova',
        'fx-meteor',
      ]) {
        final codec = await ui.instantiateImageCodec(
          await File('assets/images/$key.webp').readAsBytes(),
        );
        art.images[key] = (await codec.getNextFrame()).image;
        codec.dispose();
      }
      final session = Adventure(art)..start(TestGame());
      addTearDown(() {
        session.dispose();
        art.dispose();
      });
      final painters = <String, void Function(ui.Canvas, int)>{
        for (final element in MageElement.values)
          '${element.name}-shot': (c, r) => MageCombatArt().projectile(
            c,
            ui.Offset.zero,
            -.2,
            .17,
            element,
            r,
          ),
        for (final element in MageElement.values)
          '${element.name}-impact': (c, r) =>
              MageCombatArt().impact(c, ui.Offset.zero, .24, 70, element, r),
        'warcry': (c, r) => (SpellBurst(
          session,
          SpellClip.warcry,
          ui.Offset.zero,
          radius: 70,
          rank: r,
        )..age = .23).render(c),
        'whirlwind': (c, r) =>
            paintSteelWhirlwind(art, c, ui.Offset.zero, .22, r),
        'ice-armor': (c, r) => paintIceShield(c, ui.Offset.zero, .42, rank: r),
        'frenzy': (c, r) =>
            paintBattleAura(c, ui.Offset.zero, .42, frenzy: true, rank: r),
        'sword': (c, r) => paintMeleeWeaponSwing(
          c,
          ui.Offset.zero,
          meleeWeaponProfiles['shortsword']!,
          phase: .3,
          bearing: -.15,
          reach: 90,
          pose: 0,
          rank: r,
          finisher: true,
        ),
        'heavy-contact': (c, r) {
          final effect = ImpactParticles(
            AcceptedImpact(ui.Offset.zero, -.2, ImpactKind.heavy, rank: r),
            onFinished: () {},
          );
          effect.particles.update(.08);
          effect.particles.render(c);
        },
      };
      final baselineExport = Platform.environment['VFX_BASELINE_EXPORT'];
      final baseline = baselineExport == null
          ? jsonDecode(
                  await File(
                    'test/fixtures/vfx_clutter_before_simple.json',
                  ).readAsString(),
                )
                as Map
          : const {};
      final measurements = <String, Object>{};
      Future<Uint8List> projectilePixels(void Function(ui.Canvas) draw) async {
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        canvas.translate(96, 92);
        draw(canvas);
        final picture = recorder.endRecording();
        final image = await picture.toImage(192, 144);
        picture.dispose();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final result = Uint8List.fromList(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        image.dispose();
        return result;
      }

      if (baselineExport == null) {
        for (final element in MageElement.values) {
          final bolt = ArcaneBolt(
            session,
            ui.Offset.zero,
            0,
            1,
            element: element.name,
            rank: 3,
          )..remaining = .71;
          expect(
            await projectilePixels(bolt.render),
            orderedEquals(
              await projectilePixels(
                (canvas) => MageCombatArt().projectile(
                  canvas,
                  const ui.Offset(0, -14),
                  0,
                  .88 - bolt.remaining,
                  element,
                  3,
                ),
              ),
            ),
            reason:
                '${element.name} has one core, without a second atlas overlay',
          );
        }
      }
      final sheetRecorder = ui.PictureRecorder(),
          sheet = ui.Canvas(sheetRecorder);
      sheet.drawColor(const ui.Color(0xff20382d), ui.BlendMode.src);
      var row = 0;
      for (final entry in painters.entries) {
        for (var column = 0; column < 3; column++) {
          final rank = [1, 3, 5][column];
          final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
          canvas.translate(96, 92);
          entry.value(canvas, rank);
          final picture = recorder.endRecording();
          final image = await picture.toImage(192, 144);
          picture.dispose();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final pixels = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          var alpha = 0, strong = 0;
          for (var i = 3; i < pixels.length; i += 4) {
            alpha += pixels[i];
            if (pixels[i] > 100) strong++;
          }
          final id = '${entry.key}-$rank';
          measurements[id] = {'alpha': alpha, 'strongPixels': strong};
          expect(alpha, greaterThan(0), reason: '$id remains visible');
          if (baselineExport == null) {
            expect(
              alpha,
              lessThan((baseline[id]['alpha'] as num) * .85),
              reason: '$id removes overlapping glow, not its action silhouette',
            );
          }
          sheet.drawImage(
            image,
            ui.Offset(column * 192.0, row * 144.0),
            ui.Paint(),
          );
          image.dispose();
        }
        row++;
      }
      if (baselineExport != null) {
        await File(baselineExport).writeAsString(
          const JsonEncoder.withIndent('  ').convert(measurements),
        );
      }
      final proofDir = Platform.environment['SIMPLE_VFX_PROOF_DIR'];
      final picture = sheetRecorder.endRecording();
      if (proofDir != null) {
        await Directory(proofDir).create(recursive: true);
        final image = await picture.toImage(576, row * 144);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$proofDir/skill-contact-sheet.png').writeAsBytes(
          Uint8List.view(png!.buffer, png.offsetInBytes, png.lengthInBytes),
        );
        image.dispose();
        await File('$proofDir/measurements.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(measurements),
        );
      }
      picture.dispose();
    },
  );
}
