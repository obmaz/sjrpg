import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'back_actions.dart';
import 'blacksmith_panel.dart';
import 'commission_board.dart';
import 'device_controls.dart';
import 'equipment_panel.dart';
import 'game_ui.dart';
import 'mount_panel.dart';
import 'panel_controls.dart';
import 'quest_cards.dart';
import 'quest_guide.dart';
import 'rpg_widgets.dart';
import 'skills_panel.dart';
import 'stage_completion_banner.dart';
import 'travel_panel.dart';
import 'world_map.dart';
import 'world_model.dart';

class AdventurePanel extends StatefulWidget {
  const AdventurePanel({
    required this.session,
    required this.name,
    required this.onClose,
    required this.onRestart,
    this.onRetryCheckpoint,
    this.onAdvance,
    this.onTravel,
    this.onCheckpoint,
    this.backActions,
    this.offeredPath,
    super.key,
  });
  final Adventure session;
  final String name;
  final VoidCallback onClose, onRestart;
  final VoidCallback? onRetryCheckpoint;
  final VoidCallback? onAdvance, onCheckpoint;
  final void Function(WorldStage stage, String wellId)? onTravel;
  final BackActions? backActions;
  final TimePath? offeredPath;
  @override
  State<AdventurePanel> createState() => _AdventurePanelState();
}

