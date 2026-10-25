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
  const FramedSurface({required this.art, required this.child, super.key});
  final GameArt art;
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _FramePainter(art),
    child: Padding(padding: const EdgeInsets.all(10), child: child),
  );
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
          '레벨마다 1포인트 · 각 스킬 최대 5등급\n배운 사용 스킬 2개를 주·보조 버튼에 지정하세요.',
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
        selected = p.selectedSkill == skill.id,
        secondary = p.secondarySkill == skill.id;
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
                child: Icon(skillIcon(skill.id), color: color, size: 27),
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
                child: Text(
                  rank == 5
                      ? '최대 등급'
                      : p.level < skill.requiredLevel
                      ? 'Lv.${skill.requiredLevel} 필요'
                      : rank == 0
                      ? '습득 · 1P'
                      : '강화 · 1P',
                ),
              ),
              if (!skill.passive && rank > 0)
                OutlinedButton(
                  onPressed: () => setState(() {
                    p.selectSkill(skill.id);
                    widget.session.refresh();
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: selected ? gold : cream,
                    side: BorderSide(
                      color: selected ? gold : const Color(0xff78917b),
                    ),
                  ),
                  child: Text(selected ? '주 스킬' : '주 슬롯 지정'),
                ),
              if (!skill.passive && rank > 0)
                OutlinedButton(
                  onPressed: () => setState(() {
                    p.selectSkill(skill.id, slot: 1);
                    widget.session.refresh();
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: secondary ? gold : cream,
                    side: BorderSide(
                      color: secondary ? gold : const Color(0xff78917b),
                    ),
                  ),
                  child: Text(secondary ? '보조 스킬' : '보조 슬롯 지정'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class InventoryView extends StatefulWidget {
  const InventoryView(this.session, {super.key});
  final Adventure session;
  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  Gear? selected;
  GearSlot? filter;
  @override
  Widget build(BuildContext context) {
    final p = widget.session.progress;
    if (selected == null || !p.inventory.contains(selected)) {
      selected = p.weapon;
    }
    final item = selected!,
        equipped = p.equipped[item.base.slot],
        active = p.isEquipped(item);
    final items = p.inventory
        .where((g) => filter == null || g.base.slot == filter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lv.${p.level} ${p.heroClass.title} · 장비 ${p.inventory.length}/${Progress.capacity}',
          style: const TextStyle(color: gold, fontSize: 15),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final slot in GearSlot.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Text(
                        ['무기', '방어구', '부적'][slot.index],
                        style: const TextStyle(fontSize: 12, color: cream),
                      ),
                      const SizedBox(height: 6),
                      _cell(p.equipped[slot], equippedSlot: true),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              '공격 ${p.swordDamage.round()}',
              style: const TextStyle(color: cream, fontSize: 14),
            ),
            Text(
              '방어 ${p.armor.round()}',
              style: const TextStyle(color: cream, fontSize: 14),
            ),
            Text(
              '생명 ${p.maxHp.round()}',
              style: const TextStyle(color: cream, fontSize: 14),
            ),
            Text(
              '${p.heroClass.resource} ${p.maxEnergy.round()}',
              style: const TextStyle(color: cream, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xe00a2425),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(item.rarity.color).withValues(alpha: .6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.name,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(item.rarity.color),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${item.rarity.title} · ${item.base.slot == GearSlot.weapon
                    ? '${item.base.tempo.toStringAsFixed(2)}초 / 사거리 ${item.base.range.round()}'
                    : item.base.slot == GearSlot.armor
                    ? '방어구'
                    : '부적'}',
                style: const TextStyle(color: Color(0xffa9beb1), fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                item.stats,
                style: const TextStyle(color: cream, fontSize: 14, height: 1.6),
              ),
              if (item.base.slot == GearSlot.weapon) ...[
                const SizedBox(height: 7),
                Text(
                  '무기 DPS ${(item.attack / item.base.tempo).toStringAsFixed(1)} · 기본 공격 주기',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xffa9beb1),
                  ),
                ),
              ],
              if (!active && equipped != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _delta('공격', item.attack - equipped.attack),
                    if (item.base.slot == GearSlot.weapon)
                      _delta(
                        'DPS',
                        item.attack / item.base.tempo -
                            equipped.attack / equipped.base.tempo,
                      ),
                    _delta('방어', item.armor - equipped.armor),
                    _delta('생명', item.health - equipped.health),
                    _delta('마나', item.mana - equipped.mana),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilledButton(
                    onPressed: active
                        ? null
                        : () => setState(() => widget.session.equip(item)),
                    child: Text(active ? '장착 중' : '장착'),
                  ),
                  OutlinedButton(
                    onPressed: active
                        ? null
                        : () => setState(() {
                            p.sell(item);
                            selected = p.weapon;
                            widget.session.refresh();
                          }),
                    child: Text('판매 +${item.saleValue} G'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          children: [
            ChoiceChip(
              label: const Text('전체'),
              selected: filter == null,
              onSelected: (_) => setState(() => filter = null),
            ),
            for (final slot in GearSlot.values)
              ChoiceChip(
                label: Text(['무기', '방어구', '부적'][slot.index]),
                selected: filter == slot,
                onSelected: (_) => setState(() => filter = slot),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: math.max(8, items.length),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) =>
              _cell(index < items.length ? items[index] : null),
        ),
        const SizedBox(height: 12),
        const Text(
          '색은 희귀도를 나타냅니다. 장비를 누르면 옵션을 비교할 수 있습니다. 장착 중인 장비는 판매되지 않습니다.',
          style: TextStyle(fontSize: 12, height: 1.7, color: Color(0xffa9beb1)),
        ),
      ],
    );
  }

  Widget _delta(String label, double value) => value == 0
      ? const SizedBox.shrink()
      : Text(
          '$label ${value > 0 ? '+' : ''}${label == 'DPS' ? value.toStringAsFixed(1) : value.round()}',
          style: TextStyle(
            fontSize: 13,
            color: value > 0
                ? const Color(0xff9fe5a5)
                : const Color(0xfff6a194),
          ),
        );
  Widget _cell(Gear? item, {bool equippedSlot = false}) {
    final active = item != null && widget.session.progress.isEquipped(item),
        chosen = item == selected;
    return Semantics(
      button: item != null,
      label: item == null ? '빈 장비 칸' : '${item.name}${active ? ' 장착 중' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: item == null ? null : () => setState(() => selected = item),
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff22423b), Color(0xff0c2525)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: chosen
                    ? gold
                    : item != null
                    ? Color(item.rarity.color).withValues(alpha: .65)
                    : const Color(0xff42594e),
                width: chosen ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: item != null
                        ? CustomPaint(
                            painter: GearGlyph(item, widget.session.art),
                          )
                        : Icon(
                            equippedSlot ? Icons.add : Icons.circle_outlined,
                            color: const Color(0xff4d6457),
                            size: 18,
                          ),
                  ),
                ),
                if (active)
                  const Positioned(
                    right: 3,
                    bottom: 3,
                    child: Icon(Icons.check_circle, color: gold, size: 16),
                  ),
              ],
            ),
          ),
        ),
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
