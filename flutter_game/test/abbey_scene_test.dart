import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/forest_undergrowth_art.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_checkpoint.dart';
import 'package:guardian_new/mobility_motion.dart';
import 'package:guardian_new/quest_structure_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'abbey stair route admits a whole body and cliffs do not permit a drop',
    () {
      final w = AdventureWorld(), site = w.sites.first;
      const size = Guardian.onFootSize, half = Offset(14, 12);
      final path = ForestQuestStructureArt.chapelSteps(site.at);
      for (final bodySize in const [Guardian.onFootSize, Size(42, 36)]) {
        final bodyHalf = Offset(bodySize.width / 2, bodySize.height / 2);
        for (var i = 1; i < path.length; i++) {
          final from = path[i - 1] - bodyHalf, to = path[i] - bodyHalf;
          expect(
            w.blocked(from & bodySize),
            false,
            reason: 'stair start $i $bodySize',
          );
          expect(
            w.blocked(to & bodySize),
            false,
            reason: 'stair end $i $bodySize',
          );
          expect(
            w.clearLine(from, to, bodySize),
            true,
            reason: 'continuous ramp $i $bodySize',
          );
          expect(
            (w.move(from, to - from, bodySize) - to).distance,
            lessThan(.01),
            reason: 'stair move $i $bodySize',
          );
        }
      }
      final from =
          ForestQuestStructureArt.artPoint(
            'roots',
            site.at,
            const Offset(704, 870),
          ) -
          half;
      const delta = Offset(0, 225);
      expect(w.blocked(from & size), false);
      expect((w.move(from, delta, size) - from).distance, lessThan(40));
      final landing = blinkLanding(
        w,
        from,
        size,
        1.57079632679,
        225,
        occupied: (_) => false,
      );
      expect(landing, isNotNull);
      expect(landing!.dy, greaterThan(from.dy + 150));
      expect(w.blocked(landing & size), false);
      final wall =
          ForestQuestStructureArt.artPoint(
            'roots',
            site.at,
            const Offset(704, 654),
          ) -
          half;
      expect(
        w.clearLine(from, wall, size, crossLedges: true),
        false,
        reason: 'the building is never a traversable ledge',
      );
    },
  );
  test(
    'forest mixes six grounded understory species and keeps the road center clear',
    () {
      final w = AdventureWorld();
      final plants = w.props
          .where((p) => ForestUndergrowthArt.variantOf(p.kind) != null)
          .toList();
      expect(plants.length, greaterThan(100));
      expect(
        plants.map((p) => ForestUndergrowthArt.variantOf(p.kind)).toSet(),
        {0, 1, 2, 3, 4, 5},
      );
      for (final p in plants) {
        final variant = ForestUndergrowthArt.variantOf(p.kind)!;
        expect(w.trails.any((trail) => trail.near(p.body.center, 10)), false);
        expect(p.collisionBodies.isNotEmpty, variant == 3);
        expect(
          ForestUndergrowthArt.bounds(
            p.body.bottomCenter,
            variant,
            p.drawSize.height,
          ).contains(p.body.bottomCenter),
          true,
        );
      }
    },
  );
  test(
    'the generated abbey uses native silhouette size and restores a walkable forecourt',
    () {
      final s = Adventure(GameArt(), heroClass: HeroClass.mage)
        ..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.dormantEnemies.clear();
      s.waveTime = 100000;
      final p = s.progress;
      while (p.level < 30) {
        p.gainXp(p.nextLevelXp - p.xp);
      }
      void learn(String id, int rank) {
        final d = p.skills.firstWhere((d) => d.id == id);
        for (final e in d.requires.entries) {
          learn(e.key, e.value);
        }
        while (p.rank(id) < rank) {
          expect(p.learn(d), true);
        }
      }

      for (final id in [
        'chargedBolt',
        'chainLightning',
        'telekinesis',
        'lightning',
        'blink',
      ]) {
        learn(id, id == 'chargedBolt' ? 10 : 1);
      }
      p.selectBasic('chargedBolt');
      for (final (slot, id) in [
        'firebolt',
        'chainLightning',
        'telekinesis',
        'lightning',
      ].indexed) {
        p.selectSkill(id, slot: slot);
      }
      s.syncLife();
      p.hp = p.maxHp;
      p.energy = p.maxEnergy;
      final root = s.world.sites.first;
      final npc = s.forestQuests.npcs.firstWhere((n) => n.key == 'elin');
      final at = npc.at + const Offset(50 - 14, -12);
      expect(s.world.blocked(at & s.hero.body.size), false);
      s.hero.position.setValues(at.dx, at.dy);
      expect(s.forestQuests.nearbyNpc?.key, 'elin');
      final restored = GameCheckpoint.capture(s)!.restore(GameArt())
        ..start(TestGame());
      addTearDown(restored.dispose);
      expect((restored.hero.body.topLeft - at).distance, lessThan(.01));
      final dir = Platform.environment['SJRPG_ABBEY_PROOF'];
      if (dir != null) {
        Directory(dir).createSync(recursive: true);
        void save(String name, Offset pos) {
          s.hero.position.setValues(pos.dx, pos.dy);
          File(
            '$dir/$name.json',
          ).writeAsStringSync(GameCheckpoint.capture(s)!.encode());
        }

        save('chapel', at);
        save(
          'stairs',
          ForestQuestStructureArt.artPoint(
                'roots',
                root.at,
                const Offset(272, 964),
              ) -
              const Offset(14, 12),
        );
        p.selectSkill('blink');
        save(
          'ledge',
          ForestQuestStructureArt.artPoint(
                'roots',
                root.at,
                const Offset(704, 870),
              ) -
              const Offset(14, 12),
        );
      }
    },
  );
}
