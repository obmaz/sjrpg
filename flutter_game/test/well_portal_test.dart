import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/travel_journal.dart';
import 'package:guardian_new/well_portal.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in WorldStage.values) {
    test(
      '$stage places every portal on reachable dry ground beside its well',
      () {
        final s = Adventure(GameArt(), stage: stage)..start(TestGame());
        addTearDown(s.dispose);
        for (final well in wellSitesForStage(stage, hubOrigin: s.world.spawn)) {
          final at = wellPortalPosition(s, well);
          expect(at, isNotNull, reason: '${stage.name}/${well.id}');
          expect((at! - well.at).distance, lessThan(240));
          expect(
            s.world.blocked(Rect.fromCenter(center: at, width: 44, height: 36)),
            false,
          );
          expect(
            s.world.clearLine(s.world.wellApproach(well), at, const Size(3, 3)),
            true,
          );
        }
      },
    );
  }

  test(
    'discovery activates one portal, saves once and never warps automatically',
    () {
      final game = TestGame(), s = Adventure(GameArt());
      s.start(game);
      addTearDown(s.dispose);
      var opens = 0, saves = 0;
      final director = WellDiscoveryDirector(
        s,
        onOpen: () => opens++,
        onDiscovered: () => saves++,
      )..gameRef = game;
      s.pause();
      director.update(.1);
      expect(s.travelJournal.wells, isEmpty);
      s.resume();
      for (var i = 0; i < 8; i++) {
        director.update(.1);
      }
      expect(s.travelJournal.hasDiscovered(WorldStage.forest, 'hub'), true);
      final portal = game.added.whereType<WellPortal>().single;
      expect(s.world.blocked(wellPortalBody(portal.at)), true);
      expect(
        s.world.clearLine(
          portal.at - const Offset(90, 0),
          portal.at + const Offset(90, 0),
          Guardian.onFootSize,
        ),
        false,
      );
      expect(
        s.world.blocked(
          Rect.fromCenter(
            center: portal.at + const Offset(0, 50),
            width: 28,
            height: 24,
          ),
        ),
        false,
      );

      expect(saves, 1);
      expect(opens, 0);
      portal.onTap();
      expect(opens, 1);
      s.pause();
      portal.onTap();
      expect(opens, 1);
      s.resume();
      s.riding = withOwnedMounts(s).mounts.first;
      portal.onTap();
      expect(opens, 1);
      s.riding = null;
      s.hero.position.setValues(6000, 4200);
      portal.onTap();
      expect(opens, 1);
      final base = wellPortalBody(portal.at);
      director.onRemove();
      expect(
        s.world.blocked(base),
        false,
        reason: 'removed gates leave no invisible blocker',
      );
    },
  );

  test(
    'Flame portal tickers are independent and preserve the authored anchor grid',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0x00000000), ui.BlendMode.src);
      final picture = recorder.endRecording(),
          image = await picture.toImage(1254, 1254);
      picture.dispose();
      addTearDown(image.dispose);
      final animation = wellPortalAnimation(image);
      expect(identical(animation, wellPortalAnimation(image)), true);
      expect(animation.frames, hasLength(16));
      expect(animation.frames.every((frame) => frame.stepTime == 1 / 30), true);
      expect(animation.frames[6].sprite.srcPosition, Vector2(939, 313));
      expect(animation.frames[7].sprite.srcPosition, Vector2(626, 313));
      for (final frame in animation.frames) {
        expect(frame.sprite.srcSize, Vector2.all(313));
        expect(frame.sprite.srcPosition.x + 313, lessThanOrEqualTo(1252));
        expect(frame.sprite.srcPosition.y + 313, lessThanOrEqualTo(1252));
      }
      final first = SpriteAnimationComponent(animation: animation),
          second = SpriteAnimationComponent(animation: animation);
      first.update(1 / 30);
      expect(first.animationTicker!.currentIndex, 1);
      expect(second.animationTicker!.currentIndex, 0);
    },
  );
}
