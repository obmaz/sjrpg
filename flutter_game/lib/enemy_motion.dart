import 'dart:math' as math;
import 'dart:ui';

/// Render-only motion; collision, attack bearings and enemy speed stay authoritative.
class EnemyMotion {
  double facing = math.pi / 2, stride = 0, weight = 0, reaction = 0;
  double hitSide = 0;
  bool _initialized = false;

  void hit(Offset impulse) {
    reaction = .16;
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
    facing += turn * (1 - math.exp(-18 * dt));
    final target = (distance / dt / 90).clamp(0.0, 1.0);
    weight += (target - weight) * (1 - math.exp(-16 * dt));
    // Tie the gait to travelled distance, so a blocked enemy never walks in place.
    stride = (stride + distance / 32 * math.pi * 2) % (math.pi * 2);
    reaction = math.max(0, reaction - dt);
  }

  int get phase => stride < math.pi ? 0 : 1;
  double get lift => math.sin(stride).abs() * 1.8 * weight;
  double get recoil => math.sin(reaction / .16 * math.pi);
  double get lean => hitSide * recoil * .075;
  double get scaleX => 1 + math.sin(stride * 2) * .018 * weight + recoil * .035;
  double get scaleY => 1 - math.sin(stride * 2) * .018 * weight - recoil * .04;
}
