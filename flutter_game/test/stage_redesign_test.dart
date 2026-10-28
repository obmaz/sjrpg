import 'dart:convert';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session({HeroClass hero = HeroClass.warrior}) {
    final s = inCombatField(Adventure(GameArt(), heroClass: hero))
      ..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    s.hero.position.setValues(6000, 4200);
    return s;
  }

  List<HuntEnemy> crowd(Adventure s) => [
    for (final p in const [
      Offset(6050, 4200),
      Offset(6090, 4200),
      Offset(6130, 4200),
      Offset(6050, 4240),
      Offset(6090, 4240),
      Offset(6130, 4240),
    ])
      s.spawnEnemy('goblin', p)!..life.initial(500),
  ];
  test(
    'an occupied mount explains the blocker and becomes boardable after the enemy dies',
    () {
      final s = session();
      final motor = withOwnedMounts(
        s,
      ).mounts.firstWhere((m) => m.def.id == 'motor');
      // The expanded starter ward protects the parked town motor. Exercise an
      // actually contested mount on clear ground in the combat fixture instead.
      motor.at = const Offset(6100, 4200);
      expect(
        s.world.blocked(
          Rect.fromCenter(
            center: motor.at,
            width: motor.def.bodySize.width,
            height: motor.def.bodySize.height,
          ),
        ),
        false,
      );
      expect(
        s.world.sanctuary.protects(
          Rect.fromCenter(
            center: motor.at,
            width: motor.def.bodySize.width,
            height: motor.def.bodySize.height,
          ),
        ),
        false,
      );
      s.hero.position.setValues(motor.at.dx - 12, motor.at.dy + 55);
      final enemy = s.spawnEnemy('goblin', motor.at - const Offset(12, 11))!;
      final progress = s.progress.toSave();
      expect(s.boardNearbyMount(), false);
      expect(s.riding, null);
      expect(s.notice, '탈것 주변의 적을 먼저 정리하세요');
      expect(s.progress.toSave(), progress);
      s.hit(enemy, 100000, Offset.zero);
      expect(s.boardNearbyMount(), true);
      expect(s.riding, motor);
      expect(s.world.blocked(s.hero.body), false);
    },
  );
  test(
    'melee starts with one target and cleave investment increases its cap',
    () {
      final s = session(), mobs = crowd(s);
      // Keep all six victims within reach, so reach never masks the target cap.
      final sword = s.progress.createGear(gearById('longsword'));
      s.progress.addOwnedGear(sword);
      s.progress.equip(sword);
      final original = mobs.map((m) => m.body.topLeft).toList();
      s.hero.bearing = 0;
      s.hero.slash();
      expect(mobs.where((m) => m.life.value < 500).length, 1);
      for (final (index, mob) in mobs.indexed) {
        mob.life.initial(500);
        mob.position.setValues(original[index].dx, original[index].dy);
        s.updateEnemySpacing(mob);
      }
      s.progress.ranks['cleave'] = 3;
      s.hero.attackClock = 0;
      s.hero.slash();
      expect(mobs.where((m) => m.life.value < 500).length, 3);
      for (final (index, mob) in mobs.indexed) {
        mob.life.initial(500);
        mob.position.setValues(original[index].dx, original[index].dy);
        s.updateEnemySpacing(mob);
      }
      s.progress.ranks['cleave'] = 5;
      s.hero.attackClock = 0;
      s.hero.slash();
      expect(mobs.where((m) => m.life.value < 500).length, 5);
    },
  );
  test('offensive skills and specialties gain a target for every point', () {
    for (final hero in HeroClass.values) {
      final p = Progress(heroClass: hero);
      for (final skill in p.skills.where(
        (s) => const {
          'leap',
          'howl',
          'warcry',
          'battleCry',
          'grimWard',
          'whirlwind',
          'frostNova',
          'chainLightning',
          'meteor',
        }.contains(s.id),
      )) {
        expect(
          [
            for (var rank = 1; rank <= 5; rank++)
              p.skillTargetLimit(skill, atRank: rank),
          ],
          [3, 4, 5, 6, 7],
          reason: skill.id,
        );
      }
      final specialties = hero == HeroClass.warrior
          ? <String, List<String>>{}
          : {
              'cinderReach': ['meteor'],
              'forkedStorm': ['chainLightning'],
            };
      for (final entry in specialties.entries) {
        for (final id in entry.value) {
          final skill = p.skills.firstWhere((skill) => skill.id == id);
          final caps = <int>[];
          for (var rank = 0; rank <= 5; rank++) {
            p.ranks[entry.key] = rank;
            caps.add(p.skillTargetLimit(skill, atRank: 5));
          }
          expect(caps, [7, 8, 9, 10, 11, 12], reason: '$id ${entry.key}');
        }
      }
    }
  });
  test('whirlwind cannot select additional victims across later pulses', () {
    final s = session(), mobs = crowd(s);
    final spin = WhirlwindPulse(s, s.hero, 5);
    spin.update(.05);
    final first = mobs.where((m) => m.life.value < 500).toList();
    expect(first.length, 3);
    for (final m in first) {
      m.life.update(0);
    }
    for (var i = 0; i < 10; i++) {
      spin.update(.05);
    }
    expect(spin.targets.length, 3);
    expect(
      mobs.where((m) => !first.contains(m)).every((m) => m.life.value == 500),
      true,
    );
  });
  test('explosive basic projectiles count the direct victim once', () {
    final s = session(hero: HeroClass.mage), mobs = crowd(s);
    final bolt = ArcaneBolt(
      s,
      s.hero.body.center,
      0,
      12,
      explosive: true,
      targetLimit: 3,
    );
    for (var i = 0; i < 10; i++) {
      bolt.update(.05);
    }
    expect(bolt.resolved, true);
    expect(mobs.where((m) => m.life.value < 500).length, 3);
    expect(mobs.first.life.value, closeTo(500 - 12 * .7, .000001));
  });
  test('normal, elite and boss life use the current reduced baseline', () {
    final s = session();
    expect(
      s.spawnEnemy('goblin', const Offset(6050, 4200))!.life.max,
      closeTo(44.8, .000001),
    );
    expect(
      s.spawnEnemy('wolf', const Offset(6100, 4200))!.life.max,
      closeTo(60.8, .000001),
    );
    expect(
      s.spawnEnemy('skeleton', const Offset(6150, 4200))!.life.max,
      closeTo(83.2, .000001),
    );
    expect(
      s
          .spawnEnemy(
            'goblin',
            const Offset(6200, 4200),
            trait: EnemyTrait.armored,
          )!
          .life
          .max,
      closeTo(44.8 * 1.8, .001),
    );
    expect(
      s.spawnEnemy('golem', const Offset(6300, 4200), boss: true)!.life.max,
      2880,
    );
  });
  test('moving cannot bypass the finite spawn interval or active pack cap', () {
    final s = session();
    s.waveTime = 0;
    for (var i = 0; i < 150; i++) {
      s.tick(.05);
    }
    expect(s.living, 0);
    for (var i = 0; i < 20; i++) {
      s.tick(.05);
    }
    expect(s.living, 6);
    for (var i = 0; i < 8; i++) {
      s.spawnPack();
    }
    expect(s.living, lessThanOrEqualTo(30));
  });
  test('all mandatory sites gate the boss, reward once, and persist', () {
    final s = session();
    s.progress.kills = stageKillGoal;
    s.tick(.05);
    expect(s.bossSummoned, false);
    s.mobs.clear();
    for (final site in questSites) {
      s.hero.position.setValues(site.at.dx - 14, site.at.dy - 12);
      final gold = s.progress.gold;
      expect(s.cleanseNearbySite(), true, reason: site.id);
      expect(s.progress.gold, gold + 40);
      expect(s.cleanseNearbySite(), false);
    }
    expect(s.mandatoryQuestsComplete, true);
    s.tick(.05);
    expect(s.bossSummoned, true);
    final boss = s.mobs.firstWhere((m) => m.boss);
    s.hit(boss, 1000000, Offset.zero);
    expect(s.stageCleared, true);
    expect(s.won, true);
    final restored = GameCheckpoint.capture(s)!.restore(GameArt());
    addTearDown(restored.dispose);
    expect(restored.stageCleared, true);
    expect(restored.cleansedSites, s.cleansedSites);
  });
  test('a defeated boss alone cannot complete the stage', () {
    final s = session();
    final boss = s.spawnEnemy('golem', const Offset(6100, 4200), boss: true)!;
    s.hit(boss, 1000000, Offset.zero);
    expect(s.progress.bossDefeated, true);
    expect(s.won, false);
    expect(s.stageCleared, false);
  });
  test(
    'purchased horses require a button, persist and keep basic attacks mounted',
    () {
      final s = session();
      final horse = withOwnedMounts(
        s,
      ).mounts.firstWhere((m) => m.def.id == 'horse');
      s.hero.position.setValues(horse.at.dx - 14, horse.at.dy + 50);
      s.tick(.05);
      expect(s.riding, null);
      expect(s.nearbyAction, NearbyAction.mount);
      expect(s.boardNearbyMount(), true);
      expect(s.riding, horse);
      expect(s.hero.body.size, horse.def.bodySize);
      expect(s.world.blocked(s.hero.body), false);
      final checkpoint = GameCheckpoint.capture(s)!;
      final restored = checkpoint.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.riding?.def.id, 'horse');
      expect(restored.hero.body.size, horse.def.bodySize);
      s.hero.slash();
      expect(s.riding, horse);
      expect(s.hero.body.size, horse.def.bodySize);
    },
  );
  test('boats stay on water and cannot dismount in the middle of a lake', () {
    final s = session();
    final boat = withOwnedMounts(s).mounts.firstWhere((m) => m.def.waterOnly);
    expect(s.world.largeWater(boat.at), true);
    final shore = s.world.spawnNear(
      boat.at - const Offset(220, 12),
      const Size(28, 24),
    )!;
    s.hero.position.setValues(shore.dx, shore.dy);
    expect(s.boardNearbyMount(), true);
    expect(s.riding, boat);
    final moved = s.world.move(
      Offset(s.hero.position.x, s.hero.position.y),
      const Offset(-700, 0),
      boat.def.bodySize,
      waterOnly: true,
    );
    final body = Rect.fromLTWH(
      moved.dx,
      moved.dy,
      boat.def.bodySize.width,
      boat.def.bodySize.height,
    );
    expect(s.world.blocked(body, waterOnly: true), false);
    expect(s.world.blocked(body), true);
    s.hero.resizeBody(boat.def.bodySize, const Offset(5680, 1700) * worldScale);
    boat.at = s.hero.body.center;
    expect(s.dismount(), false);
    expect(s.riding, boat);
    final restored = GameCheckpoint.capture(s)!.restore(GameArt());
    addTearDown(restored.dispose);
    expect(restored.riding?.def.id, 'boat');
    expect(restored.world.blocked(restored.hero.body, waterOnly: true), false);
  });
  test(
    'old wounded bosses migrate once and historical cleared saves remain cleared',
    () {
      final s = session();
      s.progress.kills = stageKillGoal;
      final data = GameCheckpoint.capture(s)!.data;
      data.remove('balance');
      data.remove('sites');
      data.remove('mounts');
      data.remove('riding');
      data['boss'] = {'x': 6100.0, 'y': 4200.0, 'hp': 900.0, 'maxHp': 1800.0};
      final migrated = GameCheckpoint.decode(jsonEncode(data))!;
      expect(migrated.data['boss']['hp'], 1440);
      expect(migrated.data['boss']['maxHp'], 2880);
      expect(
        GameCheckpoint.decode(migrated.encode())!.data['boss'],
        migrated.data['boss'],
      );
      data['boss'] = null;
      (data['progress'] as Map)['bossDefeated'] = true;
      final cleared = GameCheckpoint.decode(
        jsonEncode(data),
      )!.restore(GameArt());
      addTearDown(cleared.dispose);
      expect(cleared.stageCleared, true);
      expect(cleared.cleansedSites.length, 3);
    },
  );
  test('invalid quest and mount records cannot overwrite progress', () {
    final s = session(), data = GameCheckpoint.capture(session())!.data;
    final badSite = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    badSite['sites'] = ['unknown'];
    expect(GameCheckpoint.decode(jsonEncode(badSite)), null);
    final badMount = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    badMount['riding'] = 'dragon';
    expect(GameCheckpoint.decode(jsonEncode(badMount)), null);
    expect(GameCheckpoint.capture(s), isNotNull);
  });
}
