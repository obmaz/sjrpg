import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'adventure.dart';
import 'game_ui.dart';
import 'world_model.dart';

/// The crest is decorative; every completion seal is derived from saved progress.
class StageCompletionBanner extends StatelessWidget {
  const StageCompletionBanner(this.session, {super.key});
  final Adventure session;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 500;
    final sites = session.world.stage == WorldStage.sands
        ? timeCommissions
              .where((q) => q.path == session.timePath)
              .map((q) => q.site)
              .toList()
        : session.world.sites;
    final completed = sites
        .where((s) => session.cleansedSites.contains(s.id))
        .length;
    final crest = session.art.images['victory-crest'];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 8),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withValues(alpha: .6)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff22483a), Color(0xff0c2524)],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: compact ? 72 : 108,
                    child: crest == null
                        ? const Icon(
                            Icons.workspace_premium,
                            color: gold,
                            size: 60,
                          )
                        : RawImage(
                            image: crest,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '의뢰 완수',
                        style: TextStyle(
                          color: gold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.world.stage.bossName} 토벌',
                        style: const TextStyle(
                          color: cream,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.world.stage.theme,
                        style: const TextStyle(
                          color: Color(0xffa4bcb6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _seal(
                    Icons.water_drop_outlined,
                    '필수 의뢰',
                    '$completed/${sites.length}',
                    session.mandatoryQuestsComplete,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _seal(
                    Icons.sports_martial_arts,
                    '지역 정화',
                    '${math.min(session.stageKills, session.world.stage.killGoal)}/${session.world.stage.killGoal}',
                    session.stageKills >= session.world.stage.killGoal,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _seal(
                    Icons.verified_outlined,
                    '보스 토벌',
                    session.progress.bossDefeated ? '완료' : '대기',
                    session.progress.bossDefeated,
                  ),
                ),
              ],
            ),
            if (session.progress.claimedResetStages.contains(
              session.world.stage,
            )) ...[
              const SizedBox(height: 8),
              const Text(
                '첫 완료 보상 · 초기화권 1장',
                style: TextStyle(color: gold, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _seal(IconData icon, String label, String value, bool done) =>
      Semantics(
        container: true,
        label: '$label · $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xff102d29),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: done
                  ? gold.withValues(alpha: .45)
                  : const Color(0xff34534b),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: done ? gold : cream, size: 12),
              const SizedBox(width: 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: cream,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
