import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'game_ui.dart';
import 'rpg_model.dart';
import 'rpg_widgets.dart';
import 'skill_tree_layout.dart';

class SkillTree extends StatefulWidget {
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
  State<SkillTree> createState() => _SkillTreeState();
}

class _SkillTreeState extends State<SkillTree> {
  int? _school;
  Adventure get session => widget.session;
  ScrollController get controller => widget.controller;
  SkillDef? get focused => widget.focused;
  ValueChanged<SkillDef> get onFocus => widget.onFocus;

  @override
  void didUpdateWidget(covariant SkillTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focused?.id != focused?.id && focused != null) {
      final next = skillTreeSchoolIndex(session.progress, focused!.id);
      if (_school != next) {
        _school = next;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && controller.hasClients) controller.jumpTo(0);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = session.progress;
    _school ??= focused == null ? 0 : skillTreeSchoolIndex(p, focused!.id);
    final labels = skillTreeSchoolLabels(p);
    return LayoutBuilder(
      builder: (context, box) {
        final dense = box.maxHeight < 180;
        final tiny = box.maxHeight < 110;
        final layout = SkillSchoolLayout(
          p,
          _school!,
          math.max(44, box.maxWidth - 18),
          dense: dense,
          textScale: MediaQuery.textScalerOf(context).scale(12) / 12,
        );
        void changeSchool(int school) {
          if (_school == school) return;
          setState(() => _school = school);
          if (controller.hasClients) controller.jumpTo(0);
          final first = p.skills
              .where(
                (skill) =>
                    skillTreeSkillVisible(p, skill) &&
                    skillTreeSchoolIndex(p, skill.id) == school,
              )
              .firstOrNull;
          if (first != null) onFocus(first);
        }

        void select(SkillDef skill) {
          onFocus(skill);
          if (!controller.hasClients) return;
          controller.animateTo(
            (layout.rects[skill.id]!.center.dy - (box.maxHeight - 44) / 2)
                .clamp(0.0, controller.position.maxScrollExtent),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }

        return Column(
          children: [
            SizedBox(
              key: const ValueKey('skill-school-header'),
              height: 44,
              child: Row(
                children: [
                  for (final (index, label) in labels.indexed)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index < labels.length - 1 ? 4 : 0,
                        ),
                        child: Semantics(
                          button: true,
                          selected: _school == index,
                          label: '$label 계열',
                          child: Material(
                            color: _school == index
                                ? const Color(0xff35554e)
                                : mobileRaisedSurface,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              key: ValueKey('skill-school-tab-$index'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => changeSchool(index),
                              child: Center(
                                child: Text(
                                  p.heroClass == HeroClass.warrior &&
                                          box.maxWidth < 310
                                      ? const ['함성', '숙련', '전투', '특수'][index]
                                      : label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: _school == index
                                        ? mobileText
                                        : const Color(0xffa1b2b6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: tiny ? 0 : 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xff111e26),
                  border: Border.all(color: mobileBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: tiny ? 0 : 4,
                  ),
                  child: Scrollbar(
                    controller: controller,
                    thumbVisibility: true,
                    thickness: 3,
                    child: SingleChildScrollView(
                      key: const ValueKey('skill-tree-vertical'),
                      controller: controller,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: layout.contentWidth,
                        height: layout.height,
                        child: Stack(
                          children: [
                            if (p.heroClass == HeroClass.warrior &&
                                _school! < 3)
                              for (
                                var tier = 0;
                                tier < warriorSkillTiers.length;
                                tier++
                              )
                                Positioned(
                                  left: 2,
                                  top:
                                      tier *
                                      (layout.nodeHeight + layout.rowGap),
                                  child: Text(
                                    'Lv. ${warriorSkillTiers[tier]}',
                                    style: const TextStyle(
                                      color: Color(0xff9cafaf),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _SchoolConnections(
                                  p,
                                  layout.skills,
                                  layout,
                                ),
                              ),
                            ),
                            for (final skill in layout.skills)
                              Positioned.fromRect(
                                rect: layout.rects[skill.id]!,
                                child: _node(
                                  skill,
                                  layout.rects[skill.id]!.width,
                                  dense,
                                  () => select(skill),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
        core = math.min(
          dense
              ? 36.0
              : p.heroClass == HeroClass.warrior
              ? 60.0
              : 52.0,
          width - 4,
        );
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
                        color: locked
                            ? const Color(0xff1b262d)
                            : mobileRaisedSurface,
                        border: Border.all(
                          color: chosen
                              ? mobileAccent
                              : rank > 0
                              ? color
                              : Colors.transparent,
                          width: chosen ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: chosen || canLearn
                            ? [
                                BoxShadow(
                                  color: mobileAccent.withValues(alpha: .12),
                                  blurRadius: 4,
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
                      fontSize: dense ? 11 : 12,
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

class _SchoolConnections extends CustomPainter {
  _SchoolConnections(this.progress, this.skills, this.layout);
  final Progress progress;
  final List<SkillDef> skills;
  final SkillNodeGeometry layout;
  @override
  void paint(Canvas canvas, Size size) {
    for (final child in skills) {
      for (final parent in child.requires.entries) {
        if (!layout.rects.containsKey(parent.key)) continue;
        final points = skillTreeConnectionPoints(layout, parent.key, child.id);
        final ready = progress.rank(parent.key) >= parent.value;
        final color = ready ? const Color(0xffbbccb4) : const Color(0xff64716f);
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xcc08100f)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = ready ? 2 : 1.5,
        );
        final end = points.last;
        canvas.drawPath(
          Path()
            ..moveTo(end.dx - 4, end.dy - 5)
            ..lineTo(end.dx, end.dy + 3)
            ..lineTo(end.dx + 4, end.dy - 5)
            ..close(),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SchoolConnections oldDelegate) => true;
}
