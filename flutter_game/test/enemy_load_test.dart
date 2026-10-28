import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_model.dart';

import 'support/test_game.dart';

class _LoadWorld extends AdventureWorld {
  _LoadWorld({super.stage});
  int lines = 0, longLines = 0, routes = 0, moves = 0;
  int lineMicros = 0, routeMicros = 0, moveMicros = 0;
  @override
  bool clearEnemyLine(Offset from, Offset to, Size size) {
    lines++;
    if ((to - from).distanceSquared > 200 * 200) longLines++;
    final clock = Stopwatch()..start();
    final result = super.clearEnemyLine(from, to, size);
    lineMicros += clock.elapsedMicroseconds;
    return result;
  }

  @override
  List<Offset> routeEnemy(Offset from, Offset to, Size size) {
    routes++;
    final clock = Stopwatch()..start();
    final result = super.routeEnemy(from, to, size);
    routeMicros += clock.elapsedMicroseconds;
    return result;
  }

  @override
  Offset moveEnemy(Offset from, Offset delta, Size size) {
    moves++;
    final clock = Stopwatch()..start();
    final result = super.moveEnemy(from, delta, size);
    moveMicros += clock.elapsedMicroseconds;
    return result;
  }
}

class _LoadSession extends Adventure {
  _LoadSession(WorldStage stage)
    : observed = _LoadWorld(stage: stage),
      super(GameArt(), stage: stage);
  final _LoadWorld observed;
  @override
  AdventureWorld get world => observed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final stage in [WorldStage.forest, WorldStage.sands]) {
    test('30-enemy ${stage.name} deterministic CPU load', () {
      final s = inCombatField(_LoadSession(stage))..start(TestGame());
      addTearDown(s.dispose);
      s.mobs.clear();
      s.dormantEnemies.clear();
      s.hero.invulnerable = 1000;
      s.waveTime = 10000;
      for (var i = 0; i < 30; i++) {
        final angle = i * math.pi * 2 / 30;
        final radius = 400 + i % 3 * 120.0;
        final enemy = s.spawnEnemy(
          'goblin',
          s.hero.body.center +
              Offset(math.cos(angle), math.sin(angle)) * radius,
        );
        expect(enemy, isNotNull);
      }
      final samples = <int>[];
      for (var frame = 0; frame < 600; frame++) {
        final clock = Stopwatch()..start();
        s.tick(1 / 30);
        for (final enemy in List<HuntEnemy>.of(s.mobs)) {
          enemy.update(1 / 30);
        }
        clock.stop();
        samples.add(clock.elapsedMicroseconds);
      }
      samples.sort();
      // Host VM diagnostics, deliberately not a phone rendering FPS claim.
      // ignore: avoid_print
      print(
        'ENEMY_LOAD ${stage.name} median_us=${samples[300]} '
        'p95_us=${samples[570]} total_us=${samples.reduce((a, b) => a + b)} '
        'lines=${s.observed.lines} long_lines=${s.observed.longLines} '
        'routes=${s.observed.routes} moves=${s.observed.moves} '
        'line_us=${s.observed.lineMicros} route_us=${s.observed.routeMicros} '
        'move_us=${s.observed.moveMicros}',
      );
      expect(s.mobs.length, 30);
      for (final enemy in s.mobs) {
        expect(s.world.blocksEnemy(enemy.body), false);
        expect(enemy.body.overlaps(s.hero.body), false);
        for (final other in s.mobs) {
          if (other != enemy) expect(enemy.body.overlaps(other.body), false);
        }
      }
    });
  }
}
