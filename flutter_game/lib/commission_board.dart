import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'game_art.dart';
import 'game_ui.dart';
import 'panel_controls.dart';
import 'quest_cards.dart';
import 'quest_guide.dart';
import 'world_model.dart';

class CommissionBoard extends StatelessWidget {
  const CommissionBoard({
    required this.session,
    required this.onCommit,
    this.onAdvance,
    this.offeredPath,
    super.key,
  });
  final Adventure session;
  final VoidCallback onCommit;
  final VoidCallback? onAdvance;
  final TimePath? offeredPath;
  @override
  Widget build(BuildContext context) {
    final stage = session.world.stage;
    if (stage == WorldStage.sands && session.timePath == null) {
      final giver = timeQuestGivers
          .where((g) => g.path == offeredPath)
          .firstOrNull;
      if (giver == null) {
        return const Text(
          '야영지의 의뢰인을 찾아 대화하세요.\n서쪽 기록관의 의뢰는 제3-1장 고대 왕국으로, 동쪽 통신관의 의뢰는 제3-2장 사이버펑크로 이어집니다.\n\n첫 의뢰를 받은 줄기만 진행할 수 있습니다. 제2장 사막에서 네 의뢰와 지역 정화·감시자 토벌을 마치면 다음 시대로 이동합니다.',
          style: TextStyle(color: cream, fontSize: 15, height: 1.6),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${giver.name}의 첫 의뢰입니다. 제2장 사막의 네 의뢰와 지역 정화·감시자 토벌을 마치면 ${giver.destination}으로 이동합니다.',
            style: const TextStyle(color: cream, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 14),
          _choice(
            timeCommissions.firstWhere((q) => q.path == giver.path),
            bannerHeight: MediaQuery.sizeOf(context).height < 500 ? 80 : 104,
          ),
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

    if (stage == WorldStage.sands &&
        offeredPath != null &&
        offeredPath != session.timePath) {
      final owner = timeQuestGivers.firstWhere(
        (g) => g.path == session.timePath,
      );
      return Text(
        '이미 ${owner.name}의 의뢰를 시작했습니다. 다른 시대의 의뢰를 함께 받을 수 없습니다.\n\n${session.mainQuestNext}',
        style: const TextStyle(color: cream, fontSize: 15, height: 1.6),
      );
    }

    final journey = timeCommissions
        .where((q) => q.path == session.timePath)
        .toList();
    final current = journey
        .where(
          (q) =>
              session.acceptedCommission == q.id ||
              session.canAcceptCommission(q),
        )
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stage == WorldStage.sands) ...[
          _pathHeader(session.timePath!),
          const SizedBox(height: 8),
          Text(
            '현재 · 제2장 사막 유적\n필수 의뢰 ${journey.where((q) => session.cleansedSites.contains(q.id)).length} / 4 · 반대 시간축 잠금',
            style: const TextStyle(
              color: Color(0xffabc3b8),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (current != null) ...[
            Text(
              session.acceptedCommission == current.id ? '진행 중 의뢰' : '다음 의뢰',
              style: const TextStyle(
                color: gold,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _commission(current),
          ],
          for (final q in journey)
            if (q != current) _record(q),
        ] else ...[
          Text(
            stage.commission,
            style: const TextStyle(color: cream, fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 18),
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

  Widget _choice(CommissionDef q, {required double bannerHeight}) {
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
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: bannerHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _CommissionArt(session.art, past ? 0 : 1),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xdd0d2523), Color(0x220d2523)],
                        stops: [0, .8],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          past ? '과거의 기록' : '미래의 신호',
                          style: TextStyle(
                            color: past ? gold : const Color(0xffa1e4ef),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          past ? '제3-1장 · 고대 왕국' : '제3-2장 · 사이버펑크',
                          style: const TextStyle(
                            color: cream,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
            path == TimePath.past ? '완료 후 · 제3-1장 고대 왕국' : '완료 후 · 제3-2장 사이버펑크',
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

  Widget _record(CommissionDef q) {
    final done = session.cleansedSites.contains(q.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xff102d29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xff37554b)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey('commission-record-${q.id}'),
          iconColor: gold,
          collapsedIconColor: const Color(0xff9bb9aa),
          leading: Icon(
            done ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: done ? const Color(0xff8bdcc2) : const Color(0xff9bb9aa),
            size: 20,
          ),
          title: Text(
            '${q.step + 1}. ${q.title}',
            style: const TextStyle(
              color: cream,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            done ? '해결 완료' : '이전 의뢰 해결 후 열림',
            style: const TextStyle(color: Color(0xffabc3b8), fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            Text(
              q.story,
              style: const TextStyle(
                color: Color(0xffb9cec1),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
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
            if (canAccept) ...[
              const SizedBox(height: 12),
              GameAction(
                '${q.title} 수락',
                primary: true,
                icon: Icons.assignment_turned_in_outlined,
                onTap: () {
                  if (session.acceptCommission(q)) onCommit();
                },
              ),
            ],
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
          ],
        ),
      ),
    );
  }

  Widget _site(QuestSite site) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: QuestSiteCard(
      art: session.art,
      site: site,
      done: session.cleansedSites.contains(site.id),
      stage: session.world.stage,
    ),
  );
  Widget _progress(String title, String subtitle, double value) =>
      QuestProgressCard(title: title, status: subtitle, progress: value);
}

class _CommissionArt extends CustomPainter {
  _CommissionArt(this.art, this.index);
  final GameArt art;
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final image = art.images['time-paths'];
    if (image == null || size.isEmpty) return;
    final source = Rect.fromLTWH(
      0,
      index * image.height / 2,
      image.width.toDouble(),
      image.height / 2,
    );
    final fitted = applyBoxFit(BoxFit.cover, source.size, size);
    canvas.drawImageRect(
      image,
      Alignment.center.inscribe(fitted.source, source),
      Alignment.center.inscribe(fitted.destination, Offset.zero & size),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _CommissionArt oldDelegate) =>
      oldDelegate.art != art || oldDelegate.index != index;
}
