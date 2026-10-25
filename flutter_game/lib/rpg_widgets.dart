import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'class_selection.dart';
import 'game_art.dart';
import 'game_ui.dart';
import 'rpg_model.dart';

IconData elementIcon(String element) => element == 'ice'
    ? Icons.ac_unit
    : element == 'lightning'
    ? Icons.bolt
    : Icons.local_fire_department;
int skillEffect(String id) => switch (id) {
  'warcry' || 'ironSkin' => 0,
  'whirlwind' => 1,
  'frostNova' => 2,
  'chainLightning' => 3,
  'meteor' || 'firebolt' => 4,
  'frenzy' => 5,
  'iceArmor' => 6,
  _ => 7,
};
IconData skillIcon(String id) => switch (id) {
  'warcry' => Icons.campaign,
  'whirlwind' => Icons.cyclone,
  'frenzy' => Icons.flash_on,
  'ironSkin' => Icons.shield,
  'mastery' => Icons.military_tech,
  'frostNova' => Icons.ac_unit,
  'iceArmor' => Icons.security,
  'chainLightning' => Icons.bolt,
  'meteor' => Icons.whatshot,
  'arcaneMastery' => Icons.auto_awesome,
  'firebolt' => Icons.local_fire_department,
  _ => Icons.sports_martial_arts,
};
Color skillColor(SkillDef s) => s.branch == '냉기'
    ? const Color(0xffa8e4f0)
    : s.branch == '화염'
    ? const Color(0xfff4ab6f)
    : s.branch == '번개'
    ? const Color(0xffcdb7ff)
    : gold;

class FramedSurface extends StatelessWidget {
  const FramedSurface({
    required this.art,
    required this.child,
    this.compact = false,
    super.key,
  });
  final GameArt art;
  final Widget child;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff173d39), Color(0xff0b2225)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xff577d72)),
          boxShadow: const [
            BoxShadow(color: Color(0x88000b0c), blurRadius: 24),
          ],
        ),
        child: child,
      );
    }
    return CustomPaint(
      painter: _FramePainter(art),
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.art);
  final GameArt art;
  @override
  void paint(Canvas canvas, Size size) {
    final image = art.images['popup-frame'];
    if (image == null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
        Paint()..color = ink,
      );
      return;
    }
    canvas.save();
    canvas.scale(.25);
    canvas.drawImageNine(
      image,
      Rect.fromLTWH(150, 150, image.width - 300, image.height - 300),
      Rect.fromLTWH(0, 0, size.width * 4, size.height * 4),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.art != art;
}

class PotionBelt extends StatelessWidget {
  const PotionBelt(this.session, {super.key});
  final Adventure session;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _potion(
        Icons.science,
        const Color(0xffffa49a),
        session.progress.healingPotions,
        '치유 물약',
        () => session.potion(),
      ),
      const SizedBox(width: 6),
      _potion(
        Icons.science,
        const Color(0xffa2caff),
        session.progress.energyPotions,
        '${session.progress.heroClass.resource} 물약',
        () => session.potion(energy: true),
      ),
    ],
  );
  Widget _potion(
    IconData icon,
    Color color,
    int count,
    String label,
    VoidCallback action,
  ) => Semantics(
    button: true,
    label: '$label $count개',
    excludeSemantics: true,
    child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 50,
        height: 44,
        decoration: BoxDecoration(
          color: ink.withValues(alpha: .88),
          border: Border.all(color: gold.withValues(alpha: .55)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 32,
              child: CustomPaint(
                painter: PotionPainter(
                  session.art,
                  blue: color == const Color(0xffa2caff),
                ),
              ),
            ),
            Text('$count', style: const TextStyle(color: cream, fontSize: 13)),
          ],
        ),
      ),
    ),
  );
}

class SkillsView extends StatefulWidget {
  const SkillsView(this.session, {super.key});
  final Adventure session;
  @override
  State<SkillsView> createState() => _SkillsViewState();
}

class _SkillsViewState extends State<SkillsView> {
  @override
  Widget build(BuildContext context) {
    final p = widget.session.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 72,
              height: 84,
              child: CustomPaint(
                painter: ClassFigure(widget.session.art, p.heroClass),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lv.${p.level} ${p.heroClass.title}',
                    style: const TextStyle(
                      color: cream,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '사용 가능한 포인트 ${p.skillPoints}',
                    style: const TextStyle(color: gold, fontSize: 15),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '경험치 ${p.xp} / ${p.nextLevelXp}',
                    style: const TextStyle(
                      color: Color(0xffb8cbbd),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '레벨마다 1포인트 · 각 스킬 최대 5등급\n배운 사용 스킬 4개를 전투 버튼에 지정하세요.',
          style: TextStyle(fontSize: 13, height: 1.7, color: Color(0xffbbccbd)),
        ),
        const SizedBox(height: 18),
        for (final skill in p.skills) _skill(skill),
      ],
    );
  }

