import 'dart:async' as async;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'effect_visibility.dart';

enum ImpactKind {
  magic(22, 0xff94e5ff),
  fire(24, 0xffffb65e),
  ice(22, 0xffb9f6ff),
  lightning(24, 0xffc2b6ff),
  melee(35, 0xffffdc95),
  heavy(55, 0xffffe6ac);

  const ImpactKind(this.holdMilliseconds, this.color);
  final int holdMilliseconds, color;

  static ImpactKind forElement(String element) => switch (element) {
    'fire' => fire,
    'ice' => ice,
    'lightning' => lightning,
    _ => magic,
  };
}

/// A notification of damage that already happened, never a deferred attack.
class AcceptedImpact {
  const AcceptedImpact(
    this.at,
    this.bearing,
    this.kind, {
    this.rank = 1,
    this.hitStop = true,
  });
  final ui.Offset at;
  final double bearing;
  final ImpactKind kind;
  final int rank;
  final bool hitStop;
}

/// One bounded visual batch and one engine stop per simulation turn. Damage,
/// rewards and input ownership stay with Adventure, not the wall-clock timer.
class CombatFeedback {
  CombatFeedback({
    required this.game,
    required this.active,
    required this.visible,
  });

  final BonfireGameInterface? Function() game;
  final bool Function() active;
  final bool Function(ui.Offset) visible;
  static const maxBurstsPerBatch = 2, maxLiveBursts = 10;
  static const minimumStopInterval = Duration(milliseconds: 240);
  final _pending = <AcceptedImpact>[];
  async.Timer? _batch, _release;
  double _stopRecovery = 0;
  BonfireGameInterface? _recoveryGame;
  int _pendingHoldMilliseconds = 0;
  BonfireGameInterface? _heldGame, _batchGame;
  double _previousScale = 1;
  bool _disposed = false,
      _deadlinePassed = false,
      _observedStoppedUpdate = false;
  CombatClockObserver? _observer;
  int _liveBursts = 0;

  void accepted(AcceptedImpact impact) {
    if (_disposed || !active() || !visible(impact.at)) return;
    // Keep the strongest contacts when a spell hits a large crowd. Never
    // allocate particles or start a timer for each victim of the same attack.
    if (impact.hitStop) {
      _pendingHoldMilliseconds = math.max(
        _pendingHoldMilliseconds,
        impact.kind.holdMilliseconds,
      );
    }
    _batchGame ??= game();
    _pending.add(impact);
    _pending.sort(
      (a, b) => b.kind.holdMilliseconds.compareTo(a.kind.holdMilliseconds),
    );
    if (_pending.length > maxBurstsPerBatch) _pending.removeLast();
    _batch ??= async.Timer(Duration.zero, _flush);
  }

  void _flush({bool hold = true}) {
    _batch = null;
    final impacts = List<AcceptedImpact>.of(_pending);
    final holdMilliseconds = _pendingHoldMilliseconds;
    _pendingHoldMilliseconds = 0;
    _pending.clear();
    final target = _batchGame;
    _batchGame = null;
    if (_disposed ||
        !active() ||
        target == null ||
        !identical(target, game()) ||
        impacts.isEmpty) {
      return;
    }
    for (final impact in impacts) {
      if (_liveBursts >= maxLiveBursts) break;
      _liveBursts++;
      target.add(ImpactParticles(impact, onFinished: () => _liveBursts--));
    }
    // Bonfire's BaseGame uses Flame HasTimeScale. A wall timer is necessary:
    // an engine stopped at zero cannot advance its own recovery component.
    // Never extend/restart a hold, and never resume a paused engine here.
    if (!identical(_recoveryGame, target)) _stopRecovery = 0;
    if (!hold ||
        holdMilliseconds == 0 ||
        _release != null ||
        _stopRecovery > 0 ||
        target.timeScale <= 0) {
      return;
    }
    _recoveryGame = target;
    _stopRecovery = minimumStopInterval.inMilliseconds / 1000;
    _heldGame = target;
    _deadlinePassed = _observedStoppedUpdate = false;
    if (!identical(_observer?._game, target) || _observer!.isRemoving) {
      _observer?.removeFromParent();
      _observer = CombatClockObserver._(this, target);
      target.add(_observer!);
    }
    _previousScale = target.timeScale;
    target.timeScale = 0;
    _release = async.Timer(
      Duration(milliseconds: holdMilliseconds),
      _onDeadline,
    );
  }

  void _onDeadline() {
    _release = null;
    _deadlinePassed = true;
    if (_observedStoppedUpdate || !identical(_heldGame, game())) {
      _restoreClock();
    }
  }

  void _observeUpdate(BonfireGameInterface source, double dt) {
    if (!_disposed &&
        dt.isFinite &&
        dt > 0 &&
        identical(source, _recoveryGame) &&
        identical(source, game())) {
      _stopRecovery = math.max(0, _stopRecovery - math.min(dt, .1));
    }
    if (_disposed ||
        !identical(_heldGame, source) ||
        dt != 0 ||
        source.timeScale != 0) {
      return;
    }
    _observedStoppedUpdate = true;
    // HasTimeScale captured zero before traversing the world. Restoring the
    // root clock here cannot change dt for this frame's remaining siblings.
    if (_deadlinePassed) _restoreClock();
  }

