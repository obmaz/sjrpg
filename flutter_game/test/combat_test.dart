import 'support/test_game.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/world_model.dart' show questSites, worldScale;
import 'package:guardian_new/game_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Adventure session;
  late TestGame game;
  setUp(() {
    session = Adventure(GameArt());
    game = TestGame();
    session.start(game);
  });
  tearDown(() => session.dispose());
  test(
    'pausing clears held attacks and blocks skills, rewards and simulation time',
    () {
      session.holdAttack('touch', true);
      session.pause();
      session.hero.slash();
      session.hero.skill();
      session.hero.dodge();
      session.tick(1);
      expect(session.attackSources, isEmpty);
      expect(session.hero.strikes, 0);
      expect(session.hero.skillClock, 0);
      expect(session.elapsed, 0);
      expect(game.paused, true);
      session.resume();
      expect(game.paused, false);
    },
  );
  test(
    'a held attack repeats at its cooldown and a dead enemy rewards only once',
    () {
      final mob = session.mobs.first;
      final kills = session.progress.kills;
      session.hit(mob, 999, Offset.zero);
      session.hit(mob, 999, Offset.zero);
      expect(session.progress.kills, kills + 1);
      expect(session.progress.gold, 8);
      session.holdAttack('touch', true);
      for (var i = 0; i < 30; i++) {
        session.hero.update(.05);
      }
      expect(session.hero.strikes, greaterThanOrEqualTo(4));
      expect(session.hero.strikes, lessThanOrEqualTo(5));
    },
  );
  test(
    'rolling locks its direction and resumes held attacks after landing',
    () {
      final hero = session.hero;
      hero.position.setValues(3840, 3400);
      final before = hero.position.clone(), direction = hero.bearing;
      final energy = session.progress.energy;
      session.holdAttack('touch', true);
      hero.dodge();
      hero.bearing = 0;
      hero.slash();
      hero.skill();
      expect(hero.strikes, 0);
      expect(hero.skillClock, 0);
      expect(session.progress.energy, energy);
      for (var i = 0; i < 4; i++) {
        hero.update(.05);
      }
      expect(hero.rollBearing, direction);
      expect(hero.position.x, closeTo(before.x, .001));
      expect(hero.position.y, greaterThan(before.y));
      expect(hero.strikes, 0);
      for (var i = 0; i < 3; i++) {
        hero.update(.05);
      }
      expect(hero.strikes, greaterThan(0));
    },
  );
  test(
    'a fatal hit takes priority over the sanctuary heal and further rewards',
    () {
      session.progress.hp = 1;
      session.hurtHero(5);
      final hp = session.progress.hp, kills = session.progress.kills;
      session.tick(10);
      session.hit(session.mobs.first, 999, Offset.zero);
      expect(session.defeated, true);
      expect(session.progress.hp, hp);
      expect(hp, 0);
      expect(session.progress.kills, kills);
    },
  );
  test(
    'exploration replenishes a new area and the encounter cap remains bounded',
    () {
      session.hero.position.setValues(6800, 4700);
      for (var i = 0; i < 170; i++) {
        session.tick(.05);
      }
      expect(
        session.mobs.where(
          (e) => (e.position - session.hero.position).length < 650,
        ),
        isNotEmpty,
      );
      for (var i = 0; i < 15; i++) {
        session.spawnPack();
      }
      expect(session.living, lessThanOrEqualTo(40));
    },
  );
  test(
    'the first boss is summoned once and its defeat ends the adventure once',
    () {
      session.cleansedSites.addAll(questSites.map((q) => q.id));
      session.progress.kills = stageKillGoal;
      session.tick(.05);
      session.tick(.05);
      final bosses = session.mobs.where((m) => m.boss).toList();
      expect(bosses.length, 1);
      final before = session.progress.gold;
      session.hit(bosses.single, 9999, Offset.zero);
      session.hit(bosses.single, 9999, Offset.zero);
      expect(session.won, true);
      expect(session.progress.bossDefeated, true);
      expect(session.progress.gold, before + 100);
      expect(game.paused, true);
    },
  );
  test(
    'large enemies can round the fountain without stalling at a narrow corner',
    () {
      session.hero.invulnerable = 999;
      for (final from in const [
        Offset(3664, 2820),
        Offset(3664, 2890),
        Offset(3940, 2810),
      ]) {
        session.mobs.clear();
        final enemy = session.spawnEnemy(
          'golem',
          from * worldScale,
          boss: true,
        )!;
        if (from.dx > 3900) enemy.speed = 12;
        for (var i = 0; i < 3600; i++) {
          enemy.update(.05);
          expect(session.world.blocked(enemy.body), false);
          if ((enemy.body.center - session.hero.body.center).distance < 64) {
            break;
          }
        }
        expect(
          (enemy.body.center - session.hero.body.center).distance,
          lessThan(64),
          reason: 'boss from $from stopped at ${enemy.position}',
        );
      }
    },
  );
}
