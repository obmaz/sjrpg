import 'dart:math' as math;
import 'dart:ui';

import 'combat_balance.dart';
import 'enemy_difficulty.dart';
import 'stage_content.dart';

enum CaveTheme { wind, bat, ice, fire, crystal }

class CaveDefinition {
  const CaveDefinition(this.theme, this.name, this.color, this.enemies);
  final CaveTheme theme;
  final String name;
  final Color color;
  final List<String> enemies;
  static CaveDefinition forStage(WorldStage stage) => const [
    CaveDefinition(CaveTheme.wind, '바람 동굴', Color(0xffb4c7b6), [
      'goblin',
      'wolf',
    ]),
    CaveDefinition(CaveTheme.bat, '박쥐 동굴', Color(0xffb69cbb), [
      'viper',
      'cultist',
    ]),
    CaveDefinition(CaveTheme.ice, '얼음 동굴', Color(0xff84d4ef), [
      'wraith',
      'skeleton',
    ]),
    CaveDefinition(CaveTheme.fire, '화염 동굴', Color(0xfff39a60), [
      'cultist',
      'troll',
    ]),
    CaveDefinition(CaveTheme.crystal, '수정 동굴', Color(0xffb6a0eb), [
      'crystal-beetle',
      'wraith',
    ]),
  ][EnemyPower.chapter(stage) - 1];
  String get resistance => switch (theme) {
    CaveTheme.ice => '얼음 피해 50%',
    CaveTheme.fire => '화염 피해 50%',
    _ => '속성 피해 감소 없음',
  };
  double damageMultiplier({required bool cold, required bool fire}) =>
      theme == CaveTheme.ice && cold || theme == CaveTheme.fire && fire
      ? .5
      : 1;
}

/// A private scene, discarded on exit. Junctions reconnect before the next room;
/// both arms have equal combat progress, so a branch never requires backtracking.
class DungeonLayout {
  DungeonLayout() {
    void join(Offset a, Offset b) {
      edges.add((a, b));
    }

    for (var i = 1; i < rooms.length; i++) {
      final a = rooms[i - 1], b = rooms[i];
      if (i == 2 || i == 4) {
        final mid = Offset.lerp(a, b, .5)!;
        for (final sign in [-1, 1]) {
          final fork = mid + Offset(0, sign * 300.0);
          join(a, fork);
          join(fork, b);
        }
      } else {
        join(a, b);
      }
    }
    join(rooms.last, goal);
    // Union all pieces: overlapping contours must not create even/odd holes.
    floor = Path();
    for (final room in [...rooms, goal]) {
      floor = Path.combine(
        PathOperation.union,
        floor,
        Path()..addOval(Rect.fromCircle(center: room, radius: 180)),
      );
    }
    for (final (a, b) in edges) {
      final d = b - a, n = Offset(-d.dy, d.dx) / d.distance * 100;
      for (final p in [
        Path()..addPolygon([a + n, b + n, b - n, a - n], true),
        Path()..addOval(Rect.fromCircle(center: a, radius: 100)),
        Path()..addOval(Rect.fromCircle(center: b, radius: 100)),
      ]) {
        floor = Path.combine(PathOperation.union, floor, p);
      }
    }
  }
  static const rooms = [
    Offset(3000, 5000),
    Offset(3800, 4780),
    Offset(4700, 4900),
    Offset(5500, 4600),
    Offset(6400, 4750),
    Offset(7200, 4480),
  ];
  final edges = <(Offset, Offset)>[];
  late Path floor;
  Offset get start => rooms.first;
  // Leave room to collect the final guard's drop before entering the exit.
  Offset get goal => rooms.last + const Offset(480, -140);
  Rect get bounds => floor.getBounds().inflate(220);
  bool permits(Rect body) {
    for (final x in [body.left, body.center.dx, body.right]) {
      for (final y in [body.top, body.center.dy, body.bottom]) {
        if (!floor.contains(Offset(x, y))) return false;
      }
    }
    return true;
  }
}

enum DungeonOutcome { cleared, expired, abandoned }

class DungeonRun {
  DungeonRun(WorldStage stage, int playerLevel)
    : definition = CaveDefinition.forStage(stage),
      enemyLevel = playerLevel + 2;
  final CaveDefinition definition;
  final int enemyLevel;
  final layout = DungeonLayout();
  static const timeLimit = 300.0;
  double remaining = timeLimit;
  DungeonOutcome? outcome;
  bool get ended => outcome != null;
  void tick(double simulationSeconds) {
    if (ended || !simulationSeconds.isFinite || simulationSeconds <= 0) return;
    remaining = math.max(
      0,
      remaining - CombatBalance.realSeconds(simulationSeconds),
    );
    if (remaining == 0) outcome = DungeonOutcome.expired;
  }

  String get clock {
    final seconds = remaining.ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
