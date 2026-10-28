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
    final item = s.progress.createGear(
      gearById(weapon),
      rarity: Rarity.unique,
      gifts: gifts.isEmpty ? null : gifts,
    );
    // Plain weapons must not inherit a random passive in damage comparisons.
    final plain = gifts.isEmpty
        ? s.progress.createGear(gearById(weapon))
        : item;
    s.progress.inventory.add(plain);
    expect(s.progress.equip(plain), true);
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

  void link(Adventure s, HuntEnemy? enemy) {
    final h = s.hero, profile = s.progress.weapon.base.comboProfile!;
    final view = h.comboHud.value;
    advance(s, profile.barDuration * (view.windowStart + view.windowEnd) / 2);
    if (enemy != null) place(s, enemy);
    final count = h.comboHud.value.count;
    h.slash();
    for (var i = 0; i < 300 && h.comboHud.value.count == count; i++) {
      h.update(.01);
    }
    expect(h.comboHud.value.count, count + 1);
  }

  test('finite timing accelerates recovery and earns a finishing attack', () {
    final s = field(), h = s.hero;
    final mob = s.spawnEnemy(
      'goblin',
      s.hero.body.center + const Offset(50, 0),
    )!..life.initial(100000);
    place(s, mob);
    final damage = s.progress.basicDamage;
    h.slash();
    expect(h.comboHud.value.count, 1);
    expect(mob.life.value, closeTo(100000 - damage, .001));
    final view = h.comboHud.value,
        profile = s.progress.weapon.base.comboProfile!;
    advance(s, profile.barDuration * (view.windowStart + view.windowEnd) / 2);
    place(s, mob);
    final remaining = h.attackClock;
    h.slash();
    expect(h.attackClock, closeTo(remaining * .65, .001));
    expect(h.comboHud.value.queued, true);
    expect(h.strikes, 1);
    expect(h.attackClock, greaterThan(0));
    while (h.comboHud.value.count < 2) {
      h.update(.01);
    }
    expect(h.comboHud.value.count, 2);
    link(s, mob);
    expect(h.comboHud.value.finisher, true);
    expect(h.comboHud.value.count, 3);
    expect(h.timedCombo.active, false);
    expect(100000 - mob.life.value, greaterThanOrEqualTo(damage * 3.6 - .001));
  });

  test(
    'held attacks never auto-finish and repeated input cannot bypass recovery',
    () {
      final s = field(), h = s.hero;
      final mob = s.spawnEnemy(
        'goblin',
        s.hero.body.center + const Offset(50, 0),
      )!..life.initial(100000);
      h.slash();
      final before = h.strikes;
      h.slash();
      expect(h.strikes, before);
      expect(h.comboHud.value.missed, true);
      s.holdAttack('test', true);
      for (var i = 0; i < 80; i++) {
        place(s, mob);
        h.update(.05);
        expect(h.comboFinisher, false);
        expect(h.comboHud.value.count, lessThanOrEqualTo(1));
      }
      expect(h.strikes, greaterThan(3));
    },
  );

  test('queued timing is canceled by pause and equipment changes', () {
    for (final action in ['pause', 'equip', 'sanctuary']) {
      final s = field(), h = s.hero;
      h.slash();
      final profile = s.progress.weapon.base.comboProfile!,
          view = h.comboHud.value;
      advance(s, profile.barDuration * (view.windowStart + view.windowEnd) / 2);
      h.slash();
      expect(h.comboHud.value.queued, true);
      if (action == 'pause') {
        s.pause();
        s.resume();
      } else if (action == 'sanctuary') {
        h.position.setValues(s.world.spawn.dx, s.world.spawn.dy);
      } else {
        final gear = s.progress.createGear(gearById('spear'));
        s.progress.inventory.add(gear);
        s.equip(gear);
      }
      advance(s, 2);
      expect(h.strikes, 1);
      expect(h.comboHud.value.active, false);
      inCombatField(s);
      advance(s, 2);
      expect(h.strikes, 1);
    }
  });

  test(
    'all finite weapon lengths and dual-blade moving windows drive real strikes',
    () {
      for (final def in gearCatalog.where((g) => g.comboProfile != null)) {
        final s = field(weapon: def.id), h = s.hero;
        h.slash();
        final length = def.comboProfile!.chainLength ?? 12;
        final windows = <double>{};
        for (var i = 1; i < length; i++) {
          windows.add(h.comboHud.value.windowStart);
          link(s, null);
        }
        expect(h.comboHud.value.count, length, reason: def.id);
        expect(h.comboHud.value.finisher, !def.comboProfile!.endless);
        if (def.comboProfile!.endless) {
          expect(h.timedCombo.active, true);
          expect(windows.length, greaterThan(8));
        }
      }
    },
  );

  test(
    'third and sixth timed enemy contacts proc real weapon traits; whiffs do not',
    () {
      for (final contact in [false, true]) {
        final s = field(
              weapon: 'dualblades',
              gifts: [WeaponGift.comboFury, WeaponGift.comboGuard],
            ),
            h = s.hero;
        s.progress.energy = 10;
        final mob = contact
            ? (s.spawnEnemy('goblin', s.hero.body.center + const Offset(50, 0))!
                ..life.initial(100000))
            : null;
        if (mob != null) place(s, mob);
        h.slash();
        for (var i = 1; i < 6; i++) {
          link(s, mob);
        }
        if (contact) {
          expect(
            s.progress.energy,
            closeTo(10 + s.progress.rageOnHit(protected: false) * 6 + 12, .001),
          );
          expect(h.comboGuardTime, closeTo(.9, .001));
          final hp = s.progress.hp,
              normal = s.progress.mitigate(20, protection: h.protection);
          s.hurtHero(20, periodic: true);
          expect(s.progress.hp, closeTo(hp - normal * .75, .001));
          s.hurtHero(1, periodic: true, dispel: true);
          expect(h.comboGuardTime, 0);
        } else {
          expect(s.progress.energy, 10);
          expect(h.comboGuardTime, 0);
          expect(h.comboHud.value.traitProc, false);
        }
      }
    },
  );
}
