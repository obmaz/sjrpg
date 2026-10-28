import 'package:flutter/material.dart';

import 'adventure.dart';
import 'back_actions.dart';
import 'basic_attack_strip.dart';
import 'combat_balance.dart';
import 'game_ui.dart';
import 'panel_controls.dart';
import 'rpg_model.dart';
import 'rpg_widgets.dart';
import 'skill_preview.dart';
import 'skill_tree.dart';

const _dim = Color(0xffa4bcb6);

class SkillsPanel extends StatefulWidget {
  const SkillsPanel({
    required this.session,
    required this.onClose,
    this.backActions,
    super.key,
  });
  final Adventure session;
  final VoidCallback onClose;
  final BackActions? backActions;
  @override
  State<SkillsPanel> createState() => _SkillsPanelState();
}

class _SkillsPanelState extends State<SkillsPanel> {
  final treeScroll = ScrollController(), detailScroll = ScrollController();
  SkillDef? selected;
  late SkillDef focused = p.heroClass == HeroClass.warrior
      ? p.skills.firstWhere((skill) => skill.id == 'howl')
      : p.basicSkill;
  Adventure get s => widget.session;
  Progress get p => s.progress;
  void Function()? stopBackAction;
  @override
  void initState() {
    super.initState();
    stopBackAction = widget.backActions?.register(() {
      if (selected != null) {
        setState(() => selected = null);
      } else {
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    stopBackAction?.call();
    treeScroll.dispose();
    detailScroll.dispose();
    super.dispose();
  }

  void inspect(SkillDef skill) => setState(() {
    selected = skill;
    focused = skill;
    if (detailScroll.hasClients) detailScroll.jumpTo(0);
  });
  String actionFor(SkillDef skill) => p.rank(skill.id) >= skill.rankLimit
      ? '최대 등급'
      : p.level < skill.requiredLevelForRank(p.rank(skill.id) + 1)
      ? 'Lv.${skill.requiredLevelForRank(p.rank(skill.id) + 1)} 필요'
      : p.rank(skill.id) == 0 && !p.prerequisitesMet(skill)
      ? '선행 필요'
      : p.skillPoints <= 0
      ? '포인트 없음'
      : p.rank(skill.id) == 0
      ? '습득 · 1P'
      : '강화 · 1P';

  Future<void> confirmReset() async {
    final refund = p.investedSkillPoints;
    if (refund == 0) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight:
                MediaQuery.sizeOf(dialogContext).height -
                MediaQuery.paddingOf(dialogContext).vertical -
                40,
          ),
          child: FramedSurface(
            art: s.art,
            compact: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GamePanelHeader(
                  title: '스킬 초기화',
                  onClose: () => Navigator.of(dialogContext).pop(false),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '투자한 $refund 포인트를 돌려받습니다.',
                          style: const TextStyle(
                            color: cream,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '기본 공격과 시작 기술은 1등급으로 남습니다. 진행 중인 기술 효과는 종료되며 재사용 대기시간은 유지됩니다.',
                          style: TextStyle(
                            color: _dim,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '초기화권 1장 사용 · 보유 ${p.skillResetTickets}장',
                          style: const TextStyle(color: gold, fontSize: 15),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '각 스테이지를 처음 완료하면 초기화권 1장을 받습니다. 골드는 사용하지 않습니다.',
                            style: TextStyle(
                              color: _dim,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (p.skillResetTickets == 0)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              '초기화권이 없습니다',
                              style: TextStyle(
                                color: Color(0xffffa493),
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GameAction(
                          '취소',
                          onTap: () => Navigator.of(dialogContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GameAction(
                          '초기화권 1장 · 초기화',
                          primary: true,
                          onTap: !p.canResetSkills
                              ? null
                              : () => Navigator.of(dialogContext).pop(true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (approved != true || !mounted || !s.resetSkills()) return;
    setState(() {
      selected = null;
      focused = p.skills.first;
      if (treeScroll.hasClients) treeScroll.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final short = media.size.height < 500;
    final compactMage =
        short && media.size.width < 600 && p.heroClass == HeroClass.mage;
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
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Stack(
                    children: [
                      ExcludeSemantics(
                        excluding: selected != null,
                        child: ExcludeFocus(
                          excluding: selected != null,
                          child: Column(
                            children: [
                              GamePanelHeader(
                                title: '스킬 트리',
                                subtitle: short
                                    ? null
                                    : 'Lv.${p.level} ${p.heroClass.title}',
                                dense: short,
                                onClose: widget.onClose,
                                trailing: Container(
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
                              ),
                              if (!compactMage)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    8,
                                  ),
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
                              BasicAttackStrip(
                                session: s,
                                compact: short,
                                onFocus: (skill) =>
                                    setState(() => focused = skill),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: SkillTree(
                                    session: s,
                                    controller: treeScroll,
                                    focused: focused,
                                    onFocus: (skill) =>
                                        setState(() => focused = skill),
                                  ),
                                ),
                              ),
                              if (short && media.size.width >= 600)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _investmentBar(short: true),
                                    ),
                                    SizedBox(width: 270, child: _footer()),
                                  ],
                                )
                              else ...[
                                _investmentBar(short: short),
                                _footer(),
                              ],
                            ],
                          ),
                        ),
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
      ),
    );
  }

  Widget _footer() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GameIconButton(
              label: '스킬 초기화',
              onTap: p.investedSkillPoints > 0 ? confirmReset : null,
              icon: Icons.restart_alt_rounded,
            ),
            Positioned(
              right: -2,
              top: -3,
              child: IgnorePointer(
                child: Semantics(
                  label: '초기화권 ${p.skillResetTickets}장',
                  excludeSemantics: true,
                  child: Container(
                    width: 19,
                    height: 19,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.skillResetTickets > 0
                          ? gold
                          : const Color(0xff314d49),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${p.skillResetTickets}',
                      style: TextStyle(
                        color: p.skillResetTickets > 0 ? ink : _dim,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GameAction(
            '모험 계속하기',
            primary: true,
            icon: Icons.play_arrow_rounded,
            onTap: widget.onClose,
          ),
        ),
      ],
    ),
  );

  String prerequisitesText(SkillDef skill) => skill.requires.isEmpty
      ? '계열의 시작 기술'
      : '모두 필요 · ${skill.requires.entries.map((entry) => '${p.skills.firstWhere((skill) => skill.id == entry.key).name} ${entry.value}등급').join(' · ')}';

  Widget _investmentBar({required bool short}) {
    final action = actionFor(focused);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: const BoxDecoration(
        color: Color(0xff102d29),
        border: Border(top: BorderSide(color: Color(0xff37574b))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  focused.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!short)
                  Text(
                    prerequisitesText(focused),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _dim,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: short || MediaQuery.sizeOf(context).width < 360 ? 104 : 122,
            child: GameAction(
              action,
              primary: true,
              semanticLabel: '${focused.name} $action',
              onTap: p.canLearn(focused)
                  ? () => setState(() {
                      s.learn(focused);
                    })
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          GameIconButton(
            label: '스킬 설명과 배치',
            onTap: () => inspect(focused),
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }

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
            height: compact ? 44 : 60,
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
            child: compact
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: SizedBox.square(
                          dimension: 28,
                          child: skill == null
                              ? const Icon(Icons.add, color: _dim, size: 18)
                              : _art(skill, 28),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${slot + 1}',
                        style: const TextStyle(color: cream, fontSize: 11),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: skill == null
                            ? const Icon(Icons.add, color: _dim, size: 18)
                            : _art(skill, 40),
                      ),
                      Text(
                        skill?.shortName ?? '${slot + 1}',
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

  Widget _pips(int rank, int limit) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < limit; i++)
        Container(
          width: limit > 10 ? 3 : 9,
          height: 4,
          margin: EdgeInsets.symmetric(horizontal: limit > 10 ? 1 : 2),
          decoration: BoxDecoration(
            color: i < rank ? gold : const Color(0xff3b564d),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
    ],
  );

  Widget _details(SkillDef skill) {
    final compact = MediaQuery.sizeOf(context).height < 500;
    final rank = p.rank(skill.id),
        color = skillColor(skill),
        current = p.skillSlots.indexOf(skill.id),
        action = actionFor(skill);
    final mustKeepPrimary =
        current == 0 &&
        [1, 2, 3].any((slot) => !p.canSelectSkill(skill.id, slot: slot));
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
          GamePanelHeader(
            title: skill.basic
                ? '기본 공격'
                : skill.passive
                ? '지속 효과'
                : skill.branch,
            dense: true,
            closeLabel: '스킬 상세 닫기',
            onClose: () => setState(() => selected = null),
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
                        _pips(rank, skill.rankLimit),
                        const SizedBox(width: 8),
                        Text(
                          '$rank / ${skill.rankLimit}',
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
                    SkillRankPreview(p, skill),
                    SizedBox(height: compact ? 6 : 10),
                    Text(
                      skill.basic
                          ? '기본 공격 · 자원 소모 없음 · 필요 레벨 ${skill.requiredLevel}'
                          : skill.passive
                          ? '지속 효과 · 필요 레벨 ${skill.requiredLevel}'
                          : '${p.heroClass.resource} ${p.skillCost(skill, atRank: p.rank(skill.id).clamp(1, skill.rankLimit)).round()} · 재사용 ${CombatBalance.realSeconds(p.skillCooldown(skill, atRank: p.rank(skill.id).clamp(1, skill.rankLimit))).toStringAsFixed(1)}초 · 필요 레벨 ${skill.requiredLevel}',
                      style: const TextStyle(
                        color: _dim,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        prerequisitesText(skill),
                        style: TextStyle(
                          color:
                              p.rank(skill.id) == 0 &&
                                  !p.prerequisitesMet(skill)
                              ? const Color(0xffffbb88)
                              : _dim,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (skill.mobility)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          '이동 전용 · 습득하면 회피 옆에 표시됩니다 · M',
                          style: TextStyle(
                            color: gold,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (!skill.passive && !skill.mobility && rank == 0)
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
          if (skill.basic && rank > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: GameAction(
                p.selectedBasic == skill.id ? '기본 공격 사용 중' : '기본 공격으로 사용',
                semanticLabel: '${skill.name} 기본 공격으로 사용',
                primary: p.selectedBasic == skill.id,
                onTap: () => setState(() {
                  p.selectBasic(skill.id);
                  s.refresh();
                }),
              ),
            ),
          if (!skill.passive && !skill.mobility && rank > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Column(
                children: [
                  if (mustKeepPrimary)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '1번 슬롯은 비울 수 없습니다. 다른 기술과 자리를 바꿀 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _dim,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
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
                                  '${skill.name} · 슬롯 ${i + 1} 지정${current == i
                                      ? ' · 사용 중'
                                      : !p.canSelectSkill(skill.id, slot: i)
                                      ? ' · 1번 슬롯 유지 필요'
                                      : ''}',
                              primary: current == i,
                              onTap: !p.canSelectSkill(skill.id, slot: i)
                                  ? null
                                  : () => setState(() {
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
