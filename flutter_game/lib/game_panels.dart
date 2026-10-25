import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_ui.dart';

class AdventurePanel extends StatefulWidget {
  const AdventurePanel({
    required this.session,
    required this.name,
    required this.onClose,
    required this.onRestart,
    super.key,
  });
  final Adventure session;
  final String name;
  final VoidCallback onClose, onRestart;
  @override
  State<AdventurePanel> createState() => _AdventurePanelState();
}

class _AdventurePanelState extends State<AdventurePanel> {
  String message = '';
  @override
  Widget build(BuildContext context) {
    final s = widget.session,
        p = s.progress,
        name = widget.name,
        media = MediaQuery.of(context);
    final result = name == 'victory' || name == 'defeat';
    final title = {
      'bag': '모험가의 가방',
      'journal': '모험 일지',
      'map': '모험 지도',
      'settings': '모험 설정',
      'shop': '숲길 상점',
      'talk': '숲의 현자',
      'pause': '잠시 쉬어가기',
      'defeat': '다시 일어설 시간',
      'victory': '숲의 수호자',
    }[name]!;
    List<Widget> body;
    if (name == 'shop') {
      void buy(bool Function() purchase) {
        setState(
          () => message = purchase() ? '구매했습니다. 모험을 계속하세요.' : '골드가 부족합니다.',
        );
        s.refresh();
      }

      body = [
        _line(Icons.monetization_on, '보유 골드', '${p.gold}'),
        const SizedBox(height: 16),
        _shop('치유의 물약', '체력을 50 회복합니다.', '20 골드', () => buy(s.buyHeal)),
        _shop('검 연마', '검 공격력 +5', '45 골드', () => buy(s.buySword)),
        _shop('생명의 부적', '최대 체력 +20 · 체력 회복', '60 골드', () => buy(s.buyVitality)),
        if (message.isNotEmpty)
          Text(
            message,
            style: const TextStyle(color: gold, fontSize: 14, height: 1.6),
          ),
      ];
    } else if (name == 'bag') {
      body = [
        const Text('롱소드', style: TextStyle(fontSize: 23, color: gold)),
        const SizedBox(height: 10),
        Text(
          '공격력 ${p.swordDamage.round()} · 세 번째 베기 강화',
          style: const TextStyle(fontSize: 15, height: 1.7),
        ),
        const SizedBox(height: 22),
        const _Info(
          icon: Icons.auto_awesome,
          title: '회전 베기',
          text: '주변 적을 밀어내며 강하게 벱니다.\n재사용 5초',
        ),
        const SizedBox(height: 18),
        const _Info(
          icon: Icons.air,
          title: '빠른 회피',
          text: '바라보는 방향으로 짧게 이동합니다.\n회피 중 잠깐 무적 · 재사용 1.5초',
        ),
        const SizedBox(height: 20),
        _line(Icons.monetization_on, '골드', '${p.gold}'),
      ];
    } else if (name == 'journal' || name == 'talk') {
      body = [
        if (name == 'talk') ...[
          const Text(
            '“숲길에 모여든 적들을 물리쳐 주게.\n숲의 파수꾼도 잠에서 깨어나고 있네.”',
            style: TextStyle(fontSize: 16, height: 1.8, color: cream),
          ),
          const SizedBox(height: 22),
        ],
        _quest(
          '숲길의 위협',
          '몬스터를 24마리 물리치세요.',
          math.min(24, p.kills) / 24,
          '${math.min(24, p.kills)} / 24',
        ),
        const SizedBox(height: 16),
        _quest(
          '숲의 파수꾼',
          '골렘을 쓰러뜨리고 마을을 지키세요.',
          p.bossDefeated ? 1 : 0,
          p.bossDefeated
              ? '완료'
              : s.bossSummoned
              ? '토벌 중'
              : '숲길 정화 후 등장',
        ),
        const SizedBox(height: 18),
        const Text(
          '주변 적을 쓰러뜨리면 골드를 얻습니다.\n분수 주변에서 체력을 회복하고, 상점에서 장비를 강화하세요.',
          style: TextStyle(fontSize: 14, height: 1.8, color: Color(0xffbed0bd)),
        ),
      ];
    } else if (name == 'map') {
      body = [
        SizedBox(
          height: 260,
          child: CustomPaint(painter: MapPainter(s, round: false)),
        ),
        const SizedBox(height: 18),
        Text(
          '현재 위치 · ${s.region}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: gold, fontSize: 16),
        ),
        const SizedBox(height: 14),
        const Text(
          '중앙의 분수 마을에서 출발합니다.\n서쪽에는 깊은 숲, 동쪽에는 호수와 강,\n남동쪽에는 넓은 모래벌판이 있습니다.\n강은 남쪽 목교를 통해 건너세요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.9),
        ),
      ];
    } else if (result) {
      body = [
        Icon(
          name == 'victory' ? Icons.eco : Icons.shield_outlined,
          color: gold,
          size: 64,
        ),
        const SizedBox(height: 18),
        Text(
          name == 'victory'
              ? '파수꾼을 쓰러뜨렸습니다.\n숲에 다시 평화가 찾아왔습니다.'
              : '모험은 여기서 끝나지 않습니다.\n다시 도전해 숲을 지켜주세요.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, height: 1.8),
        ),
        const SizedBox(height: 24),
        _line(Icons.bolt, '물리친 적', '${p.kills}'),
        _line(Icons.monetization_on, '획득 골드', '${p.gold}'),
        _line(Icons.timer_outlined, '모험 시간', gameTime(s.elapsed)),
      ];
    } else {
      body = [
        const _Info(
          icon: Icons.touch_app_outlined,
          title: '모바일 조작',
          text:
              '왼쪽 조이스틱으로 이동합니다.\n공격을 누르고 있으면 연속으로 벱니다.\n회전 · 회피 버튼도 함께 사용할 수 있습니다.',
        ),
        const SizedBox(height: 18),
        const _Info(
          icon: Icons.keyboard_outlined,
          title: '키보드 조작',
          text:
              'WASD / 방향키 — 이동\nSpace / J — 연속 공격\nN / K — 회전 베기\n왼쪽 Shift — 회피',
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: widget.onRestart,
          icon: const Icon(Icons.refresh),
          label: const Text('처음부터 다시 시작'),
        ),
      ];
    }
    return ColoredBox(
      color: const Color(0xb9081816),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 460,
                maxHeight: media.size.height - media.padding.vertical - 36,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: gold, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 30),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 22,
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
                    const Divider(height: 1, color: Color(0x556f805a)),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: body,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: ink,
                          ),
                          onPressed: result ? widget.onRestart : widget.onClose,
                          child: Text(
                            result ? '새로운 모험' : '모험 계속하기',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            color: gold,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
  Widget _shop(
    String title,
    String description,
    String price,
    VoidCallback buy,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff1a3e36),
        border: Border.all(color: const Color(0xff52684b)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, color: cream)),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xffb4c9b7),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: buy, child: Text('$price · 구매')),
          ],
        ),
      ),
    ),
  );
  Widget _quest(
    String title,
    String description,
    double progress,
    String status,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xffe4d5ad),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 9),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xff405246),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
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
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) => Row(
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
