import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/loot_policy.dart';
import 'package:guardian_new/rpg_model.dart';
import 'package:guardian_new/stage_content.dart';

void main() {
  test(
    'new campaigns vary but chest categories retain their weighted budget',
    () {
      final seeds = {for (var i = 0; i < 12; i++) Progress().chestLootSeed};
      expect(seeds.length, greaterThan(1));
      final orders = <String>{};
      for (final seed in seeds) {
        final contents = List.generate(
          10,
          (i) => chestContent(WorldStage.forest, i, seed: seed),
        );
        expect(contents.where((c) => c == ChestContent.gear), hasLength(7));
        for (final category in [
          ChestContent.supplies,
          ChestContent.coins,
          ChestContent.ambush,
        ]) {
          expect(contents.where((c) => c == category), hasLength(1));
        }
        orders.add(contents.map((c) => c.name).join(','));
      }
      expect(orders.length, greaterThan(1));
    },
  );
  test('reload and unrelated reward order preserve every chest roll', () {
    final p = Progress(chestLootSeed: 91273)..level = 20;
    final restored = Progress.fromSave(jsonDecode(jsonEncode(p.toSave())))!;
    expect(restored.chestLootSeed, p.chestLootSeed);
    for (final stage in WorldStage.values) {
      for (var i = 0; i < 25; i++) {
        final content = chestContent(stage, i, seed: p.chestLootSeed);
        final expected = p.rollLoot(
          chestRewardRandom(p.chestLootSeed, stage, i),
          chest: true,
        );
        for (var other = 20; other > 0; other--) {
          chestRewardRandom(p.chestLootSeed, stage, other).nextInt(10000);
        }
        expect(chestContent(stage, i, seed: restored.chestLootSeed), content);
        final actual = restored.rollLoot(
          chestRewardRandom(restored.chestLootSeed, stage, i),
          chest: true,
        );
        final a = actual.toSave()..remove('serial');
        final e = expected.toSave()..remove('serial');
        expect(a, e);
      }
    }
  });
  test('old progress gets a stable seed and malformed seeds are rejected', () {
    final saved = Progress().toSave()..remove('chestLootSeed');
    final a = Progress.fromSave(saved)!;
    final b = Progress.fromSave(saved)!;
    expect(a.chestLootSeed, b.chestLootSeed);
    for (final bad in [-1, 0x80000000, 1.5, 'seed', null]) {
      expect(Progress.fromSave({...saved, 'chestLootSeed': bad}), isNull);
    }
  });
}
