import 'dart:math' as math;

/// Presentation and timing are independent of the saved equipment identity.
/// Existing weapon IDs therefore keep their saves and physical hit shapes.
class WeaponComboProfile {
  const WeaponComboProfile(
    this.id,
    this.effect, {
    this.chainLength = 3,
    this.barDuration = .9,
    this.windowWidth = .25,
    this.changingWindow = false,
    this.finisherScale = 1.6,
  });

  final String id, effect;
  final int? chainLength;
  final double barDuration, windowWidth, finisherScale;
  final bool changingWindow;
  bool get endless => chainLength == null;
  String get chainLabel => endless ? '무한 콤보' : '$chainLength연격';

  ComboTimingWindow windowFor(int nextHit) {
    final center = changingWindow
        ? .50 + math.sin(nextHit * 2.3999632297) * .17
        : .68;
    return ComboTimingWindow(
      (center - windowWidth / 2).clamp(.08, .90),
      (center + windowWidth / 2).clamp(.10, .94),
    );
  }
}

const meleeWeaponProfiles = <String, WeaponComboProfile>{
  'shortsword': WeaponComboProfile('shortsword', 'crescent', chainLength: 3),
  'longsword': WeaponComboProfile('longsword', 'silver-cross', chainLength: 4),
  'axe': WeaponComboProfile('axe', 'amber-cleave', chainLength: 2),
  'mace': WeaponComboProfile('mace', 'iron-star', chainLength: 3),
  'greatsword': WeaponComboProfile(
    'greatsword',
    'broad-edge',
    chainLength: 2,
    barDuration: 1.05,
  ),
  'twinaxes': WeaponComboProfile('twinaxes', 'crossed-axes', chainLength: 5),
  'spear': WeaponComboProfile('spear', 'needle-thrust', chainLength: 4),
  'runeblade': WeaponComboProfile('runeblade', 'rune-arc', chainLength: 5),
  'dualblades': WeaponComboProfile(
    'dualblades',
    'twin-moons',
    chainLength: null,
    barDuration: .46,
    windowWidth: .28,
    changingWindow: true,
  ),
  'rapier': WeaponComboProfile(
    'rapier',
    'silver-lance',
    chainLength: 6,
    barDuration: .78,
  ),
  'katana': WeaponComboProfile('katana', 'draw-cut', chainLength: 5),
  'halberd': WeaponComboProfile('halberd', 'poleaxe-hook', chainLength: 3),
  'warhammer': WeaponComboProfile(
    'warhammer',
    'earth-crack',
    chainLength: 2,
    barDuration: 1.08,
  ),
  'flail': WeaponComboProfile('flail', 'chain-orbit', chainLength: 4),
  'glaive': WeaponComboProfile('glaive', 'jade-sweep', chainLength: 5),
  'falchion': WeaponComboProfile('falchion', 'sun-hook', chainLength: 4),
};

class ComboTimingWindow {
  const ComboTimingWindow(this.start, this.end);
  final double start, end;
  bool contains(double progress) => progress >= start && progress <= end;
}

enum ComboPress { started, linked, finisher, missed }

class ComboPressResult {
  const ComboPressResult(this.kind, this.count, {this.tripletProc = false});
  final ComboPress kind;
  final int count;
  final bool tripletProc;
  bool get successful => kind != ComboPress.missed;
}

/// Simulation-time judgement shared by input and the timing gauge.
/// Rendering never advances time or changes its judgement.
class TimedWeaponCombo {
  WeaponComboProfile? _profile;
  double elapsed = 0;
  int count = 0;
  bool get active => _profile != null && count > 0;
  double get progress =>
      !active ? 0 : (elapsed / _profile!.barDuration).clamp(0.0, 1.0);
  ComboTimingWindow? get window =>
      active ? _profile!.windowFor(count + 1) : null;

  void advance(double dt) {
    if (!active || !dt.isFinite || dt <= 0) return;
    elapsed += dt;
    if (elapsed > _profile!.barDuration) reset();
  }

  ComboPressResult press(
    WeaponComboProfile profile, {
    bool hasTripletTrait = false,
  }) {
    if (!active || _profile!.id != profile.id) {
      _profile = profile;
      elapsed = 0;
      count = 1;
      return const ComboPressResult(ComboPress.started, 1);
    }
    if (!window!.contains(progress)) {
      reset();
      return const ComboPressResult(ComboPress.missed, 0);
    }
    count++;
    elapsed = 0;
    final result = ComboPressResult(
      !profile.endless && count >= profile.chainLength!
          ? ComboPress.finisher
          : ComboPress.linked,
      count,
      tripletProc: hasTripletTrait && count % 3 == 0,
    );
    if (result.kind == ComboPress.finisher) reset();
    return result;
  }

  void reset() {
    _profile = null;
    elapsed = 0;
    count = 0;
  }
}
