import 'dart:math' as math;

/// The pale, delayed part of an enemy health bar is feedback, never extra health.
class DamageTrail {
  double value = 1, _delay = 0;
  bool _initialized = false;

  void damage(double before, double after) {
    value = (_initialized ? math.max(value, before) : before).clamp(0, 1);
    _initialized = true;
    if (after < before) _delay = .12;
  }

  void update(double dt, double actual) {
    actual = actual.clamp(0, 1);
    if (!_initialized || actual >= value) {
      value = actual;
      _initialized = true;
      _delay = 0;
      return;
    }
    final used = math.max(0.0, dt - _delay);
    _delay = math.max(0, _delay - dt);
    value = actual + (value - actual) * math.exp(-12 * used);
    if (value - actual < .001) value = actual;
  }
}
