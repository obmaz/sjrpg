import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'adventure.dart';
import 'combat_numbers.dart';
import 'player_health_feedback.dart';

/// One local presentation clock serves both the meter and the edge warning.
class PlayerHealthFeedbackScope extends StatefulWidget {
  const PlayerHealthFeedbackScope({
    required this.session,
    required this.child,
    super.key,
  });
  final Adventure session;
  final Widget child;
  static PlayerHealthFeedback? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HealthScope>()?.feedback;
  @override
  State<PlayerHealthFeedbackScope> createState() =>
      _PlayerHealthFeedbackScopeState();
}

class _PlayerHealthFeedbackScopeState extends State<PlayerHealthFeedbackScope>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late PlayerHealthFeedback feedback;
  late final Ticker ticker;
  bool foreground = true, reduced = false, enabled = true;
  @override
  void initState() {
    super.initState();
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    ticker = createTicker((_) => sample());
    attach();
  }

  void attach() {
    feedback = PlayerHealthFeedback(widget.session)..addListener(syncTicker);
    widget.session.addListener(sample);
  }

  void sample() {
    feedback.sample(foreground: foreground && enabled, reducedMotion: reduced);
    syncTicker();
  }

  void syncTicker() {
    if (feedback.needsFrames &&
        enabled &&
        (feedback.reading.value.danger != HealthDanger.none ||
            feedback.damageRemaining > 0)) {
      if (!ticker.isActive) ticker.start();
    } else {
      ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    enabled = TickerMode.valuesOf(context).enabled;
    sample();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    sample();
  }

  @override
  void didUpdateWidget(covariant PlayerHealthFeedbackScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      oldWidget.session.removeListener(sample);
      feedback.removeListener(syncTicker);
      feedback.dispose();
      ticker.stop();
      attach();
      sample();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(sample);
    feedback.removeListener(syncTicker);
    ticker.dispose();
    feedback.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _HealthScope(feedback: feedback, child: widget.child);
}

class _HealthScope extends InheritedWidget {
  const _HealthScope({required this.feedback, required super.child});
  final PlayerHealthFeedback feedback;
  @override
  bool updateShouldNotify(_HealthScope oldWidget) =>
      !identical(feedback, oldWidget.feedback);
}

class _HealthSurface extends StatefulWidget {
  const _HealthSurface({required this.feedback, required this.danger});
  final PlayerHealthFeedback feedback;
  final bool danger;
  @override
  State<_HealthSurface> createState() => _HealthSurfaceState();
}

class _HealthSurfaceState extends State<_HealthSurface> {
  late CustomPainter painter = createPainter();
  CustomPainter createPainter() => widget.danger
      ? HealthDangerPainter(widget.feedback)
      : HealthMeterPainter(widget.feedback);
  void release() {
    if (painter case final HealthDangerPainter danger) {
      danger.release();
    }
  }

  @override
  void didUpdateWidget(covariant _HealthSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.feedback, widget.feedback) ||
        oldWidget.danger != widget.danger) {
      release();
      painter = createPainter();
    }
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: painter,
      size: widget.danger ? Size.infinite : Size.zero,
    ),
  );
}

class HealthMeter extends StatelessWidget {
  const HealthMeter(
    this.session, {
    this.height = 7,
    this.leadingInset = 0,
    super.key,
  });
  final Adventure session;
  final double height, leadingInset;
  @override
  Widget build(BuildContext context) {
    final feedback = PlayerHealthFeedbackScope.maybeOf(context);
    if (feedback == null || !identical(feedback.session, session)) {
      return PlayerHealthFeedbackScope(
        session: session,
        child: HealthMeter(session, height: height, leadingInset: leadingInset),
      );
    }
    return ValueListenableBuilder<HealthReading>(
      valueListenable: feedback.reading,
      builder: (context, reading, _) => Semantics(
        label: reading.label,
        excludeSemantics: true,
        child: SizedBox(
          height: math.max(
            12,
            MediaQuery.textScalerOf(context).scale(8.5) * 1.2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: leadingInset),
                  child: SizedBox(
                    key: const ValueKey('hud-health-gauge'),
                    height: height,
                    child: _HealthSurface(feedback: feedback, danger: false),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              SizedBox(
                width: 82,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${CombatNumbers.stat(reading.hp, rounding: CombatRounding.up)} / ${CombatNumbers.stat(reading.maximum, rounding: CombatRounding.up)}',
                      style: const TextStyle(
                        fontSize: 8.5,
                        height: 1,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HealthMeterPainter extends CustomPainter {
  HealthMeterPainter(this.feedback) : super(repaint: feedback);
  final PlayerHealthFeedback feedback;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(bounds, const Radius.circular(2));
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRect(bounds, Paint()..color = const Color(0x99000000));
    final reading = feedback.reading.value;
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        size.width * (reading.hp / reading.maximum).clamp(0.0, 1.0),
        size.height,
      ),
      Paint()..color = const Color(0xff963747),
    );
    final tint = feedback.warningTintOpacity;
    if (tint > 0) {
      canvas.drawRect(
        bounds,
        Paint()..color = Color.fromRGBO(232, 49, 56, tint),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HealthMeterPainter oldDelegate) =>
      !identical(oldDelegate.feedback, feedback);
}

class HealthDangerVignette extends StatelessWidget {
  const HealthDangerVignette(this.session, {super.key});
  final Adventure session;
  @override
  Widget build(BuildContext context) {
    final feedback = PlayerHealthFeedbackScope.maybeOf(context);
    if (feedback == null || !identical(feedback.session, session)) {
      return PlayerHealthFeedbackScope(
        session: session,
        child: HealthDangerVignette(session),
      );
    }
    return IgnorePointer(
      child: ExcludeSemantics(
        child: _HealthSurface(feedback: feedback, danger: true),
      ),
    );
  }
}

class HealthDangerPainter extends CustomPainter {
  HealthDangerPainter(this.feedback) : super(repaint: feedback);
  final PlayerHealthFeedback feedback;
  ui.Shader? _shader;
  final _paint = Paint();
  void release() {
    _paint.shader = null;
    _shader?.dispose();
    _shader = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = feedback.dangerOpacity;
    if (alpha <= 0 || size.isEmpty) return;
    _shader ??= const RadialGradient(
      radius: .5,
      colors: [Color(0x20b52b36), Color(0x59b52b36), Color(0xffb52b36)],
      stops: [.56, .82, 1],
    ).createShader(const Rect.fromLTWH(0, 0, 1, 1));
    _paint
      ..shader = _shader
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    // One elliptical gradient; no blur, offscreen layer, or corner overdraw.
    canvas.save();
    canvas.scale(size.width, size.height);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HealthDangerPainter oldDelegate) =>
      !identical(feedback, oldDelegate.feedback);
}
