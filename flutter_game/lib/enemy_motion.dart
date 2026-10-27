import 'dart:math' as math;
import 'dart:ui';

/// Render-only motion; collision, attack bearings and enemy speed stay authoritative.
class EnemyMotion {
  EnemyMotion({this.mass = 1});
  final double mass;
  double get reactionDuration => .16 * math.sqrt(mass);
  double facing = math.pi / 2, stride = 0, weight = 0, reaction = 0;
  double hitSide = 0;
  bool _initialized = false;

  void hit(Offset impulse) {
    reaction = reactionDuration;
    hitSide = impulse.distance > 0 ? impulse.dx / impulse.distance : 0;
  }

  void update(double dt, {required double distance, required double bearing}) {
    if (dt <= 0) return;
    if (!_initialized) {
      facing = bearing;
      _initialized = true;
    }
    final turn = math.atan2(
      math.sin(bearing - facing),
      math.cos(bearing - facing),
    );
    facing += turn * (1 - math.exp(-14 / math.sqrt(mass) * dt));
    final target = (distance / dt / 90).clamp(0.0, 1.0);
    weight += (target - weight) * (1 - math.exp(-16 * dt));
    // Tie the gait to travelled distance, so a blocked enemy never walks in place.
    stride =
        (stride + distance / (42 * math.sqrt(mass)) * math.pi * 2) %
        (math.pi * 2);
    reaction = math.max(0, reaction - dt);
  }

  int get phase => stride < math.pi ? 0 : 1;
  double get lift => math.sin(stride).abs() * 1.2 / math.sqrt(mass) * weight;
  double get recoil => math.sin(reaction / reactionDuration * math.pi);
  double get lean => hitSide * recoil * .075;
  double get scaleX =>
      1 +
      math.sin(stride * 2) * .012 * weight +
      recoil * .035 / math.sqrt(mass);
  double get scaleY =>
      1 - math.sin(stride * 2) * .012 * weight - recoil * .04 / math.sqrt(mass);
}

/// Exact integration of a short acceleration envelope; attacks still stop at
/// their committed feet instead of coasting through a warning or collision.
class EnemyInertia {
  EnemyInertia({this.mass = 1});
  final double mass;
  Offset velocity = Offset.zero;

  Offset advance(Offset target, double dt) {
    if (dt <= 0 || !dt.isFinite) return Offset.zero;
    final rate = 12 / math.sqrt(mass), decay = math.exp(-rate * dt);
    final previous = velocity;
    velocity = target + (previous - target) * decay;
    return target * dt + (previous - target) * ((1 - decay) / rate);
  }

  void stop() => velocity = Offset.zero;
}
