import 'package:flutter/material.dart';

import 'combat_distance.dart';
import 'game_ui.dart';
import 'rpg_model.dart';
import 'skill_preview_model.dart';

class SkillRankPreview extends StatelessWidget {
  const SkillRankPreview(this.progress, this.skill, {super.key});
  final Progress progress;
  final SkillDef skill;
  @override
  Widget build(BuildContext context) {
    final rank = progress.rank(skill.id), rows = previewSkill(progress, skill);
    final canUpgrade = rank < skill.rankLimit;
    Widget cell(String text, {bool highlight = false}) => Expanded(
      flex: 3,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: highlight ? gold : cream,
          fontSize: 14,
          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
    return Container(
      key: ValueKey('skill-preview-${skill.id}'),
      margin: const EdgeInsets.only(top: 14, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff153832),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff3c6253)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                flex: 5,
                child: Text(
                  '장비·레벨 기준',
                  style: TextStyle(color: Color(0xffa4bcb6), fontSize: 12),
                ),
              ),
              cell(rank == 0 ? '현재' : '$rank등급'),
              if (canUpgrade)
                cell(rank == 0 ? '습득 후' : '${rank + 1}등급', highlight: true),
            ],
          ),
          const Divider(height: 18, color: Color(0xff3c6253)),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      row.label,
                      style: const TextStyle(color: cream, fontSize: 13),
                    ),
                  ),
                  cell(row.format(row.current)),
                  if (canUpgrade) cell(row.format(row.next), highlight: true),
                ],
              ),
            ),
          if (rows.any((row) => row.suffix.startsWith('걸음')))
            const Text(
              CombatDistance.help,
              style: TextStyle(color: Color(0xffa4bcb6), fontSize: 12),
            ),
          if (rows.any((row) => row.label.contains('피해')))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '피해는 대상 1명·방어 적용 전입니다. 여럿을 함께 맞히면 1명당 피해가 줄어듭니다',
                style: TextStyle(color: Color(0xffa4bcb6), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
