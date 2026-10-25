import 'dart:math' as math;
import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('classes start with distinct usable weapons, skills and resources', () {
    final warrior = Progress(), mage = Progress(heroClass: HeroClass.mage);
    expect(warrior.weapon.base.heroClass, HeroClass.warrior);
    expect(mage.weapon.base.heroClass, HeroClass.mage);
    expect(warrior.selectedSkill, 'warcry');
    expect(mage.selectedSkill, 'frostNova');
    expect(warrior.rank('cleave'), 1);
    expect(mage.rank('firebolt'), 1);
    expect(warrior.energy, 25);
    expect(mage.energy, mage.maxEnergy);
    expect(warrior.stage, 1);
    expect(mage.stage, 1);
  });
  test(
    'XP unlocks skills, each investment spends one point and rank is bounded',
    () {
      final p = Progress();
      final whirlwind = warriorSkills.firstWhere((s) => s.id == 'whirlwind');
      expect(p.learn(whirlwind), false);
      expect(p.skillPoints, 1);
      p.gainXp(140);
      expect(p.level, 3);
      expect(p.stage, 1);
      expect(p.skillPoints, 3);
      expect(p.learn(whirlwind), true);
      expect(p.selectSkill('whirlwind'), true);
      expect(p.learn(mageSkills.first), false);
      expect(p.selectSkill('cleave'), false);
      p.skillPoints = 20;
      for (var i = 0; i < 12; i++) {
        p.learn(whirlwind);
      }
      expect(p.rank('whirlwind'), 5);
      expect(p.skillPoints, 16);
      expect(p.learn(whirlwind), false);
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
      expect(p.swordDamage, 18);
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
    final s = Adventure(GameArt());
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
      final s = Adventure(GameArt(), heroClass: HeroClass.mage);
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
    'free mage attacks cannot soft lock at zero mana; skills and cooldowns cannot be bypassed',
    () {
      final game = TestGame(),
          s = Adventure(GameArt(), heroClass: HeroClass.mage);
      s.start(game);
      addTearDown(s.dispose);
      s.progress.energy = 0;
      s.hero.slash();
      expect(game.added.whereType<ArcaneBolt>().length, 1);
      s.hero.skill();
      expect(s.hero.skillClock, 0);
      s.progress.energy = 90;
      s.hero.skill();
      expect(s.progress.energy, 72);
      expect(s.hero.skillClock, 6);
      s.hero.skill();
      expect(s.progress.energy, 72);
      final rank = s.progress.rank('frostNova');
      s.progress.gainXp(140);
      s.progress.learn(mageSkills.firstWhere((s) => s.id == 'chainLightning'));
      s.progress.selectSkill('chainLightning');
      s.hero.skill();
      expect(s.hero.skillClock, 5);
      s.progress.selectSkill('frostNova');
      expect(s.hero.skillClock, 6);
      expect(s.progress.rank('frostNova'), rank);
      s.pause();
      final energy = s.progress.energy;
      s.potion(energy: true);
      expect(s.progress.energy, energy);
    },
  );
  test(
    'chests reward once and stage clearance resumes exploration without resummoning',
    () {
      final s = Adventure(GameArt());
      s.start(TestGame());
      addTearDown(s.dispose);
      s.hero.position.setValues(stageChests.first.dx, stageChests.first.dy);
      s.openChest();
      s.openChest();
      expect(s.openedChests.length, 1);
      expect(s.progress.gold, 18);
      expect(s.loot.length, 1);
      s.progress.kills = 24;
      s.tick(.05);
      final boss = s.mobs.firstWhere((m) => m.boss);
      s.hit(boss, 99999, Offset.zero);
      expect(s.won, true);
      expect(s.progress.bossDefeated, true);
      expect(s.loot.where((l) => l.item.rarity == Rarity.unique).length, 1);
      s.continueExploring();
      expect(s.active, true);
      final before = s.mobs.length;
      s.spawnPack();
      s.tick(.05);
      expect(s.mobs.length, before);
      final e = stageExits.first;
      s.hero.position.setValues(e.x, e.y);
      expect(s.nearbyExit, e);
      expect(s.progress.stage, 1);
    },
  );
  test(
    'all four exits and treasure approaches admit a ground body for multiple seeds',
    () {
      for (final seed in [1, 7829, 18344]) {
        final w = AdventureWorld(seed: seed);
        for (final p in [
          ...stageChests,
          ...stageExits.map((e) => Offset(e.x, e.y)),
        ]) {
          expect(
            w.blocked(Rect.fromCenter(center: p, width: 24, height: 22)),
            false,
            reason: 'landmark $p seed $seed',
          );
          expect(w.spawnNear(p, const Size(48, 40)), isNotNull);
        }
      }
    },
  );
  test(
    'a pending enemy cannot be killed until its collision lifecycle has mounted',
    () {
      final game = TestGame()..mountEnemies = false;
      final s = Adventure(GameArt(), heroClass: HeroClass.mage);
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
    'two skill slots stay distinct and swapping cannot reset either cooldown',
    () {
      final s = Adventure(GameArt(), heroClass: HeroClass.mage);
      s.start(TestGame());
      addTearDown(s.dispose);
      s.progress.gainXp(140);
      s.progress.learn(mageSkills.firstWhere((d) => d.id == 'chainLightning'));
      expect(s.progress.secondarySkill, 'chainLightning');
      s.progress.energy = 90;
      s.hero.skill();
      s.hero.skill(secondary: true);
      expect(s.hero.cooldowns['frostNova'], 6);
      expect(s.hero.cooldowns['chainLightning'], 5);
      expect(s.progress.energy, 44);
      s.progress.selectSkill('chainLightning');
      expect(s.progress.secondarySkill, 'frostNova');
      s.hero.skill();
      s.hero.skill(secondary: true);
      expect(s.progress.energy, 44);
      expect(s.progress.selectedSkill, isNot(s.progress.secondarySkill));
    },
  );
  test(
    'boss slam locks its warning area, can be evaded and is interrupted by a stun',
    () {
      final s = Adventure(GameArt());
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
      boss.slamClock = 0;
      boss.update(.05);
      for (var i = 0; i < 19; i++) {
        boss.update(.05);
      }
      expect(
        s.progress.hp,
        closeTo(s.progress.maxHp - s.progress.mitigate(24), .001),
      );
      boss.windup = .5;
      boss.stun = 1;
      boss.update(.05);
      expect(boss.windup, 0);
      expect(boss.slamTarget, isNull);
    },
  );
  test('battle feedback remains bounded and freezes with the simulation', () {
    final s = Adventure(GameArt());
    s.start(TestGame());
    addTearDown(s.dispose);
    for (var i = 0; i < 40; i++) {
      s.bubble('+8 골드', arrival, const Color(0xffffd774));
      s.bubble('18', arrival, const Color(0xffffedb4));
    }
    expect(s.texts.where((t) => t.isReward).length, 2);
    expect(s.texts.length, 16);
    final text = s.texts.last, remaining = text.remaining;
    s.pause();
    text.update(.5);
    expect(text.remaining, remaining);
  });
}
