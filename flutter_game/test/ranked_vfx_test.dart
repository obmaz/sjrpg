import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/combat_feedback.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/ranked_vfx.dart';
import 'package:guardian_new/spell_vfx.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'each point changes the rendered effect for the ten major skills',
    () async {
      final art = await GameArt.load(),
          s = Adventure(GameArt())..start(TestGame());
      addTearDown(() {
        s.dispose();
        for (final shader in art.materials) {
          shader.dispose();
        }
        for (final im in art.images.values) {
          im.dispose();
        }
      });
      final rendered = Adventure(art)..start(TestGame());
      addTearDown(rendered.dispose);
      for (final id in [
        'whirlwind',
        'warcry',
        'frostNova',
        'iceArmor',
        'frenzy',
        'chainLightning',
        'meteor',
        'charge',
        'crushingBlow',
        'seismicSlam',
      ]) {
        final hashes = <int>{};
        final brightness = <int>[];
        for (var rank = 1; rank <= 5; rank++) {
          final rec = ui.PictureRecorder(), canvas = ui.Canvas(rec);
          const at = ui.Offset(210, 270);
          switch (id) {
            case 'whirlwind':
              paintSteelWhirlwind(art, canvas, at, .22, rank);
            case 'warcry':
            case 'frostNova':
              final v = SpellBurst(
                rendered,
                id == 'warcry' ? SpellClip.warcry : SpellClip.iceNova,
                ui.Offset.zero,
                radius: 170,
                rank: rank,
              )..age = .23;
              canvas.translate(at.dx, at.dy);
              v.render(canvas);
            case 'iceArmor':
              paintIceShield(canvas, at, .42, rank: rank);
            case 'frenzy':
              paintBattleAura(canvas, at, .42, frenzy: true, rank: rank);
            case 'chainLightning':
              final v = LightningTrace(rendered, [
                const ui.Offset(90, 250),
                const ui.Offset(180, 220),
                const ui.Offset(300, 270),
              ], rank: rank)..age = .12;
              v.render(canvas);
            case 'meteor':
              final v = MeteorFall(
                rendered,
                const ui.Offset(210, 270),
                at,
                1,
                rank: rank,
              )..age = .35;
              v.render(canvas);
            case 'charge':
              final v = ImpactParticles(
                AcceptedImpact(ui.Offset.zero, 0, ImpactKind.heavy, rank: rank),
                onFinished: () {},
              );
              v.particles.update(.08);
              canvas.translate(at.dx, at.dy);
              v.particles.render(canvas);
            case 'crushingBlow':
            case 'seismicSlam':
              canvas.translate(at.dx, at.dy);
              paintGroundStrike(
                canvas,
                .28,
                rank,
                directional: id == 'crushingBlow',
              );
          }
          final pic = rec.endRecording(), image = await pic.toImage(420, 440);
          pic.dispose();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          hashes.add(Object.hashAll(data));
          brightness.add(
            [
              for (var i = 3; i < data.length; i += 4) data[i],
            ].fold(0, (a, b) => a + b),
          );
          image.dispose();
        }
        expect(hashes.length, 5, reason: '$id must change at every point');
        expect(
          brightness.last,
          greaterThan(brightness.first),
          reason: '$id rank5 should be visibly stronger',
        );
      }
      for (final rank in [1, 3, 5]) {
        final frames = {
          for (var i = 0; i < 12; i++) steelWhirlwindFrame(rank, (i + .5) / 24),
        };
        expect(frames.length, 12);
        expect(
          frames.first,
          rank == 1
              ? 0
              : rank == 3
              ? 12
              : 24,
        );
      }
    },
  );
}
