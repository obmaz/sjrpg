import 'dart:ui' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure s;
  late TestGame game;
  setUp(() {
    s = Adventure(GameArt());
    game = TestGame();
    s.start(game);
  });
  tearDown(() => s.dispose());
  test(
    'cultists telegraph a locked aim, freeze while paused and can be interrupted',
    () {
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      final caster = s.spawnEnemy('cultist', const Offset(6220, 4200))!;
      for (var i = 0; i < 30 && caster.windup == 0; i++) {
        caster.update(.05);
      }
      expect(caster.windup, greaterThan(0));
      final locked = caster.slamTarget, windup = caster.windup;
      s.pause();
      caster.update(.3);
      expect(caster.windup, windup);
      s.resume();
      s.hero.position.y += 70;
      for (var i = 0; i < 15; i++) {
        caster.update(.05);
      }
      final bolt = game.added.whereType<ShadowBolt>().single;
      expect(bolt.direction.dy, closeTo(0, .001));
      expect(bolt.direction.dx, closeTo(-1, .001));
      expect(locked, isNot(s.hero.body.center));
      final hp = s.progress.hp;
      for (var i = 0; i < 45; i++) {
        bolt.update(.05);
      }
      expect(s.progress.hp, hp);
      caster.windup = .4;
      caster.slamTarget = s.hero.body.center;
      caster.stun = 1;
      caster.update(.05);
      expect(caster.windup, 0);
      expect(caster.slamTarget, null);
      expect(game.added.whereType<ShadowBolt>().length, 1);
    },
  );
  for (final technological in [false, true]) {
    test(
      'hostile projectile $technological hits once and cannot tunnel through a tree',
      () {
        s.hero.position.setValues(6000, 4200);
        final shot = ShadowBolt(
          s,
          s.hero.body.center - const Offset(140, 0),
          0,
          technological: technological,
        );
        final hp = s.progress.hp;
        for (var i = 0; i < 20; i++) {
          shot.update(.05);
        }
        expect(shot.resolved, true);
        expect(s.progress.hp, lessThan(hp));
        final after = s.progress.hp;
        s.hero.invulnerable = 0;
        shot.update(.05);
        expect(s.progress.hp, after);
        final tree = s.world.props.firstWhere(
          (p) =>
              p.kind == 'tree' &&
              !s.world.blocked(
                Rect.fromLTWH(p.body.left - 70, p.body.center.dy - 11, 24, 22),
              ) &&
              !s.world.blocked(
                Rect.fromLTWH(p.body.right + 30, p.body.center.dy - 11, 24, 22),
              ),
        );
        s.hero.position.setValues(
          tree.body.right + 30,
          tree.body.center.dy - 11,
        );
        final blocked = ShadowBolt(
          s,
          Offset(tree.body.left - 40, tree.body.center.dy),
          0,
          technological: technological,
        );
        for (var i = 0; i < 40; i++) {
          blocked.update(.05);
        }
        expect(blocked.resolved, true);
        expect(s.progress.hp, after);
      },
    );
  }
  test(
    'ruins add their ranged population while the forest opening stays ordinary',
    () {
      expect(s.mobs.any((m) => m.kind == 'cultist'), false);
      s.progress.gainXp(140);
      s.hero.position.setValues(10500 * worldScale, 7200 * worldScale);
      s.spawnPack();
      expect(s.mobs.any((m) => m.kind == 'cultist'), true);
      for (var i = 0; i < 20; i++) {
        s.spawnPack();
      }
      expect(s.living, lessThanOrEqualTo(40));
    },
  );
  test(
    'the fountain heals after combat and potion rewards do not flood each wave',
    () {
      s.progress.hp = 80;
      s.syncLife();
      s.tick(1);
      expect(s.progress.hp, 84);
      s.hurtHero(20);
      final hurt = s.progress.hp;
      s.tick(1);
      expect(s.progress.hp, hurt);
      s.progress.kills = 35;
      s.hit(s.mobs.firstWhere((m) => !m.isDead), 99999, Offset.zero);
      expect(s.progress.healingPotions, 4);
      expect(s.progress.energyPotions, 2);
      s.progress.kills = 47;
      s.hit(s.mobs.firstWhere((m) => !m.isDead), 99999, Offset.zero);
      expect(s.progress.healingPotions, 4);
      expect(s.progress.energyPotions, 3);
    },
  );
  test('moving aim assistance does not steer the joystick direction', () {
    final mage = Adventure(GameArt(), heroClass: HeroClass.mage);
    mage.start(TestGame());
    addTearDown(mage.dispose);
    mage.mobs.clear();
    mage.hero.position.setValues(6000, 4200);
    mage.spawnEnemy('skeleton', const Offset(5880, 4200));
    mage.hero.bearing = 0;
    mage.hero.velocity.setValues(270, 0);
    mage.hero.slash();
    final shot = (mage.game as TestGame).added.whereType<ArcaneBolt>().single;
    expect(shot.direction.dx, closeTo(-1, .001));
    expect(mage.hero.bearing, 0);
    expect(mage.hero.velocity.x, 270);
  });
}
