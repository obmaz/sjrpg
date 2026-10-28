import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/rpg_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure field({
    String weapon = 'shortsword',
    List<WeaponGift> gifts = const [],
  }) {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    s.mobs.clear();
    s.waveTime = 10000;
    final gear = s.progress.createGear(
      gearById(weapon),
      rarity: gifts.isEmpty ? Rarity.common : Rarity.unique,
      gifts: gifts.isEmpty ? null : gifts,
    );
    s.progress.inventory.add(gear);
    expect(s.progress.equip(gear), true);
    s.hero.bearing = 0;
    addTearDown(s.dispose);
    return s;
  }

  void advance(Adventure s, double seconds) {
    while (seconds > .000001) {
      final dt = math.min(.01, seconds);
      s.hero.update(dt);
      seconds -= dt;
    }
  }

  void place(Adventure s, HuntEnemy enemy) {
    enemy.position.setValues(
      s.hero.body.center.dx + 50,
      s.hero.body.center.dy - 12,
    );
  }

  test('ordinary taps never open a timing meter or shorten recovery', () {
    final s = field(), h = s.hero;
    h.slash();
    final interval = h.attackClock;
    expect(h.strikes, 1);
    expect(h.comboHud.value.visible, false);
    expect(h.timedCombo.active, false);
    for (final elapsed in [.12, .17, .08]) {
      advance(s, elapsed);
      final remaining = h.attackClock;
      h.slash();
      expect(h.strikes, 1);
      expect(h.attackClock, remaining);
      expect(h.comboHud.value.visible, false);
      expect(h.comboFlow, false);
    }
    advance(s, interval);
    h.slash();
    expect(h.strikes, 2);
    expect(h.attackClock, closeTo(interval, 1e-8));
    expect(h.comboHud.value.visible, false);
  });

  test(
    'every melee weapon keeps equal basic hit damage beyond its old chain',
    () {
      for (final def in gearCatalog.where((g) => g.comboProfile != null)) {
        final s = field(weapon: def.id), h = s.hero;
        final mob = s.spawnEnemy('goblin', h.body.center + const Offset(50, 0))!
          ..life.initial(100000);
        for (var hit = 0; hit < 10; hit++) {
          place(s, mob);
          final hp = mob.life.value;
          h.slash();
          expect(
            hp - mob.life.value,
            closeTo(s.progress.basicDamage, .001),
            reason: '${def.id} hit$hit',
          );
          expect(h.strikes, hit + 1, reason: def.id);
          expect(h.comboFinisher, false, reason: def.id);
          expect(h.comboFlow, false, reason: def.id);
          expect(h.comboHud.value.visible, false, reason: def.id);
          advance(s, h.attackClock + .001);
        }
      }
    },
  );

  test('a tap during recovery is never queued across an interruption', () {
    for (final action in ['pause', 'equip', 'sanctuary']) {
      final s = field(), h = s.hero;
      h.slash();
      advance(s, .2);
      h.slash();
      expect(h.strikes, 1);
      if (action == 'pause') {
        s.pause();
        s.resume();
      } else if (action == 'sanctuary') {
        h.position.setValues(s.world.spawn.dx, s.world.spawn.dy);
      } else {
        final gear = s.progress.createGear(gearById('spear'));
        s.progress.inventory.add(gear);
        expect(s.equip(gear), true);
      }
      advance(s, 3);
      expect(h.strikes, 1, reason: action);
      expect(h.comboHud.value.visible, false, reason: action);
      inCombatField(s);
      advance(s, 2);
      expect(h.strikes, 1, reason: action);
    }
  });

  test('ordinary hits do not trigger timing-only fury or guard gifts', () {
    for (final contact in [false, true]) {
      final s = field(
        weapon: 'dualblades',
        gifts: [WeaponGift.comboFury, WeaponGift.comboGuard],
      );
      final h = s.hero;
      s.progress.energy = 10;
      final mob = contact
          ? (s.spawnEnemy('goblin', h.body.center + const Offset(50, 0))!
              ..life.initial(100000))
          : null;
      for (var hit = 0; hit < 9; hit++) {
        if (mob != null) place(s, mob);
        h.slash();
        advance(s, h.attackClock + .001);
      }
      expect(
        s.progress.energy,
        closeTo(
          contact ? 10 + s.progress.rageOnHit(protected: false) * 9 : 10,
          .001,
        ),
      );
      expect(h.comboGuardTime, 0);
      expect(h.comboHud.value.traitProc, false);
      expect(h.comboHud.value.visible, false);
    }
  });
}
