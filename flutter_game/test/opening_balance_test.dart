import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/combat_balance.dart';
import 'package:guardian_new/enemy_difficulty.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/stage_content.dart';

void main() {
  test('each level costs half its former rounded requirement', () {
    for (var level = 1; level <= 100; level++) {
      final previous = ((55 + (level - 1) * 30) * 1.5).ceil();
      expect(CombatBalance.experienceForLevel(level), (previous / 2).ceil());
    }
  });
  test(
    'old banked XP is carried over once and unknown versions are rejected',
    () {
      final old = Progress()
        ..xp = 80
        ..hp = 0
        ..energy = 7;
      final save = old.toSave()..remove('experienceVersion');
      final restored = Progress.fromSave(save)!;
      expect(restored.level, 2);
      expect(restored.xp, 38);
      expect(restored.hp, 0);
      expect(restored.energy, 7);
      expect(restored.skillPoints, old.skillPoints + 1);
      final again = Progress.fromSave(restored.toSave())!;
      expect(again.level, restored.level);
      expect(again.xp, restored.xp);
      expect(again.skillPoints, restored.skillPoints);
      expect(
        Progress.fromSave(restored.toSave()..['experienceVersion'] = 3),
        isNull,
      );
      expect(Progress.fromSave(Progress().toSave()..['xp'] = 42), isNull);
    },
  );
  test('near-town packs halve without reducing distant packs or bosses', () {
    for (final initial in [false, true]) {
      for (final level in [1, 5, 20]) {
        final normal = CombatBalance.packSize(
          initial: initial,
          playerLevel: level,
          living: 0,
        );
        final near = CombatBalance.packSize(
          initial: initial,
          playerLevel: level,
          living: 0,
          nearTown: true,
        );
        expect(near, (normal / 2).ceil());
      }
    }
    for (final stage in WorldStage.values) {
      final near = EnemyPower.atDistance(
        stage: stage,
        distance: CombatBalance.nearTownRadius - .001,
      );
      final edge = EnemyPower.atDistance(
        stage: stage,
        distance: CombatBalance.nearTownRadius + .001,
      );
      expect(near.healthMultiplier, closeTo(edge.healthMultiplier / 2, .0001));
      expect(near.damageMultiplier, closeTo(edge.damageMultiplier, .0001));
      expect(
        EnemyPowerSave.fromSave(near.toSave()).healthMultiplier,
        near.healthMultiplier,
      );
      final boss = EnemyPower.atDistance(
        stage: stage,
        distance: 1000,
        boss: true,
      );
      expect(boss.healthMultiplier, greaterThanOrEqualTo(1));
    }
  });
}
