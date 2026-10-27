import 'dart:math' as math;

import 'adventure.dart';

/// A shared, bounded HUD view of actual simulation time. It never advances the
/// game and never applies engine timeScale a second time to session.elapsed.
class HudMotionClock {
  static const frameStep = 1 / 30;
  Adventure? _session;
  double? _lastElapsed, _lastPaint;
  bool? _reducedMotion;

  /// Poll only while session/lifecycle state can resume without engine signals.
  /// Engine pause/scale have no notifier, so those gates belong in advance().
  bool canObserve(
    Adventure session, {
    bool enabled = true,
    bool foreground = true,
    bool reducedMotion = false,
    bool allowReducedMotion = false,
  }) =>
      enabled &&
      foreground &&
      (!reducedMotion || allowReducedMotion) &&
      session.active &&
      session.game != null;

  bool canAdvance(
    Adventure session, {
    bool enabled = true,
    bool foreground = true,
    bool reducedMotion = false,
    bool allowReducedMotion = false,
  }) {
    if (!canObserve(
      session,
      enabled: enabled,
      foreground: foreground,
      reducedMotion: reducedMotion,
      allowReducedMotion: allowReducedMotion,
    )) {
      return false;
    }
    final game = session.game!;
    return !game.paused && game.timeScale.isFinite && game.timeScale > 0;
  }

  void reset() {
    _session = null;
    _lastElapsed = _lastPaint = null;
    _reducedMotion = null;
  }

  double advance(
    Adventure session, {
    bool enabled = true,
    bool foreground = true,
    bool reducedMotion = false,
    bool allowReducedMotion = false,
  }) {
    if (!identical(_session, session) || _reducedMotion != reducedMotion) {
      reset();
      _session = session;
      _reducedMotion = reducedMotion;
    }
    final current = session.elapsed;
    if (!canAdvance(
          session,
          enabled: enabled,
          foreground: foreground,
          reducedMotion: reducedMotion,
          allowReducedMotion: allowReducedMotion,
        ) ||
        !current.isFinite ||
        current < 0) {
      _lastElapsed = _lastPaint = null;
      return 0;
    }
    final previous = _lastElapsed, painted = _lastPaint;
    _lastElapsed = current;
    if (previous == null || painted == null || current < previous) {
      _lastPaint = current;
      return 0;
    }
    final delta = current - painted;
    if (delta + .000001 < frameStep) return 0;
    // Keep actual simulation cadence (including a legitimate 10Hz source),
    // while dropping long-gap overshoot instead of replaying a backlog.
    _lastPaint = current;
    return math.min(delta, .1);
  }
}
