import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'adventure.dart';
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
    if (feedback.needsFrames && enabled) {
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
    if (painter case final HealthMeterPainter meter) {
      meter.release();
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
  const HealthMeter(this.session, {this.height = 33, super.key});
  final Adventure session;
  final double height;
  @override
  Widget build(BuildContext context) {
    final feedback = PlayerHealthFeedbackScope.maybeOf(context);
    if (feedback == null || !identical(feedback.session, session)) {
      return PlayerHealthFeedbackScope(
        session: session,
        child: HealthMeter(session, height: height),
      );
    }
    return ValueListenableBuilder<HealthReading>(
      valueListenable: feedback.reading,
      builder: (context, reading, _) => Semantics(
        label: reading.label,
        excludeSemantics: true,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _HealthSurface(feedback: feedback, danger: false),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 17, 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${reading.hp.ceil()} / ${reading.maximum.ceil()}',
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xfffff0de),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1,
                      shadows: [
                        Shadow(color: Color(0xff351719), blurRadius: 2),
                      ],
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
  ui.Shader? _fillShader;
  Size _shaderSize = Size.zero;
  bool? _criticalShader;
  void release() {
    _fillShader?.dispose();
    _fillShader = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final edge = math.min(13.0, size.height * .42);
    final shape = Path()
      ..moveTo(0, 1)
      ..lineTo(size.width - edge, 1)
      ..lineTo(size.width - 1, size.height / 2)
      ..lineTo(size.width - edge, size.height - 1)
      ..lineTo(0, size.height - 1)
      ..close();
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRect(bounds, Paint()..color = const Color(0xff291c20));
    final actual = feedback.reading.value.ratio;
    if (feedback.trailRatio > actual) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * feedback.trailRatio, size.height),
        Paint()..color = const Color(0xffb88b69),
      );
    }
    final critical = feedback.reading.value.danger == HealthDanger.critical;
    final fill = Rect.fromLTWH(0, 0, size.width * actual, size.height);
    if (_fillShader == null ||
        _shaderSize != size ||
        _criticalShader != critical) {
      release();
      _shaderSize = size;
      _criticalShader = critical;
      _fillShader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: critical
            ? const [Color(0xffc5443d), Color(0xff7f202c)]
            : const [Color(0xffd65d4c), Color(0xff8e2e32)],
      ).createShader(bounds);
    }
    canvas.drawRect(fill, Paint()..shader = _fillShader);
    canvas.drawLine(
      const Offset(3, 3),
      Offset(math.max(3, fill.right - 5), 3),
      Paint()
        ..color = const Color(0x66f5bb9d)
        ..strokeWidth = 1,
    );
    canvas.restore();
    final warning = feedback.reading.value.danger != HealthDanger.none;
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = warning
            ? Color.lerp(
                const Color(0xffad6b54),
                const Color(0xffe0a177),
                feedback.pulse,
              )!
            : const Color(0xffb5a17b),
    );
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
      colors: [Color(0x00b52b36), Color(0x59b52b36), Color(0xffb52b36)],
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
