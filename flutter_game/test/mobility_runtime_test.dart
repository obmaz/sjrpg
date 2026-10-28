import 'dart:convert';
import 'dart:ui' as ui;
import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/player_afflictions.dart';
import 'package:guardian_new/skill_aim.dart';
import 'package:guardian_new/sorceress_combat.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field(HeroClass type, {bool learned = true}) {
    final s = inCombatField(Adventure(GameArt(), heroClass: type))
      ..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    s.dormantEnemies.clear();
    s.waveTime = 10000;
    final required = type == HeroClass.mage ? 18 : 8;
    while (s.progress.level < required) {
      s.progress.gainXp(s.progress.nextLevelXp - s.progress.xp);
    }
    void learn(SkillDef def, int rank) {
      for (final e in def.requires.entries) {
        learn(s.progress.skills.firstWhere((d) => d.id == e.key), e.value);
      }
      while (s.progress.rank(def.id) < rank) {
        expect(s.progress.learn(def), true, reason: def.id);
      }
    }

    if (learned) learn(s.progress.mobilitySkill, 1);
    s.syncLife();
    return s;
  }

  void walk(Guardian h) => h.onJoystickChangeDirectional(
    JoystickDirectionalEvent(
      directional: JoystickMoveDirectional.MOVE_RIGHT,
      radAngle: 0,
      intensity: 1,
    ),
  );
  Offset openField(Adventure s) {
    for (var y = 4000.0; y <= 8000; y += 80) {
      final at = Offset(6000, y);
      if (!s.world.blocked(Rect.fromLTWH(at.dx - 50, at.dy - 50, 600, 120)) &&
          !s.world.sanctuary.protects(at & s.hero.body.size)) {
        s.hero.position.setValues(at.dx, at.dy);
        s.hero.lastClearPosition = at;
        return at;
      }
    }
    throw StateError('needs authored open ground');
  }

  test('ordinary movement halves while dodge keeps164px distance', () {
    final s = field(HeroClass.warrior, learned: false);
    openField(s);
    walk(s.hero);
    s.hero.update(1 / 30);
    final before = s.hero.position.toOffset();
    for (var i = 0; i < 30; i++) {
      s.hero.update(1 / 30);
    }
    expect((s.hero.position.toOffset() - before).distance, closeTo(135, .02));
    s.releaseInput();
    s.hero.bearing = 0;
    final start = s.hero.position.toOffset();
    s.hero.dodge();
    for (var i = 0; i < 10; i++) {
      s.hero.update(.032);
    }
    expect((s.hero.position.toOffset() - start).distance, closeTo(164.16, .03));
  });
  for (final hz in [30, 60]) {
    test('sprint$hz Hz moves270 then135 without frenzy stacking', () {
      final s = field(HeroClass.warrior);
      openField(s);
      walk(s.hero);
      s.hero.update(1 / hz);
      s.hero.frenzyTime = 10;
      expect(s.hero.useMobility(), true);
      final clock = s.progress.mobilityCooldown;
      expect(s.hero.useMobility(), false);
      final start = s.hero.position.toOffset();
      for (var i = 0; i < hz; i++) {
        s.hero.update(1 / hz);
      }
      expect(s.hero.speed, 270);
      expect((s.hero.position.toOffset() - start).distance, closeTo(270, .04));
      expect(s.hero.mobilityClock, closeTo(clock - 1, 1e-8));
      for (var i = 0; i < hz * 2; i++) {
        s.hero.update(1 / hz);
      }
      expect(s.hero.sprintTime, 0);
      expect(s.hero.speed, lessThanOrEqualTo(155));
      s.hero.frenzyTime = 0;
      s.hero.update(1 / hz);
      expect(s.hero.speed, 135);
    });
  }
  test('pause zero dt root and accepted hurt preserve cooldown safely', () {
    final s = field(HeroClass.warrior);
    expect(s.hero.useMobility(), true);
    final clock = s.hero.mobilityClock, time = s.hero.sprintTime;
    s.hero.update(0);
    s.pause();
    s.hero.update(.05);
    expect(s.hero.mobilityClock, clock);
    expect(s.hero.sprintTime, time);
    s.resume();
    s.hero.interruptFor(PlayerStatus.root);
    expect(s.hero.sprintTime, 0);
    expect(s.hero.mobilityClock, clock);
    s.hero.restoreMobility(clock, 1);
    s.hurtHero(1);
    expect(s.hero.sprintTime, 0);
    expect(s.hero.mobilityClock, clock);
  });
  test('unlearned and frozen mobility cannot consume cooldown', () {
    final s = field(HeroClass.warrior, learned: false);
    expect(s.hero.useMobility(), false);
    expect(s.hero.mobilityClock, 0);
    s.afflictions.apply(PlayerStatus.freeze);
    expect(s.hero.useMobility(), false);
  });
  test('D2 blink crosses live enemies and validates its terrain landing', () {
    final s = field(HeroClass.mage), from = openField(s);
    s.hero.bearing = 0;
    final blockers = [
      for (final x in [120.0, 200.0, s.progress.mobilityRange])
        s.spawnEnemy('goblin', from + Offset(x, 0))!,
    ];
    final mana = s.progress.energy,
        cost = s.progress.skillCost(s.progress.mobilitySkill);
    expect(cost, 24);
    expect(s.hero.useMobility(), true);
    final landed = s.hero.position.toOffset();
    expect((landed - from).distance, greaterThan(164.16));
    expect(
      (landed - from).distance,
      lessThanOrEqualTo(s.progress.mobilityRange),
    );
    expect(
      (landed - from).distance,
      greaterThan((blockers[1].body.topLeft - from).distance),
      reason: 'a live creature in the corridor does not stop Teleport',
    );
    expect(s.progress.energy, mana - cost);
    expect(s.world.blocked(s.hero.body), false);
    expect(s.hero.lastClearPosition, landed);
    expect(
      s.hero.mobilityClock,
      0,
      reason: 'D2 Teleport has no synthetic cooldown',
    );
    expect(s.hero.castLock, greaterThan(0));
    expect(
      s.hero.useMobility(),
      false,
      reason: 'the casting animation prevents instant repeat',
    );
  });
  test(
    'D2 Teleport crosses an intermediate wall but moves a blocked endpoint back onto valid terrain',
    () {
      final s = field(HeroClass.mage), size = s.hero.body.size;
      final range = s.progress.mobilityRange;
      ({Offset from, Rect obstacle})? crossing;
      for (final prop in s.world.props) {
        final from = prop.body.center - Offset(range / 2, size.height / 2);
        final target = from + Offset(range, 0);
        if (!s.world.blocked(from & size) &&
            !s.world.blocked(target & size) &&
            !s.world.clearLine(from, target, size)) {
          crossing = (from: from, obstacle: prop.body);
          break;
        }
      }
      expect(crossing, isNotNull);
      final original = crossing!.from;
      s.hero.position.setValues(original.dx, original.dy);
      s.hero.bearing = 0;
      final mana = s.progress.energy;
      expect(s.hero.useMobility(), true);
      expect(
        (s.hero.position.toOffset() - original).distance,
        closeTo(range, .001),
      );
      expect(s.world.blocked(s.hero.body), false);
      expect(
        s.progress.energy,
        mana - s.progress.skillCost(s.progress.mobilitySkill),
      );
      ({Offset from, Offset blocked})? endpoint;
      for (final prop in s.world.props) {
        final blocked =
                prop.body.center - Offset(size.width / 2, size.height / 2),
            from = blocked - Offset(range, 0);
        if (!s.world.blocked(from & size) && s.world.blocked(blocked & size)) {
          endpoint = (from: from, blocked: blocked);
          break;
        }
      }
      expect(endpoint, isNotNull);
      s.hero.position.setValues(endpoint!.from.dx, endpoint.from.dy);
      final spec = s.progress.sorceressSpell(s.progress.mobilitySkill);
      final landing = s.hero.sorceressCombat.teleportLanding(spec, null);
      expect(landing, isNotNull);
      expect(s.world.blocked(landing! & size), false);
      expect(landing.dx, lessThan(endpoint.blocked.dx));
      expect((landing - endpoint.from).distance, lessThanOrEqualTo(range));
    },
  );
  test('mobility rejects a real whirlwind channel without ghost pulses', () {
    final s = field(HeroClass.warrior);
    s.progress.level = 100;
    s.progress.skillPoints = 100;
    final origin = openField(s);
    final def = s.progress.skills.firstWhere((d) => d.id == 'whirlwind');
    void learn(SkillDef skill, int rank) {
      for (final requirement in skill.requires.entries) {
        learn(
          s.progress.skills.firstWhere((d) => d.id == requirement.key),
          requirement.value,
        );
      }
      while (s.progress.rank(skill.id) < rank) {
        expect(s.progress.learn(skill), true);
      }
    }

    learn(def, 1);
    expect(s.progress.selectSkill(def.id), true);
    s.progress.energy = s.progress.maxEnergy;
    final target = s.spawnEnemy('goblin', origin + const Offset(80, 0))!;
    target.life.initial(1000);
    s.hero.skill();
    final pulse = (s.game as TestGame).added.whereType<WhirlwindPulse>().single;
    final spin = s.hero.spin;
    expect(spin, greaterThan(0));
    expect(s.hero.useMobility(), false);
    expect(s.hero.spin, spin);
    expect(s.hero.mobilityClock, 0);
    pulse.update(
      0,
    ); // Existing deliberate first strike still fires immediately.
    for (var i = 0; i < 24; i++) {
      s.hero.update(.05);
      pulse.update(.05);
    }
    expect(pulse.pulses, 3);
    expect(target.life.value, lessThan(1000));
    expect(s.hero.mobilityClock, 0);
    expect(s.hero.useMobility(), true);
  });
  test(
    'mobility rejects physical windup and Teleport respects an unfinished casting animation',
    () {
      final warrior = field(HeroClass.warrior);
      warrior.hero.chargeTime = .4;
      expect(warrior.hero.useMobility(), false);
      expect(warrior.hero.chargeTime, .4);
      expect(warrior.hero.mobilityClock, 0);
      warrior.hero.chargeTime = 0;
      warrior.hero.heavyWindup = .3;
      expect(warrior.hero.useMobility(), false);
      expect(warrior.hero.heavyWindup, .3);
      expect(warrior.hero.mobilityClock, 0);
      final mage = field(HeroClass.mage);
      openField(mage);
      mage.hero.bearing = 0;
      mage.hero.castLock = .5;
      mage.hero.aim = SkillAim(0, mage.progress.selectedSkill, 0);
      mage.hero.queuedCast = (
        slot: 0,
        id: mage.progress.selectedSkill,
        aim: null,
      );
      final mana = mage.progress.energy;
      expect(mage.hero.useMobility(), false);
      expect(mage.progress.energy, mana);
      expect(mage.hero.castLock, .5);
      mage.hero.aim = null;
      mage.hero.queuedCast = null;
      for (var i = 0; i < 10; i++) {
        mage.hero.update(.05);
      }
      mage.hero.castLock = 0;
      expect(mage.hero.useMobility(), true);
      expect(mage.hero.physicalAction, false);
      expect(mage.hero.castLock, greaterThan(0));
      expect(
        mage.progress.energy,
        mana - mage.progress.skillCost(mage.progress.mobilitySkill),
      );
    },
  );
  test(
    'checkpoint preserves remaining mobility and defaults old saves to zero',
    () {
      final s = field(HeroClass.warrior);
      expect(s.hero.useMobility(), true);
      s.hero.update(.05);
      final cp = GameCheckpoint.capture(s)!,
          r = GameCheckpoint.decode(
            GameCheckpoint.capture(s)!.encode(),
          )!.restore(GameArt());
      addTearDown(r.dispose);
      expect(r.hero.mobilityClock, closeTo(s.hero.mobilityClock, 1e-9));
      expect(r.hero.sprintTime, closeTo(s.hero.sprintTime, 1e-9));
      final old = jsonDecode(cp.encode()) as Map<String, dynamic>;
      old.remove('mobilityClock');
      old.remove('sprintTime');
      final legacy = GameCheckpoint.decode(jsonEncode(old))!.restore(GameArt());
      addTearDown(legacy.dispose);
      expect(legacy.hero.mobilityClock, 0);
      expect(legacy.hero.sprintTime, 0);
      final bad = jsonDecode(cp.encode()) as Map<String, dynamic>;
      bad['mobilityClock'] = -1;
      expect(GameCheckpoint.decode(jsonEncode(bad)), isNull);
      bad['mobilityClock'] = 1000;
      expect(GameCheckpoint.decode(jsonEncode(bad)), isNull);
    },
  );
  test(
    'checkpoint clamps buff to cooldown and never grants an unlearned sprint',
    () {
      final s = field(HeroClass.warrior);
      expect(s.hero.useMobility(), true);
      final data =
          jsonDecode(GameCheckpoint.capture(s)!.encode())
              as Map<String, dynamic>;
      data['mobilityClock'] = 1.0;
      data['sprintTime'] = 20.0;
      final r = GameCheckpoint.decode(jsonEncode(data))!.restore(GameArt());
      addTearDown(r.dispose);
      expect(r.hero.mobilityClock, 1);
      expect(r.hero.sprintTime, 1);
      final locked = field(HeroClass.warrior, learned: false);
      locked.hero.restoreMobility(3, 2);
      final cp = GameCheckpoint.capture(locked)!;
      expect(cp.data['mobilityClock'], 3);
      expect(cp.data['sprintTime'], 0);
    },
  );

  test('mounting and refund end sprint without refilling cooldown', () {
    final s = field(HeroClass.warrior);
    openField(s);
    expect(s.hero.useMobility(), true);
    final clock = s.hero.mobilityClock;
    final mount = withOwnedMounts(s).mounts.firstWhere((m) => !m.def.waterOnly);
    mount.at = s.hero.body.center;
    expect(s.boardNearbyMount(), true);
    expect(s.hero.sprintTime, 0);
    expect(s.hero.mobilityClock, clock);
    final restored = GameCheckpoint.capture(s)!.restore(GameArt());
    addTearDown(restored.dispose);
    expect(restored.riding, isNotNull);
    expect(restored.hero.sprintTime, 0);
    expect(restored.hero.mobilityClock, clock);
    final other = field(HeroClass.warrior);
    expect(other.hero.useMobility(), true);
    final otherClock = other.hero.mobilityClock;
    other.progress.awardSkillResetTicket(WorldStage.forest);
    expect(other.resetSkills(), true);
    expect(other.hero.sprintTime, 0);
    expect(other.hero.mobilityClock, otherClock);
  });
  test(
    'learned frozen mobility rejects use and blink has animated cast rings',
    () async {
      final s = field(HeroClass.mage);
      openField(s);
      s.afflictions.apply(PlayerStatus.freeze);
      expect(s.hero.useMobility(), false);
      expect(s.hero.mobilityClock, 0);
      s.afflictions.clear();
      s.hero.bearing = 0;
      expect(s.hero.useMobility(), true);
      expect(
        s.hero.swing,
        s.progress.skillMotionTime(s.progress.mobilitySkill),
      );
      final effect = (s.game as TestGame).added
          .whereType<SorceressFlash>()
          .where((effect) => effect.spec.id == 'blink' && effect.mode == 'cast')
          .single;
      Future<List<int>> pixels() async {
        final recorder = ui.PictureRecorder(),
            canvas = ui.Canvas(recorder)..translate(40, 90);
        effect.render(canvas);
        final picture = recorder.endRecording(),
            image = await picture.toImage(440, 200);
        picture.dispose();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List().toList();
        image.dispose();
        return bytes;
      }

      final before = await pixels();
      effect.update(0);
      expect(effect.age, 0);
      s.pause();
      effect.update(.05);
      expect(effect.age, 0);
      s.resume();
      for (var i = 0; i < 4; i++) {
        effect.update(.05);
      }
      final after = await pixels();
      expect(before, isNot(orderedEquals(after)));
      for (var i = 0; i < 6; i++) {
        effect.update(.05);
      }
      expect(effect.finished, true);
    },
  );
}
