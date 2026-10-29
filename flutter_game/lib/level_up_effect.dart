import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'effect_visibility.dart';

/// A generated, ground-level celebration that follows without hiding the hero.
class LevelUpEffect extends GameComponent with EffectVisibility {
  LevelUpEffect(this.session) {
    size = Vector2.all(1);
    _follow();
  }
  final Adventure session;
  static const duration = 1.8;
  double age = 0;
  bool finished = false;
  void restart() => age = 0;
  void _follow() {
    final feet = session.hero.body.bottomCenter;
    position.setValues(feet.dx, feet.dy);
  }

  @override
  bool get isVisible => true;
  @override
  int get priority => 29;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromLTWH(position.x - 110, position.y - 172, 220, 220);
  @override
  void update(double dt) {
    if (finished) return;
    if (session.disposed) {
      finished = true;
      removeFromParent();
      return;
    }
    if (!session.active) return;
    _follow();
    age = math.min(duration, age + dt.clamp(0, .05));
    if (age >= duration) {
      finished = true;
      removeFromParent();
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (finished || session.disposed) return;
    final frame = (age / duration * 15).clamp(0.0, 15.0);
    final first = frame.floor(), blend = frame - frame.floor();
    final fade = math.min(1.0, (1 - age / duration) * 8);
    const rect = ui.Rect.fromLTWH(-110, -172, 220, 220);
    session.art.effects.draw(
      canvas,
      'fx-level-up',
      first,
      rect,
      opacity: (1 - blend) * fade,
    );
    if (blend > 0 && first < 15) {
      session.art.effects.draw(
        canvas,
        'fx-level-up',
        first + 1,
        rect,
        opacity: blend * fade,
      );
    }
  }
}
