import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/level_up_effect.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/stage_content.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'non-gory remains retain species silhouettes and generated level-up frames render',
    () async {
      final art = await GameArt.loadMenu();
      addTearDown(art.dispose);
      const kinds = [
        'goblin',
        'wolf',
        'skeleton',
        'boar',
        'viper',
        'scorpion',
        'mummy',
        'drone',
      ];
      await art.ensureStage(
        WorldStage.forest,
        heroClass: HeroClass.warrior,
        enemyKinds: kinds,
      );
      final game = TestGame(), session = Adventure(art)..start(game);
      addTearDown(session.dispose);
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xff36473b), ui.BlendMode.src);
      final fingerprints = <int>{};
      for (var i = 0; i < kinds.length; i++) {
        final before = game.added.length;
        for (
          var attempt = 0;
          attempt < 200 && game.added.length == before;
          attempt++
        ) {
          final enemy = HuntEnemy(session, kinds[i], session.hero.body.center);
          enemy.life.remove(enemy.life.max);
          enemy.rewarded = true;
          session.barbarianUtilities.recordCorpse(enemy);
        }
        expect(game.added.length, before + 1);
        final marker = game.added.last;
        final r = ui.PictureRecorder(), c = ui.Canvas(r);
        c.translate(64, 64);
        marker.render(c);
        final p = r.endRecording(), image = await p.toImage(128, 128);
        p.dispose();
        final data = (await image.toByteData())!.buffer.asUint8List();
        expect(data.where((v) => v != 0).length, greaterThan(100));
        fingerprints.add(Object.hashAll(data));
        canvas.drawImage(
          image,
          ui.Offset((i % 4) * 160 + 16, (i ~/ 4) * 145 + 8),
          ui.Paint(),
        );
        art.text(
          canvas,
          kinds[i],
          ui.Offset((i % 4) * 160 + 80, (i ~/ 4) * 145 + 127),
          size: 14,
          color: const ui.Color(0xfff1e6c6),
        );
        image.dispose();
      }
      expect(fingerprints.length, kinds.length);
      expect(art.images['fx-level-up'], isNotNull);
      for (var i = 0; i < 4; i++) {
        final effect = LevelUpEffect(session)..age = (i + 1) * .3;
        canvas.save();
        canvas.translate(80 + i * 160.0, 495);
        effect.render(canvas);
        canvas.restore();
      }
      final picture = recorder.endRecording(),
          image = await picture.toImage(640, 540);
      picture.dispose();
      final export = Platform.environment['SJRPG_CORPSE_PROOF'];
      if (export != null) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(export).writeAsBytes(png!.buffer.asUint8List());
      }
      image.dispose();
    },
  );
}
