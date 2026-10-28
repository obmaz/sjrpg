import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/area_damage.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/shadow_assault_effect.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field(int rank, {List<WeaponGift> gifts = const []}) {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    s.mobs.clear();
    s.waveTime = 10000;
    s.progress.level = 30;
    s.progress.ranks['shadowAssault'] = rank;
    void require(SkillDef def) {
      for (final entry in def.requires.entries) {
        final parent = s.progress.skills.firstWhere((v) => v.id == entry.key);
        require(parent);
        s.progress.ranks[entry.key] = math.max(
          s.progress.rank(entry.key),
          entry.value,
        );
      }
    }

    require(s.progress.skills.firstWhere((v) => v.id == 'shadowAssault'));
    expect(s.progress.selectSkill('shadowAssault'), true);
    s.progress.energy = s.progress.maxEnergy;
    if (gifts.isNotEmpty) {
      final gear = s.progress.createGear(
        gearById('shortsword'),
        rarity: Rarity.unique,
        gifts: gifts,
      );
      s.progress.inventory.add(gear);
      s.progress.equip(gear);
    }
    addTearDown(s.dispose);
    return s;
  }

  List<HuntEnemy> targets(Adventure s, int count, {double gap = 100}) => [
    for (var i = 0; i < count; i++)
      s.spawnEnemy('goblin', s.hero.body.center + Offset(80 + i * gap, 0))!
        ..life.initial(100000),
  ];

  void advance(Adventure s, double duration) {
    while (duration > 1e-8) {
      final dt = math.min(.01, duration);
      s.hero.update(dt);
      duration -= dt;
    }
  }

  void validPress(Adventure s) {
    final hud = s.hero.comboHud.value;
    expect(s.hero.shadowAssaultActive, true);
    advance(s, .9 * ((hud.windowStart + hud.windowEnd) / 2 - hud.progress));
    s.hero.skill();
  }

  for (final rank in [1, 2, 3, 4, 5]) {
    test(
      'rank $rank hits at most $rank distinct targets with rising damage',
      () {
        final s = field(rank), enemies = targets(s, 6);
        final skill = s.progress.skills.firstWhere(
          (v) => v.id == 'shadowAssault',
        );
        final energy = s.progress.energy, origin = s.hero.body.topLeft;
        s.holdAttack('old-held-input', true);
        s.hero.skill();
        expect(s.attackSources, isEmpty);
        expect(s.progress.energy, energy - skill.cost);
        expect(s.hero.body.topLeft, isNot(origin));
        for (var hit = 1; hit <= rank; hit++) {
          expect(s.hero.shadowAssaultTargetsHit, hit);
          expect(enemies.where((m) => m.life.value < 100000).length, hit);
          expect(
            enemies[hit - 1].life.value,
            closeTo(
              100000 - s.progress.skillDamage(skill) * (1.1 + hit * .1),
              .01,
            ),
          );
          expect(s.world.blocksEnemy(s.hero.body), false);
          expect(enemies.any((m) => m.body.overlaps(s.hero.body)), false);
          if (hit < rank) validPress(s);
        }
        expect(s.hero.shadowAssaultActive, false);
        expect(s.hero.comboHud.value.finisher, true);
        expect(s.progress.energy, energy - skill.cost);
        expect(s.hero.cooldowns[skill.id], greaterThan(0));
        expect(
          (s.game as TestGame).added.whereType<ShadowAssaultEcho>().length,
          rank * 2,
        );
      },
    );
  }

  test('splash has two-target cap and a shared twenty-percent budget', () {
    final s = field(3);
    final enemies = targets(s, 4, gap: 30);
    final skill = s.progress.skills.firstWhere((v) => v.id == 'shadowAssault');
    final base = s.progress.skillDamage(skill) * 1.2;
    s.hero.skill();
    expect(enemies[0].life.value, closeTo(100000 - base * .7, .01));
    expect(enemies[1].life.value, closeTo(100000 - base * .1 * .7, .01));
    expect(enemies[2].life.value, closeTo(100000 - base * .1 * .7, .01));
    expect(enemies[3].life.value, 100000);
    expect(s.hero.shadowAssaultTargetsHit, 1);
  });

  test('an early press, a timeout and ordinary attack end the skill', () {
    for (final ending in ['early', 'timeout', 'basic']) {
      final s = field(5), enemies = targets(s, 5);
      s.hero.skill();
      final energy = s.progress.energy;
      if (ending == 'early') {
        s.hero.skill();
      } else if (ending == 'timeout') {
        advance(s, .91);
      } else {
        s.hero.slash();
      }
      expect(s.hero.shadowAssaultActive, false, reason: ending);
      expect(enemies.skip(1).every((m) => m.life.value == 100000), true);
      expect(s.progress.energy, energy);
      expect(s.hero.cooldowns['shadowAssault'], greaterThan(0));
    }
  });

  test('a disappeared next target cannot be hit or renew the chain', () {
    final s = field(5), enemies = targets(s, 2);
    s.hero.skill();
    enemies[1].life.remove(enemies[1].life.max);
    advance(s, .01);
    expect(s.hero.shadowAssaultActive, false);
    expect(s.hero.continueShadowAssault(), false);
    expect(s.hero.shadowAssaultTargetsHit, 1);
  });

  test('the next plain attack cannot inherit an expired skill finisher', () {
    final s = field(1);
    targets(s, 2);
    s.hero.skill();
    advance(s, .6);
    expect(s.hero.shadowAssaultActive, false);
    s.hero.slash();
    expect(s.hero.comboFinisher, false);
    expect(s.hero.comboHud.value.visible, false);
  });

  test(
    'three successful skill strikes preserve existing weapon triplet gifts',
    () {
      final s = field(3, gifts: [WeaponGift.comboFury, WeaponGift.comboGuard]);
      targets(s, 3);
      s.hero.skill();
      final energy = s.progress.energy;
      validPress(s);
      validPress(s);
      expect(s.progress.energy, energy + WeaponGiftInfo.comboRageGain);
      expect(s.hero.comboGuardTime, greaterThan(0));
      expect(s.hero.comboHud.value.traitProc, true);
    },
  );

  test('blocked authored scenery cannot be crossed or attacked through', () {
    final s = field(5);
    ({Offset from, Offset to})? scenario;
    for (final prop in s.world.props) {
      for (final wall in prop.collisionBodies) {
        final center = wall.center;
        final horizontal = wall.width / 2 + 60;
        if (horizontal > 175) continue;
        final from = center - Offset(horizontal + 12, 11);
        final to = center + Offset(horizontal - 12, -11);
        if (!s.world.blocksEnemy(from & const Size(24, 22)) &&
            !s.world.blocksEnemy(to & const Size(24, 22)) &&
            !s.world.clearEnemyLine(
              from + const Offset(12, 11),
              to + const Offset(12, 11),
              const Size(3, 3),
            )) {
          scenario = (from: from, to: to);
          break;
        }
      }
      if (scenario != null) break;
    }
    expect(scenario, isNotNull);
    final pair = scenario!;
    s.hero.position.setValues(pair.from.dx, pair.from.dy);
    final origin = s.hero.body.topLeft;
    final enemy = HuntEnemy(s, 'goblin', pair.to)..combatReady = true;
    s.mobs.add(enemy);
    expect(s.canHitEnemy(enemy), true);
    final energy = s.progress.energy, hp = enemy.life.value;
    s.hero.skill();
    expect(s.hero.body.topLeft, origin);
    expect(s.hero.shadowAssaultActive, false);
    expect(s.hero.cooldowns['shadowAssault'], isNull);
    expect(s.progress.energy, energy);
    expect(enemy.life.value, hp);
  });

  test('ordinary checkpoint resume never resumes an unpaid timing chain', () {
    final s = field(3);
    targets(s, 3);
    s.hero.skill();
    final saved = GameCheckpoint.capture(s)!;
    final loaded = saved.restore(GameArt())..start(TestGame());
    addTearDown(loaded.dispose);
    expect(loaded.hero.shadowAssaultActive, false);
    expect(loaded.hero.comboHud.value.visible, false);
    expect(
      loaded.hero.cooldowns['shadowAssault'],
      s.hero.cooldowns['shadowAssault'],
    );
    expect(enemyGroupDamageScale(3), closeTo(.7, 1e-10));
  });
}
