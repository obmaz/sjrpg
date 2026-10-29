import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_control_layout.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/sanctuary.dart';
import 'package:guardian_new/town_gates.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('20 percent XP and one extra point every fifth level', () {
    final p = Progress()..awardXp(10);
    expect(p.xp, 12);
    final points = p.skillPoints;
    while (p.level < 10) {
      p.gainXp(p.nextLevelXp - p.xp);
    }
    expect(p.skillPoints, points + 11);
    final migrated = Progress.fromSave(
      p.toSave()..remove('milestonePointsVersion'),
    )!;
    expect(migrated.skillPoints, p.skillPoints + 2);
    expect(
      Progress.fromSave(migrated.toSave())!.skillPoints,
      migrated.skillPoints,
    );
    expect(
      Progress.fromSave(p.toSave()..['milestonePointsVersion'] = 2),
      isNull,
    );
  });
  test('town closes for 30 real seconds with continuous door motion', () {
    final g = TownGates();
    const ward = Sanctuary(Offset.zero, 100);
    const inside = Rect.fromLTWH(-10, -10, 20, 20),
        outside = Rect.fromLTWH(150, 0, 20, 20);
    g.observe(false);
    expect(g.remaining / CombatBalance.gameSpeed, 30);
    expect(g.permits(ward, outside, inside), false);
    expect(g.permits(ward, inside, outside), true);
    expect(g.closure, 0);
    g.update(TownGates.motionDuration / 2, false);
    expect(g.closure, closeTo(.5, .0001));
    g.update(
      TownGates.lockDuration - TownGates.motionDuration / 2 - .01,
      false,
    );
    expect(g.locked, true);
    g.update(.02, false);
    expect(g.permits(ward, outside, inside), true);
    expect(g.closure, greaterThan(0));
    g.update(TownGates.motionDuration, false);
    expect(g.closure, 0);
  });
  test('ground sweep blocks enemies while airborne movement crosses', () {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    const from = Offset(6000, 4200);
    s.hero.position.setValues(from.dx, from.dy);
    final m = s.spawnEnemy('goblin', from + const Offset(55, 0))!;
    final end = s.moveHeroBody(from, const Offset(160, 0), s.hero.body.size);
    expect(end.dx + s.hero.body.width, lessThanOrEqualTo(m.body.left));
    expect(
      s
          .moveHeroBody(
            from,
            const Offset(160, 0),
            s.hero.body.size,
            airborne: true,
          )
          .dx,
      greaterThan(m.body.right),
    );
    m.life.update(0);
    expect(
      s.moveHeroBody(from, const Offset(160, 0), s.hero.body.size).dx,
      greaterThan(m.body.right),
    );
  });
  test('monsters have species leashes and retain their spawn home', () {
    final s = inCombatField(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    const home = Offset(6000, 4200);
    final g = s.spawnEnemy('goblin', home)!;
    final w = s.spawnEnemy('wolf', home + const Offset(0, 70))!;
    expect(w.leashRadius, greaterThan(g.leashRadius));
    g.position.x += g.leashRadius + 50;
    s.hero.position.setValues(g.position.x + 90, g.position.y);
    final before = (Offset(g.position.x, g.position.y) - home).distance;
    for (var i = 0; i < 30; i++) {
      s.tick(1 / 30);
      g.update(1 / 30);
    }
    expect(g.returningHome, true);
    expect(
      (Offset(g.position.x, g.position.y) - home).distance,
      lessThan(before),
    );
    expect(s.saveEnemy(g)['homeX'], home.dx);
    final c = GameCheckpoint.capture(s)!;
    final restored = c.restore(GameArt());
    addTearDown(restored.dispose);
    expect(restored.townGates.remaining, closeTo(s.townGates.remaining, .001));
  });
  for (final size in const [Size(844, 390), Size(1280, 720)]) {
    test('reference fan fits $size with separate touch targets', () {
      final l = BattleControlLayout(size);
      Rect box(double right, double bottom, double side) => Rect.fromLTWH(
        size.width - right - side,
        size.height - bottom - side,
        side,
        side,
      );
      final main = box(l.attackRight, l.bottom, l.attackSize);
      final all = [
        main,
        box(l.dodgeRight, l.bottom + l.dodgeRise, l.smallSize),
        box(l.dodgeRight, l.bottom + l.mobilityRise, l.smallSize),
        for (final p in l.skills) box(p.$1, l.bottom + p.$2, p.$3),
      ];
      for (var i = 0; i < all.length; i++) {
        expect(all[i].width, greaterThanOrEqualTo(44));
        expect((Offset.zero & size).contains(all[i].topLeft), true);
        expect((Offset.zero & size).contains(all[i].bottomRight), true);
        for (var j = i + 1; j < all.length; j++) {
          expect(all[i].overlaps(all[j]), false, reason: '$i / $j');
        }
      }
      expect(main.center.dy / size.height, closeTo(.77, .05));
    });
  }
}
