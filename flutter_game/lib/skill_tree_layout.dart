import 'dart:math' as math;
import 'dart:ui';

import 'rpg_model.dart';

typedef SkillTreeSlot = ({String id, double column});

// Diablo II Barbarian: warcries, masteries and combat skills, three columns
// per school and six level tiers. Empty spaces intentionally carry long arrows.
const _warriorRows = <List<SkillTreeSlot>>[
  [
    (id: 'howl', column: 0),
    (id: 'findPotion', column: 2),
    (id: 'swordMastery', column: 3),
    (id: 'axeMastery', column: 4),
    (id: 'maceMastery', column: 5),
    (id: 'bash', column: 7),
  ],
  [
    (id: 'taunt', column: 0),
    (id: 'shout', column: 1),
    (id: 'polearmMastery', column: 3),
    (id: 'throwingMastery', column: 4),
    (id: 'spearMastery', column: 5),
    (id: 'leap', column: 6),
    (id: 'doubleSwing', column: 8),
  ],
  [
    (id: 'findItem', column: 2),
    (id: 'increasedStamina', column: 3),
    (id: 'stun', column: 7),
    (id: 'doubleThrow', column: 8),
  ],
  [
    (id: 'battleCry', column: 0),
    (id: 'ironSkin', column: 5),
    (id: 'leapAttack', column: 6),
    (id: 'concentrate', column: 7),
  ],
  [
    (id: 'battleOrders', column: 1),
    (id: 'grimWard', column: 2),
    (id: 'increasedSpeed', column: 3),
    (id: 'frenzy', column: 8),
  ],
  [
    (id: 'warcry', column: 0),
    (id: 'battleCommand', column: 1),
    (id: 'naturalResistance', column: 5),
    (id: 'whirlwind', column: 6),
    (id: 'berserk', column: 7),
  ],
];
const warriorSkillTiers = [1, 6, 12, 18, 24, 30];
const warriorSchoolLabels = ['함성', '전투 숙련', '전투 기술'];
final warriorTreeIds = Set<String>.unmodifiable(
  _warriorRows.expand((row) => row.map((slot) => slot.id)),
);

bool skillTreeSkillVisible(Progress progress, SkillDef skill) =>
    progress.heroClass == HeroClass.warrior
    ? warriorTreeIds.contains(skill.id) ||
          skill.id == 'shadowAssault' ||
          skill.id == 'battleSprint'
    : !skill.basic || skill.id == progress.defaultBasicId;

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
    (id: 'meteor', column: 0),
    (id: 'coldMastery', column: 2),
    (id: 'lightningMastery', column: 3.5),
    (id: 'blink', column: 5),
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
abstract interface class SkillNodeGeometry {
  Map<String, Rect> get rects;
  double get contentWidth;
  double get rowGap;
  int get columns;
}

