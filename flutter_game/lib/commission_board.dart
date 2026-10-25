import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_ui.dart';
import 'game_art.dart';
import 'panel_controls.dart';
import 'world_model.dart';

class CommissionBoard extends StatelessWidget {
  const CommissionBoard({
    required this.session,
    required this.onCommit,
    this.onAdvance,
    super.key,
  });
  final Adventure session;
  final VoidCallback onCommit;
  final VoidCallback? onAdvance;
  @override
  Widget build(BuildContext context) {
    final stage = session.world.stage;
    if (stage == WorldStage.sands && session.timePath == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '시간의 균열은 두 시대를 가리킵니다. 한쪽의 의뢰를 선택하세요.',
            style: TextStyle(color: cream, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 14),
          for (final path in TimePath.values)
            _choice(timeCommissions.firstWhere((q) => q.path == path)),
          const Text(
            '선택한 줄기에서 의뢰 네 개가 이어집니다. 다른 시간축은 잠깁니다.',
            style: TextStyle(
              color: Color(0xffabc3b8),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          stage.commission,
          style: const TextStyle(color: cream, fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 18),
        if (stage == WorldStage.sands) ...[
          Text(
            session.timePath == null
                ? '두 의뢰 중 하나를 선택하세요'
                : '${session.timePath == TimePath.past ? '과거' : '미래'} 의뢰 진행 중 · 반대 시간축 잠금',
            style: const TextStyle(color: gold, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 12),
          if (session.timePath == null)
            for (final path in TimePath.values) ...[
              _pathHeader(path),
              const SizedBox(height: 8),
              _commission(timeCommissions.firstWhere((q) => q.path == path)),
            ]
          else ...[
            _pathHeader(session.timePath!),
            const SizedBox(height: 8),
            for (final q in timeCommissions.where(
              (q) => q.path == session.timePath,
            ))
              _commission(q),
            _pathHeader(
              session.timePath == TimePath.past
                  ? TimePath.future
                  : TimePath.past,
            ),
          ],
        ] else ...[
          for (final site in session.world.sites) _site(site),
        ],
        const SizedBox(height: 8),
        _progress(
          '지역 정화',
          '${math.min(session.stageKills, stage.killGoal)} / ${stage.killGoal}',
          session.stageKills / stage.killGoal,
        ),
        const SizedBox(height: 12),
        _progress(
          stage.bossName,
          session.stageCleared
              ? '의뢰 해결'
              : session.bossSummoned
              ? '출현 · 토벌하세요'
              : '필수 의뢰와 지역 정화 후 출현',
          session.progress.bossDefeated ? 1 : 0,
        ),
        if (session.stageCleared &&
            onAdvance != null &&
            (stage == WorldStage.forest || stage == WorldStage.sands)) ...[
          const SizedBox(height: 16),
          GameAction(
            stage == WorldStage.forest
                ? '제2장 의뢰 받기'
                : session.timePath == TimePath.past
                ? '태초의 왕국으로'
                : '네온의 심연으로',
            primary: true,
            icon: Icons.explore_rounded,
            onTap: onAdvance,
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          '성소는 미니맵과 큰 지도에서 찾을 수 있습니다. 야영지의 상인에게 장비를 구매하고, 전투를 벗어나 거점에서 회복하세요.',
          style: TextStyle(color: Color(0xffabc3b8), fontSize: 13, height: 1.6),
        ),
      ],
    );
  }

  Widget _choice(CommissionDef q) {
    final past = q.path == TimePath.past;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            past ? const Color(0xff4b3c25) : const Color(0xff1c3d4c),
            const Color(0xff102d29),
          ],
        ),
        border: Border.all(color: past ? gold : const Color(0xff79cad8)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(
                  painter: _CommissionArt(session.art, q.site.artIndex),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      past ? '과거의 기록' : '미래의 신호',
                      style: const TextStyle(
                        color: gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      q.title,
                      style: const TextStyle(color: cream, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      past ? '제3-1장 · 고대 왕국으로' : '제3-2장 · 사이버펑크 도시로',
                      style: const TextStyle(
                        color: Color(0xffb9cec1),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GameAction(
            '${q.title} 수락',
            primary: true,
            icon: past ? Icons.history_rounded : Icons.electric_bolt,
            onTap: () {
              if (session.acceptCommission(q)) onCommit();
            },
          ),
        ],
      ),
    );
  }

  Widget _pathHeader(TimePath path) {
    final locked = session.timePath != null && session.timePath != path;
    return Row(
      children: [
        Icon(
          locked
              ? Icons.lock_rounded
              : path == TimePath.past
              ? Icons.history_rounded
              : Icons.electric_bolt,
          color: locked ? Colors.grey : gold,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            path == TimePath.past ? '과거의 기록 → 제3-1장' : '미래의 신호 → 제3-2장',
            style: TextStyle(
              color: locked ? Colors.grey : gold,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _commission(CommissionDef q) {
    final done = session.cleansedSites.contains(q.id),
        active = session.acceptedCommission == q.id;
    final locked = session.timePath != null && session.timePath != q.path;
    final canAccept = session.canAcceptCommission(q);
    final count = active
        ? math.min(
            q.goal,
            math.max(0, session.progress.kills - session.commissionStartKills),
          )
        : done
        ? q.goal
        : 0;
    return Opacity(
      opacity: locked ? .45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? const Color(0xff25473e) : const Color(0xff102d29),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active || done ? gold : const Color(0xff37554b),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle
                      : locked
                      ? Icons.lock_rounded
                      : Icons.assignment_outlined,
                  size: 20,
                  color: done ? const Color(0xff8bdcc2) : gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${q.step + 1}. ${q.title}',
                    style: const TextStyle(
                      color: cream,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              q.story,
              style: const TextStyle(
                color: Color(0xffb9cec1),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              locked
                  ? '다른 시간축을 선택했습니다'
                  : done
                  ? '해결 완료'
                  : active
                  ? '위협 제거 $count / ${q.goal} · ${q.site.name} 조사'
                  : canAccept
                  ? q.site.hint
                  : '이전 의뢰 해결 후 열림',
              style: TextStyle(
                color: active || done ? gold : const Color(0xff9bb9aa),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (active) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: count / q.goal,
                color: gold,
                backgroundColor: const Color(0xff081f1d),
                minHeight: 4,
              ),
            ],
            if (canAccept) ...[
              const SizedBox(height: 12),
              GameAction(
                '${q.title} 수락',
                primary: q.step == 0,
                icon: Icons.assignment_turned_in_outlined,
                onTap: () {
                  if (session.acceptCommission(q)) onCommit();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _site(QuestSite site) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _progress(
      site.name,
      session.cleansedSites.contains(site.id) ? '복구 완료' : site.hint,
      session.cleansedSites.contains(site.id) ? 1 : 0,
    ),
  );
  Widget _progress(String title, String subtitle, double value) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xff102d29),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xff37554b)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: cream,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: const TextStyle(color: gold, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: value.clamp(0, 1),
          color: gold,
          backgroundColor: const Color(0xff081f1d),
          minHeight: 4,
        ),
      ],
    ),
  );
}

class _CommissionArt extends CustomPainter {
  _CommissionArt(this.art, this.index);
  final GameArt art;
  final int index;
  @override
  void paint(Canvas canvas, Size size) => art.landmark(
    canvas,
    index,
    Offset(size.width / 2, size.height * .94),
    size.width,
    themed: true,
  );
  @override
  bool shouldRepaint(covariant _CommissionArt oldDelegate) =>
      oldDelegate.art != art || oldDelegate.index != index;
}
