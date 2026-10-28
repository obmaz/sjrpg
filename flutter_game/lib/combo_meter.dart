import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'combo_feedback.dart';

/// Fits the free strip between combat controls and the four menu buttons.
/// Very short portrait screens use one inline row rather than covering combat.
class ComboMeterLayout {
  const ComboMeterLayout(this.bounds, {this.compact = false});
  final Rect bounds;
  final bool compact;

  factory ComboMeterLayout.forViewport(Size size, EdgeInsets padding) {
    final landscape = size.width > size.height && size.width >= 500;
    final shortPortrait = !landscape && size.height < 500;
    final tightLandscape = landscape && size.width < 700;
    final inset = padding.bottom > 8;
    final compact =
        shortPortrait || tightLandscape || size.width < 300 || inset;
    final maxWidth = compact ? 164.0 : 176.0;
    // Tight landscape puts both potions at x=136, up to150px wide.
    // Safe-area devices also need a horizontal gap because menus sit higher.
    final stick = shortPortrait
        ? math.min(112.0, math.max(44.0, size.height - 330))
        : size.width < 360
        ? 122.0
        : 142.0;
    final attackLeft = size.width - (size.width < 360 ? 104 : 126);
    final left = tightLandscape
        ? 294.0
        : inset && shortPortrait
        ? 12 + stick + 8
        : (size.width - math.min(maxWidth, size.width - 32)) / 2;
    final rightLimit = inset && (shortPortrait || tightLandscape)
        ? attackLeft - 8
        : size.width - 16;
    final width = math.min(maxWidth, rightLimit - left);
    final height = inset
        ? 14.0
        : compact
        ? 18.0
        : landscape
        ? 34.0
        : 38.0;
    final bottom = math.max(8.0, padding.bottom) + (compact ? 58 : 62);
    return ComboMeterLayout(
      Rect.fromLTWH(left, size.height - bottom - height, width, height),
      compact: compact,
    );
  }
}

class ComboMeterOverlay extends StatelessWidget {
  const ComboMeterOverlay({
    required this.feedback,
    required this.viewport,
    required this.padding,
    super.key,
  });
  final ValueListenable<ComboHudState> feedback;
  final Size viewport;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final layout = ComboMeterLayout.forViewport(viewport, padding);
    return Positioned.fromRect(
      rect: layout.bounds,
      child: IgnorePointer(
        child: ValueListenableBuilder<ComboHudState>(
          valueListenable: feedback,
          builder: (context, state, _) => state.visible
              ? ComboMeter(state: state, compact: layout.compact)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class ComboMeter extends StatelessWidget {
  const ComboMeter({required this.state, this.compact = false, super.key});
  final ComboHudState state;
  final bool compact;
  static const gold = Color(0xfff3d58f), teal = Color(0xff87e5d5);

  String get _status => state.missed
      ? '연계 끊김'
      : state.finisher
      ? '마무리 일격'
      : state.nextFinisher
      ? '다음 마무리 · 금색에서 공격'
      : state.traitProc
      ? '연계 특성'
      : state.queued
      ? '연계 성공'
      : state.flow
      ? '연속 공격'
      : '';
  String get _count => state.endless
      ? '${state.count} COMBO ∞'
      : '${state.count} / ${state.chainLength} COMBO';

  Widget get _pips {
    final finite = !state.endless;
    final total = state.chainLength?.clamp(1, 8) ?? 3;
    return Row(
      key: const ValueKey('combo-progress-pips'),
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final filled = finite
            ? index < state.count
            : state.traitProc || index < state.count % 3;
        return Padding(
          padding: EdgeInsets.only(left: finite ? (index == 0 ? 0 : 2) : 4),
          child: Container(
            key: ValueKey('combo-progress-$index'),
            width: finite ? 3.5 : 5,
            height: finite ? 3.5 : 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? gold : const Color(0xff173331),
              border: Border.all(
                color: finite && state.nextFinisher && index == total - 1
                    ? const Color(0xffffedbd)
                    : const Color(0xffbb9b5d),
                width: finite ? .7 : 1,
              ),
            ),
          ),
        );
      }),
    );
  }

  String get _heading => state.nextFinisher
      ? '마무리 · 금색 공격'
      : !state.endless && (state.finisher || state.missed)
      ? _status
      : _count;

  Widget _text(String text, {double size = 14, Color color = gold}) =>
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: size,
            height: 1.05,
            fontWeight: FontWeight.w800,
            color: color,
            shadows: const [
              Shadow(
                color: Color(0xff081b1b),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      );

  Widget get _bar => CustomPaint(
    key: const ValueKey('combo-timing-bar'),
    painter: ComboTimingPainter(state),
    child: const SizedBox.expand(),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${state.endless ? '${state.count}회 무한 연계' : '${state.chainLength}회 중 ${state.count}회 연계'}${_status.isEmpty ? '' : ', $_status'}${state.nextFinisher ? '. 커서가 금색 구간에 올 때 공격 버튼을 다시 누르면 마무리 일격이 나갑니다' : ''}',
    excludeSemantics: true,
    child: compact
        ? LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                SizedBox(
                  width: (constraints.maxWidth * .25).clamp(22.0, 56.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _text(
                          state.nextFinisher
                              ? '마무리'
                              : state.endless
                              ? '${state.count}∞'
                              : '${state.count}/${state.chainLength}',
                          size: 12,
                          color: state.missed ? const Color(0xffe38b76) : gold,
                        ),
                      ),
                      if (!state.endless) ...[
                        const SizedBox(height: .5),
                        SizedBox(
                          height: 3,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _pips,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(child: SizedBox(height: 14, child: _bar)),
              ],
            ),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 17,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _text(
                          _heading,
                          size: state.nextFinisher ? 12 : 14,
                          color: state.missed ? const Color(0xffe38b76) : gold,
                        ),
                      ),
                      if (state.endless && _status.isNotEmpty)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _text(_status, size: 10, color: teal),
                          ),
                        ),
                      const SizedBox(width: 6),
                      _pips,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 13,
                child: state.endless
                    ? FractionallySizedBox(widthFactor: .72, child: _bar)
                    : _bar,
              ),
            ],
          ),
  );
}

