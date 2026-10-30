import 'package:flutter/material.dart';

import 'adventure.dart';
import 'game_ui.dart';
import 'rpg_model.dart';
import 'rpg_widgets.dart';

/// Learned basic attacks switch directly; their four active slots stay separate.
class BasicAttackStrip extends StatelessWidget {
  const BasicAttackStrip({
    required this.session,
    required this.onFocus,
    required this.onChanged,
    this.compact = false,
    this.leading,
    super.key,
  });
  final Adventure session;
  final ValueChanged<SkillDef> onFocus;
  final VoidCallback onChanged;
  final bool compact;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = session.progress, basics = p.basicSkills.toList(growable: false);
    if (basics.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          if (leading != null)
            SizedBox(width: 54, child: leading)
          else
            const SizedBox(
              width: 28,
              child: Text(
                '기본\n공격',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xffa4bcb6), fontSize: 11),
              ),
            ),
          const SizedBox(width: 6),
          for (var i = 0; i < basics.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == basics.length - 1 ? 0 : 6),
                child: _card(basics[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(SkillDef skill) {
    final p = session.progress,
        rank = p.rank(skill.id),
        chosen = p.primarySkill?.id == skill.id;
    final label = switch (skill.id) {
      'cleave' => '베기',
      'quickCut' => '속사',
      'heavyStrike' => '일격',
      _ => skill.shortName,
    };
    void select() {
      if (rank > 0) {
        p.selectBasic(skill.id);
        session.refresh();
        onChanged();
      } else {
        onFocus(skill);
      }
    }

    return Semantics(
      button: true,
      selected: chosen,
      label: '기본 공격 ${skill.name} ${rank > 0 ? '선택' : '살펴보기'}',
      hint: rank > 0 ? '무료 전환 · $rank등급' : '습득하려면 선행 기술과 스킬 포인트가 필요합니다',
      onTap: select,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: select,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: compact ? 48 : 56,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: chosen ? const Color(0xff2d4837) : const Color(0xff102b29),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: chosen ? gold : const Color(0xff36594d),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CustomPaint(
                            painter: skill.id == 'sorceressAttack'
                                ? GearGlyph(p.weapon, session.art)
                                : EffectIconPainter(
                                    session.art,
                                    skillEffect(skill.id),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (rank == 0)
                        const Icon(
                          Icons.lock_outline,
                          size: 13,
                          color: Color(0xffa4bcb6),
                        )
                      else
                        Text(
                          '$rank',
                          style: const TextStyle(color: gold, fontSize: 11),
                        ),
                      if (chosen)
                        const Padding(
                          padding: EdgeInsets.only(left: 3),
                          child: Icon(Icons.check, size: 13, color: gold),
                        ),
                    ],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: rank > 0 ? cream : const Color(0xffa4bcb6),
                    fontSize: 12,
                    height: 1.1,
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
