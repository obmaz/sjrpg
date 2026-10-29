import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/enemy_difficulty.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/shop_content.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session({WorldStage stage = WorldStage.forest}) {
    final s = Adventure(GameArt(), stage: stage)..start(TestGame());
    s.mobs.clear();
    addTearDown(s.dispose);
    return s;
  }

  test('farther fields and later chapters produce stronger enemies', () {
    final forest = session();
    final near = forest.spawnEnemy(
      'goblin',
      forest.world.spawn + const Offset(500, 0),
    )!;
    HuntEnemy? far;
    for (final trail in forest.world.trails.reversed) {
      final at = trail.points.last;
      if ((at - forest.world.spawn).distance < 16000) continue;
      far = forest.spawnEnemy('goblin', at);
      if (far != null) break;
    }
    expect(far, isNotNull);
    expect(far!.life.max, greaterThan(near.life.max));
    final later = session(stage: WorldStage.tombs);
    final advanced = later.spawnEnemy(
      'goblin',
      later.world.spawn + const Offset(500, 0),
    )!;
    expect(advanced.life.max, greaterThan(near.life.max));
  });

  test('newly acquired gear options grow gently with player level', () {
    final low = Progress(), high = Progress()..level = 21;
    final a = low.rollLoot(math.Random(81), boss: true);
    final b = high.rollLoot(math.Random(81), boss: true);
    expect(b.base.id, a.base.id);
    expect(b.power, greaterThan(a.power));
    expect(b.power - a.power, lessThanOrEqualTo(3));
    expect(b.vitality, greaterThan(a.vitality));
  });

  test('a newly earned unique weapon carries two working abilities', () {
    final s = inCombatField(session()), p = s.progress;
    final weapon = p.createGear(
      gearById('longsword'),
      rarity: Rarity.unique,
      gifts: [WeaponGift.frost, WeaponGift.guardian],
    );
    p.inventory.add(weapon);
    expect(p.equip(weapon), true);
    final enemy = s.spawnEnemy('goblin', const Offset(6100, 4200))!;
    expect(s.hit(enemy, 1, Offset.zero), true);
    expect(enemy.slow, greaterThan(0), reason: 'first unique ability slows');
    final hp = p.hp;
    s.hurtHero(10);
    expect(
      p.hp,
      closeTo(hp - p.mitigate(10) * .92, .00001),
      reason: 'second unique ability reduces incoming damage',
    );
  });

  test('enemy snapshots do not change during pursuit or later levelling', () {
    final s = inCombatField(session());
    final enemy = s.spawnEnemy('goblin', const Offset(6100, 4200))!;
    final hp = enemy.life.max, power = enemy.power;
    enemy.position.setValues(29000, 18000);
    s.progress.level = 40;
    expect(enemy.life.max, hp);
    expect(enemy.power, same(power));
    expect(
      enemy.outgoingDamage(10),
      closeTo(10 * power.damageMultiplier * 1.2, .00001),
    );
  });

  test(
    'elite and unique rewards grant one and two distinct working options',
    () {
      final p = Progress();
      for (var seed = 0; seed < 30; seed++) {
        final elite = p.rollLoot(math.Random(seed), elite: true);
        final unique = p.rollLoot(math.Random(seed), unique: true);
        expect(elite.gifts.length, 1);
        expect(unique.rarity, Rarity.unique);
        expect(unique.gifts.length, 2);
        expect(unique.gifts.toSet().length, 2);
        expect(unique.power, greaterThanOrEqualTo(elite.power));
      }
      final s = inCombatField(session());
      final enemy = s.spawnEnemy(
        'goblin',
        const Offset(6100, 4200),
        tier: EnemyTier.unique,
        trait: EnemyTrait.armored,
      )!;
      final plain = s.spawnEnemy(
        'goblin',
        const Offset(6200, 4200),
        trait: EnemyTrait.armored,
      )!;
      expect(enemy.life.max, greaterThan(plain.life.max));
      expect(enemy.outgoingDamage(10), greaterThan(plain.outgoingDamage(10)));
      enemy.wardPhase = 4.5;
      expect(enemy.wardWarning, true);
      expect(enemy.wardActive, false);
      enemy.wardPhase = 5.5;
      final hp = enemy.life.value;
      expect(s.hit(enemy, 10, Offset.zero), true);
      expect(enemy.life.value, closeTo(hp - 6.5, .00001));
      enemy.wardPhase = 0;
      s.hit(enemy, 100000, Offset.zero);
      expect(s.loot.single.item.rarity, Rarity.unique);
      expect(s.loot.single.item.gifts.length, 2);
      final gold = s.progress.gold;
      expect(s.hit(enemy, 100000, Offset.zero), false);
      expect(s.progress.gold, gold);
    },
  );

  test(
    'shop quote and purchase share acquisition stats without scaling twice',
    () {
      final p = Progress()..level = 31;
      for (final stage in WorldStage.values) {
        for (final def in p.shopGear) {
          final offer = ShopGearOffer(def, stage, acquiredLevel: p.level);
          final item = offer.create(p);
          expect(offer.matches(item), true);
          expect(item.stats, offer.preview.stats);
          final before = item.toSave();
          p.level++;
          expect(item.toSave(), before);
          p.level--;
        }
      }
    },
  );

  test('legacy equipment keeps numeric stats and original single option', () {
    final p = Progress()..level = 50;
    for (final rarity in Rarity.values) {
      final old = {
        'serial': 7,
        'base': 'longsword',
        'rarity': rarity.name,
        'power': 4,
        'vitality': 8,
        'focus': 0,
        'locked': false,
        'gift': rarity == Rarity.rare ? 'guardian' : null,
      };
      final gear = Gear.fromSave(old);
      expect(gear.power, 4);
      expect(gear.vitality, 8);
      expect(gear.affixVersion, 0);
      expect(gear.gifts.length, rarity == Rarity.rare ? 1 : 0);
      expect(Gear.fromSave(gear.toSave()).toSave(), gear.toSave());
      p.inventory.add(gear);
    }
    expect(
      () => Gear.fromSave({
        ...p.inventory.last.toSave(),
        'gifts': ['frost', 'frost'],
        'affixVersion': 1,
      }),
      throwsFormatException,
    );
  });

  test(
    'wounded unique power and ward phase survive checkpoint and dormancy',
    () {
      final s = inCombatField(session());
      s.progress.level = 9;
      final enemy = s.spawnEnemy(
        'goblin',
        const Offset(6100, 4200),
        tier: EnemyTier.unique,
        trait: EnemyTrait.swift,
      )!;
      enemy.life.update(enemy.life.max * .4);
      enemy.wardPhase = 5.75;
      final hp = enemy.life.value, max = enemy.life.max;
      final saved = s.saveEnemy(enemy);
      final cp = GameCheckpoint.capture(s)!;
      final restored = cp.restore(GameArt())..start(TestGame());
      addTearDown(restored.dispose);
      final again = restored.mobs.singleWhere((m) => m.isUnique);
      expect(again.life.value, hp);
      expect(again.life.max, max);
      expect(again.wardPhase, 5.75);
      expect(again.power.toSave(), enemy.power.toSave());
      expect(restored.saveEnemy(again), saved);
      final roundtrip = GameCheckpoint.decode(
        GameCheckpoint.capture(restored)!.encode(),
      )!;
      expect(roundtrip.data['enemies'], cp.data['enemies']);
    },
  );

  test('legacy enemy health is migrated once preserving wounded ratio', () {
    final s = inCombatField(session(stage: WorldStage.tombs));
    s.spawnEnemy(
      'goblin',
      Offset(s.hero.position.x, s.hero.position.y) + const Offset(110, 0),
    );
    final raw =
        jsonDecode(GameCheckpoint.capture(s)!.encode()) as Map<String, dynamic>;
    final enemy = (raw['enemies'] as List).single as Map;
    enemy.remove('power');
    enemy.remove('tier');
    enemy.remove('wardPhase');
    enemy['hp'] = 10.0;
    enemy['maxHp'] = 40.0;
    final cp = GameCheckpoint.decode(jsonEncode(raw))!;
    final migrated = (cp.data['enemies'] as List).single as Map;
    expect(
      migrated['maxHp'],
      closeTo(40 * (migrated['power']['health'] as num), .000001),
    );
    expect((migrated['hp'] as num) / (migrated['maxHp'] as num), .25);
    expect(
      GameCheckpoint.decode(cp.encode())!.data['enemies'],
      cp.data['enemies'],
    );
    final invalid = jsonDecode(cp.encode()) as Map<String, dynamic>;
    ((invalid['enemies'] as List).single as Map)['power']['damage'] =
        double.infinity;
    // jsonEncode correctly refuses non-finite values as well.
    expect(
      () => jsonEncode(invalid),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
  });
}
