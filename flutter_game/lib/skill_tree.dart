import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'game_ui.dart';
import 'interface_art.dart';
import 'panel_controls.dart';
import 'rpg_model.dart';
import 'rpg_widgets.dart';
import 'skill_tree_layout.dart';

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
    final p = session.progress,
        skills = p.skills
            .where((s) => !s.basic || s.id == p.defaultBasicId)
            .toList();
    return LayoutBuilder(
      builder: (context, box) {
        final dense = box.maxHeight < 110,
            header = dense ? 0.0 : 32.0,
            layout = SkillTreeLayout(
              p,
              box.maxWidth,
              dense: dense,
              textScale: MediaQuery.textScalerOf(context).scale(12) / 12,
            ),
            rects = layout.rects,
            height = layout.height;
        void select(SkillDef skill) {
          onFocus(skill);
          if (!controller.hasClients) return;
          final target =
              (rects[skill.id]!.center.dy - (box.maxHeight - header) / 2).clamp(
                0.0,
                controller.position.maxScrollExtent,
              );
          controller.animateTo(
            target,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              if (!dense)
                SizedBox(
                  key: const ValueKey('skill-school-header'),
                  height: header,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _TabletSection(
                          width: box.maxWidth,
                          height: header,
                          heading: true,
                        ),
                      ),
                      Row(
                        children: [
                          for (final branch in p.skillBranches)
                            Expanded(
                              child: Text(
                                branch,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: gold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Scrollbar(
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
                            child: _TabletSection(
                              width: box.maxWidth,
                              height: height,
                            ),
                          ),
                          const Positioned.fill(
                            child: ColoredBox(color: Color(0x33030c0c)),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _Connections(p, skills, rects),
                            ),
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
                ),
              ),
            ],
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
                                  color: gold.withValues(alpha: .25),
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

// Split the existing artwork at its title band instead of squeezing the full
// tablet into a short viewport. Both sections share the decoded image cache.
class _TabletSection extends StatelessWidget {
  const _TabletSection({
    required this.width,
    required this.height,
    this.heading = false,
  });
  final double width, height;
  final bool heading;
  static const headingFraction = 92 / 1152;

  @override
  Widget build(BuildContext context) {
    final imageHeight =
        height / (heading ? headingFraction : 1 - headingFraction);
    return ExcludeSemantics(
      child: ClipRect(
        child: OverflowBox(
          alignment: heading ? Alignment.topCenter : Alignment.bottomCenter,
          minWidth: width,
          maxWidth: width,
          minHeight: imageHeight,
          maxHeight: imageHeight,
          child: Image(
            image: skillTabletArtwork,
            width: width,
            height: imageHeight,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
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
    final groups = <String, List<SkillDef>>{};
    for (final skill in skills) {
      if (skill.requires.isEmpty) continue;
      final entries = skill.requires.entries.toList()
        ..sort(
          (a, b) => rects[a.key]!.center.dx.compareTo(rects[b.key]!.center.dx),
        );
      final key =
          '${rects[skill.id]!.top}|${entries.map((e) => e.key).join(',')}';
      (groups[key] ??= []).add(skill);
    }
    Color tint(bool ready, bool learned) => ready
        ? (learned ? const Color(0xff8ee3c3) : gold)
        : const Color(0xff778276);
    void line(Path path, Color color, bool ready) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xdd020807)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = ready ? 2.5 : 1.8
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final children in groups.values) {
      final requirements = children.first.requires.entries.toList()
        ..sort(
          (a, b) => rects[a.key]!.center.dx.compareTo(rects[b.key]!.center.dx),
        );
      final parents = requirements.map((e) => rects[e.key]!).toList();
      final top = parents.first.bottom, bottom = rects[children.first.id]!.top;
      final parentX =
          parents.map((r) => r.center.dx).reduce((a, b) => a + b) /
          parents.length;
      final childX =
          children.map((s) => rects[s.id]!.center.dx).reduce((a, b) => a + b) /
          children.length;
      final hub = Offset((parentX + childX) / 2, top + (bottom - top) * .5);
      final anyReady = children.any(progress.prerequisitesMet);
      for (final requirement in requirements) {
        final parent = rects[requirement.key]!;
        final a = parent.bottomCenter + const Offset(0, 3);
        // Shared trunks indicate a usable path to at least one child. Each
        // child arrow separately checks all of that child's required ranks.
        final met = children.any(
          (child) =>
              progress.rank(requirement.key) >=
              child.requires[requirement.key]!,
        );
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(
            a.dx,
            a.dy + (hub.dy - a.dy) * .65,
            hub.dx,
            hub.dy - (hub.dy - a.dy) * .25,
            hub.dx,
            hub.dy,
          );
        line(
          path,
          tint(met, children.every((s) => progress.rank(s.id) > 0)),
          met,
        );
      }
      for (final child in children) {
        final b = rects[child.id]!.topCenter;
        final end = b - const Offset(0, 12);
        final ready = progress.prerequisitesMet(child);
        final color = tint(ready, progress.rank(child.id) > 0);
        final path = Path()
          ..moveTo(hub.dx, hub.dy)
          ..cubicTo(
            hub.dx,
            hub.dy + (end.dy - hub.dy) * .35,
            end.dx,
            end.dy - (end.dy - hub.dy) * .25,
            end.dx,
            end.dy,
          )
          ..lineTo(b.dx, b.dy - 7);
        line(path, color, ready);
        canvas.drawPath(
          Path()
            ..moveTo(b.dx - 4, b.dy - 11)
            ..lineTo(b.dx, b.dy - 3)
            ..lineTo(b.dx + 4, b.dy - 11)
            ..close(),
          Paint()..color = color,
        );
      }
      canvas.drawCircle(hub, 3, Paint()..color = const Color(0xff061410));
      canvas.drawCircle(
        hub,
        1.8,
        Paint()
          ..color = tint(
            anyReady,
            children.every((s) => progress.rank(s.id) > 0),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Connections oldDelegate) => true;
}
