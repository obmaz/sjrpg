import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_feedback.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/ranked_vfx.dart';
import 'package:guardian_new/sorceress_vfx.dart';
import 'package:guardian_new/spell_vfx.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'hero-owned whirlwind is not painted a second time by its lifecycle component',
    () async {
      final session = Adventure(GameArt())..start(TestGame());
      addTearDown(session.dispose);
      final component = SteelWhirlwind(
        session,
        session.hero,
        rank: 5,
        duration: 1,
        renderWithHero: true,
      )..age = .3;
      final recorder = ui.PictureRecorder();
      component.render(ui.Canvas(recorder));
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 64);
      picture.dispose();
      try {
        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(pixels!.buffer.asUint8List().every((v) => v == 0), true);
      } finally {
        image.dispose();
      }
    },
  );

  test(
    'original rank milestones change the rendered budget for ten major skills',
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
        'frozenArmor',
        'frenzy',
        'chainLightning',
        'meteor',
        'charge',
        'crushingBlow',
        'seismicSlam',
      ]) {
        final hashes = <int>{};
        final brightness = <int>[];
        for (final rank
            in ([
                  'frostNova',
                  'frozenArmor',
                  'chainLightning',
                  'meteor',
                ].contains(id)
                ? [1, 5, 10, 15, 20]
                : [1, 2, 3, 4, 5])) {
          final rec = ui.PictureRecorder(), canvas = ui.Canvas(rec);
          const at = ui.Offset(210, 270);
          switch (id) {
            case 'whirlwind':
              paintSteelWhirlwind(art, canvas, at, .22, rank);
            case 'warcry':
              final v = SpellBurst(
                rendered,
                id == 'warcry' ? SpellClip.warcry : SpellClip.iceNova,
                ui.Offset.zero,
                radius: 170,
                rank: rank,
              )..age = .23;
              canvas.translate(at.dx, at.dy);
              v.render(canvas);
            case 'frostNova':
              SorceressVfx.ground(
                canvas,
                id,
                at,
                time: .42,
                progress: .42,
                radius: 90,
                rank: rank,
              );
            case 'frozenArmor':
              SorceressVfx.buff(canvas, id, at, time: .42, rank: rank);
            case 'frenzy':
              paintBattleAura(canvas, at, .42, frenzy: true, rank: rank);
            case 'chainLightning':
              SorceressVfx.beam(
                canvas,
                id,
                [
                  const ui.Offset(90, 250),
                  const ui.Offset(180, 220),
                  const ui.Offset(300, 270),
                ],
                time: .12,
                rank: rank,
              );
            case 'meteor':
              SorceressVfx.impact(
                canvas,
                id,
                at,
                progress: .35,
                radius: 100,
                rank: rank,
              );
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
        expect(
          hashes.length,
          5,
          reason: '$id must change across invested rank milestones',
        );
        expect(
          brightness.last,
          greaterThan(brightness.first),
          reason: '$id final rank should have a stronger bounded visual budget',
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
