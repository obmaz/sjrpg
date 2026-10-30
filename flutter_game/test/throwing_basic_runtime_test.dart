import 'dart:math' as math;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/barbarian_combat.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field(String id) {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    s.mobs.clear();
    s.waveTime = 10000;
    s.progress.level = 100;
    final gear = s.progress.createGear(gearById(id));
    s.progress.inventory.add(gear);
    expect(s.progress.equip(gear), true);
    s.hero.bearing = 0;
    addTearDown(s.dispose);
    return s;
  }

  void fly(BarbarianThrownAxe projectile) {
    for (var i = 0; i < 150 && !projectile.resolved; i++) {
      projectile.update(.01);
    }
  }

  for (final id in ['throwingaxes', 'javelin']) {
    test('$id basic travels before hitting exactly one target', () {
      final s = field(id);
      final first = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(120, 0),
      )!..life.initial(100000);
      final second = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(165, 0),
      )!..life.initial(100000);
      s.progress.energy = 0;
      final damage = s.progress.basicDamage;
      s.hero.slash();
      expect(first.life.value, 100000);
      expect(second.life.value, 100000);
      final projectile = (s.game as TestGame).added
          .whereType<BarbarianThrownAxe>()
          .single;
      expect(projectile.projectileId, id);
      expect(projectile.speed, id == 'javelin' ? 640 : 520);
      expect(projectile.range, s.progress.weapon.base.range);
      final before = projectile.position.toOffset();
      projectile.update(.02);
      expect(
        (projectile.position.toOffset() - before).distance,
        closeTo(projectile.speed * .02, .002),
      );
      expect(first.life.value, 100000);
      fly(projectile);
      expect(first.life.value, closeTo(100000 - damage, .001));
      expect(second.life.value, 100000);
      expect(s.progress.energy, greaterThan(0));
      final energy = s.progress.energy;
      projectile.update(.05);
      expect(s.progress.energy, energy);
    });
  }
  test('basic thrown range expires without damaging a distant enemy', () {
    final s = field('throwingaxes');
    // Isolate the empty-flight range proof from auto-targetable charged stones.
    Offset? corridor;
    for (final point in [
      s.hero.position.toOffset() + const Offset(0, -700),
      ...s.world.trails.expand((t) => t.points),
    ]) {
      corridor = s.world.spawnNear(
        point,
        s.hero.body.size,
        avoidSanctuary: true,
        occupied: (body) =>
            s.encounterAreas.values.any(
              (a) => (a.stone - body.center).distance < 650,
            ) ||
            !s.world.clearEnemyLine(
              body.topLeft,
              body.topLeft + const Offset(500, 0),
              body.size,
            ),
      );
      if (corridor != null) break;
    }
    expect(corridor, isNotNull, reason: 'an unobstructed range-test corridor');
    s.hero.position.setValues(corridor!.dx, corridor.dy);
    final enemy = s.spawnEnemy(
      'goblin',
      s.hero.body.center + const Offset(460, 0),
    )!..life.initial(100000);
    s.hero.slash();
    final projectile = (s.game as TestGame).added
        .whereType<BarbarianThrownAxe>()
        .single;
    fly(projectile);
    expect(projectile.travelled, closeTo(390, 1e-6));
    expect(enemy.life.value, 100000);
  });
  test(
    'mastered basic throws apply one mastery and one critical multiplier',
    () {
      final s = field('javelin');
      final enemy = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(120, 0),
      )!..life.initial(100000);
      s.progress.ranks['throwingMastery'] = 20;
      final damage = s.progress.basicDamage;
      var sawCrit = false, sawNormal = false;
      for (var i = 0; i < 80; i++) {
        s.tick(BattleText.streamInterval + .001);
        s.hero.attackClock = s.hero.castLock = 0;
        final hp = enemy.life.value;
        s.hero.slash();
        final projectile = (s.game as TestGame).added
            .whereType<BarbarianThrownAxe>()
            .last;
        fly(projectile);
        expect(
          hp - enemy.life.value,
          closeTo(damage * (projectile.critical ? 2 : 1), .001),
        );
        expect(s.texts.last.critical, projectile.critical);
        sawCrit |= projectile.critical;
        sawNormal |= !projectile.critical;
      }
      expect(sawCrit && sawNormal, true);
      final stats = s.progress.basicAttackStats();
      expect(
        stats.dps,
        closeTo(
          damage * (1 + s.progress.weaponCriticalChance) / stats.interval,
          1e-6,
        ),
      );
    },
  );
  test('a thrown sweep stops at a closed chest and breaks it once', () {
    final s = field('javelin');
    int? index;
    Offset? launch;
    for (var i = 0; i < s.world.chests.length && index == null; i++) {
      final chest = s.world.chests[i];
      for (final offset in [
        const Offset(-60, 0),
        const Offset(60, 0),
        const Offset(0, -50),
        const Offset(0, 50),
      ]) {
        final at = chest + offset;
        if (!s.world.blocksEnemy(
          Rect.fromCenter(center: at, width: 8, height: 8),
        )) {
          index = i;
          launch = at;
          break;
        }
      }
    }
    expect(index, isNotNull);
    final chest = s.world.chests[index!];
    final bearing = math.atan2(chest.dy - launch!.dy, chest.dx - launch.dx);
    final projectile = BarbarianThrownAxe(
      s,
      launch,
      bearing,
      100,
      range: 200,
      rank: 1,
      profile: s.progress.weapon.base.throwingProfile,
    );
    fly(projectile);
    expect(projectile.resolved, true);
    expect(s.world.openedChests, contains(index));
    final count = s.world.openedChests.length;
    projectile.update(.05);
    expect(s.world.openedChests.length, count);
  });
  test(
    'DoubleThrow uses equipped projectile profile but retains skill range',
    () {
      final s = field('javelin');
      s.progress.ranks['doubleThrow'] = 1;
      expect(s.progress.selectSkill('doubleThrow'), true);
      s.progress.energy = s.progress.maxEnergy;
      s.hero.skill();
      for (var i = 0; i < 15; i++) {
        s.hero.update(.02);
      }
      final projectiles = (s.game as TestGame).added
          .whereType<BarbarianThrownAxe>();
      expect(projectiles.length, 2);
      expect(
        projectiles.every((p) => p.projectileId == 'javelin' && p.range == 420),
        true,
      );
      expect(projectiles.first.direction.dx, closeTo(math.cos(.035), 1e-8));
    },
  );
}
