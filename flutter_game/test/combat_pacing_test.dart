import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/enemy_difficulty.dart';
import 'package:guardian_new/equipment_panel.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/loot_policy.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_preview_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field({HeroClass hero = HeroClass.warrior}) {
    final s = inCombatField(Adventure(GameArt(), heroClass: hero))
      ..start(TestGame());
    s.mobs.clear();
    addTearDown(s.dispose);
    return s;
  }

  test(
    'default basic cadence and damage reflect the deliberate combat reduction',
    () {
      // The physical starting weapon keeps the established global reduction.
      final warrior = Progress();
      expect(warrior.basicDps / 33.088235294117645, closeTo(.1836, .000001));
      expect(warrior.attackInterval / .34, closeTo(1 / .30, .000001));
      final tempo = warrior.basicTempo;
      warrior.ranks['cleave'] = 5;
      expect(warrior.basicTempo / tempo, closeTo(1.06, .000001));
      expect(warrior.basicTempo / tempo, lessThan(1.32));
      // Sorceress uses a paid 13/25-second spell animation, not staff swing cadence.
      final mage = Progress(heroClass: HeroClass.mage),
          first = mage.sorceressSpell(mage.basicSkill);
      expect(mage.selectedBasic, 'firebolt');
      expect(first.manaCost, greaterThan(0));
      expect(mage.actualBasicInterval(), 13 / 25);
      expect(
        mage.basicDps,
        closeTo(first.meanDamage / CombatBalance.realSeconds(13 / 25), .000001),
      );
      mage.ranks['firebolt'] = 20;
      expect(
        mage.actualBasicInterval(),
        13 / 25,
        reason:
            'hard spell points increase source damage without shortening the cast animation',
      );
      expect(mage.basicDamage, greaterThan(first.meanDamage));
      final s = field(hero: HeroClass.mage);
      s.hero.slash();
      expect(s.hero.castLock, 13 / 25);
      final mana = s.progress.energy, clock = s.hero.attackClock;
      s.hero.slash();
      expect(s.progress.energy, mana);
      expect(s.hero.attackClock, clock);
    },
  );

  test(
    'resources recover slower through real hit, hurt, mana tick and levelup',
    () {
      final warrior = field();
      warrior.progress.energy = 0;
      final enemy = warrior.spawnEnemy('goblin', const Offset(6100, 4200))!;
      warrior.hero.slash();
      expect(enemy.life.value, lessThan(enemy.life.max));
      expect(warrior.progress.energy, closeTo(2.1, .000001));
      warrior.progress.energy = 0;
      warrior.hero.invulnerable = 0;
      warrior.hurtHero(1);
      expect(warrior.progress.energy, closeTo(4.9, .000001));
      final mage = field(hero: HeroClass.mage);
      mage.progress.energy = 0;
      mage.tick(1);
      expect(mage.progress.energy, closeTo(6.3, .000001));
      for (final hero in HeroClass.values) {
        final p = Progress(heroClass: hero)..energy = 0;
        p.gainXp(p.nextLevelXp);
        expect(p.level, 2);
        expect(p.energy, closeTo(hero == HeroClass.mage ? 31.5 : 10, .000001));
      }
    },
  );

  test(
    'fractional mastery previews match actual learned damage and critical chance',
    () {
      final p = Progress()
        ..level = 100
        ..skillPoints = 20;
      final skill = p.skills.firstWhere((s) => s.id == 'swordMastery');
      expect(p.learn(skill), true);
      expect(p.learn(skill), true);
      final before = p.toSave();
      final preview = previewSkill(p, skill);
      final row = preview.firstWhere((r) => r.label == '해당 무기 치명타');
      expect(row.format(row.current), '3.8%');
      expect(row.format(row.next), '4.2%');
      expect(p.toSave(), before);
      final damage = p.basicDamage;
      expect(p.learn(skill), true);
      expect(p.basicDamage, greaterThan(damage));
      expect(p.weaponCriticalChance * 100, closeTo(row.next, .000001));
      expect(
        previewSkill(p, skill).firstWhere((r) => r.label == row.label).current,
        row.next,
      );
    },
  );

  test(
    'incoming attack gets twenty percent once without rewriting spawn power',
    () {
      final s = field();
      const power = EnemyPower(5000, 1.1, 1.25);
      final enemy = s.spawnEnemy(
        'goblin',
        const Offset(6035, 4200),
        power: power,
      )!;
      expect(enemy.power, same(power));
      expect(enemy.outgoingDamage(4), closeTo(6, .000001));
      final hp = s.progress.hp;
      enemy.bearing = math.pi;
      enemy.meleeWindup = .01;
      enemy.update(.02);
      expect(s.progress.hp, closeTo(hp - s.progress.mitigate(6), .000001));
      expect(enemy.power.toSave(), power.toSave());
      final cp = GameCheckpoint.capture(s)!;
      expect(cp.data['enemies'].single['power'], power.toSave());
    },
  );

  test(
    'new poison snapshots buff once while saved poison potency is preserved',
    () {
      final s = field();
      final enemy = s.spawnEnemy('viper', const Offset(6100, 4200))!;
      s.afflictions.apply(
        PlayerStatus.poison,
        potency: enemy.outgoingDamage(1),
      );
      expect(s.afflictions.poisonPotency, closeTo(1.2, .000001));
      final before = s.progress.hp;
      s.tick(.9);
      expect(
        s.progress.hp,
        closeTo(before - s.progress.mitigate(2.4), .000001),
      );
      s.afflictions.clear();
      s.afflictions.apply(PlayerStatus.poison, potency: 1.1);
      final cp = GameCheckpoint.capture(s)!;
      final restored = cp.restore(GameArt())..start(TestGame());
      addTearDown(restored.dispose);
      expect(restored.afflictions.poisonPotency, 1.1);
      expect(restored.afflictions.toSave(), s.afflictions.toSave());
    },
  );

  test(
    'ordinary leveling takes five kills and old earned levels stay intact',
    () {
      final p = Progress();
      for (var i = 0; i < 4; i++) {
        p.reward();
      }
      expect(p.level, 1);
      p.reward();
      expect(p.level, 2);
      expect(p.xp, 8);
      final old = Progress()
        ..level = 8
        ..xp = 264;
      final owned = old.inventory.map((g) => g.toSave()).toList();
      final saved =
          jsonDecode(jsonEncode(old.toSave())) as Map<String, dynamic>;
      saved.remove('experienceVersion');
      final restored = Progress.fromSave(saved)!;
      expect(restored.level, 9);
      expect(restored.xp, 65);
      expect(restored.inventory.map((g) => g.toSave()), owned);
      expect(restored.nextLevelXp, 222);
    },
  );

  test('larger packs preserve finite waves and stop at the new active cap', () {
    final s = field();
    final distant = s.world.trails
        .expand((trail) => trail.points)
        .firstWhere(
          (at) =>
              (at - s.world.spawn).distance >
                  CombatBalance.nearTownRadius + 500 &&
              !s.world.blocked(
                Rect.fromLTWH(
                  at.dx,
                  at.dy,
                  s.hero.body.width,
                  s.hero.body.height,
                ),
              ),
        );
    s.hero.position.setValues(distant.dx, distant.dy);
    s.spawnPack(initial: true);
    expect(s.living, 5);
    s.mobs.clear();
    s.encounterAreas.clear();
    s.spawnPack();
    expect(s.living, 6);
    s.progress.level = 5;
    s.mobs.clear();
    s.encounterAreas.clear();
    s.spawnPack();
    expect(s.living, 8);
    final area = s.encounterAreas[s.encounterKey]!;
    expect(area.waves, 1);
    while (s.living < CombatBalance.maxActiveEnemies) {
      area.waves = 0;
      final before = s.living;
      s.spawnPack();
      expect(s.living, greaterThan(before));
    }
    expect(s.living, 30);
    final spent = area.waves;
    s.spawnPack();
    expect(s.living, 30);
    expect(area.waves, spent);
  });

  test(
    'old forty-survivor checkpoints keep all wounded enemies across the new cap',
    () {
      final s = field();
      for (var row = 0; row < 5; row++) {
        for (var column = 0; column < 8; column++) {
          final mob = s.spawnEnemy(
            'goblin',
            Offset(6100 + column * 35, 4150 + row * 35),
          )!;
          mob.life.update(mob.life.max * .4);
        }
      }
      expect(s.living, 40);
      final old = GameCheckpoint.capture(s)!;
      expect(old.data['enemies'].length, 40);
      final restored = old.restore(GameArt())..start(TestGame());
      addTearDown(restored.dispose);
      for (var i = 0; i < 4; i++) {
        restored.elapsed += .6;
        restored.wakeEnemies();
      }
      expect(restored.living, 30);
      expect(restored.dormantEnemies, hasLength(10));
      final saved = GameCheckpoint.capture(restored)!;
      expect(saved.data['enemies'].length, 40);
      for (final enemy in saved.data['enemies']) {
        expect(
          (enemy['hp'] as num) / (enemy['maxHp'] as num),
          closeTo(.4, .000001),
        );
      }
    },
  );

  test(
    'kills and shrines never add potions; supply and first chests add both once',
    () {
      final s = field();
      final p = s.progress;
      final before = (p.healingPotions, p.energyPotions);
      for (var i = 0; i < 70; i++) {
        final mob = s.spawnEnemy('goblin', const Offset(6100, 4200))!;
        s.hit(mob, 100000, Offset.zero);
      }
      for (final tier in EnemyTier.values) {
        final mob = s.spawnEnemy(
          'goblin',
          const Offset(6100, 4200),
          tier: tier,
        )!;
        s.hit(mob, 100000, Offset.zero);
      }
      final boss = s.spawnEnemy('golem', const Offset(6200, 4200), boss: true)!;
      s.hit(boss, 100000, Offset.zero);
      expect((p.healingPotions, p.energyPotions), before);
      final site = s.world.sites.first;
      s.hero.position.setValues(site.at.dx, site.at.dy + 90);
      expect(s.cleanseNearbySite(), true);
      expect((p.healingPotions, p.energyPotions), before);
      expect(s.breakChest(0), true);
      expect(
        (p.healingPotions, p.energyPotions),
        (before.$1 + 1, before.$2 + 1),
      );
      final supplies = List.generate(s.stageChestLocations.length, (i) => i)
          .firstWhere(
            (i) => chestContent(s.world.stage, i) == ChestContent.supplies,
          );
      expect(s.breakChest(supplies), true);
      expect(
        (p.healingPotions, p.energyPotions),
        (before.$1 + 2, before.$2 + 2),
      );
      expect(s.breakChest(supplies), false);
      expect(
        (p.healingPotions, p.energyPotions),
        (before.$1 + 2, before.$2 + 2),
      );
    },
  );

  test(
    'expensive potion bundle prices charge once and reject insufficient funds',
    () {
      final s = field();
      s.progress.gold = 80;
      final healing = s.progress.healingPotions;
      expect(s.buyHeal(), true);
      expect(s.progress.gold, 0);
      expect(s.progress.healingPotions, healing + 2);
      expect(s.buyHeal(), false);
      s.progress.gold = 72;
      final resource = s.progress.energyPotions;
      expect(s.buyEnergy(), true);
      expect(s.progress.gold, 0);
      expect(s.progress.energyPotions, resource + 2);
      expect(s.buyEnergy(), false);
    },
  );

  for (final size in [
    const Size(320, 420),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets(
      'potion offers show and charge their real shared prices at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = field()..pause();
        s.progress.gold = 1000;
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          MaterialApp(
            home: EquipmentPanel(session: s, startInShop: true, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('물약'));
        await tester.pumpAndSettle();
        final heal = find.bySemanticsLabel('치유 물약 ×2 구매 · 80 골드');
        await tester.ensureVisible(heal);
        await tester.tap(heal);
        await tester.pumpAndSettle();
        expect(s.progress.gold, 920);
        final resource = find.bySemanticsLabel('분노 물약 ×2 구매 · 72 골드');
        await tester.ensureVisible(resource);
        await tester.tap(resource);
        await tester.pumpAndSettle();
        expect(s.progress.gold, 848);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      },
    );
  }
}
