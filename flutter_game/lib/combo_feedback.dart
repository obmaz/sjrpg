import 'package:flutter/foundation.dart';

/// Simulation-owned view data. Painting never advances or judges the combo.
@immutable
class ComboHudState {
  const ComboHudState({
    this.count = 0,
    this.chainLength,
    this.progress = 0,
    this.windowStart = 0,
    this.windowEnd = 0,
    this.active = false,
    this.queued = false,
    this.finisher = false,
    this.missed = false,
    this.traitProc = false,
    this.flow = false,
  });

  final int count;
  final int? chainLength;
  final double progress, windowStart, windowEnd;
  final bool active, queued, finisher, missed, traitProc, flow;
  bool get endless => chainLength == null;

  /// The next accepted press finishes this finite chain; no new combat rule.
  bool get nextFinisher =>
      active &&
      !queued &&
      !finisher &&
      !missed &&
      chainLength != null &&
      count == chainLength! - 1 &&
      windowEnd > windowStart;
  bool get visible => active || finisher || missed || traitProc;

  @override
  bool operator ==(Object other) =>
      other is ComboHudState &&
      count == other.count &&
      chainLength == other.chainLength &&
      progress == other.progress &&
      windowStart == other.windowStart &&
      windowEnd == other.windowEnd &&
      active == other.active &&
      queued == other.queued &&
      finisher == other.finisher &&
      missed == other.missed &&
      traitProc == other.traitProc &&
      flow == other.flow;

  @override
  int get hashCode => Object.hash(
    count,
    chainLength,
    progress,
    windowStart,
    windowEnd,
    active,
    queued,
    finisher,
    missed,
    traitProc,
    flow,
  );
}