  Widget _skill(SkillDef skill) {
    final p = widget.session.progress,
        rank = p.rank(skill.id),
        color = skillColor(skill),
        currentSlot = p.skillSlots.indexOf(skill.id),
        selected = currentSlot >= 0;
    final action = rank == 5
        ? '최대 등급'
        : p.level < skill.requiredLevel
        ? 'Lv.${skill.requiredLevel} 필요'
        : rank == 0
        ? '습득 · 1P'
        : '강화 · 1P';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xe0143532),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? color : const Color(0xff435e50),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: .45)),
                ),
                child: CustomPaint(
                  size: const Size.square(43),
                  painter: EffectIconPainter(
                    widget.session.art,
                    skillEffect(skill.id),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: TextStyle(
                        fontSize: 17,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${skill.branch} · ${skill.passive ? '지속 효과' : '사용 스킬'}',
                      style: const TextStyle(fontSize: 12, color: cream),
                    ),
                  ],
                ),
              ),
              Text(
                '$rank / 5',
                style: TextStyle(
                  color: rank > 0 ? gold : const Color(0xff82998a),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            skill.description,
            style: const TextStyle(fontSize: 14, height: 1.6, color: cream),
          ),
          const SizedBox(height: 7),
          Text(
            skill.passive
                ? '필요 레벨 ${skill.requiredLevel}'
                : '필요 레벨 ${skill.requiredLevel} · ${p.heroClass.resource} ${skill.cost.round()} · ${skill.cooldown.round()}초',
            style: const TextStyle(fontSize: 12, color: Color(0xffa9bfae)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton(
                onPressed: p.canLearn(skill)
                    ? () => setState(() => widget.session.learn(skill))
                    : null,
                child: Text(action, semanticsLabel: '${skill.name} $action'),
              ),
              if (!skill.passive && rank > 0)
                PopupMenuButton<int>(
                  tooltip: '${skill.name} 전투 슬롯 지정',
                  onSelected: (slot) => setState(() {
                    p.selectSkill(skill.id, slot: slot);
                    widget.session.refresh();
                  }),
                  itemBuilder: (context) => [
                    for (var slot = 0; slot < 4; slot++)
                      PopupMenuItem(
                        value: slot,
                        child: Text(
                          '스킬 ${slot + 1}${p.skillSlots[slot] == skill.id ? ' · 사용 중' : ''}',
                        ),
                      ),
                  ],
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected ? gold : const Color(0xff78917b),
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selected ? '스킬 ${currentSlot + 1}' : '슬롯 지정',
                          style: const TextStyle(color: cream),
                        ),
                        const Icon(Icons.expand_more, color: gold, size: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class GearGlyph extends CustomPainter {
  GearGlyph(this.item, this.art);
  final Gear item;
  final GameArt art;
  @override
  void paint(Canvas canvas, Size size) {
    final image = art.images['gear-icons'];
    if (image == null) return;
    final index = gearCatalog.indexOf(item.base), cell = image.width / 6;
    if (index < 0) return;
    final side = math.min(size.width, size.height);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH((index % 6) * cell, (index ~/ 6) * cell, cell, cell),
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: side,
        height: side,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant GearGlyph oldDelegate) =>
      oldDelegate.item != item || oldDelegate.art != art;
}

class PotionPainter extends CustomPainter {
  PotionPainter(this.art, {this.blue = false});
  final GameArt art;
  final bool blue;
  @override
  void paint(Canvas canvas, Size size) {
    final image = art.images['atlas'];
    if (image == null) return;
    final cell = image.width / 4;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (blue) {
      paint.colorFilter = const ColorFilter.matrix([
        .3,
        .25,
        .45,
        0,
        0,
        .3,
        .4,
        .3,
        0,
        0,
        .7,
        .2,
        .1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(cell * 3, cell, cell, cell),
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant PotionPainter oldDelegate) =>
      oldDelegate.blue != blue || oldDelegate.art != art;
}

class BossHealth extends StatelessWidget {
  const BossHealth(this.enemy, {super.key});
  final HuntEnemy enemy;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
      decoration: BoxDecoration(
        color: const Color(0xdd182b26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gold.withValues(alpha: .75)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            enemy.windup > 0 ? '숲의 파수꾼 · 강타 준비' : '숲의 파수꾼',
            style: const TextStyle(
              color: cream,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (enemy.life.value / enemy.life.max).clamp(0, 1),
              minHeight: 7,
              color: const Color(0xffd76d4d),
              backgroundColor: const Color(0xff382923),
            ),
          ),
        ],
      ),
    ),
  );
}
