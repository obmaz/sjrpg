import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_ui.dart';
import 'rpg_model.dart';
import 'world_model.dart' show questSites;
import 'rpg_widgets.dart';
import 'device_controls.dart';
import 'world_map.dart';
import 'equipment_panel.dart';
import 'panel_controls.dart';
import 'skills_panel.dart';

class AdventurePanel extends StatefulWidget {
  const AdventurePanel({
    required this.session,
    required this.name,
    required this.onClose,
    required this.onRestart,
    this.onRetryCheckpoint,
    super.key,
  });
  final Adventure session;
  final String name;
  final VoidCallback onClose, onRestart;
  final VoidCallback? onRetryCheckpoint;
  @override
  State<AdventurePanel> createState() => _AdventurePanelState();
}

class _AdventurePanelState extends State<AdventurePanel> {
  final panelScroll = ScrollController();
  bool showMap = false;
  @override
  void didUpdateWidget(covariant AdventurePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
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
    if (name == 'map') {
      return ExpandedWorldMap(session: s, onClose: widget.onClose);
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
      return SkillsPanel(session: s, onClose: widget.onClose);
    }
    final result = name == 'victory' || name == 'defeat';
    final title =
        {
          'bag': '모험가의 가방',
          'skills': '스킬과 성장',
          'journal': '제1장 · 십자로의 숲',
          'map': '모험 지도',
          'settings': '모험 설정',
          'shop': '숲길 상점',
          'talk': '숲의 현자',
          'pause': '잠시 쉬어가기',
          'defeat': '쓰러진 수호자',
          'victory': '첫 스테이지 정화',
          'exit': '다음 스테이지',
        }[name] ??
        '모험';
    List<Widget> body;
    if (name == 'journal' || name == 'talk' || name == 'map') {
      body = [
        if (name == 'talk') ...[
          const Text(
            '“네 갈래 길 아래에 오래된 어둠이 잠들어 있네. 뿌리 우물·달빛 샘·태양 제단부터 정화해 주게. 세 성소와 숲길을 정화하면 파수꾼이 깨어날 걸세. 상자와 전리품을 모으고, 얻은 힘을 스스로 선택하게나. 전투를 벗어나 분수 곁에서 쉬면 생명이 회복된다네.”',
            style: TextStyle(fontSize: 16, height: 1.8, color: cream),
          ),
          const SizedBox(height: 22),
        ],
        for (final site in questSites) ...[
          _quest(
            '${site.name} · 필수',
            site.hint,
            s.cleansedSites.contains(site.id) ? 1 : 0,
            s.cleansedSites.contains(site.id) ? '정화 완료' : '찾아가 정화하세요',
          ),
          const SizedBox(height: 12),
        ],
        _quest(
          '숲길 정화',
          '필수 성소 3곳과 몬스터 처치 목표를 완수해 파수꾼을 깨우세요.',
          math.min(stageKillGoal, p.kills) / stageKillGoal,
          '${math.min(stageKillGoal, p.kills)} / $stageKillGoal',
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
        const Text(
          '마을 남쪽에서 말·자전거·오토바이를, 큰 호숫가에서 배를 찾을 수 있습니다. 가까이 가서 타기를 누르세요.',
          style: TextStyle(color: cream, fontSize: 14, height: 1.6),
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
          ExpansionTile(
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
              s.openedChests.contains(memory.chest) ? memory.title : '찾지 못한 기억',
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
                style: const TextStyle(fontSize: 15, height: 1.7, color: cream),
              ),
            ],
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
        const SizedBox(height: 18),
        const Text(
          '네 갈래의 다음 여정',
          style: TextStyle(
            color: gold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        for (final exit in stageExits) _exit(exit, s.stageCleared),
        const SizedBox(height: 12),
        const Text(
          '이번 버전은 제1장만 플레이할 수 있습니다. 네 출구는 서로 다른 다음 스테이지로 이어질 예정입니다.',
          style: TextStyle(color: Color(0xffbacdbe), fontSize: 13, height: 1.7),
        ),
      ];
    } else if (name == 'exit') {
      final exit = s.nearbyExit;
      body = [
        Icon(
          s.stageCleared ? Icons.door_front_door_outlined : Icons.lock_outline,
          size: 58,
          color: gold,
        ),
        const SizedBox(height: 18),
        Text(
          exit == null ? '십자로의 숲' : '${exit.direction}쪽 · ${exit.destination}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: gold, fontSize: 23),
        ),
        const SizedBox(height: 14),
        Text(
          exit?.description ?? '네 갈래의 다음 여정',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.7),
        ),
        const SizedBox(height: 20),
        Text(
          s.stageCleared
              ? '숲의 봉인을 해제했습니다.\n다음 스테이지는 아직 준비 중입니다.\n현재는 제1장의 남은 보물을 탐험할 수 있습니다.'
              : '숲의 파수꾼이 길을 봉인하고 있습니다.\n성소 3곳을 정화하고 몬스터 $stageKillGoal마리와 파수꾼을 물리치세요.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.8, color: cream),
        ),
      ];
    } else if (result) {
      body = [
        Icon(
          name == 'victory' ? Icons.workspace_premium : Icons.shield_outlined,
          color: gold,
          size: 64,
        ),
        const SizedBox(height: 18),
        Text(
          name == 'victory'
              ? '십자로의 숲을 정화했습니다.\n파수꾼의 유산과 남은 보물을 챙겨 보세요.'
              : widget.onRetryCheckpoint != null
              ? '마지막 저장 지점에서 다시 도전하세요.\n장비와 스킬 성장은 유지됩니다.'
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
        _line(Icons.bolt, '물리친 적', '${p.kills}'),
        _line(Icons.monetization_on_outlined, '보유 골드', '${p.gold} G'),
        _line(Icons.timer_outlined, '모험 시간', gameTime(s.elapsed)),
        const SizedBox(height: 12),
        if (name == 'defeat' && widget.onRetryCheckpoint != null)
          GameAction(
            '직업을 바꿔 새 모험',
            onTap: widget.onRestart,
            icon: Icons.refresh,
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
        DeviceControls(s.device),
        _info(
          Icons.touch_app_outlined,
          '모바일 조작',
          '왼쪽 조이스틱으로 이동합니다. 공격을 누르면 연속 공격하며, 사용 스킬 4개와 회피를 동시에 사용할 수 있습니다. 위쪽 물약은 터치하면 사용합니다.',
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
          'WASD / 방향키 — 이동\nSpace / J — 연속 공격\nN / K — 스킬 1\nL / O / P — 스킬 2 / 3 / 4\n왼쪽 Shift — 회피\n1 / 2 — 생명 / 자원 물약',
        ),
        const SizedBox(height: 18),
        const Text(
          '5초마다 이 브라우저에 자동 저장합니다. 다음에 모험 이어하기로 돌아올 수 있습니다. 새 모험을 시작하면 이전 진행을 덮어씁니다.',
          style: TextStyle(color: Color(0xffbacdbe), fontSize: 13, height: 1.7),
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
                    const SizedBox(height: 10),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xff75958b),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 10, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 21,
                                color: cream,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!result)
                            IconButton(
                              tooltip: '닫기',
                              onPressed: widget.onClose,
                              icon: const Icon(Icons.close, color: gold),
                            ),
                        ],
                      ),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                      child: GameAction(
                        name == 'defeat'
                            ? widget.onRetryCheckpoint != null
                                  ? '체크포인트 재도전'
                                  : '새로운 모험'
                            : name == 'victory'
                            ? '계속 탐험하기'
                            : '모험 계속하기',
                        primary: true,
                        onTap: name == 'defeat'
                            ? widget.onRetryCheckpoint ?? widget.onRestart
                            : name == 'victory'
                            ? () {
                                s.continueExploring();
                                widget.onClose();
                              }
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
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: cream),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: gold,
            fontWeight: FontWeight.bold,
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
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xffe4d5ad),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xff405246),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress,
          color: const Color(0xff3b7860),
          backgroundColor: const Color(0xffc6bc9a),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),
        Text(status, style: const TextStyle(fontSize: 13, color: ink)),
      ],
    ),
  );
  Widget _exit(StageExit exit, bool cleared) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xff29483d),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: gold.withValues(alpha: .5)),
          ),
          child: Text(
            exit.direction,
            style: const TextStyle(color: gold, fontSize: 15),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exit.destination,
                style: const TextStyle(fontSize: 16, color: cream),
              ),
              Text(
                cleared ? '봉인 해제 · 다음 지역 준비 중' : '파수꾼이 길을 봉인했습니다',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: Color(0xffa9bfae),
                ),
              ),
            ],
          ),
        ),
        Icon(
          cleared ? Icons.door_front_door_outlined : Icons.lock_outline,
          size: 18,
          color: gold,
        ),
      ],
    ),
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
