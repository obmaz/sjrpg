import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/battle_effects.dart';
import 'package:guardian_new/boss_attacks.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const origin = Offset(6000, 4200), target = Offset(6200, 4200);
  bool hits(BossAttack attack, Offset point) =>
      attack.zones.any((z) => z.contains(point));
  test(
    'stage telegraphs have distinct dodge gaps and keep the forest strike intact',
    () {
      final forest = BossAttack.forStage(WorldStage.forest, origin, target);
      expect(forest.warningTime, .85);
      expect(forest.damage, 24);
      expect(hits(forest, target + const Offset(0, 104)), true);
      expect(hits(forest, target + const Offset(0, 106)), false);
      final sand = BossAttack.forStage(WorldStage.sands, origin, target);
      expect(sand.zones.length, 3);
      expect(hits(sand, target + const Offset(90, 0)), true);
      expect(hits(sand, target + const Offset(0, 80)), false);
      final past = BossAttack.forStage(WorldStage.past, origin, target);
      expect(hits(past, target), true);
      expect(hits(past, origin + const Offset(-100, 0)), false);
      expect(hits(past, origin + const Offset(0, 200)), false);
      expect(hits(past, origin + const Offset(261, 0)), false);
      final future = BossAttack.forStage(WorldStage.future, origin, target);
      expect(future.zones.length, 2);
      expect(hits(future, target), true);
      expect(hits(future, target + const Offset(140, 0)), true);
      expect(hits(future, target + const Offset(80, 80)), false);
      final overload = BossAttack.forStage(
        WorldStage.future,
        origin,
        target,
        enraged: true,
      );
      expect(overload.zones.length, 4);
      expect(hits(overload, target + const Offset(80, 80)), true);
      expect(hits(overload, target + const Offset(100, 42)), false);
      expect(hits(overload, target + const Offset(220, 220)), false);
      expect(
        BossAttack.forStage(
          WorldStage.sands,
          origin,
          target,
          enraged: true,
        ).zones.length,
        5,
      );
    },
  );
  for (final stage in WorldStage.values) {
    test(
      '$stage warning freezes, locks aim and lets the player leave its danger shape',
      () {
        final s = inCombatField(Adventure(GameArt(), stage: stage));
        final game = TestGame();
        s.start(game);
        addTearDown(s.dispose);
        s.mobs.clear();
        final base = stage == WorldStage.forest ? origin : s.hero.body.topLeft;
        s.hero.position.setValues(base.dx + 200, base.dy);
        final boss = s.spawnEnemy('golem', base, boss: true)!
          ..slamClock = 0
          ..attackClock = 10;
        boss.update(.05);
        final attack = boss.bossAttack!;
        expect(game.added.whereType<BossAttackVisual>().single.impact, false);
        final time = boss.windup;
        s.pause();
        boss.update(.5);
        expect(boss.windup, time);
        s.resume();
        final safe = stage == WorldStage.forest
            ? attack.target + const Offset(0, 150)
            : stage == WorldStage.sands
            ? attack.target + const Offset(0, 90)
            : stage == WorldStage.past
            ? attack.origin + const Offset(0, 220)
            : attack.target + const Offset(80, 80);
        s.hero.position.setValues(safe.dx - 12, safe.dy - 11);
        final hp = s.progress.hp;
        for (var i = 0; i < 30 && boss.bossAttack != null; i++) {
          boss.update(.05);
        }
        expect(boss.bossAttack, null);
        expect(s.progress.hp, hp);
        final impact = game.added.whereType<BossAttackVisual>().last;
        expect(impact.impact, true);
        s.pause();
        impact.update(.2);
        expect(impact.age, 0);
        s.resume();
        impact.update(.05);
        expect(impact.age, .05);
      },
    );
    test(
      '$stage resolves one damage event and a new phase cannot change a warning already shown',
      () {
        final s = inCombatField(Adventure(GameArt(), stage: stage));
        final game = TestGame();
        s.start(game);
        addTearDown(s.dispose);
        s.mobs.clear();
        final base = stage == WorldStage.forest ? origin : s.hero.body.topLeft;
        s.hero.position.setValues(base.dx + 200, base.dy);
        final boss = s.spawnEnemy('golem', base, boss: true)!
          ..slamClock = 0
          ..attackClock = 10;
        boss.update(.05);
        final attack = boss.bossAttack!;
        final count = attack.zones.length;
        boss.life.update(boss.life.max * .4);
        expect(boss.bossAttack, same(attack));
        expect(attack.zones.length, count);
        final hp = s.progress.hp;
        for (var i = 0; i < 30 && boss.bossAttack != null; i++) {
          boss.update(.05);
        }
        expect(s.progress.hp, lessThan(hp));
        final after = s.progress.hp;
        for (var i = 0; i < 10; i++) {
          boss.update(.05);
        }
        expect(s.progress.hp, after);
        boss.slamClock = 0;
        boss.update(.05);
        expect(boss.bossAttack!.enraged, true);
        if (stage == WorldStage.sands) expect(boss.bossAttack!.zones.length, 5);
        if (stage == WorldStage.future) {
          expect(boss.bossAttack!.zones.length, 4);
        }
      },
    );
  }
  test('stun and death invalidate the warning without a delayed strike', () {
    final s = inCombatField(Adventure(GameArt()));
    final game = TestGame();
    s.start(game);
    addTearDown(s.dispose);
    s.mobs.clear();
    s.hero.position.setValues(6200, 4200);
    final boss = s.spawnEnemy('golem', origin, boss: true)!..slamClock = 0;
    boss.update(.05);
    final warning = game.added.whereType<BossAttackVisual>().single;
    boss.stun = .5;
    boss.update(.05);
    expect(boss.bossAttack, null);
    expect(warning.validWarning, false);
    final hp = s.progress.hp;
    for (var i = 0; i < 30; i++) {
      boss.update(.05);
    }
    expect(s.progress.hp, hp);
    boss.stun = 0;
    boss.slamClock = 0;
    boss.update(.05);
    final second = game.added.whereType<BossAttackVisual>().last;
    s.hit(boss, 100000000, Offset.zero);
    expect(second.validWarning, false);
    final rewardedHp = s.progress.hp;
    boss.update(.05);
    expect(s.progress.hp, rewardedHp);
  });
  test('a prestarted ground attack cannot damage through a solid tree', () {
    final s = inCombatField(Adventure(GameArt()));
    s.start(TestGame());
    addTearDown(s.dispose);
    s.mobs.clear();
    final tree = s.world.props.firstWhere(
      (p) =>
          p.kind == 'tree' &&
          !s.world.blocked(
            Rect.fromLTWH(p.body.left - 80, p.body.center.dy - 20, 48, 40),
          ) &&
          !s.world.blocked(
            Rect.fromLTWH(p.body.right + 30, p.body.center.dy - 11, 24, 22),
          ),
    );
    s.hero.position.setValues(tree.body.right + 30, tree.body.center.dy - 11);
    final boss = s.spawnEnemy(
      'golem',
      Offset(tree.body.left - 80, tree.body.center.dy - 20),
      boss: true,
    )!;
    boss.bossAttack = BossAttack.forStage(
      WorldStage.forest,
      boss.body.center,
      s.hero.body.center,
    );
    boss.windup = .05;
    boss.attackClock = 10;
    final hp = s.progress.hp;
    boss.update(.05);
    expect(s.progress.hp, hp);
    expect(boss.bossAttack, null);
  });
}
