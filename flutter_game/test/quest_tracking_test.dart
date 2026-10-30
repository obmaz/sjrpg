import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/world_model.dart';

import 'support/forest_quest_flow.dart';
import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Adventure session([WorldStage stage = WorldStage.forest]) {
    final s = Adventure(GameArt(), stage: stage)..start(TestGame());
    addTearDown(s.dispose);
    return s;
  }

  test(
    'manual tracking persists, toggles off, and advances after purification',
    () {
      final s = session(),
          site = s.world.sites.last,
          at = s.hero.position.clone();
      s.pause();
      expect(s.toggleTrackedSite(site), true);
      expect(s.hero.position, at);
      expect(s.trackedSite?.id, site.id);
      final cp = GameCheckpoint.capture(s)!;
      final restored = cp.restore(GameArt());
      addTearDown(restored.dispose);
      expect(restored.trackedSite?.id, site.id);
      expect(s.toggleTrackedSite(site), true);
      expect(s.trackedSite, null);
      expect(s.toggleTrackedSite(site), true);
      s.resume();
      completeForestQuest(s, site.id);
      expect(s.trackedSiteId, isNot(site.id));
      expect(s.trackedSite, isNotNull);
      expect(s.toggleTrackedSite(site), false);
    },
  );
  test(
    'tracking never chooses a time branch or accepts a locked commission',
    () {
      final s = session(WorldStage.sands),
          past = timeCommissions.first,
          future = timeCommissions.firstWhere((q) => q.path == TimePath.future);
      expect(s.toggleTrackedSite(past.site), false);
      expect(s.timePath, null);
      expect(s.acceptedCommission, null);
      final giver = timeQuestGivers.firstWhere(
        (g) => g.path == TimePath.future,
      );
      s.hero.position.setValues(giver.at.dx - 14, giver.at.dy - 12);
      expect(s.acceptCommission(future), true);
      expect(s.trackedSite?.id, future.id);
      final next = timeCommissions.firstWhere(
        (q) => q.path == TimePath.future && q.step == 1,
      );
      expect(s.toggleTrackedSite(next.site), false);
      expect(s.toggleTrackedSite(future.site), true);
      expect(s.trackedSite, null);
      expect(s.toggleTrackedSite(future.site), true);
      s.mobs.clear();
      s.progress.kills = future.goal;
      s.hero.position.setValues(future.site.at.dx - 14, future.site.at.dy + 45);
      expect(s.cleanseNearbySite(), true);
      expect(s.trackedSite, null);
      expect(s.toggleTrackedSite(next.site), true);
      expect(s.acceptedCommission, null);
    },
  );
  test('stale navigation metadata never discards valid saved progress', () {
    final s = session();
    final cp = GameCheckpoint.capture(s)!;
    for (final bad in [
      null,
      42,
      'missing-site',
      {'id': 'roots'},
    ]) {
      final data = jsonDecode(cp.encode()) as Map<String, dynamic>;
      data['trackedSite'] = bad;
      final decoded = GameCheckpoint.decode(jsonEncode(data))!;
      expect(decoded.data['trackedSite'], null);
      expect(decoded.progress.toSave(), cp.progress.toSave());
    }
    final data = jsonDecode(cp.encode()) as Map<String, dynamic>;
    data['sites'] = ['roots'];
    data['trackedSite'] = 'roots';
    expect(GameCheckpoint.decode(jsonEncode(data))!.data['trackedSite'], null);
  });
  test('stage advancement drops the previous navigation selection', () {
    final s = session();
    s.cleansedSites.addAll(s.world.sites.map((q) => q.id));
    s.progress.kills = 120;
    s.progress.bossDefeated = true;
    s.trackedSiteId = 'roots';
    final advanced = GameCheckpoint.advance(s)!;
    expect(advanced.data['trackedSite'], null);
    expect(advanced.data['stage'], 'sands');
  });
}
