import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/mobility_motion.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('authored stair and slope openings admit the full walking body', () {
    for (final stage in WorldStage.values) {
      final world = AdventureWorld(stage: stage);
      for (final item in world.landmarks) {
        final terrace = item.terrace;
        if (terrace == null) continue;
        final a = terrace.outline[terrace.entrance],
            b = terrace
                .outline[(terrace.entrance + 1) % terrace.outline.length];
        final mid = item.artPoint((a + b) / 2);
        final center =
            terrace.outline.reduce((a, b) => a + b) /
            terrace.outline.length.toDouble();
        var n = center - (a + b) / 2;
        n /= n.distance;
        const size = Guardian.onFootSize;
        final from = mid - n * 65 - const Offset(14, 12),
            to = mid + n * 65 - const Offset(14, 12);
        expect(
          world.blocked(from & size),
          false,
          reason: '${item.name} approach',
        );
        expect(world.blocked(to & size), false, reason: '${item.name} top');
        expect(
          (world.move(from, to - from, size) - to).distance,
          lessThan(.01),
          reason: item.name,
        );
      }
    }
  });
  test(
    'cliff faces block walking and rolling but blink and leap can cross only ledges',
    () {
      final s = Adventure(GameArt())..start(TestGame());
      addTearDown(s.dispose);
      final item = s.world.landmarks[1], size = s.hero.body.size;
      final from = item.artPoint(const Offset(380, 465)) - const Offset(14, 12);
      final to = item.artPoint(const Offset(420, 745)) - const Offset(14, 12);
      final delta = to - from;
      expect(s.world.blocked(from & size), false);
      expect(s.world.blocked(to & size), false);
      expect(s.world.clearLine(from, to, size), false);
      expect(
        (s.moveHeroBody(from, delta, size) - to).distance,
        greaterThan(50),
      );
      expect(
        (s.moveHeroBody(from, delta, size, airborne: true) - to).distance,
        lessThan(.01),
      );
      final landing = blinkLanding(
        s.world,
        from,
        size,
        math.atan2(delta.dy, delta.dx),
        delta.distance,
        occupied: (_) => false,
      );
      expect(landing, isNotNull);
      expect((landing! - to).distance, lessThan(.01));
      // Crossing a ledge must not allow passage through a separate wall or rock.
      s.world.addRuntimeSolid(
        Rect.fromCenter(center: (from + to) / 2, width: 90, height: 15),
      );
      final stopped = blinkLanding(
        s.world,
        from,
        size,
        math.atan2(delta.dy, delta.dx),
        delta.distance,
        occupied: (_) => false,
      );
      expect(stopped == null || (stopped - to).distance > 100, true);
      expect(s.world.clearLine(from, to, size, crossLedges: true), false);
    },
  );
  for (final type in HeroClass.values) {
    test('$type roll cannot cross an edge; its paid blink or leap can', () {
      final s = Adventure(GameArt(), heroClass: type)..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.dormantEnemies.clear();
      s.waveTime = 10000;
      final h = s.hero, p = s.progress, item = s.world.landmarks[1];
      final from = item.artPoint(const Offset(230, 435)) - const Offset(14, 12);
      h.position.setValues(from.dx, from.dy);
      h.bearing = math.pi;
      final walked = s.moveHeroBody(from, const Offset(-180, 0), h.body.size);
      h.position.setValues(walked.dx, walked.dy);
      while (p.level < 30) {
        p.gainXp(p.nextLevelXp - p.xp);
      }
      void learn(String skillId, int rank) {
        final def = p.skills.firstWhere((d) => d.id == skillId);
        for (final entry in def.requires.entries) {
          learn(entry.key, entry.value);
        }
        while (p.rank(skillId) < rank) {
          expect(p.learn(def), true);
        }
      }

      final id = type == HeroClass.mage ? 'blink' : 'leap';
      learn(id, 1);
      s.syncLife();
      expect(p.selectSkill(id), true);
      p.energy = p.maxEnergy;
      final output = Platform.environment['SJRPG_TERRACE_PROOF'];
      if (output != null) {
        File(
          '$output.${type.name}',
        ).writeAsStringSync(GameCheckpoint.capture(s)!.encode());
      }
      h.dodge();
      for (var i = 0; i < 40; i++) {
        s.tick(.02);
        h.update(.02);
      }
      expect(
        h.body.left,
        closeTo(walked.dx, 1),
        reason: 'roll stays on the plateau',
      );
      final energy = p.energy;
      h.skill();
      expect(p.energy, lessThan(energy));
      for (var i = 0; i < 40; i++) {
        s.tick(.02);
        h.update(.02);
      }
      expect(h.body.left, lessThan(walked.dx - 60));
      expect(s.world.blocked(h.body), false);
    });
  }
  test(
    'standing on a terrace remains visible, opaque and stable after resume',
    () {
      final s = Adventure(GameArt(), heroClass: HeroClass.mage)
        ..start(TestGame());
      addTearDown(s.dispose);
      final item = s.world.landmarks[1];
      final at = item.artPoint(const Offset(380, 465)) - const Offset(14, 12);
      s.hero.position.setValues(at.dx, at.dy);
      final prop = WoodlandProp(
        s,
        s.world.props.firstWhere((p) => p.landmark == item),
      );
      expect(prop.occludesHero, false);
      expect(prop.priority, lessThan(s.hero.priority));
      final restored = GameCheckpoint.decode(
        GameCheckpoint.capture(s)!.encode(),
      )!.restore(GameArt())..start(TestGame());
      addTearDown(restored.dispose);
      expect((restored.hero.body.topLeft - at).distance, lessThan(.01));
      final out = Platform.environment['SJRPG_TERRACE_PROOF'];
      if (out != null) {
        final saved = GameCheckpoint.capture(s)!;
        File(out).writeAsStringSync(saved.encode());
        File('$out.geometry.json').writeAsStringSync(
          '{"x":${at.dx},"y":${at.dy},"targetX":${item.artPoint(const Offset(420, 745)).dx - 14},"targetY":${item.artPoint(const Offset(420, 745)).dy - 12}}',
        );
      }
    },
  );
}
