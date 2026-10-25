import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/spell_vfx.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'spell timelines visit every frame, clamp their ends and never sample a neighboring cell',
    () {
      for (final clip in SpellClip.values) {
        expect(clip.frameAt(-1), clip.first);
        expect(clip.frameAt(clip.duration * 2), clip.first + clip.count - 1);
        final frames = <int>{};
        for (var i = 0; i < clip.count; i++) {
          final age = clip.duration * (i + .5) / clip.count;
          final frame = clip.frameAt(age);
          frames.add(frame);
          final r = clip.source(1024, 1024, age);
          expect(r.left, greaterThan((frame % 4) * 256));
          expect(r.top, greaterThan((frame ~/ 4) * 256));
          expect(r.right, lessThan((frame % 4 + 1) * 256));
          expect(r.bottom, lessThan((frame ~/ 4 + 1) * 256));
        }
        expect(frames.length, clip.count);
      }
    },
  );
  test('burst animation freezes with gameplay and terminates once', () {
    final s = Adventure(GameArt());
    s.start(TestGame());
    addTearDown(s.dispose);
    final effect = SpellBurst(
      s,
      SpellClip.iceNova,
      const ui.Offset(6000, 4200),
      radius: 170,
    );
    expect(effect.priority, lessThan(s.hero.priority));
    effect.update(.05);
    s.pause();
    effect.update(.05);
    expect(effect.age, .05);
    s.resume();
    for (var i = 0; i < 30; i++) {
      effect.update(.05);
    }
    expect(effect.finished, true);
    expect(effect.age, SpellClip.iceNova.duration);
    effect.update(.05);
    expect(effect.age, SpellClip.iceNova.duration);
  });
  test('a meteor has one impact and one damage event after its warning', () {
    final s = Adventure(GameArt()), game = TestGame();
    s.start(game);
    addTearDown(s.dispose);
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
    final mob = s.spawnEnemy('goblin', const ui.Offset(6100, 4200))!;
    final life = mob.life.value;
    final meteor = MeteorFall(s, s.hero.body.center, mob.body.center, 5);
    for (var i = 0; i < 12; i++) {
      meteor.update(.05);
    }
    expect(mob.life.value, life);
    for (var i = 0; i < 12; i++) {
      meteor.update(.05);
    }
    expect(mob.life.value, life - 5);
    final impacts = game.added.whereType<SpellBurst>().where(
      (e) => e.clip == SpellClip.meteorImpact,
    );
    expect(impacts.length, 1);
    expect(s.impactStrength, 1.5);
    expect(s.cameraImpact.length, lessThan(1.8));
  });
  test(
    'frost nova keeps immediate damage and control while playing ice frames',
    () {
      final s = Adventure(GameArt(), heroClass: HeroClass.mage),
          game = TestGame();
      s.start(game);
      addTearDown(s.dispose);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      final mob = s.spawnEnemy('skeleton', const ui.Offset(6100, 4200))!;
      final life = mob.life.value;
      s.hero.skill();
      expect(mob.life.value, lessThan(life));
      expect(mob.stun, 2);
      expect(mob.slow, 3);
      expect(game.added.whereType<SpellBurst>().single.clip, SpellClip.iceNova);
      expect(s.hero.skillClock, greaterThan(0));
    },
  );
  test(
    'connected melee holds only the strike pose; clocks and dodge remain responsive',
    () {
      final s = Adventure(GameArt());
      s.start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      s.hero.bearing = 0;
      s.hero.slash();
      expect(s.hero.impactHold, 0);
      s.hero.attackClock = 0;
      final mob = s.spawnEnemy('goblin', const ui.Offset(6050, 4200))!;
      s.hero.slash();
      expect(s.hero.impactHold, greaterThan(0));
      expect(mob.hurt, .14);
      final pose = s.hero.swing, attack = s.hero.attackClock;
      s.hero.cooldowns['warcry'] = 3;
      s.hero.update(.01);
      expect(s.hero.swing, pose);
      expect(s.hero.attackClock, closeTo(attack - .01, .0001));
      expect(s.hero.cooldowns['warcry'], closeTo(2.99, .0001));
      s.hero.dodge();
      expect(s.hero.impactHold, 0);
      expect(s.hero.swing, 0);
      expect(s.hero.dashing, greaterThan(0));
      for (var i = 0; i < 40; i++) {
        s.tick(.05);
      }
      expect(s.cameraImpact.length, 0);
    },
  );
  for (final asset in ['fx-meteor', 'fx-ice-nova']) {
    test(
      '$asset contains sixteen distinct transparent animation frames',
      () async {
        final data = await rootBundle.load('assets/images/$asset.webp');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        expect(image.width, 1024);
        expect(image.height, 1024);
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        final hashes = <int>{};
        for (var cell = 0; cell < 16; cell++) {
          var hash = 0, visible = 0, transparent = 0;
          for (var y = 0; y < 256; y += 2) {
            for (var x = 0; x < 256; x += 2) {
              final at =
                  (((cell ~/ 4) * 256 + y) * 1024 + (cell % 4) * 256 + x) * 4;
              hash =
                  (hash * 31 +
                      rgba[at] +
                      rgba[at + 1] * 3 +
                      rgba[at + 2] * 5 +
                      rgba[at + 3] * 7) &
                  0x7fffffff;
              if (rgba[at + 3] > 25) visible++;
              if (rgba[at + 3] == 0) transparent++;
            }
          }
          expect(visible, greaterThan(100));
          expect(transparent, greaterThan(100));
          hashes.add(hash);
        }
        expect(hashes.length, 16);
        image.dispose();
      },
    );
  }
}
