import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure owned() {
    final s = withOwnedMounts(Adventure(GameArt()))..start(TestGame());
    addTearDown(s.dispose);
    return s;
  }

  test(
    'old free boats are not granted and their rider returns to safe land',
    () {
      final s = owned(), boat = s.mounts.firstWhere((m) => m.def.waterOnly);
      s.riding = boat;
      s.hero.resizeBody(boat.def.bodySize, boat.at);
      final raw = GameCheckpoint.capture(s)!.data;
      (raw['progress'] as Map).remove('mountProgress');
      final cp = GameCheckpoint.decode(jsonEncode(raw))!;
      final restored = cp.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.mounts, isEmpty);
      expect(restored.riding, isNull);
      expect(restored.world.blocked(restored.hero.body), false);
      expect(restored.progress.gold, s.progress.gold);
    },
  );
  test(
    'archived location never overwrites the globally fallen horse condition',
    () {
      final s = owned(), raw = GameCheckpoint.capture(s)!.data;
      final progress = raw['progress'] as Map,
          mp = progress['mountProgress'] as Map;
      ((mp['conditions'] as Map)['horse'] as Map).addAll(<String, dynamic>{
        'hits': 3,
        'fallen': true,
        'durability': 0,
      });
      final cp = GameCheckpoint.decode(jsonEncode(raw))!;
      final restored = cp.restore(GameArt());
      addTearDown(restored.dispose);
      final horse = restored.mounts.firstWhere((m) => m.def.id == 'horse');
      expect(horse.fallen, true);
      expect(horse.hits, 3);
      expect(horse.durability, 0);
      restored.start(TestGame());
      expect(GameCheckpoint.capture(restored), isNotNull);
    },
  );
  test(
    'mount skill cooldown and a ridden boost survive resume but death clears boost',
    () {
      final s = owned(),
          horse = s.mounts.firstWhere((m) => m.def.id == 'horse');
      s.riding = horse;
      s.hero.resizeBody(horse.def.bodySize, horse.at);
      s.mountSkillClock = 9;
      s.mountBoostTime = 2;
      final cp = GameCheckpoint.capture(s)!;
      final restored = cp.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.mountSkillClock, 9);
      expect(restored.mountBoostTime, 2);
      expect(restored.riding?.def.id, 'horse');
      inCombatField(s);
      s.hero.invulnerable = 0;
      s.hurtHero(1000000, periodic: true);
      final paid = GameCheckpoint.capture(s, forDefeat: true)!;
      final retry = paid.forRevival().restore(GameArt());
      addTearDown(retry.dispose);
      expect(retry.mountSkillClock, 9);
      expect(retry.mountBoostTime, 0);
      expect(retry.riding, isNull);
    },
  );
}
