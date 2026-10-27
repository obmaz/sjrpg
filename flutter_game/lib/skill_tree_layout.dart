import 'dart:math' as math;
import 'dart:ui';

import 'rpg_model.dart';

typedef SkillTreeSlot = ({String id, double column});

// Six visual columns keep the first forks in reading order. Later nodes retain
// their school positions; adjacency means neighboring visible nodes in a row.
const _warriorRows = <List<SkillTreeSlot>>[
  [
    (id: 'cleave', column: .5),
    (id: 'mastery', column: 2.5),
    (id: 'warcry', column: 4.5),
  ],
  [
    (id: 'whirlwind', column: 0),
    (id: 'frenzy', column: 1),
    (id: 'ironSkin', column: 2),
    (id: 'weaponTempo', column: 3),
    (id: 'battleVigor', column: 4),
    (id: 'resoundingCry', column: 5),
  ],
  [
    (id: 'seismicSlam', column: .5),
    (id: 'battleFocus', column: 2.5),
    (id: 'rallyingVoice', column: 4.5),
  ],
  [
    (id: 'charge', column: 0),
    (id: 'rendingEdge', column: 1),
    (id: 'veteranGuard', column: 2.5),
    (id: 'warDrums', column: 4.5),
  ],
  [
    (id: 'crushingBlow', column: 0),
    (id: 'stormOfSteel', column: 1),
    (id: 'secondWind', column: 2.5),
    (id: 'unyieldingOath', column: 4.5),
  ],
];
const _mageRows = <List<SkillTreeSlot>>[
  [
    (id: 'firebolt', column: .5),
    (id: 'frostNova', column: 2.5),
    (id: 'arcaneMastery', column: 4.5),
  ],
  [
    (id: 'warmth', column: 0),
    (id: 'emberFocus', column: 1),
    (id: 'iceArmor', column: 2),
    (id: 'deepFreeze', column: 3),
    (id: 'chainLightning', column: 4),
    (id: 'conductivity', column: 5),
  ],
  [
    (id: 'meteor', column: .5),
    (id: 'coldMastery', column: 2.5),
    (id: 'lightningMastery', column: 4.5),
  ],
  [
    (id: 'cinderReach', column: .5),
    (id: 'frozenAegis', column: 2.5),
    (id: 'forkedStorm', column: 4.5),
  ],
  [
    (id: 'phoenixHeart', column: .5),
    (id: 'glacialReserve', column: 2.5),
    (id: 'arcaneEconomy', column: 4.5),
  ],
];

List<List<SkillTreeSlot>> skillTreeRows(HeroClass heroClass) =>
    heroClass == HeroClass.warrior ? _warriorRows : _mageRows;

/// Geometry has fixed rows, independent of points, locks or old learned ranks.
class SkillTreeLayout {
  SkillTreeLayout(
    Progress progress,
    double width, {
    required bool dense,
    required double textScale,
  }) {
    final rows = skillTreeRows(progress.heroClass);
    final label = (dense ? 11.0 : 12.0) * textScale * 1.1;
    nodeHeight = math
        .max(dense ? 70.0 : 94.0, (dense ? 36.0 : 52.0) + 4 + label * 2 + 8)
        .ceilToDouble();
    rowGap = dense ? 48 : 64;
    final unit = width / 6;
    for (var row = 0; row < rows.length; row++) {
      for (final slot in rows[row]) {
        final split = rows[row].any(
          (other) =>
              other.id != slot.id && (other.column - slot.column).abs() < 1.5,
        );
        final nodeWidth = math.min(
          split ? 96.0 : 120.0,
          split ? math.max(44.0, unit - 2) : width / 3 - 8,
        );
        rects[slot.id] = Rect.fromLTWH(
          (slot.column + .5) * unit - nodeWidth / 2,
          10 + row * (nodeHeight + rowGap),
          nodeWidth,
          nodeHeight,
        );
      }
    }
    height = 20 + rows.length * nodeHeight + (rows.length - 1) * rowGap;
  }
  final rects = <String, Rect>{};
  late final double nodeHeight, rowGap, height;
}