class ComboTimingPainter extends CustomPainter {
  const ComboTimingPainter(this.state);
  final ComboHudState state;
  static double _unit(double value) =>
      value.isFinite ? value.clamp(0.0, 1.0) : 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final edge = math.min(7.0, size.height / 2);
    final shape = Path()
      ..moveTo(edge, 1)
      ..lineTo(size.width - edge, 1)
      ..lineTo(size.width - 1, size.height / 2)
      ..lineTo(size.width - edge, size.height - 1)
      ..lineTo(edge, size.height - 1)
      ..lineTo(1, size.height / 2)
      ..close();
    canvas.drawPath(shape, Paint()..color = const Color(0xee082c2b));
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.7
        ..color = const Color(0xff31271c),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = state.finisher || state.nextFinisher
            ? const Color(0xffffe2a4)
            : const Color(0xffd2ad65),
    );
    final inner = Rect.fromLTRB(
      edge + 3,
      3,
      size.width - edge - 3,
      size.height - 3,
    );
    if (inner.isEmpty) return;
    canvas.save();
    canvas.clipPath(shape);
    final start = _unit(state.windowStart), end = _unit(state.windowEnd);
    if (end > start && !state.missed) {
      final window = Rect.fromLTRB(
        inner.left + inner.width * start,
        2,
        inner.left + inner.width * end,
        size.height - 2,
      );
      canvas.drawRect(
        window,
        Paint()
          ..color = state.queued
              ? const Color(0xaa6be8c9)
              : state.nextFinisher
              ? const Color(0xdddf983c)
              : const Color(0x99b88a34),
      );
      canvas.drawRect(
        window.deflate(.7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..color = const Color(0xffffd58c),
      );
    }
    if (state.nextFinisher && end > start) {
      final center = Offset(
        inner.left + inner.width * (start + end) / 2,
        size.height / 2,
      );
      final radius = math.min(3.2, size.height * .24);
      final mark = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius, center.dy)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - radius, center.dy)
        ..close();
      canvas.drawPath(mark, Paint()..color = const Color(0xfffff0bb));
      canvas.drawPath(
        mark,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..color = const Color(0xff573315),
      );
    }
    for (var i = 1; i < 6; i++) {
      final x = inner.left + inner.width * i / 6;
      canvas.drawLine(
        Offset(x, 4),
        Offset(x, size.height - 4),
        Paint()
          ..color = const Color(0x4456a8a1)
          ..strokeWidth = .6,
      );
    }
    if (!state.missed) {
      final progress = state.queued && end > start
          ? (start + end) / 2
          : _unit(state.progress);
      final cursor = inner.left + inner.width * progress;
      canvas.drawLine(
        Offset(cursor, 1),
        Offset(cursor, size.height - 1),
        Paint()
          ..color = const Color(0x5571e6df)
          ..strokeWidth = 6,
      );
      canvas.drawLine(
        Offset(cursor, 1),
        Offset(cursor, size.height - 1),
        Paint()
          ..color = const Color(0xffe4fff0)
          ..strokeWidth = 1.8,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ComboTimingPainter oldDelegate) =>
      oldDelegate.state != state;
}
