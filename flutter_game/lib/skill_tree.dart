import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_ui.dart';
import 'rpg_model.dart';
import 'rpg_widgets.dart';
import 'panel_controls.dart';

// Within each family the branches split and rejoin. Row numbers are a minimum:
// a cross-family prerequisite always pushes its child below every parent.
const _positions = <String, (int, double)>{
  'cleave': (0, 0),
  'whirlwind': (1, -.24),
  'frenzy': (1, .24),
  'seismicSlam': (2, 0),
  'rendingEdge': (3, -.24),
  'stormOfSteel': (4, 0),
  'mastery': (0, 0),
  'ironSkin': (1, -.24),
  'weaponTempo': (1, .24),
  'veteranGuard': (2, -.24),
  'battleFocus': (2, .24),
  'secondWind': (3, 0),
  'warcry': (0, 0),
  'battleVigor': (1, -.24),
  'resoundingCry': (1, .24),
  'warDrums': (2, -.24),
  'rallyingVoice': (2, .24),
  'unyieldingOath': (3, 0),
  'firebolt': (0, 0),
  'warmth': (1, -.24),
  'emberFocus': (1, .24),
  'cinderReach': (2, -.24),
  'meteor': (2, .24),
  'phoenixHeart': (3, 0),
  'frostNova': (0, 0),
  'iceArmor': (1, -.24),
  'deepFreeze': (2, -.24),
  'coldMastery': (2, .24),
  'frozenAegis': (3, -.24),
  'glacialReserve': (4, 0),
  'arcaneMastery': (0, 0),
  'conductivity': (1, .24),
  'chainLightning': (2, -.24),
  'forkedStorm': (3, -.24),
  'lightningMastery': (3, .24),
  'arcaneEconomy': (4, 0),
};

