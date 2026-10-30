/// Public combat units. Simulation and checkpoints retain canonical units so
/// changing the denomination cannot change combat ratios or migrate a save twice.
enum CombatUnit {
  stat(1000),
  resource(10);

  const CombatUnit(this.scale);
  final double scale;
}

enum CombatRounding { nearest, up, down }

abstract final class CombatNumbers {
  static double value(num canonical, CombatUnit unit) => canonical * unit.scale;

  static String stat(
    num canonical, {
    int digits = 0,
    CombatRounding rounding = CombatRounding.nearest,
  }) => format(
    canonical,
    unit: CombatUnit.stat,
    digits: digits,
    rounding: rounding,
  );
  static String resource(
    num canonical, {
    int digits = 0,
    CombatRounding rounding = CombatRounding.nearest,
  }) => format(
    canonical,
    unit: CombatUnit.resource,
    digits: digits,
    rounding: rounding,
  );

  static String format(
    num canonical, {
    required CombatUnit unit,
    int digits = 0,
    CombatRounding rounding = CombatRounding.nearest,
  }) {
    final scaled = value(canonical, unit);
    if (!scaled.isFinite) return '—';
    final shown = switch (rounding) {
      CombatRounding.nearest => scaled,
      CombatRounding.up => scaled.ceilToDouble(),
      CombatRounding.down => scaled.floorToDouble(),
    };
    final parts = shown.toStringAsFixed(digits).split('.');
    final fraction = parts.length == 1
        ? ''
        : parts[1].replaceFirst(RegExp(r'0+$'), '');
    final integer = parts.first == '-0' && fraction.isEmpty ? '0' : parts.first;
    final whole = integer.replaceAllMapped(
      RegExp(r'\d(?=(\d{3})+(?!\d))'),
      (m) => '${m[0]},',
    );
    return fraction.isEmpty ? whole : '$whole.$fraction';
  }
}
