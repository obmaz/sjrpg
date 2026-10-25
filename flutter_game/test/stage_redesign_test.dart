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
    final s = Adventure(GameArt(), heroClass: hero)..start(TestGame());
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
      final motor = s.mounts.firstWhere((m) => m.def.id == 'motor');
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
      s.hero.bearing = 0;
      s.hero.slash();
      expect(mobs.where((m) => m.life.value < 500).length, 1);
      for (final m in mobs) {
        m.life.initial(500);
      }
      s.progress.ranks['cleave'] = 3;
      s.hero.attackClock = 0;
      s.hero.slash();
      expect(mobs.where((m) => m.life.value < 500).length, 3);
    },
  );
  test(
    'every offensive skill starts at three and has a bounded growth curve',
    () {
      final tops = <int>{};
      for (final hero in HeroClass.values) {
        final p = Progress(heroClass: hero);
        for (final skill in p.skills.where(
          (s) => !s.passive && s.id != 'iceArmor',
        )) {
          expect(p.skillTargetLimit(skill, atRank: 1), 3, reason: skill.id);
          var previous = 3;
          for (var rank = 2; rank <= 5; rank++) {
            final cap = p.skillTargetLimit(skill, atRank: rank);
            expect(cap, inInclusiveRange(previous, 11));
            previous = cap;
          }
          tops.add(previous);
        }
      }
      expect(tops.length, greaterThanOrEqualTo(3));
    },
  );
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
    expect(mobs.first.life.value, 488);
  });
  test('normal, elite and boss life all use the doubled baseline', () {
    final s = session();
    expect(s.spawnEnemy('goblin', const Offset(6050, 4200))!.life.max, 56);
    expect(s.spawnEnemy('wolf', const Offset(6100, 4200))!.life.max, 76);
    expect(s.spawnEnemy('skeleton', const Offset(6150, 4200))!.life.max, 104);
    expect(
      s
          .spawnEnemy(
            'goblin',
            const Offset(6200, 4200),
            trait: EnemyTrait.armored,
          )!
          .life
          .max,
      closeTo(56 * 1.8, .001),
    );
    expect(
      s.spawnEnemy('golem', const Offset(6300, 4200), boss: true)!.life.max,
      3600,
    );
  });
  test(
    'moving cannot bypass the slower spawn interval and packs are larger',
    () {
      final s = session();
      s.waveTime = 0;
      for (var i = 0; i < 150; i++) {
        s.tick(.05);
      }
      expect(s.living, 0);
      for (var i = 0; i < 20; i++) {
        s.tick(.05);
      }
      expect(s.living, greaterThanOrEqualTo(6));
      for (var i = 0; i < 8; i++) {
        s.spawnPack();
      }
      expect(s.living, lessThanOrEqualTo(40));
    },
  );
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
    'ground mounts require a button and persist; attacking returns to foot',
    () {
      final s = session();
      final horse = s.mounts.firstWhere((m) => m.def.id == 'horse');
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
      expect(s.riding, null);
      expect(s.hero.body.size, const Size(28, 24));
    },
  );
  test('boats stay on water and cannot dismount in the middle of a lake', () {
    final s = session();
    final boat = s.mounts.firstWhere((m) => m.def.waterOnly);
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
    s.hero.resizeBody(boat.def.bodySize, const Offset(5680, 1700));
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
      expect(migrated.data['boss']['hp'], 1800);
      expect(migrated.data['boss']['maxHp'], 3600);
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