class SkillTree extends StatelessWidget {
  const SkillTree({
    required this.session,
    required this.controller,
    required this.focused,
    required this.onFocus,
    super.key,
  });
  final Adventure session;
  final ScrollController controller;
  final SkillDef? focused;
  final ValueChanged<SkillDef> onFocus;
  @override
  Widget build(BuildContext context) {
    final p = session.progress, skills = p.skills, rows = <String, int>{};
    int row(SkillDef skill) => rows.putIfAbsent(skill.id, () {
      final parents = skills.where((s) => skill.requires.containsKey(s.id));
      return math.max(
        _positions[skill.id]?.$1 ?? 0,
        parents.isEmpty ? 0 : 1 + parents.map(row).reduce(math.max),
      );
    });
    for (final skill in skills) {
      row(skill);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final dense = box.maxHeight < 110, lane = box.maxWidth / 3;
        final nodeHeight = dense ? 62.0 : 88.0,
            gap = dense ? 24.0 : 30.0,
            header = dense ? 0.0 : 30.0;
        final rects = <String, Rect>{};
        for (final skill in skills) {
          final family = p.skillBranches.indexOf(skill.branch),
              offset = _positions[skill.id]?.$2 ?? 0;
          final width = math.min(
            offset == 0 ? 120.0 : 96.0,
            offset == 0 ? lane - 8 : lane / 2 - 4,
          );
          final x = lane * (family + .5 + offset);
          rects[skill.id] = Rect.fromLTWH(
            x - width / 2,
            header + 8 + row(skill) * (nodeHeight + gap),
            width,
            nodeHeight,
          );
        }
        final height =
            header +
            16 +
            (rows.values.reduce(math.max) + 1) * (nodeHeight + gap) -
            gap;
        void select(SkillDef skill) {
          onFocus(skill);
          if (!controller.hasClients) return;
          final target = (rects[skill.id]!.center.dy - box.maxHeight / 2).clamp(
            0.0,
            controller.position.maxScrollExtent,
          );
          controller.animateTo(
            target,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }

        return Scrollbar(
          controller: controller,
          thumbVisibility: true,
          thickness: 3,
          child: SingleChildScrollView(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: box.maxWidth,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: Image.asset(
                        'assets/images/skill-tablet.webp',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ColoredBox(color: const Color(0x33030c0c)),
                  ),
                  if (!dense)
                    for (var i = 0; i < 3; i++)
                      Positioned(
                        left: i * lane,
                        top: 7,
                        width: lane,
                        height: 22,
                        child: Text(
                          p.skillBranches[i],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: gold,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  Positioned.fill(
                    child: CustomPaint(painter: _Connections(p, skills, rects)),
                  ),
                  for (final skill in skills)
                    Positioned.fromRect(
                      rect: rects[skill.id]!,
                      child: _node(
                        skill,
                        rects[skill.id]!.width,
                        dense,
                        () => select(skill),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _node(SkillDef skill, double width, bool dense, VoidCallback onTap) {
    final p = session.progress,
        rank = p.rank(skill.id),
        chosen = focused?.id == skill.id;
    final locked =
        rank == 0 &&
        (p.level < skill.requiredLevel || !p.prerequisitesMet(skill));
    final canLearn = p.canLearn(skill),
        color = skillColor(skill),
        core = math.min(dense ? 36.0 : 52.0, width - 4);
    return Semantics(
      container: true,
      button: true,
      selected: chosen,
      label: '스킬 보기 · ${skill.name} · $rank 등급',
      hint: '${skill.branch} · 필요 레벨 ${skill.requiredLevel}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            key: ValueKey('skill-node-${skill.id}'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: core,
                      height: core,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        image: gameButtonImage(enabled: !locked),
                        border: Border.all(
                          color: chosen
                              ? gold
                              : rank > 0
                              ? color
                              : Colors.transparent,
                          width: chosen ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: chosen || canLearn
                            ? [
                                BoxShadow(
                                  color: gold.withValues(alpha: .24),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Opacity(
                        opacity: locked ? .35 : 1,
                        child: CustomPaint(
                          painter: EffectIconPainter(
                            session.art,
                            skillEffect(skill.id),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff091513),
                          border: Border.all(
                            color: rank > 0 ? gold : const Color(0xff56645b),
                          ),
                        ),
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            color: rank > 0 ? gold : const Color(0xffa7b4ab),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (locked)
                      const Positioned(
                        left: -2,
                        top: -2,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: Color(0xffb3c1b7),
                        ),
                      ),
                    if (canLearn)
                      const Positioned(
                        right: -3,
                        top: -4,
                        child: Icon(Icons.add_circle, size: 14, color: gold),
                      ),
                    if (!skill.passive && p.skillSlots.contains(skill.id))
                      Positioned(
                        left: -3,
                        top: -4,
                        child: Text(
                          '${p.skillSlots.indexOf(skill.id) + 1}',
                          style: const TextStyle(
                            color: cream,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    skill.shortName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: locked ? const Color(0xffa7b4ab) : cream,
                      fontSize: dense ? 10 : 12,
                      height: 1.1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Connections extends CustomPainter {
  _Connections(this.progress, this.skills, this.rects);
  final Progress progress;
  final List<SkillDef> skills;
  final Map<String, Rect> rects;
  @override
  void paint(Canvas canvas, Size size) {
    final lane = size.width / 3;
    for (final skill in skills) {
      for (final requirement in skill.requires.entries) {
        final parent = rects[requirement.key], child = rects[skill.id];
        if (parent == null || child == null) continue;
        final a = parent.bottomCenter,
            b = child.topCenter,
            ready = progress.rank(requirement.key) >= requirement.value;
        final color = ready
            ? (progress.rank(skill.id) > 0 ? const Color(0xff8ee3c3) : gold)
            : const Color(0xff778276);
        final path = Path()..moveTo(a.dx, a.dy);
        final parentLane = (a.dx / lane).floor(),
            childLane = (b.dx / lane).floor();
        if (parentLane != childLane) {
          final rail = (math.min(parentLane, childLane) + 1) * lane;
          path
            ..lineTo(a.dx, a.dy + 12)
            ..lineTo(rail, a.dy + 12)
            ..lineTo(rail, b.dy - 12)
            ..lineTo(b.dx, b.dy - 12);
        } else {
          path
            ..lineTo(a.dx, a.dy + 12)
            ..lineTo(b.dx, b.dy - 12);
        }
        path.lineTo(b.dx, b.dy - 4);
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xbb020807)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = ready ? 2.5 : 1.7
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(
          Path()
            ..moveTo(b.dx - 4, b.dy - 8)
            ..lineTo(b.dx, b.dy - 2)
            ..lineTo(b.dx + 4, b.dy - 8)
            ..close(),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Connections oldDelegate) => true;
}
