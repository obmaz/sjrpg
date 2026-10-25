import 'package:flutter/material.dart';
import 'adventure.dart';
import 'class_selection.dart';
import 'game_ui.dart';
import 'panel_controls.dart';
import 'rpg_model.dart';
import 'rpg_widgets.dart';

const _dim = Color(0xffa4bcb6);

class SkillsPanel extends StatefulWidget {
  const SkillsPanel({required this.session, required this.onClose, super.key});
  final Adventure session;
  final VoidCallback onClose;
  @override
  State<SkillsPanel> createState() => _SkillsPanelState();
}

class _SkillsPanelState extends State<SkillsPanel> {
  final gridScroll = ScrollController(), detailScroll = ScrollController();
  int filter = 0;
  SkillDef? selected;
  Adventure get s => widget.session;
  Progress get p => s.progress;
  @override
  void dispose() {
    gridScroll.dispose();
    detailScroll.dispose();
    super.dispose();
  }

  void inspect(SkillDef skill) => setState(() {
    selected = skill;
    if (detailScroll.hasClients) detailScroll.jumpTo(0);
  });
  String actionFor(SkillDef skill) => p.rank(skill.id) >= SkillDef.maxRank
      ? '최대 등급'
      : p.level < skill.requiredLevel
      ? 'Lv.${skill.requiredLevel} 필요'
      : p.skillPoints <= 0
      ? '포인트가 없습니다'
      : p.rank(skill.id) == 0
      ? '습득 · 1P'
      : '강화 · 1P';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final short = media.size.height < 500;
    return ColoredBox(
      color: const Color(0xcc040d10),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: FramedSurface(
                art: s.art,
                compact: true,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                height: 48,
                                child: s.art.images.containsKey('actors-hero')
                                    ? CustomPaint(
                                        painter: ClassFigure(
                                          s.art,
                                          p.heroClass,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.auto_awesome,
                                        color: gold,
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '스킬과 성장',
                                      style: TextStyle(
                                        color: cream,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Lv.${p.level} ${p.heroClass.title}',
                                      style: const TextStyle(
                                        color: _dim,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xff394634),
                                  border: Border.all(
                                    color: gold.withValues(alpha: .55),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${p.skillPoints} P',
                                  style: const TextStyle(
                                    color: gold,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '닫기',
                                onPressed: widget.onClose,
                                icon: const Icon(
                                  Icons.close,
                                  color: _dim,
                                  size: 21,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                          child: Row(
                            children: [
                              for (var i = 0; i < 4; i++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: i == 3 ? 0 : 8,
                                    ),
                                    child: _slot(i, compact: short),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        GameTabs(
                          const ['전체', '사용 기술', '지속 효과'],
                          filter,
                          (i) => setState(() {
                            filter = i;
                            if (gridScroll.hasClients) gridScroll.jumpTo(0);
                          }),
                        ),
                        Expanded(
                          child: Scrollbar(
                            controller: gridScroll,
                            thumbVisibility: true,
                            thickness: 3,
                            child: GridView.builder(
                              controller: gridScroll,
                              key: const PageStorageKey('skill-grid'),
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.all(14),
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 230,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: short
                                        ? (media.size.width > 600 ? 2.3 : 1.15)
                                        : 1,
                                  ),
                              itemCount: visible.length,
                              itemBuilder: (context, index) =>
                                  _card(visible[index]),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                          child: GameAction(
                            '모험 계속하기',
                            primary: true,
                            icon: Icons.play_arrow_rounded,
                            onTap: widget.onClose,
                          ),
                        ),
                      ],
                    ),
                    if (selected != null) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => selected = null),
                          child: const ColoredBox(color: Color(0xb300080a)),
                        ),
                      ),
                      Align(
                        alignment: media.size.width > 700
                            ? Alignment.centerRight
                            : Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 420,
                            maxHeight:
                                (media.size.height -
                                    media.padding.vertical -
                                    20) *
                                (short ? 1 : .88),
                          ),
                          child: _details(selected!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<SkillDef> get visible => p.skills
      .where(
        (skill) =>
            filter == 0 || (filter == 1 ? !skill.passive : skill.passive),
      )
      .toList();
  Widget _art(SkillDef skill, double side) => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox.square(
      dimension: side,
      child: CustomPaint(
        painter: EffectIconPainter(s.art, skillEffect(skill.id)),
      ),
    ),
  );
  Widget _slot(int slot, {bool compact = false}) {
    final skill = p.skillAt(slot);
    return Semantics(
      button: skill != null,
      label: '전투 슬롯 ${slot + 1} · ${skill?.name ?? '미지정'}',
      excludeSemantics: true,
      onTap: skill == null ? null : () => inspect(skill),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: skill == null ? null : () => inspect(skill),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: compact ? 48 : 68,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xff102b29),
              border: Border.all(
                color: skill == null
                    ? const Color(0xff36594d)
                    : gold.withValues(alpha: .6),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Expanded(
                  child: skill == null
                      ? const Icon(Icons.add, color: _dim, size: 18)
                      : _art(skill, 40),
                ),
                Text(
                  compact ? '${slot + 1}' : skill?.shortName ?? '${slot + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: cream, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pips(int rank) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < SkillDef.maxRank; i++)
        Container(
          width: 9,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: i < rank ? gold : const Color(0xff3b564d),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
    ],
  );

  Widget _card(SkillDef skill) {
    final rank = p.rank(skill.id),
        slot = p.skillSlots.indexOf(skill.id),
        color = skillColor(skill),
        locked = p.level < skill.requiredLevel;
    return Semantics(
      button: true,
      label: '스킬 보기 · ${skill.name} · $rank 등급',
      excludeSemantics: true,
      onTap: () => inspect(skill),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => inspect(skill),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.3),
                radius: 1,
                colors: [
                  color.withValues(alpha: locked ? .05 : .18),
                  const Color(0xff0e2927),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: slot >= 0
                    ? gold.withValues(alpha: .75)
                    : const Color(0xff46644f),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: locked ? .35 : 1,
                        child: _art(skill, 70),
                      ),
                      if (locked)
                        const Icon(Icons.lock_outline, color: _dim, size: 23),
                      if (slot >= 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: gold,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${slot + 1}',
                              style: const TextStyle(
                                color: ink,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  skill.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: locked ? _dim : cream,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                if (locked)
                  Text(
                    'Lv.${skill.requiredLevel}',
                    style: const TextStyle(color: _dim, fontSize: 12),
                  )
                else if (rank == 0)
                  Text(
                    p.skillPoints > 0 ? '습득 가능' : '미습득',
                    style: TextStyle(
                      color: p.skillPoints > 0 ? gold : _dim,
                      fontSize: 12,
                    ),
                  )
                else
                  _pips(rank),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _details(SkillDef skill) {
    final compact = MediaQuery.sizeOf(context).height < 500;
    final rank = p.rank(skill.id),
        color = skillColor(skill),
        current = p.skillSlots.indexOf(skill.id),
        action = actionFor(skill);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xff0d2828),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .65)),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 22)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    skill.passive ? '지속 효과' : skill.branch,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '스킬 상세 닫기',
                  onPressed: () => setState(() => selected = null),
                  icon: const Icon(Icons.close, color: _dim, size: 21),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xff3b584c)),
          Flexible(
            child: Scrollbar(
              controller: detailScroll,
              thumbVisibility: true,
              thickness: 3,
              child: SingleChildScrollView(
                controller: detailScroll,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: compact ? 10 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: compact ? 42 : 74, child: _art(skill, 74)),
                    SizedBox(height: compact ? 6 : 10),
                    Text(
                      skill.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: compact ? 19 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _pips(rank),
                        const SizedBox(width: 8),
                        Text(
                          '$rank / ${SkillDef.maxRank}',
                          style: const TextStyle(color: gold, fontSize: 13),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 10 : 16),
                    Text(
                      skill.description,
                      style: TextStyle(
                        color: cream,
                        fontSize: compact ? 14 : 16,
                        height: compact ? 1.5 : 1.65,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 10),
                    Text(
                      skill.passive
                          ? '지속 효과 · 필요 레벨 ${skill.requiredLevel}'
                          : '${p.heroClass.resource} ${skill.cost.round()} · 재사용 ${skill.cooldown.round()}초 · 필요 레벨 ${skill.requiredLevel}',
                      style: const TextStyle(
                        color: _dim,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    if (!skill.passive && rank == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          '습득하면 빈 전투 슬롯에 자동으로 지정됩니다',
                          style: TextStyle(
                            color: gold,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!skill.passive && rank > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Column(
                children: [
                  const Text(
                    '전투 슬롯',
                    style: TextStyle(color: _dim, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
                            child: GameAction(
                              '${i + 1}',
                              semanticLabel:
                                  '${skill.name} · 슬롯 ${i + 1} 지정${current == i ? ' · 사용 중' : ''}',
                              primary: current == i,
                              onTap: () => setState(() {
                                p.selectSkill(skill.id, slot: i);
                                s.refresh();
                              }),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: GameAction(
              action,
              semanticLabel: '${skill.name} $action',
              primary: true,
              icon: Icons.upgrade_rounded,
              onTap: p.canLearn(skill)
                  ? () => setState(() {
                      s.learn(skill);
                    })
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
