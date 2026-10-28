import 'dart:math' as math;

/// A physical projectile profile, independent of melee timing combos.
class ThrownWeaponProfile {
  const ThrownWeaponProfile(
    this.id, {
    required this.speed,
    this.impactRadius = 7,
  });

  final String id;
  final double speed, impactRadius;
}

const throwingWeaponProfiles = <String, ThrownWeaponProfile>{
  'throwingaxes': ThrownWeaponProfile(
    'throwingaxes',
    speed: 520,
    impactRadius: 9,
  ),
  'javelin': ThrownWeaponProfile('javelin', speed: 640, impactRadius: 6),
};

/// Presentation and timing are independent of the saved equipment identity.
/// Existing weapon IDs therefore keep their saves and physical hit shapes.
class WeaponComboProfile {
  const WeaponComboProfile(
    this.id,
    this.effect, {
    this.chainLength = 5,
    this.barDuration = .58,
    this.windowWidth = .25,
    this.changingWindow = false,
    this.finisherScale = 1.6,
  });

  static const flowDamageScale = .35;
  static const flowIntervalScale = .45;
  static const successRecoveryScale = .65;

  final String id, effect;
  final int? chainLength;
  final double barDuration, windowWidth, finisherScale;
  final bool changingWindow;
  bool get endless => chainLength == null;
  String get chainLabel => endless ? '무한 콤보' : '$chainLength연격';

  ComboTimingWindow windowFor(int nextHit, {double? roll}) {
    final position =
        (roll ??
                (changingWindow
                    ? .5 + math.sin(nextHit * 2.3999632297) * .5
                    : .6))
            .clamp(0.0, 1.0);
    final width = windowWidth.clamp(.12, .45);
    const firstThird = 1 / 3;
    final start = firstThird + position * (.94 - width - firstThird);
    return ComboTimingWindow(start, start + width);
  }
}

const meleeWeaponProfiles = <String, WeaponComboProfile>{
  'shortsword': WeaponComboProfile('shortsword', 'crescent', chainLength: 5),
  'longsword': WeaponComboProfile('longsword', 'silver-cross', chainLength: 6),
  'axe': WeaponComboProfile('axe', 'amber-cleave', chainLength: 4),
  'mace': WeaponComboProfile('mace', 'iron-star', chainLength: 5),
  'greatsword': WeaponComboProfile(
    'greatsword',
    'broad-edge',
    chainLength: 4,
    barDuration: .68,
  ),
  'twinaxes': WeaponComboProfile('twinaxes', 'crossed-axes', chainLength: 7),
  'spear': WeaponComboProfile('spear', 'needle-thrust', chainLength: 6),
  'runeblade': WeaponComboProfile('runeblade', 'rune-arc', chainLength: 7),
  'dualblades': WeaponComboProfile(
    'dualblades',
    'twin-moons',
    chainLength: null,
    barDuration: .30,
    windowWidth: .28,
    changingWindow: true,
  ),
  'rapier': WeaponComboProfile(
    'rapier',
    'silver-lance',
    chainLength: 8,
    barDuration: .50,
  ),
  'katana': WeaponComboProfile('katana', 'draw-cut', chainLength: 7),
  'halberd': WeaponComboProfile('halberd', 'poleaxe-hook', chainLength: 5),
  'warhammer': WeaponComboProfile(
    'warhammer',
    'earth-crack',
    chainLength: 4,
    barDuration: .70,
  ),
  'flail': WeaponComboProfile('flail', 'chain-orbit', chainLength: 6),
  'glaive': WeaponComboProfile('glaive', 'jade-sweep', chainLength: 7),
  'falchion': WeaponComboProfile('falchion', 'sun-hook', chainLength: 6),
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
  TimedWeaponCombo({math.Random? random}) : _random = random ?? math.Random();
  final math.Random _random;
  ComboTimingWindow? _window;
  WeaponComboProfile? _profile;
  double elapsed = 0;
  int count = 0;
  bool get active => _profile != null && count > 0;
  double get progress =>
      !active ? 0 : (elapsed / _profile!.barDuration).clamp(0.0, 1.0);
  ComboTimingWindow? get window => active ? _window : null;

  void _openWindow() {
    _window = _profile!.windowFor(count + 1, roll: _random.nextDouble());
  }

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
      _openWindow();
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
    if (result.kind == ComboPress.finisher) {
      reset();
    } else {
      _openWindow();
    }
    return result;
  }

  void reset() {
    _profile = null;
    _window = null;
    elapsed = 0;
    count = 0;
  }
}
