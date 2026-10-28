import 'dart:convert';
import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/quest_guide.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session([WorldStage stage = WorldStage.forest]) {
    final s = Adventure(GameArt(), stage: stage)..start(TestGame());
    s.mobs.clear();
    addTearDown(s.dispose);
    return s;
  }

  test(
    'mount wear uses actual movement, stops when idle or paused, and persists',
    () {
      final s = session(),
          m = withOwnedMounts(s).mounts.firstWhere((m) => m.def.id == 'horse');
      m.at = const Offset(6000, 4200);
      s.hero.position.setValues(5990, 4250);
      expect(s.boardNearbyMount(), true);
      final at = s.hero.position.clone();
      for (var i = 0; i < 20; i++) {
        s.hero.moveRight();
        s.hero.update(.05);
      }
      final moved = s.hero.position.x - at.x;
      expect(
        moved,
        closeTo(m.def.speed, 1),
        reason: 'one second at the purchased horse speed',
      );
      expect(m.durability, closeTo(100 - moved / 350, .001));
      s.hero.stop();
      final condition = m.durability;
      s.hero.update(.05);
      expect(m.durability, condition);
      s.pause();
      s.hero.moveRight();
      s.hero.update(.05);
      expect(m.durability, condition);
      s.resume();
      s.hero.invulnerable = 0;
      s.hurtHero(20);
      expect(m.durability, lessThan(condition));
      final cp = GameCheckpoint.capture(s)!;
      final restored = cp.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.riding?.durability, m.durability);
      expect(restored.riding?.def.id, 'horse');
      final price = m.repairCost;
      s.progress.gold = price - 1;
      expect(s.repairMount(), false);
      expect(m.durability, lessThan(100));
      s.progress.gold = price + 7;
      final stableAt = s.world.spawnNear(s.mountMerchantAt, m.def.bodySize)!;
      s.hero.position.setValues(stableAt.dx, stableAt.dy);
      m.at = s.hero.body.center;
      expect(s.nearMountMerchant, true);
      s.pause();
      expect(s.repairMount(), true);
      expect(m.durability, 100);
      expect(s.progress.gold, 7);
    },
  );
  test(
    'broken boats paddle safely and cannot be boarded again until repaired',
    () {
      final s = session(),
          m = withOwnedMounts(s).mounts.firstWhere((m) => m.def.waterOnly);
      m.at = s.world.lakes.first.bounds.center;
      s.riding = m;
      s.hero.resizeBody(m.def.bodySize, m.at);
      m.durability = .001;
      s.wearMount(10);
      expect(m.durability, 0);
      expect(m.speed, 100);
      final before = s.hero.body.center;
      for (var i = 0; i < 10; i++) {
        s.hero.moveRight();
        s.hero.update(.05);
      }
      expect((s.hero.body.center - before).distance, greaterThan(40));
      expect(s.world.blocked(s.hero.body, waterOnly: true), false);
      expect(s.dismount(), false);
      s.riding = null;
      s.hero.resizeBody(const Size(28, 24), m.at);
      expect(s.boardNearbyMount(), false);
    },
  );
  test(
    'older map coordinates migrate once with enemies, loot, stones and riding body',
    () {
      final s = session(),
          m = withOwnedMounts(s).mounts.firstWhere((m) => m.def.id == 'horse');
      s.hero.position.setValues(m.at.dx - 14, m.at.dy - 12);
      expect(s.boardNearbyMount(), true);
      final original = GameCheckpoint.capture(s)!;
      final data = jsonDecode(original.encode()) as Map<String, dynamic>;
      data.remove('mapVersion');
      void expand(Map row) {
        row['x'] = (row['x'] as num) / worldScale;
        row['y'] = (row['y'] as num) / worldScale;
      }

      expand(data);
      for (final key in ['mounts', 'enemies', 'encounters', 'loot']) {
        for (final row in data[key] as List) {
          expand(row as Map);
        }
      }
      for (final row in data['mounts'] as List) {
        (row as Map).remove('durability');
      }
      final migrated = GameCheckpoint.decode(jsonEncode(data))!;
      expect(migrated.data['mapVersion'], 2);
      expect(migrated.progress.toSave(), original.progress.toSave());
      expect(migrated.data['encounters'], original.data['encounters']);
      expect(migrated.data['enemies'], original.data['enemies']);
      final restored = migrated.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.hero.body.center, restored.riding!.at);
      expect(restored.riding!.durability, 100);
      expect(GameCheckpoint.decode(migrated.encode())!.data, migrated.data);
      data['mapVersion'] = 88;
      expect(GameCheckpoint.decode(jsonEncode(data)), null);
    },
  );
  test(
    'nearby forest guide explains approach, danger, purification, progress and boss',
    () {
      final s = session();
      s.hero.position.setValues(
        s.world.elderAt.dx + 50,
        s.world.elderAt.dy + 20,
      );
      expect(s.nearbyQuestGuide!.message, contains('성소 3곳'));
      final site = s.world.sites.first;
      s.hero.position.setValues(site.at.dx - 14, site.at.dy + 190);
      expect(s.nearbyQuestGuide!.title, contains('접근 중'));
      s.hero.position.setValues(site.at.dx - 14, site.at.dy + 45);
      expect(s.nearbyQuestGuide!.action, QuestGuideAction.cleanse);
      final mob = s.spawnEnemy('goblin', site.at + const Offset(80, 50))!;
      expect(s.nearbyQuestGuide!.message, contains('적 1명'));
      expect(s.cleanseNearbySite(), false);
      s.mobs.remove(mob);
      expect(s.cleanseNearbySite(), true);
      expect(s.nearbyQuestGuide!.title, contains('완료'));
      expect(s.nearbyQuestGuide!.message, contains('성소 2곳'));
      s.cleansedSites.addAll(s.world.sites.map((s) => s.id));
      expect(s.nearbyQuestGuide!.message, contains('120마리'));
      s.progress.kills = 120;
      expect(s.nearbyQuestGuide!.message, contains('붉은 표식'));
      s.hero.position.setValues(18000, 18000);
      expect(s.nearbyQuestGuide, null);
    },
  );
  test('NPC guidance never hides a closer shop, chest or dismount control', () {
    final s = session();
    s.hero.position.setValues(
      s.world.merchantAt.dx - 14,
      s.world.merchantAt.dy - 12,
    );
    expect(s.nearbyAction, NearbyAction.shop);
    expect(s.nearbyQuestGuide, null);
    s.hero.position.setValues(s.world.elderAt.dx + 50, s.world.elderAt.dy + 20);
    expect(s.nearbyQuestGuide, isNotNull);
    s.riding = withOwnedMounts(s).mounts.first;
    expect(s.nearbyAction, NearbyAction.dismount);
    expect(s.nearbyQuestGuide, null);
  });
  test(
    'sands guidance distinguishes unaccepted, locked, kill-gated and complete commissions',
    () {
      final s = session(WorldStage.sands), q = timeCommissions.first;
      void stand(QuestSite site) =>
          s.hero.position.setValues(site.at.dx - 14, site.at.dy + 45);
      stand(q.site);
      expect(s.nearbyQuestGuide!.title, contains('의뢰 필요'));
      final giver = timeQuestGivers.first;
      final giverAt = s.world.questGiverAt(giver.path);
      s.hero.position.setValues(giverAt.dx - 14, giverAt.dy - 12);
      expect(s.acceptCommission(q), true);
      stand(q.site);
      expect(s.nearbyQuestGuide!.message, contains('24마리'));
      stand(timeCommissions.firstWhere((q) => q.path == TimePath.future).site);
      expect(s.nearbyQuestGuide!.title, contains('잠김'));
      stand(q.site);
      s.progress.kills = q.goal;
      expect(s.nearbyQuestGuide!.action, QuestGuideAction.cleanse);
      expect(s.cleanseNearbySite(), true);
      expect(s.nearbyQuestGuide!.message, contains('다음 의뢰를 수락'));
      expect(s.acceptCommission(timeCommissions[1]), true);
      expect(s.mainQuestNext, contains('30마리'));
    },
  );
}
