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

      expect(p.skillPoints, 3);
      expect(p.learn(warriorSkills.firstWhere((s) => s.id == 'mastery')), true);
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
      expect(p.swordDamage, 18 * .75);
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
      expect(s.progress.energy, 90, reason: 'the basic cast must finish first');
      for (var i = 0; i < 6; i++) {
        s.hero.update(.05);
      }
      s.hero.skill();
      expect(s.progress.energy, 72);
      expect(s.hero.skillClock, 6);
      s.hero.skill();
      expect(s.progress.energy, 72);
      final rank = s.progress.rank('frostNova');
      s.progress.gainXp(140);
      expect(
        s.progress.learn(
          mageSkills.firstWhere((skill) => skill.id == 'arcaneMastery'),
        ),
        true,
      );
      s.progress.learn(mageSkills.firstWhere((s) => s.id == 'warmth'));
      s.progress.learn(mageSkills.firstWhere((s) => s.id == 'chainLightning'));
      s.progress.selectSkill('chainLightning');
      for (var i = 0; i < 10; i++) {
        s.hero.update(.05);
      }
      s.hero.skill();
      expect(s.hero.skillClock, 5);
      s.progress.selectSkill('frostNova');
      expect(s.hero.skillClock, closeTo(5.5, .001));
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
      expect(s.living, lessThanOrEqualTo(40));
      expect(s.won, false);
      s.hero.position.setValues(4650, 360);
      expect(s.nearbyAction, null);
    },
  );
  test('forest treasure approaches admit a ground body for multiple seeds', () {
    for (final seed in [1, 7829, 18344]) {
      final w = AdventureWorld(seed: seed);
      for (final p in [...stageChests]) {
        expect(
          w.blocked(Rect.fromCenter(center: p, width: 24, height: 22)),
          false,
          reason: 'landmark $p seed $seed',
        );
        expect(w.spawnNear(p, const Size(48, 40)), isNotNull);
      }
    }
  });
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
      expect(
        s.progress.learn(
          mageSkills.firstWhere((skill) => skill.id == 'arcaneMastery'),
        ),
        true,
      );
      s.progress.learn(mageSkills.firstWhere((s) => s.id == 'warmth'));
      s.progress.learn(mageSkills.firstWhere((d) => d.id == 'chainLightning'));
      expect(s.progress.secondarySkill, 'chainLightning');
      s.progress.energy = 90;
      s.hero.skill();
      s.hero.skill(secondary: true);
      expect(s.hero.cooldowns['chainLightning'], isNull);
      expect(s.progress.energy, 72);
      for (var i = 0; i < 10; i++) {
        s.hero.update(.05);
      }
      s.hero.skill(secondary: true);
      expect(s.hero.cooldowns['frostNova'], closeTo(5.5, .001));
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
    'four learned skills fill combat slots, swap uniquely and keep their cooldowns',
    () {
      final s = Adventure(GameArt(), heroClass: HeroClass.mage);
      s.start(TestGame());
      addTearDown(s.dispose);
      final p = s.progress;
      p.gainXp(1000);
      for (final id in [
        'arcaneMastery',
        'warmth',
        'warmth',
        'iceArmor',
        'chainLightning',
        'meteor',
      ]) {
        expect(p.learn(p.skills.firstWhere((skill) => skill.id == id)), true);
      }
      expect(p.skillSlots, [
        'frostNova',
        'iceArmor',
        'chainLightning',
        'meteor',
      ]);
      for (var slot = 0; slot < 4; slot++) {
        p.energy = p.maxEnergy;
        for (var i = 0; i < 10; i++) {
          s.hero.update(.05);
        }
        s.hero.skill(slot: slot);
        expect(s.hero.cooldowns[p.skillSlots[slot]], greaterThan(0));
      }
      final cooldowns = Map<String, double>.of(s.hero.cooldowns),
          energy = p.energy;
      expect(p.selectSkill('meteor', slot: 0), true);
      expect(p.skillSlots, [
        'meteor',
        'iceArmor',
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
    'warrior ground slam fills the fourth slot and strikes the reachable front',
    () {
      final s = Adventure(GameArt());
      s.start(TestGame());
      addTearDown(s.dispose);
      final p = s.progress;
      p.gainXp(1000);
      for (final id in [
        'mastery',
        'cleave',
        'whirlwind',
        'frenzy',
        'seismicSlam',
      ]) {
        expect(p.learn(p.skills.firstWhere((skill) => skill.id == id)), true);
      }
      expect(p.skillSlots, ['warcry', 'whirlwind', 'frenzy', 'seismicSlam']);
      s.mobs.clear();
      s.hero.position.setValues(6000, 4200);
      s.hero.bearing = 0;
      final enemy = s.spawnEnemy('skeleton', const Offset(6150, 4200))!;
      final life = enemy.life.value;
      p.energy = 100;
      s.hero.skill(slot: 3);
      expect(enemy.life.value, lessThan(life));
      expect(enemy.stun, greaterThan(0));
      expect(p.energy, 76);
      expect(s.hero.cooldowns['seismicSlam'], 8);
    },
  );
  test('ground slam cannot put its impact beyond a blocking tree', () {
    final s = Adventure(GameArt());
    s.start(TestGame());
    addTearDown(s.dispose);
    s.progress.gainXp(1000);
    for (final id in ['mastery', 'cleave', 'frenzy']) {
      expect(
        s.progress.learn(
          s.progress.skills.firstWhere((skill) => skill.id == id),
        ),
        true,
      );
    }
    expect(
      s.progress.learn(
        s.progress.skills.firstWhere((skill) => skill.id == 'whirlwind'),
      ),
      true,
    );
    s.progress.learn(
      s.progress.skills.firstWhere((skill) => skill.id == 'seismicSlam'),
    );
    s.progress.selectSkill('seismicSlam');
    s.progress.energy = 100;
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
    s.mobs.clear();
    s.hero.position.setValues(tree.body.left - 70, tree.body.center.dy - 11);
    s.hero.bearing = 0;
    final enemy = s.spawnEnemy(
      'goblin',
      Offset(tree.body.right + 30, tree.body.center.dy - 11),
    )!;
    final before = enemy.life.value;
    s.hero.skill();
    expect(enemy.life.value, before);
  });
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
  test('a disposed adventure rejects late input and simulation callbacks', () {
    final s = Adventure(GameArt());
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
    final s = Adventure(GameArt());
    s.start(TestGame());
    addTearDown(s.dispose);
    final before = s.progress.skillPoints;
    for (final memory in stageMemories) {
      final at = stageChests[memory.chest];
      s.hero.position.setValues(at.dx, at.dy);
      s.openChest();
    }
    expect(s.recoveredMemories, 3);
    expect(s.memoryRewarded, true);
    expect(s.progress.skillPoints, before + 1);
    final at = stageChests[4];
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
    final s = Adventure(GameArt());
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
    expect(s.progress.energy, before + 3);
    s.hit(enemy, 1, Offset.zero, generateRage: true);
    expect(s.progress.energy, before + 3);
    s.pause();
    s.hit(enemy, 1, Offset.zero, generateRage: true);
    expect(s.progress.energy, before + 3);
  });
}
