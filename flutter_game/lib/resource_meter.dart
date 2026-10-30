import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'adventure.dart';
import 'hud_motion_clock.dart';
import 'rpg_model.dart';

/// A small resource vessel. Its clock repaints only the clipped fluid layer;
/// text and semantics change with the session, never with animation frames.
class ResourceMeter extends StatefulWidget {
  const ResourceMeter(
    this.session, {
    this.height = 15,
    this.leadingInset = 4,
    super.key,
  }) : assert(height > 0 && height < double.infinity);

  /// The caller reserves this much height so large text keeps its full scale.
  static double minimumHeight(TextScaler scaler) =>
      (scaler.scale(12) * 1.2 + 2).ceilToDouble();

  final Adventure session;
  final double height;
  final double leadingInset;

  @override
  State<ResourceMeter> createState() => _ResourceMeterState();
}

class _ResourceMeterState extends State<ResourceMeter>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _motion = _ResourceMotion();
  late final Ticker _ticker;
  late final _ResourcePainter _painter;
  final _clock = HudMotionClock();
  bool _foreground = true, _enabled = false, _reducedMotion = false;
  String _label = '', _visibleLabel = '';
  (HeroClass, double, double)? _resource;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _ticker = createTicker(_tick);
    _painter = _ResourcePainter(widget.session, _motion);
    widget.session.addListener(_sessionChanged);
    _readLabels();
  }

  bool _readLabels() {
    final previous = _resource;
    final p = widget.session.progress;
    final energy = _resourceValue(p);
    _resource = (p.heroClass, energy, p.maxEnergy);
    final current = energy.floor();
    _visibleLabel = '${p.heroClass.resource} $current';
    _label = '$_visibleLabel / ${p.maxEnergy.round()}';
    return _resource != previous;
  }

  void _syncClock() {
    if (_clock.canObserve(
      widget.session,
      enabled: _enabled,
      foreground: _foreground,
      reducedMotion: _reducedMotion,
    )) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      _ticker.stop();
      _clock.reset();
    }
  }

  void _sessionChanged() {
    final previous = _label;
    final resourceChanged = _readLabels();
    if (_label != previous) setState(() {});
    if (resourceChanged) _motion.changed();
    _syncClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = TickerMode.valuesOf(context).enabled;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _syncClock();
  }

  @override
  void didUpdateWidget(covariant ResourceMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged = !identical(oldWidget.session, widget.session);
    if (sessionChanged) {
      oldWidget.session.removeListener(_sessionChanged);
      widget.session.addListener(_sessionChanged);
      _motion.phase = 0;
      _clock.reset();
      _painter.session = widget.session;
    }
    final resourceChanged = _readLabels();
    if (sessionChanged || resourceChanged) _motion.changed();
    _syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncClock();
  }

  void _tick(Duration elapsed) {
    final seconds = _clock.advance(
      widget.session,
      enabled: _enabled,
      foreground: _foreground,
      reducedMotion: _reducedMotion,
    );
    if (seconds > 0) _motion.advance(seconds);
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _painter.release();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: _label,
    excludeSemantics: true,
    child: SizedBox(
      height: math.max(
        widget.height,
        ResourceMeter.minimumHeight(MediaQuery.textScalerOf(context)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: SizedBox(
              height: math.min(widget.height, 14),
              width: double.infinity,
              child: RepaintBoundary(child: CustomPaint(painter: _painter)),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(widget.leadingInset, 1, 4, 1),
            child: Center(
              child: Text(
                _visibleLabel,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xfffff1d5),
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Color(0xee102025), blurRadius: 2),
                    Shadow(color: Color(0xdd102025), offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

double _resourceValue(Progress progress) {
  final maximum = progress.maxEnergy;
  if (!maximum.isFinite || maximum <= 0 || !progress.energy.isFinite) return 0;
  return progress.energy.clamp(0, maximum);
}

class _ResourceMotion extends ChangeNotifier {
  double phase = 0;
  void changed() => notifyListeners();
  void advance(double seconds) {
    phase = (phase + seconds * math.pi * 2 / 3.2) % (math.pi * 2);
    notifyListeners();
  }
}

class _ResourcePainter extends CustomPainter {
  _ResourcePainter(this.session, this.motion) : super(repaint: motion);

  Adventure session;
  final _ResourceMotion motion;
  Size _shaderSize = Size.zero;
  HeroClass? _shaderClass;
  ui.Shader? _fluidShader, _waveShader;
  final _base = Paint(), _wave = Paint(), _spark = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _frame = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xff726b60);
  final _empty = Paint()..color = const Color(0xff102426);

  void release() {
    _fluidShader?.dispose();
    _waveShader?.dispose();
    _fluidShader = _waveShader = null;
  }

  void _shaders(Size size, HeroClass heroClass) {
    if (_fluidShader != null &&
        size == _shaderSize &&
        heroClass == _shaderClass) {
      return;
    }
    release();
    _shaderSize = size;
    _shaderClass = heroClass;
    final mage = heroClass == HeroClass.mage;
    _fluidShader = ui.Gradient.linear(
      const Offset(0, 1),
      Offset(0, size.height),
      mage
          ? const [Color(0xff81dce9), Color(0xff287bc9), Color(0xff173969)]
          : const [Color(0xffedb758), Color(0xffcc5427), Color(0xff772a1d)],
      const [0, .4, 1],
    );
    _waveShader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, size.height),
      mage
          ? const [Color(0x999aeaf7), Color(0x10254b91)]
          : const [Color(0xaaffd789), Color(0x207b2b1e)],
    );
    _base.shader = _fluidShader;
    _wave.shader = _waveShader;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2 || size.height <= 2) return;
    final outer = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(.5),
      const Radius.circular(1),
    );
    final inner = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawRRect(outer, _empty);
    final p = session.progress, energy = _resourceValue(p);
    final ratio = p.maxEnergy > 0 ? energy / p.maxEnergy : 0.0;
    final fillWidth = inner.width * ratio;
    if (fillWidth > 0) {
      _shaders(size, p.heroClass);
      final mage = p.heroClass == HeroClass.mage, phase = motion.phase;
      // Flutter 3.47.8 Skwasm aliases a materialized path with its native
      // builder. Mutating a drawn path can dispose that builder before later
      // commands. Build three independent paths completely before drawing
      // and never mutate them afterward.
      final currents = [Path(), Path()], fill = Path();
      for (var layer = 0; layer < 2; layer++) {
        final current = currents[layer];
        for (var i = 0; i <= 24; i++) {
          final t = i / 24;
          final wave = math.sin(
            t * math.pi * (mage ? 3 : 5) + phase * (layer + 1),
          );
          final eddy = math.sin(t * math.pi * 7 - phase * 2 + layer) * .35;
          final y =
              inner.top +
              inner.height *
                  (.27 + layer * .32 + (wave + eddy) * (mage ? .09 : .13));
          final x = inner.left + t * inner.width;
          if (i == 0) {
            current.moveTo(x, y);
            if (layer == 0) fill.moveTo(x, y);
          } else {
            current.lineTo(x, y);
            if (layer == 0) fill.lineTo(x, y);
          }
        }
      }
      fill
        ..lineTo(inner.right, inner.bottom)
        ..lineTo(inner.left, inner.bottom)
        ..close();
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(inner, const Radius.circular(1)),
      );
      canvas.clipRect(
        Rect.fromLTWH(inner.left, inner.top, fillWidth, inner.height),
      );
      canvas.drawRect(inner, _base);
      // Two deforming currents keep a constant resource value visibly alive.
      for (var layer = 0; layer < 2; layer++) {
        _line
          ..shader = null
          ..strokeWidth = layer == 0 ? 1.3 : .8
          ..color = (mage ? const Color(0xffb8f3ff) : const Color(0xffffdd88))
              .withValues(alpha: layer == 0 ? .5 : .3);
        canvas.drawPath(currents[layer], _line);
        if (layer == 0) canvas.drawPath(fill, _wave);
      }
      final count = (fillWidth / (mage ? 42 : 28)).floor().clamp(
        1,
        mage ? 3 : 6,
      );
      for (var i = 0; i < count; i++) {
        if (mage) {
          final t = (phase / (math.pi * 2) + i * .37) % 1;
          final x = inner.left + t * fillWidth;
          final y =
              inner.center.dy +
              math.sin(phase * 2 + i * 2.1) * inner.height * .2;
          final shine = .35 + math.pow(math.sin(phase * 2 + i), 2) * .55;
          final radius = .65 + shine * 1.1;
          _line
            ..color = Color.fromRGBO(216, 253, 255, shine)
            ..strokeWidth = .8;
          canvas.drawLine(
            Offset(x - radius * 1.6, y),
            Offset(x + radius * 1.6, y),
            _line,
          );
          canvas.drawLine(Offset(x, y - radius), Offset(x, y + radius), _line);
        } else {
          final t = (phase / (math.pi * 2) + i * .19) % 1;
          final x =
              inner.left +
              (i + .5) / count * fillWidth +
              math.sin(phase * 2 + i) * 1.7;
          final y = inner.bottom - t * inner.height * 1.15;
          _spark.color = Color.fromRGBO(255, 231, 151, .75 * (1 - t));
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 1.2, height: 2.2 - t),
            _spark,
          );
        }
      }
      canvas.restore();
    }
    canvas.drawRRect(outer, _frame);
  }

  @override
  bool shouldRepaint(covariant _ResourcePainter oldDelegate) =>
      !identical(oldDelegate.session, session);
}