class _AdventurePanelState extends State<AdventurePanel> {
  final panelScroll = ScrollController();
  bool showMap = false;
  @override
  void didUpdateWidget(covariant AdventurePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name ||
        oldWidget.offeredPath != widget.offeredPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && panelScroll.hasClients) panelScroll.jumpTo(0);
      });
      showMap = false;
    }
  }

  @override
  void dispose() {
    panelScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session,
        p = s.progress,
        name = widget.name,
        media = MediaQuery.of(context);
    if (name == 'mounts') {
      return MountPanel(
        session: s,
        onClose: widget.onClose,
        onCheckpoint: widget.onCheckpoint,
      );
    }
    if (name == 'smith') {
      return BlacksmithPanel(
        session: s,
        onClose: widget.onClose,
        onCheckpoint: widget.onCheckpoint,
      );
    }
    if (name == 'map') {
      return ExpandedWorldMap(session: s, onClose: widget.onClose);
    }
    if (name == 'warp') {
      return TravelPanel(
        session: s,
        onClose: widget.onClose,
        onTravel: widget.onTravel,
      );
    }
    if (name == 'bag' || name == 'shop') {
      return EquipmentPanel(
        key: ValueKey(name),
        session: s,
        startInShop: name == 'shop',
        onClose: widget.onClose,
      );
    }
    if (name == 'skills') {
      return SkillsPanel(
        session: s,
        onClose: widget.onClose,
        backActions: widget.backActions,
      );
    }
    final result = name == 'victory' || name == 'defeat';
    final canAdvance =
        (name == 'victory' || name == 'journal' || name == 'talk') &&
        s.stageCleared &&
        widget.onAdvance != null &&
        s.world.stage.hasNextStage;
    final advanceLabel = s.world.stage.advanceLabel(s.timePath);
    void continueExploring() {
      s.continueExploring();
      widget.onClose();
    }

    final title =
        {
          'bag': '모험가의 가방',
          'skills': '스킬과 성장',
          'journal': s.world.stage.title,
          'map': '모험 지도',
          'settings': '모험 설정',
          'shop': '상점',
          'talk': s.world.stage == WorldStage.forest
              ? '숲의 현자'
              : s.world.stage == WorldStage.sands && widget.offeredPath != null
              ? timeQuestGivers
                    .firstWhere((g) => g.path == widget.offeredPath)
                    .name
              : s.stageContract?.giver ?? '의뢰 게시판',
          'pause': '잠시 쉬어가기',
          'defeat': '쓰러진 수호자',
          'victory': s.world.stage == WorldStage.forest ? '첫 스테이지 정화' : '의뢰 해결',
        }[name] ??
        '모험';
    List<Widget> body;
    if ((name == 'journal' || name == 'talk') &&
        s.world.stage != WorldStage.forest) {
      body = [
        CommissionBoard(
          session: s,
          offeredPath: name == 'talk' ? widget.offeredPath : null,
          onAdvance: canAdvance ? null : widget.onAdvance,
          onCommit: () {
            widget.onCheckpoint?.call();
            setState(() {});
            if (s.world.stage == WorldStage.sands && panelScroll.hasClients) {
              panelScroll.jumpTo(0);
            }
          },
        ),
      ];
    } else if (name == 'journal' || name == 'talk' || name == 'map') {
      body = [
        _info(Icons.flag_outlined, '지금 할 일', s.mainQuestNext),
        const SizedBox(height: 14),
        if (name == 'talk') ...[
          const Text(
            '“숲의 뿌리에 오래된 어둠이 잠들어 있네. 뿌리 우물·달빛 샘·태양 제단부터 정화해 주게. 세 성소와 숲길을 정화하면 파수꾼이 깨어날 걸세. 상자와 전리품을 모으고, 얻은 힘을 스스로 선택하게나. 전투를 벗어나 분수 곁에서 쉬면 생명이 회복된다네.”',
            style: TextStyle(fontSize: 16, height: 1.8, color: cream),
          ),
          const SizedBox(height: 22),
        ],
        for (final site in questSites) ...[
          QuestSiteCard(
            art: s.art,
            site: site,
            done: s.cleansedSites.contains(site.id),
            stage: s.world.stage,
          ),
          const SizedBox(height: 12),
        ],
        _quest(
          '숲길 정화',
          '필수 성소 3곳과 몬스터 처치 목표를 완수해 파수꾼을 깨우세요.',
          math.min(stageKillGoal, s.stageKills) / stageKillGoal,
          '${math.min(stageKillGoal, s.stageKills)} / $stageKillGoal',
        ),
        const SizedBox(height: 12),
        _quest(
          '첫 파수꾼',
          '성소 3곳을 정화하고 파수꾼을 쓰러뜨리면 제1장을 완료합니다.',
          p.bossDefeated ? 1 : 0,
          s.stageCleared
              ? '정화 완료'
              : s.bossSummoned
              ? '파수꾼 출현'
              : '필수 성소·처치 목표 완료 후 등장',
        ),
        const SizedBox(height: 18),
        _quest(
          '숲의 기억 · 선택 여정',
          '서쪽·북쪽·동쪽 길의 상자에서 기억 3개를 모으세요. 완성 보상: 스킬 포인트 +1.',
          s.recoveredMemories / stageMemories.length,
          s.memoryRewarded
              ? '보상 획득'
              : '${s.recoveredMemories} / ${stageMemories.length}',
        ),
        for (final memory in stageMemories)
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: Icon(
                s.openedChests.contains(memory.chest)
                    ? Icons.auto_stories
                    : Icons.lock_outline,
                color: s.openedChests.contains(memory.chest)
                    ? gold
                    : const Color(0xff7d9c90),
              ),
              title: Text(
                s.openedChests.contains(memory.chest)
                    ? memory.title
                    : '찾지 못한 기억',
                style: const TextStyle(fontSize: 15, color: cream),
              ),
              subtitle: Text(
                memory.hint,
                style: const TextStyle(fontSize: 13, color: Color(0xffa9c5b9)),
              ),
              childrenPadding: const EdgeInsets.only(bottom: 16),
              children: [
                Text(
                  s.openedChests.contains(memory.chest)
                      ? memory.story
                      : '이 길의 상자에 숲의 과거가 남아 있습니다.',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: cream,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _line(
          Icons.inventory_2_outlined,
          '발견한 상자',
          '${s.openedChests.length} / ${Adventure.chestLocations.length}',
        ),
        _line(Icons.military_tech, '모험가', 'Lv.${p.level} ${p.heroClass.title}'),
        const SizedBox(height: 12),
        GameAction(
          showMap ? '지도 접기' : '스테이지 지도 보기',
          onTap: () => setState(() => showMap = !showMap),
          icon: showMap ? Icons.expand_less : Icons.map_outlined,
        ),
        if (showMap || name == 'map') ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: CustomPaint(painter: MapPainter(s, round: false)),
          ),
          const SizedBox(height: 10),
          Text(
            '현재 위치 · ${s.region}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: gold, fontSize: 14),
          ),
        ],
      ];
    } else if (result) {
      body = [
        if (name == 'victory')
          StageCompletionBanner(s)
        else
          const Icon(Icons.shield_outlined, color: gold, size: 64),
        const SizedBox(height: 18),
        Text(
          name == 'victory'
              ? '의뢰를 해결했습니다.\n${s.world.stage == WorldStage.forest
                    ? '사막 유적에서 새로운 의뢰가 기다립니다.'
                    : s.world.stage == WorldStage.sands
                    ? '선택한 시대의 문이 열렸습니다.'
                    : s.world.stage.hasNextStage
                    ? '다음 의뢰를 받아 시간의 흔적을 계속 추적하세요.'
                    : '두 시대의 시간을 되찾았습니다. 남은 보물을 탐험하세요.'}'
              : widget.onRetryCheckpoint != null
              ? '사망 손실이 적용됐습니다.\n거점에서 다시 일어날 수 있습니다.'
              : '힘을 키우고 다시 도전하세요.\n장비와 스킬 조합에 따라 전투가 달라집니다.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, height: 1.8, color: cream),
        ),
        const SizedBox(height: 20),
        _line(
          Icons.person_outline,
          '모험가',
          'Lv.${p.level} ${p.heroClass.title}',
        ),
        _line(Icons.bolt, '이번 의뢰 처치', '${s.stageKills}'),
        _line(Icons.monetization_on_outlined, '보유 골드', '${p.gold} G'),
        if (name == 'defeat' && s.deathLoss != null) ...[
          _line(
            Icons.broken_image_outlined,
            '무기 파괴',
            s.deathLoss!.weaponName ?? '보유 무기 없음',
          ),
          _line(
            Icons.money_off_rounded,
            '사망 손실',
            '-${s.deathLoss!.goldLost} G · ${s.deathLoss!.goldPercent}%',
          ),
          if (s.saveFailed)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '손실 기록을 저장하지 못했습니다. 저장이 복구되면 재도전할 수 있습니다.',
                style: TextStyle(color: Color(0xffefa17e)),
              ),
            ),
        ],
        _line(Icons.timer_outlined, '모험 시간', gameTime(s.elapsed)),
        const SizedBox(height: 12),
        if (name == 'defeat' && widget.onRetryCheckpoint != null)
          GameAction(
            '직업을 바꿔 새 모험',
            onTap: widget.onRestart,
            icon: Icons.refresh,
          ),
        if (canAdvance)
          GameAction(
            '계속 탐험하기',
            icon: Icons.explore_outlined,
            onTap: continueExploring,
          ),
        if (name == 'victory')
          GameAction(
            '다른 직업으로 새 모험',
            onTap: widget.onRestart,
            icon: Icons.refresh,
          ),
      ];
    } else {
      body = [
        if (s.saveFailed) ...[
          _info(
            Icons.cloud_off_outlined,
            '자동 저장 실패',
            '저장 공간·사이트 저장 권한을 확인하세요. 5초마다 다시 시도합니다. 복구되기 전에는 이 창을 닫지 마세요.',
          ),
          const SizedBox(height: 14),
        ],
        if (s.serviceMount != null) ...[
          _quest(
            '${s.serviceMount!.def.name} · 내구도 ${s.serviceMount!.condition}%',
            s.mountRepairRequiresMerchant
                ? '말의 피격 회복·쓰러짐 보수는 탈것 상인에게 맡기세요.'
                : '이동·피격 시 소모됩니다. 20% 이하는 감속, 0%는 저속으로 이동합니다.',
            s.serviceMount!.durability / 100,
            '보수 비용 ${s.serviceMount!.repairCost} 골드',
          ),
          const SizedBox(height: 8),
          GameAction(
            '탈것 보수 · ${s.serviceMount!.repairCost}G',
            onTap: s.canRepairMount
                ? () {
                    if (s.repairMount()) {
                      widget.onCheckpoint?.call();
                      setState(() {});
                    }
                  }
                : null,
          ),
          if (s.serviceMount!.repairCost > p.gold)
            const Text('보수할 골드가 부족합니다.', style: TextStyle(color: gold)),
          const SizedBox(height: 18),
        ],
        DeviceControls(s.device),
        _info(
          Icons.touch_app_outlined,
          '모바일 조작',
          '왼쪽 조이스틱으로 이동합니다. 공격을 누르면 연속 공격하며, 사용 스킬 4개와 회피를 동시에 사용할 수 있습니다. 8레벨부터 이동 기술을 배우면 회피 옆에 전용 버튼이 나타납니다. 위쪽 물약은 터치하면 사용합니다.',
        ),
        const SizedBox(height: 18),
        _info(
          Icons.auto_awesome,
          '장비와 스킬',
          '가방에서 장비를 비교·장착·판매하세요. 레벨이 오르면 스킬 포인트를 1개 얻습니다. 스킬 화면에서 배우고 전투 슬롯 1~4에 지정하세요.',
        ),
        const SizedBox(height: 18),
        _info(
          Icons.keyboard_outlined,
          '키보드 조작',
          'WASD / 방향키 — 이동\nSpace / J — 연속 공격\nN / K — 스킬 1\nL / O / P — 스킬 2 / 3 / 4\n왼쪽 Shift — 회피\nM — 배운 이동 기술\n1 / 2 — 생명 / 자원 물약',
        ),
        const SizedBox(height: 18),
        if (!s.saveFailed)
          const Text(
            '5초마다 이 브라우저에 자동 저장합니다. 다음에 모험 이어하기로 돌아올 수 있습니다. 새 모험을 시작하면 이전 진행을 덮어씁니다.',
            style: TextStyle(
              color: Color(0xffbacdbe),
              fontSize: 13,
              height: 1.7,
            ),
          ),
        const SizedBox(height: 16),
        GameAction(
          '직업 선택 · 새 모험',
          semanticLabel: '직업을 다시 선택해 새 모험',
          onTap: widget.onRestart,
          icon: Icons.refresh,
        ),
      ];
    }
    return ColoredBox(
      color: const Color(0xbb071918),
      child: SafeArea(
        child: Align(
          alignment: media.size.width < 600 && media.size.height > 600
              ? Alignment.bottomCenter
              : Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: media.size.height - media.padding.vertical - 24,
              ),
              child: FramedSurface(
                art: s.art,
                compact: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GamePanelHeader(
                      title: title,
                      onClose: result ? null : widget.onClose,
                    ),
                    const Divider(height: 1, color: Color(0x557b8c62)),
                    Flexible(
                      child: Scrollbar(
                        controller: panelScroll,
                        thumbVisibility: true,
                        thickness: 3,
                        child: SingleChildScrollView(
                          controller: panelScroll,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: body,
                          ),
                        ),
                      ),
                    ),
                    if (canAdvance && s.saveFailed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                        child: Semantics(
                          liveRegion: true,
                          child: const Text(
                            '진행을 저장하지 못했습니다. 공간을 확인한 뒤 다시 눌러 주세요.',
                            style: TextStyle(
                              color: Color(0xffffaa8b),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                      child: GameAction(
                        canAdvance
                            ? advanceLabel
                            : name == 'defeat'
                            ? widget.onRetryCheckpoint != null
                                  ? '체크포인트 재도전'
                                  : '새로운 모험'
                            : name == 'victory'
                            ? '계속 탐험하기'
                            : '모험 계속하기',
                        primary: true,
                        onTap: canAdvance
                            ? widget.onAdvance
                            : name == 'defeat'
                            ? widget.onRetryCheckpoint ?? widget.onRestart
                            : name == 'victory'
                            ? continueExploring
                            : widget.onClose,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: gold, size: 20),
        const SizedBox(width: 9),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: cream),
          ),
        ),
        Flexible(
          flex: 3,
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 16,
              color: gold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _quest(
    String title,
    String description,
    double progress,
    String status,
  ) => QuestProgressCard(
    title: title,
    description: description,
    progress: progress,
    status: status,
  );

  Widget _info(IconData icon, String title, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: gold),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: gold, fontSize: 17)),
            const SizedBox(height: 7),
            Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.8, color: cream),
            ),
          ],
        ),
      ),
    ],
  );
}