  void _restoreClock() {
    _release?.cancel();
    _release = null;
    final target = _heldGame;
    _heldGame = null;
    _deadlinePassed = _observedStoppedUpdate = false;
    // Restore only the game/scale this controller stopped. A new stage or a
    // nonzero scale set by another owner must not be changed by a late timer.
    if (target != null && target.timeScale == 0) {
      target.timeScale = _previousScale;
    }
  }

  /// A finishing blow still publishes its visual before the victory pause.
  void finish() {
    _batch?.cancel();
    _flush(hold: false);
    cancel();
  }

  void cancel() {
    _batch?.cancel();
    _batch = null;
    _pending.clear();
    _pendingHoldMilliseconds = 0;
    _stopRecovery = 0;
    _recoveryGame = null;
    _batchGame = null;
    _restoreClock();
  }

  void dispose() {
    cancel();
    _observer?.removeFromParent();
    _observer = null;
    _disposed = true;
  }
}

/// Independent from visible particles and their budget: even a 22ms contact
/// at 30fps must reach one real, stopped world traversal before recovery.
class CombatClockObserver extends GameComponent {
  CombatClockObserver._(this._feedback, this._game);
  final CombatFeedback _feedback;
  final BonfireGameInterface _game;
  @override
  bool get isVisible => true;
  @override
  int get priority => -2147483647;
  @override
  void update(double dt) {
    super.update(dt);
    _feedback._observeUpdate(_game, dt);
  }
}

/// Flame advances and expires every accelerated spark; no sprite animation or
/// full-screen shader is needed. Paints and trajectories are allocated once.
class ImpactParticles extends GameComponent with EffectVisibility {
  ImpactParticles(this.impact, {required this.onFinished}) {
    position = Vector2(impact.at.dx, impact.at.dy);
    size = Vector2.all(1);
    particles = ParticleSystemComponent(
      particle: _buildParticle(impact),
      priority: 99999,
    );
    add(particles);
  }

  final AcceptedImpact impact;
  final void Function() onFinished;
  late final ParticleSystemComponent particles;
  bool _finished = false;
  @override
  bool get isVisible => true;
  @override
  int get priority => 99999;
  @override
  ui.Rect get effectBounds =>
      ui.Rect.fromCircle(center: position.toOffset(), radius: 110);

  @override
  void update(double dt) {
    super.update(dt);
    if (particles.particle!.shouldRemove) removeFromParent();
  }

  @override
  void onRemove() {
    if (!_finished) {
      _finished = true;
      onFinished();
    }
    super.onRemove();
  }

  static Particle _buildParticle(AcceptedImpact impact) {
    final heavy = impact.kind == ImpactKind.heavy;
    final physical = heavy || impact.kind == ImpactKind.melee;
    final color = ui.Color(impact.kind.color);
    final growth = (impact.rank - 1).clamp(0, 4);
    final count =
        (heavy
            ? 14
            : physical
            ? 9
            : 10) +
        growth;
    final duration = (heavy ? .28 : .22) + growth * .008;
    final ringPaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = (heavy ? 2.8 : 1.6) + growth * .2;
    final corePaint = ui.Paint();
    return ComposedParticle(
      lifespan: duration,
      children: [
        ComputedParticle(
          renderer: (canvas, particle) {
            final t = particle.progress;
            ringPaint.color = color.withValues(alpha: (1 - t) * .7);
            canvas.drawOval(
              ui.Rect.fromCenter(
                center: ui.Offset(0, t * 5),
                width: (heavy ? 92 : 54) * (1 + growth * .06) * t + 4,
                height: (heavy ? 50 : 30) * (1 + growth * .06) * t + 2,
              ),
              ringPaint,
            );
            if (t < .35) {
              corePaint.color = const ui.Color(
                0xfffffff2,
              ).withValues(alpha: 1 - t / .35);
              canvas.drawCircle(
                ui.Offset.zero,
                (heavy ? 9 : 5) * (1 - t),
                corePaint,
              );
            }
          },
        ),
        Particle.generate(
          count: count,
          generator: (index) {
            final angle = physical && index < count * .7
                ? impact.bearing + (index / (count * .7) - .5) * 2.2
                : impact.bearing + index * math.pi * 2 / count;
            final speed = (heavy ? 200.0 : 135.0) + index % 3 * 30;
            final axis = ui.Offset(math.cos(angle), math.sin(angle) * .75);
            final paint = ui.Paint()..strokeCap = ui.StrokeCap.round;
            return AcceleratedParticle(
              speed: Vector2(axis.dx * speed, axis.dy * speed),
              acceleration: Vector2(0, physical ? 260 : -40),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final fade = 1 - particle.progress;
                  paint
                    ..color = color.withValues(alpha: fade)
                    ..strokeWidth = (heavy ? 2.7 : 1.8) * fade + .4;
                  canvas.drawLine(
                    ui.Offset.zero,
                    -axis * (physical ? 12 : 7) * fade,
                    paint,
                  );
                  if (impact.kind == ImpactKind.ice) {
                    canvas.drawLine(
                      const ui.Offset(-2, 0),
                      const ui.Offset(2, 0),
                      paint,
                    );
                  }
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