class SkillTreeLayout implements SkillNodeGeometry {
  SkillTreeLayout(
    Progress progress,
    double width, {
    required bool dense,
    required double textScale,
  }) {
    columns = progress.heroClass == HeroClass.warrior ? 9 : 6;
    final rows = skillTreeRows(progress.heroClass);
    contentWidth = progress.heroClass == HeroClass.warrior
        ? math.max(900.0, width)
        : width;
    if (progress.heroClass == HeroClass.warrior) {
      _warrior(progress, dense: dense, textScale: textScale);
      return;
    }
    final label = (dense ? 11.0 : 12.0) * textScale * 1.1;
    nodeHeight = math
        .max(dense ? 70.0 : 94.0, (dense ? 36.0 : 52.0) + 4 + label * 2 + 8)
        .ceilToDouble();
    rowGap = dense ? 48 : 64;
    final unit = width / 6;
    for (var row = 0; row < rows.length; row++) {
      final mobilityRow = rows[row].any(
        (slot) => slot.id == progress.mobilitySkill.id,
      );
      for (final slot in rows[row]) {
        final split =
            mobilityRow ||
            rows[row].any(
              (other) =>
                  other.id != slot.id &&
                  (other.column - slot.column).abs() <= 1.5,
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
  void _warrior(
    Progress progress, {
    required bool dense,
    required double textScale,
  }) {
    final label = (dense ? 11.0 : 12.0) * textScale * 1.1;
    nodeHeight = math
        .max(dense ? 70.0 : 100.0, (dense ? 36.0 : 52.0) + 12 + label * 2)
        .ceilToDouble();
    rowGap = 64;
    final unit = contentWidth / 9;
    for (var row = 0; row < _warriorRows.length; row++) {
      for (final slot in _warriorRows[row]) {
        rects[slot.id] = Rect.fromLTWH(
          (slot.column + .5) * unit - 42,
          (dense ? 10 : 34) + row * (nodeHeight + rowGap),
          84,
          nodeHeight,
        );
      }
    }
    bonusTop = 50 + 6 * nodeHeight + 5 * rowGap;
    final extras = progress.skills
        .where(
          (skill) =>
              !warriorTreeIds.contains(skill.id) &&
              skillTreeSkillVisible(progress, skill),
        )
        .toList();
    for (var i = 0; i < extras.length; i++) {
      final column = i % 3, row = i ~/ 3;
      rects[extras[i].id] = Rect.fromLTWH(
        (column + .5) * contentWidth / 3 - 110,
        bonusTop! + 38 + row * (nodeHeight + 12),
        220,
        nodeHeight,
      );
    }
    height =
        bonusTop! +
        (extras.isEmpty
            ? 0
            : 50 + ((extras.length + 2) ~/ 3) * (nodeHeight + 12));
  }

  @override
  final rects = <String, Rect>{};
  @override
  late final double contentWidth;
  @override
  late final int columns;
  double? bonusTop;
  List<Rect> get schoolBounds => [
    for (var school = 0; school < 3; school++)
      Rect.fromLTWH(
        school * contentWidth / 3,
        0,
        contentWidth / 3,
        bonusTop ?? height,
      ),
  ];
  late final double nodeHeight, height;
  @override
  late final double rowGap;
}

/// Compact school-local arrows. A skipped node is routed in the empty gutter,
/// never through another skill's icon or label.
List<Offset> skillTreeConnectionPoints(
  SkillNodeGeometry layout,
  String parentId,
  String childId,
) {
  final parent = layout.rects[parentId]!, child = layout.rects[childId]!;
  final start = parent.bottomCenter + const Offset(0, 3),
      end = child.topCenter - const Offset(0, 8);
  bool crosses(Offset a, Offset b) => layout.rects.entries.any(
    (entry) =>
        entry.key != parentId &&
        entry.key != childId &&
        Rect.fromPoints(a, b).inflate(3).overlaps(entry.value),
  );
  if ((start.dx - end.dx).abs() < 1 && !crosses(start, end)) {
    return [start, end];
  }
  final firstY = start.dy + layout.rowGap * .3,
      lastY = end.dy - layout.rowGap * .3;
  if ((start.dx - end.dx).abs() < 1 ||
      crosses(Offset(start.dx, firstY), Offset(end.dx, lastY))) {
    final unit = layout.contentWidth / layout.columns;
    final column = (parent.center.dx / unit).floor();
    final gutter = column % 3 == 2 ? column * unit : (column + 1) * unit;
    return [
      start,
      Offset(start.dx, firstY),
      Offset(gutter, firstY),
      Offset(gutter, lastY),
      Offset(end.dx, lastY),
      end,
    ];
  }
  return [start, Offset(start.dx, firstY), Offset(end.dx, lastY), end];
}

List<String> skillTreeSchoolLabels(Progress progress) =>
    progress.heroClass == HeroClass.warrior
    ? [...warriorSchoolLabels, '특수']
    : progress.skillBranches;

int skillTreeSchoolIndex(Progress progress, String id) {
  if (progress.heroClass == HeroClass.warrior) {
    for (final row in _warriorRows) {
      for (final slot in row) {
        if (slot.id == id) return slot.column ~/ 3;
      }
    }
    return 3;
  }
  final skill = progress.skills.where((skill) => skill.id == id).firstOrNull;
  return skill == null
      ? 0
      : progress.skillBranches.indexOf(skill.branch).clamp(0, 2);
}

/// One selected school uses the complete viewport. Reference D2 cells remain
/// unchanged; tabs translate their three columns without shrinking touch areas.
class SkillSchoolLayout implements SkillNodeGeometry {
  SkillSchoolLayout(
    Progress progress,
    this.school,
    this.contentWidth, {
    required bool dense,
    required double textScale,
  }) {
    final reference = SkillTreeLayout(
      progress,
      900,
      dense: dense,
      textScale: textScale,
    );
    nodeHeight = reference.nodeHeight;
    rowGap = reference.rowGap;
    skills = progress.skills
        .where(
          (skill) =>
              skillTreeSkillVisible(progress, skill) &&
              skillTreeSchoolIndex(progress, skill.id) == school,
        )
        .toList();
    if (progress.heroClass == HeroClass.warrior && school == 3) {
      for (final (index, skill) in skills.indexed) {
        final unit = contentWidth / 2, nodeWidth = math.min(120.0, unit - 12);
        rects[skill.id] = Rect.fromLTWH(
          (index % 2 + .5) * unit - nodeWidth / 2,
          (dense ? 0 : 16) + (index ~/ 2) * (nodeHeight + 24),
          nodeWidth,
          nodeHeight,
        );
      }
      height = 32 + ((skills.length + 1) ~/ 2) * (nodeHeight + 24);
      return;
    }
    final rows = skillTreeRows(progress.heroClass);
    for (var row = 0; row < rows.length; row++) {
      for (final slot in rows[row]) {
        if (!skills.any((skill) => skill.id == slot.id)) continue;
        final localColumn = progress.heroClass == HeroClass.warrior
            ? slot.column % 3
            : switch (slot.id) {
                'lightningMastery' => 0.0,
                'blink' => 2.0,
                _ => (slot.column - school * 2) * 2,
              };
        final unit = contentWidth / 3, nodeWidth = math.min(100.0, unit - 8);
        rects[slot.id] = Rect.fromLTWH(
          (localColumn + .5) * unit - nodeWidth / 2,
          (dense ? 0 : 30) + row * (nodeHeight + rowGap),
          nodeWidth,
          nodeHeight,
        );
      }
    }
    height = rects.isEmpty
        ? 0
        : rects.values.map((rect) => rect.bottom).reduce(math.max) + 16;
  }
  final int school;
  @override
  final double contentWidth;
  @override
  final int columns = 3;
  @override
  final rects = <String, Rect>{};
  late final List<SkillDef> skills;
  late final double nodeHeight, height;
  @override
  late final double rowGap;
}
