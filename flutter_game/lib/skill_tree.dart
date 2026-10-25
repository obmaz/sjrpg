import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_ui.dart';
import 'rpg_model.dart';
import 'rpg_widgets.dart';

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
    final p = session.progress;
    final skills = p.skills;
    final short = MediaQuery.sizeOf(context).height < 520;
    final depths = <String, int>{};
    int depth(SkillDef skill) => depths.putIfAbsent(skill.id, () {
      final parents = skills.where(
        (parent) => skill.requires.containsKey(parent.id),
      );
      return parents.isEmpty ? 0 : 1 + parents.map(depth).reduce(math.max);
    });
    final layers = <int, List<SkillDef>>{};
    for (final skill in skills) {
      layers.putIfAbsent(depth(skill), () => []).add(skill);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final dense = short && box.maxHeight < 90;
        final nodeHeight = short ? (dense ? 76.0 : 88.0) : 106.0;
        final step = nodeHeight + 30;
        final width = box.maxWidth, rects = <String, Rect>{};
        final columns = layers.values.map((row) => row.length).reduce(math.max);
        final nodeWidth = math.min(132.0, width / columns - 6);
        for (final layer in layers.entries) {
          for (var i = 0; i < layer.value.length; i++) {
            final x = width * (i + .5) / layer.value.length;
            rects[layer.value[i].id] = Rect.fromLTWH(
              x - nodeWidth / 2,
              16 + layer.key * step,
              nodeWidth,
              nodeHeight,
            );
          }
        }
        final height = 32 + (layers.length - 1) * step + nodeHeight;
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
              width: width,
              height: height,
              child: CustomPaint(
                painter: _Connections(p, skills, rects),
                child: Stack(
                  children: [
                    for (final skill in skills)
                      Positioned.fromRect(
                        rect: rects[skill.id]!,
                        child: _node(
                          skill,
                          iconSize: short ? (dense ? 18 : 24) : 32,
                          onTap: () => select(skill),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _node(
    SkillDef skill, {
    required double iconSize,
    required VoidCallback onTap,
  }) {
    final p = session.progress,
        rank = p.rank(skill.id),
        chosen = focused?.id == skill.id;
    final locked =
        rank == 0 &&
        (p.level < skill.requiredLevel || !p.prerequisitesMet(skill));
    final color = skillColor(skill), canLearn = p.canLearn(skill);
    return Semantics(
      container: true,
      button: true,
      selected: chosen,
      label: '스킬 보기 · ${skill.name} · $rank 등급',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            key: ValueKey('skill-node-${skill.id}'),
            padding: EdgeInsets.all(iconSize < 30 ? 4 : 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: chosen
                    ? [const Color(0xff365349), const Color(0xff122e2a)]
                    : [const Color(0xff173b33), const Color(0xff0b2222)],
              ),
              border: Border.all(
                color: chosen || canLearn
                    ? gold
                    : rank > 0
                    ? color.withValues(alpha: .7)
                    : const Color(0xff3b5750),
                width: chosen ? 2 : 1,
              ),
              boxShadow: canLearn
                  ? [
                      BoxShadow(
                        color: gold.withValues(alpha: .1),
                        blurRadius: 9,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: locked ? .35 : 1,
                      child: SizedBox.square(
                        dimension: iconSize,
                        child: CustomPaint(
                          painter: EffectIconPainter(
                            session.art,
                            skillEffect(skill.id),
                          ),
                        ),
                      ),
                    ),
                    if (locked)
                      const Positioned(
                        right: -10,
                        bottom: 0,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Color(0xffa4bcb6),
                        ),
                      ),
                    if (canLearn)
                      const Positioned(
                        right: -14,
                        top: -3,
                        child: Icon(Icons.add_circle, size: 18, color: gold),
                      ),
                    if (!skill.passive && p.skillSlots.contains(skill.id))
                      Positioned(
                        left: -13,
                        top: -3,
                        child: Text(
                          '${p.skillSlots.indexOf(skill.id) + 1}',
                          style: const TextStyle(
                            color: gold,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    skill.shortName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: locked ? const Color(0xffa4bcb6) : cream,
                      fontSize: iconSize < 24 ? 12 : 13,
                      height: 1.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rank > 0
                      ? '$rank / ${SkillDef.maxRank}'
                      : 'Lv.${skill.requiredLevel}',
                  style: TextStyle(
                    color: rank > 0 ? color : const Color(0xffa4bcb6),
                    fontSize: 12,
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
    for (final skill in skills) {
      for (final requirement in skill.requires.entries) {
        final parent = rects[requirement.key], child = rects[skill.id];
        if (parent == null || child == null) continue;
        final a = parent.bottomCenter, b = child.topCenter;
        final ready = progress.rank(requirement.key) >= requirement.value;
        final color = ready
            ? progress.rank(skill.id) > 0
                  ? const Color(0xff86d8bb)
                  : gold
            : const Color(0xff415c52);
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(
            a.dx,
            (a.dy + b.dy) / 2,
            b.dx,
            (a.dy + b.dy) / 2,
            b.dx,
            b.dy - 6,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = ready ? 2.3 : 1.5,
        );
        final arrow = Path()
          ..moveTo(b.dx - 4, b.dy - 8)
          ..lineTo(b.dx, b.dy - 3)
          ..lineTo(b.dx + 4, b.dy - 8);
        canvas.drawPath(
          arrow,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Connections oldDelegate) => true;
}
