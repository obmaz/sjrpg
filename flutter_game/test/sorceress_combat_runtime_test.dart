import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/skill_aim.dart';
import 'package:guardian_new/skill_preview_model.dart';
import 'package:guardian_new/sorceress_combat.dart';
import 'package:guardian_new/sorceress_rules.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field(String id, {int rank = 1}) {
    final s = inCombatField(Adventure(GameArt(), heroClass: HeroClass.mage))
      ..start(TestGame());
    s.mobs.clear();
    s.waveTime = 10000;
    s.progress.level = 100;
    s.progress.skillPoints = 1000;
    final skill = s.progress.skills.firstWhere((x) => x.id == id);
    void learn(SkillDef def) {
      for (final requirement in def.requires.entries) {
        final parent = s.progress.skills.firstWhere(
          (v) => v.id == requirement.key,
        );
        learn(parent);
        s.progress.ranks[parent.id] = math.max(
          requirement.value,
          s.progress.rank(parent.id),
        );
      }
    }

    learn(skill);
    s.progress.ranks[id] = rank;
    if (id == 'sorceressAttack') {
      s.progress.selectedBasic = id;
    } else if (id != 'blink') {
      expect(s.progress.selectSkill(id), true);
    }
    s.progress.energy = s.progress.maxEnergy;
    s.hero.bearing = 0;
    addTearDown(s.dispose);
    return s;
  }

  HuntEnemy enemy(Adventure s, double distance, {bool boss = false}) =>
      s.spawnEnemy(
        'goblin',
        s.hero.body.center + Offset(distance, 0),
        boss: boss,
      )!..life.initial(100000);
  List<SorceressEffect> effects(Adventure s) =>
      (s.game as TestGame).added.whereType<SorceressEffect>().toList();
  void advance(Adventure s, double seconds) {
    while (seconds > 1e-8) {
      final dt = math.min(.02, seconds);
      s.tick(dt);
      s.hero.update(dt);
      for (final effect in effects(s)) {
        effect.update(dt);
      }
      seconds -= dt;
    }
  }

  for (final id in [
    'firebolt',
    'iceBolt',
    'iceBlast',
    'fireball',
    'glacialSpike',
  ]) {
    test('$id pays once and travels before an actual elemental hit', () {
      final s = field(id), m = enemy(s, 115), def = s.progress.skillAt(0)!;
      final spec = s.progress.sorceressSpell(def), energy = s.progress.energy;
      s.hero.skill();
      expect(m.life.value, 100000);
      expect(s.progress.energy, closeTo(energy - spec.manaCost, 1e-8));
      expect(effects(s).whereType<SorceressProjectile>().length, 1);
      advance(s, .5);
      final lost = 100000 - m.life.value;
      final preview = previewSkill(s.progress, def);
      expect(
        preview.firstWhere((v) => v.label == '1회 최소 피해').current,
        spec.minDamage,
      );
      expect(
        preview.firstWhere((v) => v.label == '1회 최대 피해').current,
        spec.maxDamage,
      );
      expect(lost, greaterThanOrEqualTo(spec.minDamage - 1e-8));
      expect(lost, lessThanOrEqualTo(spec.maxDamage + 1e-8));
      if (spec.freezeDuration > 0) expect(m.stun, greaterThan(0));
      if (spec.damageType == SorceressDamageType.cold) {
        expect(m.slow, greaterThan(0));
      }
    });
  }
  test('charged bolts wander as distinct real missiles and remain bounded', () {
    final s = field('chargedBolt', rank: 8);
    s.hero.skill();
    final bolts = effects(s).whereType<SorceressProjectile>().toList();
    expect(
      bolts.length,
      s.progress.sorceressSpell(s.progress.skillAt(0)!).projectileCount,
    );
    advance(s, .1);
    expect(bolts.map((b) => b.position.y).toSet().length, greaterThan(5));
    advance(s, 3);
    expect(bolts.every((b) => b.finished), true);
  });
  test('nova and frost nova hit eligible enemies once with shared damage', () {
    for (final id in ['nova', 'frostNova']) {
      final s = field(id), m = enemy(s, 60), other = enemy(s, 110);
      s.hero.skill();
      expect(m.life.value, lessThan(100000));
      expect(other.life.value, lessThan(100000));
      final hp = m.life.value;
      advance(s, .4);
      expect(m.life.value, hp);
    }
  });
  test('static field is current-health percentage and respects boss floor', () {
    final s = field('staticField', rank: 20), m = enemy(s, 75, boss: true);
    for (var i = 0; i < 20; i++) {
      s.hero.castLock = 0;
      s.progress.energy = s.progress.maxEnergy;
      s.hero.skill();
    }
    expect(m.life.value, closeTo(50000, 1e-6));
    final hp = m.life.value;
    s.hero.castLock = 0;
    s.hero.skill();
    expect(m.life.value, hp);
  });
  test(
    'Static Field removes exactly one quarter independently from two enemies',
    () {
      final s = field('staticField', rank: 20),
          one = enemy(s, 75),
          two = enemy(s, 125);
      s.hero.skill();
      expect(one.life.value, 75000);
      expect(two.life.value, 75000);
    },
  );
  test('Teleport crosses a closed obstacle but never ends inside it', () {
    final s = field('blink'), world = s.world, size = s.hero.body.size;
    Offset? from, goal;
    double? angle;
    for (final chest in world.chests) {
      for (final unit in [const Offset(1, 0), const Offset(0, 1)]) {
        final a = chest - unit * 80 - Offset(size.width / 2, size.height / 2);
        final b = chest + unit * 80 - Offset(size.width / 2, size.height / 2);
        if (!world.blocked(a & size) && !world.blocked(b & size)) {
          from = a;
          goal = b;
          angle = math.atan2(unit.dy, unit.dx);
          break;
        }
      }
      if (from != null) break;
    }
    expect(from, isNotNull);
    s.hero.position.setValues(from!.dx, from.dy);
    s.hero.bearing = angle!;
    const spec = SorceressSpellStats(
      id: 'blink',
      rank: 1,
      damageType: SorceressDamageType.none,
      range: 160,
    );
    final landing = s.hero.sorceressCombat.teleportLanding(spec, null);
    expect(landing, isNotNull);
    expect((landing! - goal!).distance, lessThan(.01));
    expect(
      world.clearLine(from, landing, size),
      false,
      reason: 'the closed chest blocks a walking corridor',
    );
    final blockedEnd = s.hero.sorceressCombat.teleportLanding(
      const SorceressSpellStats(
        id: 'blink',
        rank: 1,
        damageType: SorceressDamageType.none,
        range: 80,
      ),
      null,
    );
    expect(blockedEnd, isNotNull);
    expect(world.blocked(blockedEnd! & size), false);
    expect((blockedEnd - (from + (goal - from) / 2)).distance, greaterThan(15));
  });
  test('a peaceful launch stays prop-only after its caster leaves town', () {
    final s = field('firebolt'), m = enemy(s, 100);
    final spec = s.progress.sorceressSpell(s.progress.skillAt(0)!);
    final projectile = SorceressProjectile(
      s.hero.sorceressCombat,
      spec,
      s.hero.body.center,
      bearing: 0,
      damageAmount: 10000,
      propOnly: true,
    );
    for (var i = 0; i < 40; i++) {
      projectile.update(.02);
    }
    expect(m.life.value, 100000);
  });
  test(
    'lightning pierces a real line but cannot hit enemies behind the caster',
    () {
      final s = field('lightning'),
          one = enemy(s, 95),
          two = enemy(s, 180),
          behind = enemy(s, -100);
      final aim = SkillAim(0, 'lightning', 0)..delta = const Offset(74, 0);
      s.hero.skill(manualAim: aim);
      expect(one.life.value, lessThan(100000));
      expect(two.life.value, lessThan(100000));
      expect(behind.life.value, 100000);
    },
  );
  test(
    'chain lightning bounces once per distinct enemy with a bounded budget',
    () {
      final s = field('chainLightning'), m = enemy(s, 100), two = enemy(s, 180);
      s.hero.skill();
      expect(m.life.value, lessThan(100000));
      expect(two.life.value, lessThan(100000));
      final hp = m.life.value;
      advance(s, .4);
      expect(m.life.value, hp);
    },
  );
  test(
    'delayed spells share one timer and do not spend on a rejected cast',
    () {
      final s = field('meteor');
      s.progress.ranks['blizzard'] = 1;
      s.hero.skill();
      final mana = s.progress.energy;
      expect(s.hero.sorceressCombat.sharedDelay, greaterThan(0));
      expect(s.progress.selectSkill('blizzard'), true);
      s.hero.castLock = 0;
      s.hero.skill();
      expect(s.progress.energy, mana);
      expect(effects(s).whereType<SorceressMeteor>().length, 1);
      expect(effects(s).whereType<SorceressGround>(), isEmpty);
    },
  );
  test('meteor waits for contact then leaves an independently timed burn', () {
    final s = field('meteor'), m = enemy(s, 150);
    s.hero.skill();
    advance(s, 2.2);
    expect(m.life.value, 100000);
    advance(s, .3);
    expect(m.life.value, lessThan(100000));
    expect(effects(s).whereType<SorceressGround>(), isNotEmpty);
    final hp = m.life.value;
    advance(s, .4);
    expect(m.life.value, lessThan(hp));
  });
  test('hydra owns exactly three physical mouths and seeks valid targets', () {
    final s = field('hydra'), m = enemy(s, 190);
    s.hero.skill();
    advance(s, .1);
    expect(effects(s).whereType<SorceressHydra>().length, 1);
    expect(effects(s).whereType<SorceressProjectile>().length, 3);
    advance(s, .6);
    expect(m.life.value, lessThan(100000));
  });
  test(
    'frozen orb emits exactly thirty rotating and sixteen terminal shards',
    () {
      final s = field('frozenOrb');
      s.hero.skill();
      advance(s, 1.5);
      final missiles = effects(s).whereType<SorceressProjectile>().toList();
      expect(missiles.where((p) => p.orb).length, 1);
      expect(missiles.where((p) => p.simple).length, 46);
      expect(missiles.first.finished, true);
    },
  );
  test(
    'Frozen Orb bursts once against terrain before its normal range ends',
    () {
      final s = field('frozenOrb');
      final spec = s.progress.sorceressSpell(s.progress.skillAt(0)!);
      final orb = SorceressProjectile(
        s.hero.sorceressCombat,
        spec,
        const Offset(4, 4),
        bearing: math.pi,
        damageAmount: 10,
        orb: true,
      );
      orb.update(.05);
      expect(orb.finished, true);
      expect(orb.travelled, lessThan(spec.range));
      final shards = effects(
        s,
      ).whereType<SorceressProjectile>().where((p) => p.simple);
      expect(shards.length, 16);
      orb.update(.05);
      expect(
        effects(
          s,
        ).whereType<SorceressProjectile>().where((p) => p.simple).length,
        16,
      );
    },
  );
  test(
    'Frozen Orb bursts once on actual chest contact and all shards still sweep',
    () {
      final s = field('frozenOrb');
      Offset? from;
      int? chestIndex;
      for (var i = 0; i < s.world.chests.length && from == null; i++) {
        for (final offset in [
          const Offset(-60, 0),
          const Offset(60, 0),
          const Offset(0, -50),
          const Offset(0, 50),
        ]) {
          final at = s.world.chests[i] + offset;
          if (!s.world.blocked(
            Rect.fromCenter(center: at, width: 6, height: 6),
          )) {
            from = at;
            chestIndex = i;
            break;
          }
        }
      }
      expect(from, isNotNull);
      final target = s.world.chests[chestIndex!];
      final spec = s.progress.sorceressSpell(s.progress.skillAt(0)!);
      final orb = SorceressProjectile(
        s.hero.sorceressCombat,
        spec,
        from!,
        bearing: math.atan2(target.dy - from.dy, target.dx - from.dx),
        damageAmount: 10,
        orb: true,
        propOnly: true,
      );
      for (var i = 0; i < 30 && !orb.finished; i++) {
        orb.update(.02);
      }
      expect(orb.finished, true);
      expect(s.world.openedChests, contains(chestIndex));
      final shards = effects(
        s,
      ).whereType<SorceressProjectile>().where((p) => p.simple).toList();
      // Moving shards emitted before contact are separate from the final nova.
      expect(shards.length, orb.orbShards + 16);
      final count = shards.length;
      orb.update(.05);
      expect(
        effects(
          s,
        ).whereType<SorceressProjectile>().where((p) => p.simple).length,
        count,
      );
      for (final shard in shards) {
        shard.update(.05);
      }
      expect(shards.every((p) => p.travelled <= p.range), true);
    },
  );
  test('inferno costs mana over the held stream and releases cleanly', () {
    final s = field('inferno'), m = enemy(s, 80);
    final mana = s.progress.energy;
    s.hero.beginAim(0);
    advance(s, .5);
    expect(s.hero.sorceressCombat.channeling, true);
    expect(s.progress.energy, lessThan(mana));
    expect(m.life.value, lessThan(100000));
    s.hero.finishAim(false, ownerSlot: 0);
    expect(s.hero.sorceressCombat.channeling, false);
    final hp = m.life.value;
    advance(s, .4);
    expect(m.life.value, hp);
  });
  test(
    'empty-mana elemental basics do not swing a staff or create free hits',
    () {
      for (final id in ['firebolt', 'chargedBolt', 'iceBolt']) {
        final s = field(id), near = enemy(s, 60), far = enemy(s, 170);
        s.progress.selectBasic(id);
        s.progress.energy = 0;
        s.hero.slash();
        expect(near.life.value, 100000);
        expect(s.hero.swing, 0);
        expect(s.hero.attackClock, 0);
        expect(far.life.value, 100000);
        expect(effects(s).whereType<SorceressProjectile>(), isEmpty);
        expect(s.progress.energy, 0);
      }
    },
  );
  test('wall fire is a narrow damaging line rather than a filled circle', () {
    final s = field('firewall');
    final center = s.hero.body.center + const Offset(150, 0);
    final on = s.spawnEnemy('goblin', center)!..life.initial(100000);
    final off = s.spawnEnemy('goblin', center + const Offset(60, 0))!
      ..life.initial(100000);
    final spec = s.progress.sorceressSpell(s.progress.skillAt(0)!);
    s.hero.sorceressCombat.addZone(
      spec,
      center,
      duration: spec.duration,
      radius: spec.radius,
      bearing: math.pi / 2,
      line: true,
    );
    advance(s, .4);
    expect(on.life.value, lessThan(100000));
    expect(off.life.value, 100000);
  });
  test('overlapping blaze footprints share the same burn budget', () {
    final s = field('blaze'), m = enemy(s, 70);
    final spec = s.progress.sorceressSpell(s.progress.skillAt(0)!);
    final owner = s.hero.sorceressCombat;
    owner.addZone(spec, m.body.center, duration: 2, radius: 48, interval: .3);
    owner.addZone(spec, m.body.center, duration: 2, radius: 48, interval: .3);
    final max = spec.maxDamagePerSecond * .3;
    advance(s, .1);
    expect(100000 - m.life.value, greaterThan(0));
    expect(100000 - m.life.value, lessThanOrEqualTo(max + .001));
  });
  test('blizzard creates discrete falling contact waves across its area', () {
    final s = field('blizzard');
    s.hero.skill();
    advance(s, 1);
    expect(effects(s).whereType<SorceressGround>().single.falling, true);
    expect(effects(s).whereType<SorceressFlash>().length, greaterThan(5));
    expect(effects(s).whereType<SorceressGround>().single.finished, false);
    advance(s, 3.2);
    expect(effects(s).whereType<SorceressGround>().single.finished, true);
  });
  test('teleport crosses enemies and lands on a valid terrain body', () {
    final s = field('blink');
    enemy(s, 75);
    final before = s.hero.body.center, mana = s.progress.energy;
    expect(s.hero.useMobility(), true);
    expect((s.hero.body.center - before).distance, greaterThan(150));
    expect(s.world.blocked(s.hero.body), false);
    expect(s.progress.energy, lessThan(mana));
  });
  test('telekinesis pushes and stuns its actual selected enemy', () {
    final s = field('telekinesis'), m = enemy(s, 120);
    s.hero.skill();
    expect(m.life.value, lessThan(100000));
    expect(m.stun, greaterThan(0));
  });
  test('a new spell interrupts Inferno before its queued cast resolves', () {
    final s = field('inferno');
    s.progress.secondarySkill = 'firebolt';
    s.progress.ranks['firebolt'] = 1;
    s.hero.beginAim(0);
    advance(s, .1);
    expect(s.hero.sorceressCombat.channeling, true);
    s.hero.skill(slot: 1);
    expect(s.hero.sorceressCombat.channeling, false);
    advance(s, .7);
    expect(effects(s).whereType<SorceressProjectile>(), isNotEmpty);
  });
  test('Blaze restores its cast rank and remaining trail duration', () {
    final s = field('blaze', rank: 4);
    s.hero.skill();
    advance(s, .4);
    final state = s.hero.sorceressCombat.captureState();
    final restored = field('blaze', rank: 4);
    restored.hero.sorceressCombat.restoreState(
      Map<String, dynamic>.from(state),
    );
    expect(
      restored.hero.sorceressCombat.blazeTime,
      closeTo(s.hero.sorceressCombat.blazeTime, 1e-8),
    );
    expect(restored.hero.sorceressCombat.captureState()['blazeRank'], 4);
    advance(restored, .1);
    expect(effects(restored).whereType<SorceressGround>(), isNotEmpty);
  });
  test(
    'manual chain lightning cannot choose its first victim behind the ray',
    () {
      final s = field('chainLightning'), m = enemy(s, 120);
      final aim = SkillAim(0, 'chainLightning', 0)
        ..delta = const Offset(-74, 0);
      s.hero.skill(manualAim: aim);
      expect(m.life.value, 100000);
    },
  );
  test('a mage projectile cannot originate through the sanctuary boundary', () {
    final s = field('fireball'), m = enemy(s, 100);
    final spec = s.progress.sorceressSpell(s.progress.skillAt(0)!);
    final at = s.world.sanctuary.center;
    final projectile = SorceressProjectile(
      s.hero.sorceressCombat,
      spec,
      at,
      bearing: 0,
      damageAmount: 10000,
    );
    projectile.update(.05);
    expect(projectile.finished, true);
    expect(m.life.value, 100000);
  });
  test('effects pause without advancing and invalidate on a new build', () {
    final s = field('fireball');
    s.hero.skill();
    final missile = effects(s).whereType<SorceressProjectile>().single;
    final from = missile.position.clone();
    s.pause();
    missile.update(.05);
    expect(missile.position, from);
    expect(missile.age, 0);
    s.resume();
    s.buildRevision++;
    missile.update(.02);
    expect(missile.finished, true);
  });
}
