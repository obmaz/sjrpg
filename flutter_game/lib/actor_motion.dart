import 'dart:math' as math;
import 'dart:ui';

/// A gait belongs to the distance actually travelled, not the requested input.
class RunMotion {
  static const strideLength = 84.0;
  double cycle = 0;

  void advance(double distance) {
    if (distance <= 0 || !distance.isFinite) return;
    cycle = (cycle + distance / strideLength) % 1;
  }

  int phaseFor(int frameCount) {
    if (frameCount <= 0) throw ArgumentError.value(frameCount, 'frameCount');
    return (cycle * frameCount).floor() % frameCount;
  }

  int get phase => phaseFor(2);
}

enum EnemyAttackPose { melee, sweep, bolt, pounce, slam }

/// An attack moves the illustration relative to its feet; its body stays fixed.
class EnemyAttackMotion {
  EnemyAttackPose pose = EnemyAttackPose.melee;
  double bearing = 0, remaining = 0;
  static const recovery = .28;

  void strike(EnemyAttackPose next, double direction) {
    pose = next;
    bearing = direction;
    remaining = recovery;
  }

  void update(double dt) => remaining = math.max(0, remaining - dt);
  void cancel() => remaining = 0;
  bool get active => remaining > 0;

  double get extension {
    if (!active) return 0;
    final t = 1 - remaining / recovery;
    // A quick outward stroke followed by a longer recovery is visibly different
    // from a breathing pulse and has no effect on contact or movement speed.
    return t < .25
        ? math.sin(t / .25 * math.pi / 2)
        : math.cos((t - .25) / .75 * math.pi / 2);
  }

  Offset get offset {
    final reach = switch (pose) {
      EnemyAttackPose.melee => 5.0,
      EnemyAttackPose.sweep => 4.0,
      EnemyAttackPose.bolt => -3.0,
      EnemyAttackPose.pounce => 2.0,
      EnemyAttackPose.slam => 4.0,
    };
    final amount = extension * reach;
    return Offset(math.cos(bearing) * amount, math.sin(bearing) * amount);
  }

  void paintMeleeTrace(
    Canvas canvas,
    Offset center,
    Color color, {
    required bool claws,
    required bool large,
  }) {
    if (!active || pose != EnemyAttackPose.melee) return;
    final t = 1 - remaining / recovery;
    if (t > .75) return;
    final radius = large ? 48.0 : 30.0;
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - t / .75) * .9)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = large ? 3 : 2;
    for (var i = 0; i < (claws ? 2 : 1); i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + i * 5),
        bearing - .8 + t * 2.4,
        .55,
        false,
        paint,
      );
    }
  }
}
