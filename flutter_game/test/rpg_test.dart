import 'dart:math' as math;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/sorceress_combat.dart';
import 'package:guardian_new/world_model.dart';

import 'support/sorceress_fixture.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('classes start with distinct usable weapons, skills and resources', () {
    final warrior = Progress(), mage = Progress(heroClass: HeroClass.mage);
    expect(warrior.weapon.base.heroClass, HeroClass.warrior);
    expect(mage.weapon.base.heroClass, HeroClass.mage);
    expect(warrior.selectedSkill, 'howl');
    expect(mage.selectedSkill, 'firebolt');
    expect(warrior.rank('cleave'), 1);
    expect(mage.rank('firebolt'), 1);
    expect(warrior.energy, 25);
    expect(mage.energy, mage.maxEnergy);
  });
  test(
    'XP unlocks skills, each investment spends one point and rank is bounded',
    () {
      final p = Progress();
      final whirlwind = warriorSkills.firstWhere((s) => s.id == 'whirlwind');
      expect(p.learn(whirlwind), false);
      expect(p.skillPoints, 2);
      p.gainXp(106);
      expect(p.level, 3);

      expect(p.skillPoints, 4);
      final bash = p.skills.firstWhere((s) => s.id == 'bash');
      final doubleSwing = p.skills.firstWhere((s) => s.id == 'doubleSwing');
      expect(p.learn(bash), true);
      expect(p.learn(doubleSwing), false, reason: 'requires level six');
      expect(p.selectSkill('bash'), true);
      expect(p.learn(mageSkills.first), false);
      expect(p.selectSkill('cleave'), true);
      p.level = 100;
      expect(p.learn(doubleSwing), true);
      p.skillPoints = 100;
      for (var i = 0; i < 24; i++) {
        p.learn(bash);
      }
      expect(p.rank('bash'), 20);
      expect(p.skillPoints, 81);
      expect(p.learn(bash), false);
    },
  );
  test(
    'equipping and selling own gear changes stats without creating life or removing equipped gear',
    () {
      final p = Progress();
      final charm = p.createGear(
        gearById('amber'),
        rarity: Rarity.rare,
        vitality: 20,
      );
      p.collect(charm);
      p.hp = 33;
      expect(p.equip(charm), true);
      expect(p.maxHp, 140);
      expect(p.hp, 33);
      expect(p.sell(charm), false);
      final other = p.createGear(gearById('fang'));
      p.collect(other);
      p.equip(other);
      expect(p.maxHp, 100);
      expect(p.hp, 33);
      expect(p.swordDamage, 18 * Progress.playerDamageScale);
      expect(p.sell(charm), true);
      expect(p.inventory.contains(charm), false);
      final foreign = p.createGear(gearById('wand'));
      p.collect(foreign);
      expect(p.equip(foreign), false);
      expect(p.equip(Gear(999, gearById('greatsword'))), false);
    },
  );
  test(
    'loot covers class equipment with independent rolls and common copies only show gold',
    () {
      for (final c in HeroClass.values) {
        final p = Progress(heroClass: c),
            random = math.Random(74),
            rolls = List<Gear>.generate(400, (_) => p.rollLoot(math.Random(1)));
        // A deterministic sequence must still produce genuinely different bases/options.
        final sequence = List<Gear>.generate(400, (_) => p.rollLoot(random));
        expect(sequence.map((g) => g.base.id).toSet().length, greaterThan(10));
        expect(sequence.every((g) => g.base.usable(c)), true);
        expect(rolls.map((g) => g.serial).toSet().length, 400);
        final duplicate = p.createGear(p.weapon.base), gold = p.gold;
        expect(p.collect(duplicate), false);
        expect(p.gold, greaterThan(gold));
        final rolled = p.createGear(
          p.weapon.base,
          rarity: Rarity.rare,
          power: 7,
        );
        expect(p.collect(rolled), true);
        expect(p.weapon.base.attack, c == HeroClass.warrior ? 15 : 14);
      }
    },
  );
  test('a full bag leaves loot on the ground until room is made', () {
    final s = inCombatField(Adventure(GameArt()));
    s.start(TestGame());
    addTearDown(s.dispose);
    while (s.progress.inventory.length < Progress.capacity) {
      s.progress.inventory.add(
        s.progress.createGear(gearById('amber'), rarity: Rarity.magic),
      );
    }
    final item = GroundLoot(
      s,
      s.progress.createGear(gearById('longsword'), rarity: Rarity.rare),
      s.hero.body.center,
    );
    item.tryCollect();
    expect(item.collected, false);
    expect(s.progress.inventory.length, 24);
    s.progress.sell(s.progress.inventory.last);
    item.tryCollect();
    expect(item.collected, true);
    expect(s.progress.inventory.length, 24);
    item.tryCollect();
    expect(s.progress.inventory.length, 24);
  });
  test(
    'an arcane bolt sweeps to the first enemy and stops before a solid obstacle',
    () {
      final s = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage));
      s.start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      final center = s.world.bridge.center;
      final near = s.spawnEnemy('goblin', center - const Offset(65, 11))!,
          far = s.spawnEnemy('goblin', center + const Offset(90, -11))!;
      final bolt = ArcaneBolt(s, center - const Offset(200, 0), 0, 10);
      for (var i = 0; i < 20 && !bolt.resolved; i++) {
        bolt.update(.05);
      }
      expect(near.life.value, near.life.max - 10);
      expect(far.life.value, far.life.max);
      final prop = s.world.props.firstWhere((p) => p.kind == 'tree'),
          from = prop.body.center - const Offset(75, 0);
      final blocked = ArcaneBolt(s, from, 0, 999);
      for (var i = 0; i < 10 && !blocked.resolved; i++) {
        blocked.update(.05);
      }
      expect(blocked.position.x, lessThan(prop.body.right));
    },
  );
  test(
    'zero mana prevents basic attacks while paid spell buffering preserves cast locks',
    () {
      final game = TestGame(),
          s = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage))
            ..start(game);
      addTearDown(s.dispose);
      s.mobs.clear();
      final p = s.progress
        ..level = 100
        ..skillPoints = 1000;
      trainSkill(p, 'frostNova');
      p.selectBasic('firebolt');
      p.selectSkill('frostNova');
      final enemy = s.spawnEnemy('goblin', const Offset(6050, 4200))!
        ..life.initial(10000);
      p.energy = 0;
      s.hero.slash();
      expect(game.added.whereType<SorceressProjectile>(), isEmpty);
      expect(enemy.life.value, 10000);
      expect(s.hero.attackClock, 0);
      expect(s.hero.castLock, 0);
      expect(p.energy, 0);
      expect(
        p.selectedBasic,
        'firebolt',
        reason: 'mana shortage preserves the selected spell',
      );
      s.hero.skill();
      expect(s.hero.queuedCast, isNull);
      p.energy = 90;
      s.hero.attackClock = 0;
      s.hero.slash();
      expect(game.added.whereType<SorceressProjectile>(), hasLength(1));
      final afterBasic = p.energy, cost = p.skillCost(p.activeSkill);
      s.hero.skill();
      expect(s.hero.queuedCast, isNotNull);
      expect(p.energy, afterBasic);
      for (var i = 0; i < 60 && s.hero.queuedCast != null; i++) {
        s.hero.update(.05);
      }
      expect(s.hero.queuedCast, isNull);
      expect(p.energy, afterBasic - cost);
      expect(
        s.hero.cooldowns['frostNova'],
        0,
        reason: 'untimed D2 Nova is gated by its cast animation',
      );
      expect(s.hero.castLock, greaterThan(0));
      s.hero.skill();
      expect(p.energy, afterBasic - cost);
      expect(s.hero.queuedCast, isNotNull);
      s.pause();
      final energy = p.energy;
      s.potion(energy: true);
      expect(p.energy, energy);
      expect(s.hero.queuedCast, isNull);
    },
  );
  test(
    'chests reward once and stage clearance resumes exploration without resummoning',
    () {
      final s = inCombatField(Adventure(GameArt()));
      s.start(TestGame());
      addTearDown(s.dispose);
      s.hero.position.setValues(
        s.stageChestLocations.first.dx,
        s.stageChestLocations.first.dy,
      );
      s.openChest();
      s.openChest();
      expect(s.openedChests.length, 1);
      expect(s.progress.gold, 18);
      expect(s.loot.length, 1);
      // The enlarged village protects this starter chest; fight outside it.
      inCombatField(s);
      s.cleansedSites.addAll(questSites.map((q) => q.id));
      s.progress.kills = stageKillGoal;
      s.tick(.05);
      final boss = s.mobs.firstWhere((m) => m.boss);
      s.hit(boss, 99999, Offset.zero);
      expect(s.won, true);
      expect(s.progress.bossDefeated, true);
      expect(s.loot.where((l) => l.item.rarity == Rarity.rare).length, 1);
      s.continueExploring();
      expect(s.active, true);
      final before = s.mobs.where((m) => m.boss).length;
      s.spawnPack();
      s.tick(.05);
      expect(s.mobs.where((m) => m.boss).length, before);
      expect(s.living, lessThanOrEqualTo(28));
      expect(s.won, false);
      s.hero.position.setValues(4650, 360);
      expect(s.nearbyAction, null);
    },
  );
  test('forest treasure approaches admit a ground body for multiple seeds', () {
    for (final seed in [1, 7829, 18344]) {
      final w = AdventureWorld(seed: seed);
      for (final (index, p) in w.chests.indexed) {
        expect(w.blocked(w.chestBody(index)), true);
        final approaches = [
          for (final radius in [70.0, 110.0, 150.0])
            for (var direction = 0; direction < 16; direction++)
              p +
                  Offset(
                        math.cos(direction * math.pi / 8),
                        math.sin(direction * math.pi / 8),
                      ) *
                      radius,
        ];
        expect(
          approaches.any(
            (at) =>
                !w.blocked(
                  Rect.fromCenter(center: at, width: 48, height: 40),
                ) &&
                w.clearLine(at, w.chestApproach(index, at), const Size(3, 3)),
          ),
          true,
          reason: 'a whole ground body can approach chest $index, seed $seed',
        );
      }
    }
  });
  test(
    'a pending enemy cannot be killed until its collision lifecycle has mounted',
    () {
      final game = TestGame()..mountEnemies = false;
      final s = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage));
      s.start(game);
      addTearDown(s.dispose);
      final enemy = s.mobs.first, hp = enemy.life.value;
      s.hit(enemy, 99999, Offset.zero);
      expect(enemy.life.value, hp);
      expect(s.progress.kills, 0);
      enemy.combatReady = true;
      s.hit(enemy, 99999, Offset.zero);
      expect(s.progress.kills, 1);
    },
  );
  test(
    'timed spell slots remain distinct and swapping cannot reset their shared D2 delay',
    () {
      final s = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage))
        ..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      final p = s.progress
        ..level = 100
        ..skillPoints = 1000;
      for (final id in ['meteor', 'frozenOrb', 'chainLightning']) {
        trainSkill(p, id);
      }
      p.selectSkill('meteor', slot: 0);
      p.selectSkill('frozenOrb', slot: 1);
      p.selectSkill('chainLightning', slot: 2);
      p.energy = p.maxEnergy;
      final energy = p.energy, meteor = p.activeSkill;
      s.hero.skill();
      final paid = energy - p.skillCost(meteor),
          delay = p.skillCooldown(meteor);
      expect(p.energy, paid);
      expect(delay, greaterThan(0));
      expect(s.hero.cooldowns['meteor'], delay);
      expect(s.hero.cooldowns['frozenOrb'], delay);
      p.selectSkill('frozenOrb', slot: 0);
      expect(p.secondarySkill, 'meteor');
      s.hero.skill();
      s.hero.skill(secondary: true);
      expect(p.energy, paid);
      for (var i = 0; i < 4; i++) {
        s.hero.update(.05);
      }
      expect(s.hero.cooldowns['meteor'], closeTo(delay - .2, .000001));
      expect(s.hero.cooldowns['frozenOrb'], closeTo(delay - .2, .000001));
      s.hero.skill(slot: 2);
      expect(s.hero.queuedCast, isNotNull);
      for (var i = 0; i < 60 && s.hero.queuedCast != null; i++) {
        s.hero.update(.05);
      }
      final chain = p.skillAt(2)!;
      expect(p.energy, closeTo(paid - p.skillCost(chain), .000001));
      expect(s.hero.cooldowns[chain.id], 0);
      expect(
        s.hero.cooldowns['meteor'],
        greaterThan(0),
        reason: 'untimed lightning remains usable during timed-spell delay',
      );
      expect(p.selectedSkill, isNot(p.secondarySkill));
    },
  );
  test(
    'four learned skills fill combat slots, swap uniquely and keep their cooldowns',
    () {
      final s = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage));
      s.start(TestGame());
      addTearDown(s.dispose);
      final p = s.progress;
      p.level = 100;
      p.skillPoints = 1000;
      final ids = ['frostNova', 'frozenArmor', 'chainLightning', 'meteor'];
      for (final id in ids) {
        trainSkill(p, id);
      }
      for (final entry in ids.asMap().entries) {
        expect(p.selectSkill(entry.value, slot: entry.key), true);
      }
      expect(p.skillSlots, ids);
      for (var slot = 0; slot < 4; slot++) {
        final maximumSteps = (s.hero.castLock / .05).ceil() + 1;
        for (var i = 0; i < maximumSteps && s.hero.castLock > 0; i++) {
          s.hero.update(math.min(.05, s.hero.castLock));
        }
        expect(s.hero.castLock, 0);
        expect(s.hero.queuedCast, isNull);
        p.energy = p.maxEnergy;
        final skill = p.skillAt(slot)!, energy = p.energy;
        s.hero.skill(slot: slot);
        expect(s.hero.cooldowns[skill.id], p.skillCooldown(skill));
        expect(p.energy, energy - p.skillCost(skill));
      }
      final cooldowns = Map<String, double>.of(s.hero.cooldowns),
          energy = p.energy;
      expect(p.selectSkill('meteor', slot: 0), true);
      expect(p.skillSlots, [
        'meteor',
        'frozenArmor',
        'chainLightning',
        'frostNova',
      ]);
      s.hero.skill();
      s.hero.skill(slot: 3);
      expect(s.hero.cooldowns, cooldowns);
      expect(p.energy, energy);
      expect(p.selectSkill('meteor', slot: 4), false);
      expect(Progress.fromSave(p.toSave())!.skillSlots, p.skillSlots);
      final older = p.toSave()
        ..remove('tertiarySkill')
        ..remove('quaternarySkill');
      final migrated = Progress.fromSave(older)!;
      expect(migrated.selectedSkill, p.selectedSkill);
      expect(migrated.secondarySkill, p.secondarySkill);
      expect(migrated.skillSlots.toSet().length, 4);
      final duplicate = p.toSave();
      duplicate['tertiarySkill'] = p.selectedSkill;
      expect(Progress.fromSave(duplicate), null);
    },
  );
  test(
    'warrior leap attack fills the fourth slot and strikes after landing',
    () {
      final s = inCombatField(Adventure(GameArt()))..start(TestGame());
      addTearDown(s.dispose);
      final p = s.progress;
      p.level = 100;
      p.skillPoints = 100;
      p.ranks.addAll({'bash': 1, 'doubleSwing': 1, 'leap': 1, 'leapAttack': 1});
      p.selectSkill('bash', slot: 1);
      p.selectSkill('doubleSwing', slot: 2);
      p.selectSkill('leapAttack', slot: 3);
      expect(p.skillSlots, ['howl', 'bash', 'doubleSwing', 'leapAttack']);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      s.hero.bearing = 0;
      final enemy = s.spawnEnemy('skeleton', const Offset(6150, 4200))!;
      final life = enemy.life.value;
      p.energy = 100;
      s.hero.skill(slot: 3);
      expect(enemy.life.value, life);
      for (var i = 0; i < 20; i++) {
        s.hero.update(.05);
      }
      expect(enemy.life.value, lessThan(life));
      expect(s.hero.barbarianCombat.airborne, false);
      expect(p.energy, 88);
      expect(
        s.hero.cooldowns['leapAttack'],
        lessThan(p.skillCooldown(p.skillAt(3)!)),
      );
    },
  );
  test('leap attack cannot cross or strike through a blocking tree', () {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    s.progress.level = 100;
    s.progress.ranks.addAll({'leap': 1, 'leapAttack': 1});
    s.progress.selectSkill('leapAttack');
    s.progress.energy = 100;
    final tree = s.world.props.firstWhere(
      (p) =>
          p.kind == 'tree' &&
          !s.world.blocked(
            Rect.fromLTWH(p.body.left - 70, p.body.center.dy - 12, 28, 24),
          ) &&
          !s.world.blocked(
            Rect.fromLTWH(p.body.right + 30, p.body.center.dy - 11, 24, 22),
          ),
    );
    s.mobs.clear();
    s.hero.position.setValues(tree.body.left - 70, tree.body.center.dy - 12);
    s.hero.bearing = 0;
    final enemy = s.spawnEnemy(
      'goblin',
      Offset(tree.body.right + 30, tree.body.center.dy - 11),
    )!;
    final before = enemy.life.value;
    s.hero.skill();
    for (var i = 0; i < 20; i++) {
      s.hero.update(.05);
    }
    expect(enemy.life.value, before);
    expect(s.hero.body.right, lessThanOrEqualTo(tree.body.left));
  });
  test(
    'boss slam locks its warning area, can be evaded and is interrupted by a stun',
    () {
      final s = inCombatField(Adventure(GameArt()));
      s.start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      final center = s.world.bridge.center;
      s.hero.position.setValues(center.dx - 100, center.dy - 11);
      final boss = s.spawnEnemy(
        'golem',
        center + const Offset(60, -20),
        boss: true,
      )!..slamClock = 0;
      boss.update(.05);
      expect(boss.windup, greaterThan(0));
      final locked = boss.slamTarget;
      final moved = s.world.move(
        s.hero.position.toOffset(),
        const Offset(-150, 0),
        s.hero.body.size,
      );
      s.hero.position.setValues(moved.dx, moved.dy);
      expect(boss.slamTarget, locked);
      for (var i = 0; i < 20; i++) {
        boss.update(.05);
      }
      expect(s.progress.hp, s.progress.maxHp);
      s.hero.position.setValues(center.dx - 100, center.dy - 11);
      // Replay the same basic slam; the normal next cast is now a root net.
      boss.bossSequence = 0;
      boss.slamClock = 0;
      boss.update(.05);
      for (var i = 0; i < 19; i++) {
        boss.update(.05);
      }
      expect(
        s.progress.hp,
        closeTo(
          s.progress.maxHp - s.progress.mitigate(boss.outgoingDamage(24)),
          .001,
        ),
      );
      boss.windup = .5;
      boss.stun = 1;
      boss.update(.05);
      expect(boss.windup, 0);
      expect(boss.slamTarget, isNull);
    },
  );
  test('battle feedback remains bounded and freezes with the simulation', () {
    final s = inCombatField(Adventure(GameArt()));
    s.start(TestGame());
    addTearDown(s.dispose);
    for (var i = 0; i < 40; i++) {
      s.bubble('+8 골드', arrival, const Color(0xffffd774));
      s.bubble('18', arrival, const Color(0xffffedb4));
    }
    expect(s.texts.where((t) => t.isReward).length, 2);
    expect(s.texts.length, inInclusiveRange(3, 16));
    final text = s.texts.last, remaining = text.remaining;
    s.pause();
    text.update(.5);
    expect(text.remaining, remaining);
  });
  test('a disposed adventure rejects late input and simulation callbacks', () {
    final s = inCombatField(Adventure(GameArt()));
    s.start(TestGame());
    final enemy = s.mobs.first;
    s.dispose();
    s.holdAttack('touch', true);
    s.hero.slash();
    s.hero.skill();
    s.hit(enemy, 99999, Offset.zero);
    s.tick(.05);
    expect(s.active, false);
    expect(s.attackSources, isEmpty);
    expect(s.hero.strikes, 0);
    expect(s.progress.kills, 0);
    expect(s.elapsed, 0);
  });
  test('three story chests grant one optional skill point only once', () {
    final s = inCombatField(Adventure(GameArt()));
    s.start(TestGame());
    addTearDown(s.dispose);
    final before = s.progress.skillPoints;
    for (final memory in stageMemories) {
      final at = s.stageChestLocations[memory.chest];
      s.hero.position.setValues(at.dx, at.dy);
      s.openChest();
    }
    expect(s.recoveredMemories, 3);
    expect(s.memoryRewarded, true);
    expect(s.progress.skillPoints, before + 1);
    final at = s.stageChestLocations[4];
    s.hero.position.setValues(at.dx, at.dy);
    s.openChest();
    s.openChest();
    expect(s.progress.skillPoints, before + 1);
    expect(s.openedChests.length, 4);
    expect(s.noticeTime, 0);
  });
  test('level ups restore a limited portion of life', () {
    final p = Progress();
    p.hp = 10;
    p.gainXp(p.nextLevelXp);
    expect(p.level, 2);
    expect(p.hp, 10 + p.maxHp * .2);
    expect(p.hp, lessThan(p.maxHp));
  });
  test('warrior rage requires a real hit rather than empty swings', () {
    final s = inCombatField(Adventure(GameArt()));
    s.start(TestGame());
    addTearDown(s.dispose);
    final enemy = s.mobs.first;
    s.mobs.clear();
    final before = s.progress.energy;
    for (var i = 0; i < 20; i++) {
      s.hero.attackClock = 0;
      s.hero.slash();
    }
    expect(s.progress.energy, before);
    s.hit(enemy, 1, Offset.zero, generateRage: true);
    expect(s.progress.energy, closeTo(before + 2.1, .000001));
    s.hit(enemy, 1, Offset.zero, generateRage: true);
    expect(s.progress.energy, closeTo(before + 2.1, .000001));
    s.pause();
    s.hit(enemy, 1, Offset.zero, generateRage: true);
    expect(s.progress.energy, closeTo(before + 2.1, .000001));
  });
}
