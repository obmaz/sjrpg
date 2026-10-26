import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'game_ui.dart';
import 'world_model.dart';

enum QuestGuideAction { journal, cleanse, dismount }

class QuestGuide {
  const QuestGuide(this.title, this.message, this.action, this.button);
  final String title, message, button;
  final QuestGuideAction action;
}

extension QuestGuidance on Adventure {
  String get mainQuestNext {
    if (stageCleared) {
      return world.stage.hasNextStage
          ? '의뢰 완료! 여정에서 다음 모험을 선택하세요.'
          : '균열을 봉인했습니다. 남은 보물과 전투를 탐험하세요.';
    }
    if (mandatoryQuestsComplete) {
      final remaining = math.max(0, world.stage.killGoal - stageKills);
      return remaining > 0
          ? '몬스터 $remaining마리 더 처치하면 ${world.stage.bossName}이 나타납니다.'
          : '${world.stage.bossName}을 쓰러뜨리세요. 지도에 붉은 표식으로 표시됩니다.';
    }
    if (world.stage == WorldStage.sands) {
      final q = currentCommission;
      if (q == null) {
        return timePath == null
            ? '여정에서 과거·미래 중 의뢰 하나를 선택하세요. 선택한 줄기만 진행할 수 있습니다.'
            : '여정에서 다음 의뢰를 수락하세요. 처치 수는 수락한 뒤부터 집계됩니다.';
      }
      final left = math.max(
        0,
        q.goal - (progress.kills - commissionStartKills),
      );
      return left > 0
          ? '몬스터 $left마리 더 처치한 뒤 ${q.site.name}을 조사하세요.'
          : '${q.site.name} 주변의 적을 정리하고 조사하세요.';
    }
    final left = world.sites.where((s) => !cleansedSites.contains(s.id)).length;
    return '성소 $left곳 남음. 주변 적을 정리하고 성소 앞에서 정화하세요.';
  }

  QuestGuide? get nearbyQuestGuide {
    if (!ready || disposed || defeated) return null;
    QuestSite? site;
    var distance = 300.0;
    for (final candidate in world.sites) {
      final d = (candidate.at - hero.body.center).distance;
      if (d < distance) {
        distance = d;
        site = candidate;
      }
    }
    QuestGuide note(
      String title,
      String text, [
      QuestGuideAction action = QuestGuideAction.journal,
      String button = '여정 보기',
    ]) => QuestGuide(title, text, action, button);
    if (site != null) {
      // A journal-only hint must never replace the rider's exit control.
      if (riding != null &&
          (cleansedSites.contains(site.id) ||
              world.stage == WorldStage.sands)) {
        return null;
      }
      final title = site.name;
      if (cleansedSites.contains(site.id)) {
        return note('$title · 완료', mainQuestNext);
      }
      if (world.stage == WorldStage.sands) {
        final q = timeCommissions.firstWhere((q) => q.id == site!.id);
        if (timePath != null && q.path != timePath) {
          return note('$title · 잠김', '다른 시대의 길을 선택했습니다. $mainQuestNext');
        }
        if (acceptedCommission != site.id) {
          return note('$title · 의뢰 필요', mainQuestNext);
        }
        final left = math.max(
          0,
          q.goal - (progress.kills - commissionStartKills),
        );
        if (left > 0) {
          return note(
            '$title · 조사 준비',
            '몬스터 $left마리 더 처치하고 돌아오세요. 수락 후 처치만 집계됩니다.',
          );
        }
      }
      if (riding != null) {
        return note(
          '$title · 발견',
          '탈것에서 내린 뒤 주변 적을 정리하세요.',
          QuestGuideAction.dismount,
          '내리기',
        );
      }
      final enemies = mobs
          .where(
            (m) =>
                m.combatReady &&
                !m.isDead &&
                !m.isRemoving &&
                (m.body.center - site!.at).distance < 155,
          )
          .length;
      if (enemies > 0) {
        return note(
          '$title · 전투 중',
          '주변 적 $enemies명을 처치하면 ${world.stage == WorldStage.sands ? '조사' : '정화'}할 수 있습니다.',
        );
      }
      if (nearbySite?.id != site.id) {
        return note(
          '$title · 접근 중',
          '성소 앞까지 더 가까이 가세요. 주변 적이 없으면 직접 정화할 수 있습니다.',
        );
      }
      return note(
        '$title · 준비 완료',
        '주변이 안전합니다. 아래 버튼을 눌러 의뢰를 진행하세요.',
        QuestGuideAction.cleanse,
        world.stage == WorldStage.sands ? '조사하기' : '정화하기',
      );
    }
    // An NPC hint must not replace a closer shop, chest or mount control.
    if (nearbyAction != null && nearbyAction != NearbyAction.talk) return null;
    if ((hero.body.center - world.elderAt).distance < 190) {
      return note(
        world.stage == WorldStage.forest ? '숲의 현자 · 의뢰 안내' : '연락책 · 의뢰 안내',
        mainQuestNext,
      );
    }
    return null;
  }
}

class NearbyQuestCard extends StatelessWidget {
  const NearbyQuestCard(this.guide, {required this.onTap, super.key});
  final QuestGuide guide;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${guide.title}. ${guide.message} ${guide.button}',
    excludeSemantics: true,
    child: Material(
      color: ink.withValues(alpha: .94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: gold.withValues(alpha: .65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guide.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Text(
                  guide.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ),
              Text(
                '${guide.button} ›',
                style: const TextStyle(
                  color: gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
