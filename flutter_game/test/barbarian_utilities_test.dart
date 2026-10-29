import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/barbarian_utilities.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Guardian',
    )..addFont(rootBundle.load('assets-fonts/NanumGothic-Regular.ttf'))).load();
  });
  late Adventure session;
  late BarbarianUtilities utilities;
  setUp(() {
    session = inCombatField(Adventure(GameArt())..start(TestGame()));
    session.mobs.clear();
    for (final id in BarbarianUtilities.skillIds) {
      session.progress.ranks[id] = 5;
    }
    utilities = session.barbarianUtilities;
  });
  tearDown(() {
    utilities.clear();
    session.dispose();
    session.art.dispose();
  });
  SkillDef skill(String id) =>
      session.progress.skills.firstWhere((skill) => skill.id == id);
  bool activate(SkillDef skill) {
    final success = utilities.activate(skill);
    session.syncBarbarianBuffs();
    return success;
  }

  HuntEnemy corpse({ui.Offset? at, bool boss = false}) {
    final game = session.game! as TestGame;
    final before = game.added.length;
    for (var attempt = 0; attempt < 200; attempt++) {
      final enemy = HuntEnemy(
        session,
        'goblin',
        at ?? session.hero.body.center + const ui.Offset(50, 0),
        boss: boss,
      );
      enemy.life.remove(enemy.life.max);
      enemy.rewarded = true;
      utilities.recordCorpse(enemy);
      if (boss || game.added.length > before) return enemy;
    }
    throw StateError('Seeded corpse fixture could not produce a body');
  }

  HuntEnemy enemy({bool boss = false, EnemyTrait trait = EnemyTrait.none}) {
    final enemy = session.spawnEnemy(
      'goblin',
      session.hero.body.center + const ui.Offset(75, 0),
      boss: boss,
      trait: trait,
    )!;
    enemy.combatReady = true;
    return enemy;
  }

  test('ten percent corpse rolls are independent and cannot be retried', () {
    final game = session.game! as TestGame;
    final before = game.added.length;
    for (var i = 0; i < 1000; i++) {
      final enemy = HuntEnemy(session, 'goblin', session.hero.body.center);
      enemy.life.remove(enemy.life.max);
      enemy.rewarded = true;
      utilities.recordCorpse(enemy);
      final after = game.added.length;
      for (var retry = 0; retry < 5; retry++) {
        utilities.recordCorpse(enemy);
      }
      expect(game.added.length, after);
    }
    expect(game.added.length - before, inInclusiveRange(75, 125));
    expect(utilities.corpseCount, BarbarianUtilities.corpseLimit);
  });

  test(
    'accepted corpse ledger deduplicates, caps and expires in simulation time',
    () {
      final living = HuntEnemy(session, 'goblin', session.hero.body.center);
      utilities.recordCorpse(living);
      expect(utilities.corpseCount, 0);
      final first = corpse();
      utilities.recordCorpse(first);
      corpse(boss: true);
      expect(utilities.corpseCount, 1);
      for (var i = 0; i < 40; i++) {
        corpse();
      }
      expect(utilities.corpseCount, BarbarianUtilities.corpseLimit);
      session.paused = true;
      utilities.update(BarbarianUtilities.corpseLifetime + 1);
      expect(utilities.corpseCount, BarbarianUtilities.corpseLimit);
      session.paused = false;
      utilities.update(BarbarianUtilities.corpseLifetime + 1);
      expect(utilities.corpseCount, 0);
      utilities.recordCorpse(first);
      expect(
        utilities.corpseCount,
        0,
        reason: 'expiry cannot make a body reusable',
      );
    },
  );

  test(
    'corpse preflight rejects absent, unreachable and distant bodies without spend',
    () {
      final energy = session.progress.energy,
          potions = session.progress.healingPotions;
      for (final id in ['findPotion', 'findItem', 'grimWard']) {
        expect(utilities.canActivate(id), isFalse);
        expect(activate(skill(id)), isFalse);
      }
      corpse(at: session.hero.body.center + const ui.Offset(600, 0));
      expect(utilities.canActivate('findPotion'), isFalse);
      expect(activate(skill('findPotion')), isFalse);
      expect(utilities.corpseCount, 1);
      expect(session.progress.energy, energy);
      expect(session.progress.healingPotions, potions);
      expect(session.loot, isEmpty);
      utilities.clear();
      final chest = session.world.chestBody(0).center;
      session.hero.position.setValues(chest.dx - 90, chest.dy);
      corpse(at: chest);
      expect(
        (chest - session.hero.body.center).distance,
        lessThan(BarbarianUtilities.corpseRange),
      );
      expect(
        activate(skill('findItem')),
        isFalse,
        reason: 'a nearby body behind a closed chest cannot be searched',
      );
      expect(utilities.corpseCount, 1);
    },
  );

  test(
    'all three corpse skills share one consumed-body ledger and ward cap',
    () {
      corpse();
      expect(activate(skill('findPotion')), isTrue);
      expect(utilities.corpseCount, 0);
      expect(activate(skill('findItem')), isFalse);
      expect(activate(skill('grimWard')), isFalse);
      for (var i = 0; i < BarbarianUtilities.wardLimit; i++) {
        corpse();
        expect(activate(skill('grimWard')), isTrue);
      }
      corpse();
      expect(activate(skill('grimWard')), isFalse);
      expect(
        utilities.corpseCount,
        1,
        reason: 'failed capped ward keeps its corpse',
      );
      expect(utilities.wardCount, BarbarianUtilities.wardLimit);
      utilities.update(session.progress.barbarianBuffDuration('grimWard') + 1);
      expect(utilities.wardCount, 0);
      expect(activate(skill('findItem')), isTrue);
      expect(utilities.corpseCount, 0);
    },
  );

  test('howl and taunt cancel each other and spare bosses and elites', () {
    final ordinary = enemy();
    final elite = enemy(trait: EnemyTrait.armored);
    final boss = enemy(boss: true);
    expect(activate(skill('howl')), isTrue);
    expect(utilities.fearedFrom(ordinary), session.hero.body.center);
    expect(utilities.fearedFrom(elite), isNull);
    expect(utilities.fearedFrom(boss), isNull);
    expect(activate(skill('taunt')), isTrue);
    expect(utilities.taunted(ordinary), isTrue);
    expect(utilities.fearedFrom(ordinary), isNull);
    expect(utilities.outgoingDamageMultiplier(ordinary), lessThan(1));
    expect(activate(skill('howl')), isTrue);
    expect(utilities.taunted(ordinary), isFalse);
    expect(utilities.fearedFrom(ordinary), isNotNull);
    session.paused = true;
    utilities.update(10);
    expect(utilities.fearedFrom(ordinary), isNotNull);
    session.paused = false;
    utilities.update(10);
    expect(utilities.fearedFrom(ordinary), isNull);
    expect(utilities.enemyStateCount, 0);
  });

  test(
    'battle cry reduces outgoing and increases incoming only for its duration',
    () {
      final target = enemy();
      expect(activate(skill('battleCry')), isTrue);
      expect(utilities.outgoingDamageMultiplier(target), lessThan(1));
      expect(utilities.incomingDamageMultiplier(target), greaterThan(1));
      utilities.update(4);
      expect(activate(skill('taunt')), isTrue);
      utilities.update(2);
      expect(utilities.taunted(target), isTrue);
      expect(
        utilities.incomingDamageMultiplier(target),
        1,
        reason: 'taunt must not extend the old battle cry vulnerability',
      );
      expect(utilities.outgoingDamageMultiplier(target), lessThan(1));
      utilities.update(10);
      expect(utilities.outgoingDamageMultiplier(target), 1);
    },
  );

  test('buffs refresh without stacking and clear on new stage revision', () {
    for (final id in ['shout', 'battleOrders', 'battleCommand']) {
      expect(activate(skill(id)), isTrue);
    }
    final armor = utilities.armorMultiplier, life = utilities.lifeMultiplier;
    expect(armor, greaterThan(1));
    expect(life, greaterThan(1));
    expect(utilities.resourceMultiplier, life);
    expect(utilities.skillBonus, 1);
    activate(skill('shout'));
    activate(skill('battleOrders'));
    expect(utilities.armorMultiplier, greaterThan(armor));
    expect(utilities.lifeMultiplier, greaterThan(life));
    expect(
      utilities.armorMultiplier,
      session.progress.shoutArmorMultiplier(),
      reason: 'battle command adds one rank, not another stacked buff',
    );
    expect(utilities.lifeMultiplier, session.progress.battleOrdersMultiplier());
    corpse();
    session.buildRevision++;
    utilities.update(.05);
    expect(utilities.corpseCount, 0);
    expect(utilities.armorMultiplier, 1);
    expect(utilities.lifeMultiplier, 1);
    expect(utilities.skillBonus, 0);
  });

  test(
    'ward pulses fear while alive and direct war cry still damages and stuns',
    () {
      final target = enemy();
      corpse();
      expect(activate(skill('grimWard')), isTrue);
      expect(utilities.fearedFrom(target), isNotNull);
      utilities.update(.75);
      expect(utilities.fearedFrom(target), isNotNull);
      final before = target.life.value;
      final warcry = session.progress.skills.firstWhere(
        (s) => s.id == 'warcry',
      );
      expect(activate(warcry), isTrue);
      expect(target.life.value, lessThan(before));
      expect(target.stun, greaterThan(0));
      utilities.clear();
      expect(utilities.fearedFrom(target), isNull);
      expect(utilities.wardCount, 0);
    },
  );

  test('enemy control state is bounded and releases departed enemies', () {
    for (var i = 0; i < 80; i++) {
      for (final old in session.mobs) {
        old.position.setValues(13000, 9000);
      }
      final target = HuntEnemy(
        session,
        'goblin',
        session.hero.body.center + const ui.Offset(70, 0),
      )..combatReady = true;
      session.mobs.add(target);
      expect(activate(skill('taunt')), isTrue);
    }
    expect(utilities.enemyStateCount, BarbarianUtilities.enemyStateLimit);
    session.mobs.clear();
    utilities.update(.05);
    expect(utilities.enemyStateCount, 0);
  });

  for (final id in ['findPotion', 'findItem']) {
    test('$id announces successful and failed searches above the corpse', () {
      final outcomes = <String>{};
      for (var i = 0; i < 60; i++) {
        corpse();
        expect(activate(skill(id)), true);
        final messages = session.texts.where((t) => t.label.startsWith('탐색 '));
        expect(messages, isNotEmpty);
        final message = messages.last;
        expect(message.isReward, true);
        expect(message.remaining, 1.8);
        final paragraph = session.art.layoutText(
          message.label,
          size: message.textSize,
        );
        expect(
          paragraph.computeLineMetrics().length,
          2,
          reason: 'result and reward each fit one complete line',
        );
        paragraph.dispose();
        expect(message.label, isNot(contains('자원 물약')));
        outcomes.add(message.label.startsWith('탐색 성공') ? 'success' : 'failure');
      }
      expect(outcomes, {'success', 'failure'});
    });
  }

  test(
    'successful corpse searches produce real rewards without another kill',
    () {
      final kills = session.progress.kills;
      final startingPotions =
          session.progress.healingPotions + session.progress.energyPotions;
      session.progress.ranks['findPotion'] = 20;
      session.progress.ranks['findItem'] = 20;
      for (var i = 0; i < 20; i++) {
        corpse();
        expect(activate(skill('findPotion')), isTrue);
        corpse();
        expect(activate(skill('findItem')), isTrue);
      }
      expect(
        session.progress.healingPotions + session.progress.energyPotions,
        greaterThan(startingPotions),
      );
      expect(session.loot, isNotEmpty);
      expect(session.loot.length, lessThanOrEqualTo(20));
      expect(
        session.progress.kills,
        kills,
        reason: 'searching corpses does not repeat death or XP rewards',
      );
      expect(utilities.corpseCount, 0);
    },
  );

  test(
    'dispel removes beneficial shouts and preserves corpse and enemy state',
    () {
      final target = enemy();
      corpse();
      activate(skill('grimWard'));
      corpse();
      for (final id in [
        'shout',
        'battleOrders',
        'battleCommand',
        'battleCry',
      ]) {
        expect(activate(skill(id)), isTrue);
      }
      utilities.dispelBuffs();
      expect(utilities.armorMultiplier, 1);
      expect(utilities.lifeMultiplier, 1);
      expect(utilities.resourceMultiplier, 1);
      expect(utilities.skillBonus, 0);
      expect(utilities.corpseCount, 1);
      expect(utilities.wardCount, 1);
      expect(utilities.incomingDamageMultiplier(target), greaterThan(1));
    },
  );

  test(
    'actual accepted death creates one searchable corpse and no second reward',
    () {
      var target = enemy();
      for (var attempt = 0; attempt < 200; attempt++) {
        expect(
          session.hit(target, target.life.max + 1, ui.Offset.zero),
          isTrue,
        );
        if (utilities.corpseCount > 0) break;
        target = enemy();
      }
      final kills = session.progress.kills - 1;
      expect(target.rewarded, isTrue);
      expect(utilities.corpseCount, 1);
      expect(session.progress.kills, kills + 1);
      expect(activate(skill('findPotion')), isTrue);
      expect(utilities.corpseCount, 0);
      expect(activate(skill('findItem')), isFalse);
      expect(activate(skill('grimWard')), isFalse);
      expect(session.hit(target, target.life.max + 1, ui.Offset.zero), isFalse);
      expect(session.progress.kills, kills + 1);
      expect(utilities.corpseCount, 0);
    },
  );

  test('real skill input spends only when a corpse action can execute', () {
    final p = session.progress;
    p.selectedSkill = 'findPotion';
    p.energy = p.maxEnergy;
    final before = p.energy;
    session.hero.skill();
    expect(p.energy, before);
    expect(session.hero.cooldowns['findPotion'] ?? 0, 0);
    corpse();
    session.hero.skill();
    expect(utilities.corpseCount, 0);
    expect(p.energy, before - p.skillCost(p.activeSkill));
    expect(session.hero.cooldowns['findPotion'], greaterThan(0));
    final paid = p.energy;
    session.hero.cooldowns['findPotion'] = 0;
    session.hero.castLock = 0;
    session.hero.skill();
    expect(p.energy, paid);
    expect(session.hero.cooldowns['findPotion'], 0);
  });

  test(
    'source-duration shouts persist past cooldown and then expire without stacking',
    () {
      final shout = session.progress.skills.firstWhere((s) => s.id == 'shout');
      final duration = session.progress.barbarianBuffDuration('shout');
      final cooldown = session.progress.skillCooldown(shout);
      expect(duration, greaterThan(cooldown));
      expect(activate(shout), isTrue);
      final strength = utilities.armorMultiplier;
      utilities.update(cooldown + .05);
      expect(utilities.armorMultiplier, strength);
      expect(activate(shout), isTrue);
      expect(utilities.armorMultiplier, strength);
      utilities.update(duration + .05);
      session.syncBarbarianBuffs();
      expect(utilities.armorMultiplier, 1);
      expect(session.progress.activeArmorMultiplier, 1);
    },
  );
}
