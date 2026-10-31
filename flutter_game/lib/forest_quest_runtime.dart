import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'actor_motion.dart';
import 'adventure.dart';
import 'combat_balance.dart';
import 'forest_quest_npc.dart';
import 'forest_quests.dart';
import 'quest_guide.dart';
import 'quest_structure_art.dart';
import 'world_model.dart';

enum ForestNpcRole { giver, recipient, caretaker }

class ForestQuestNpcInfo {
  const ForestQuestNpcInfo(
    this.key,
    this.questId,
    this.name,
    this.role,
    this.at, {
    this.actor = 'villager',
  });
  final String key, questId, name, actor;
  final ForestNpcRole role;
  final ui.Offset at;
  ui.Rect get body => ui.Rect.fromCenter(center: at, width: 28, height: 24);
}

class _ForestThreat {
  _ForestThreat(this.token, this.attempt, {this.windup = 0});
  final int token, attempt;
  double windup;
}

/// First-stage NPC objectives are separate from well discovery and warping.
/// Only an explicit start/retry creates the three protection enemies.
class ForestQuestRuntime {
  ForestQuestRuntime(this.session);
  final Adventure session;
  ForestQuestLedger ledger = ForestQuestLedger();
  final List<ForestQuestNpcInfo> _npcs = [];
  final List<ForestQuestNpc> _actors = [];
  final Map<HuntEnemy, _ForestThreat> _threats = {};
  ForestQuestNpcInfo? selectedNpc;
  void Function()? onOpen;
  void Function(int previousLevel)? onLevelReward;
  double _npcFlash = 0;
  static const interactionRange = 145.0, protectionRadius = 650.0;
  bool get enabled =>
      session.dungeon == null && session.world.stage == WorldStage.forest;
  bool get protectionActive => ledger['sun']!.protectionActive;
  List<ForestQuestNpcInfo> get npcs {
    _ensurePositions();
    return List.unmodifiable(_npcs);
  }

  ForestQuestProgress? get selectedQuest =>
      selectedNpc == null ? null : ledger[selectedNpc!.questId];
  ForestQuestNpcInfo? get scholar =>
      npcs.where((n) => n.key == 'rowen').firstOrNull;
  ui.Offset? get defenderAt => scholar?.at;

  void _ensurePositions() {
    if (!enabled || _npcs.isNotEmpty) return;
    ui.Offset site(String id) =>
        session.world.sites.firstWhere((q) => q.id == id).at;
    final authored = [
      (
        'mira',
        'moon',
        '보급원 미라',
        ForestNpcRole.giver,
        session.world.spawn + const ui.Offset(-105, 95),
        'merchant',
      ),
      (
        'elin',
        'roots',
        '수녀 엘린',
        ForestNpcRole.caretaker,
        ForestQuestStructureArt.npcApproach('roots', site('roots')) +
            const ui.Offset(0, 50),
        'villager',
      ),
      (
        'noah',
        'moon',
        '약초사 노아',
        ForestNpcRole.recipient,
        ForestQuestStructureArt.npcApproach('moon', site('moon')) +
            const ui.Offset(0, 50),
        'merchant',
      ),
      (
        'rowen',
        'sun',
        '조사관 로웬',
        ForestNpcRole.caretaker,
        ForestQuestStructureArt.npcApproach('sun', site('sun')) +
            const ui.Offset(0, 50),
        'villager',
      ),
    ];
    for (final (key, id, name, role, at, actor) in authored) {
      final foot = session.world.spawnNear(
        at - const ui.Offset(14, 12),
        const ui.Size(28, 24),
        occupied: (body) =>
            body.overlaps(session.hero.body.inflate(4)) ||
            _npcs.any((npc) => npc.body.inflate(12).overlaps(body)),
      );
      if (foot == null) {
        continue;
      }
      final npc = ForestQuestNpcInfo(
        key,
        id,
        name,
        role,
        foot + const ui.Offset(14, 12),
        actor: actor,
      );
      _npcs.add(npc);
      session.world.addRuntimeSolid(npc.body);
    }
  }

  bool _canReachNpc(ForestQuestNpcInfo npc) {
    final delta = npc.at - session.hero.body.center;
    if (delta.distance > interactionRange) return false;
    final face = delta.distance > 0
        ? npc.at - delta / delta.distance * 24
        : npc.at;
    return session.world.clearLine(
      session.hero.body.center,
      face,
      const ui.Size(3, 3),
    );
  }

  ForestQuestNpcInfo? get nearbyNpc {
    ForestQuestNpcInfo? nearest;
    var distance = interactionRange;
    for (final npc in npcs) {
      final d = (npc.at - session.hero.body.center).distance;
      if (d < distance && _canReachNpc(npc)) {
        nearest = npc;
        distance = d;
      }
    }
    return nearest;
  }

  bool _canTalk(ForestQuestNpcInfo npc) =>
      enabled &&
      session.ready &&
      !session.disposed &&
      !session.defeated &&
      !session.won &&
      session.riding == null &&
      _canReachNpc(npc);
  QuestGuide? get guide {
    final npc = nearbyNpc;
    if (npc == null || session.disposed || session.defeated) {
      return null;
    }
    if (session.riding != null) {
      return QuestGuide(
        npc.name,
        '대화하려면 탈것에서 내리세요.',
        QuestGuideAction.dismount,
        '내리기',
      );
    }
    return QuestGuide(
      npc.name,
      ledger[npc.questId]!.currentObjective,
      QuestGuideAction.talk,
      '대화',
    );
  }

  String get mainObjective {
    final tracked = ledger[session.trackedSiteId ?? ''];
    if (tracked != null && tracked.phase != ForestQuestPhase.completed) {
      return tracked.currentObjective;
    }
    return ledger.quests
            .where((q) => q.phase != ForestQuestPhase.completed)
            .firstOrNull
            ?.currentObjective ??
        '숲의 의뢰를 모두 해결했습니다. 파수꾼을 처치하세요.';
  }

  bool _markerVisible(ForestQuestNpcInfo npc) {
    final q = ledger[npc.questId]!;
    if (q.phase == ForestQuestPhase.completed) {
      return false;
    }
    if (npc.key == 'mira') {
      return q.phase == ForestQuestPhase.offered ||
          q.phase == ForestQuestPhase.accepted && !q.hasParcel;
    }
    if (npc.key == 'noah') {
      return q.phase == ForestQuestPhase.ready || q.hasParcel;
    }
    return true;
  }

  ui.Color _color(String id) => switch (id) {
    'roots' => const ui.Color(0xffffcf70),
    'moon' => const ui.Color(0xff63e6dd),
    _ => const ui.Color(0xffc7a0ff),
  };
  void installActors({void Function()? onOpen}) {
    if (onOpen != null) this.onOpen = onOpen;
    if (!enabled || session.game == null || _actors.isNotEmpty) return;
    for (final npc in npcs) {
      final actor = ForestQuestNpc(
        art: session.art,
        name: npc.name,
        at: npc.at,
        actor: npc.actor,
        color: _color(npc.questId),
        heroAt: () => session.hero.body.center,
        enabled: () => session.active && _canTalk(npc),
        markerVisible: () => _markerVisible(npc),
        onInteract: () => openNpc(npc),
        healthRatio: npc.key != 'rowen'
            ? null
            : () {
                final q = ledger['sun']!;
                return q.protectionStarted &&
                        q.phase != ForestQuestPhase.completed
                    ? q.defenderHealth /
                          ForestQuestProgress.maximumDefenderHealth
                    : null;
              },
        flash: npc.key == 'rowen' ? () => _npcFlash > 0 ? 1.0 : 0.0 : null,
      );
      _actors.add(actor);
      session.game!.add(actor);
    }
  }

  bool openNearest() {
    final npc = nearbyNpc;
    return npc != null && openNpc(npc);
  }

  bool openNpc(ForestQuestNpcInfo npc) {
    if (!_canTalk(npc)) {
      return false;
    }
    selectedNpc = npc;
    onOpen?.call();
    return true;
  }

  bool _siteClear(String id) {
    final at = session.world.sites.firstWhere((q) => q.id == id).at;
    return !session.mobs.any(
      (m) =>
          m.combatReady &&
          !m.isDead &&
          !m.isRemoving &&
          (m.body.center - at).distance < 240,
    );
  }

  String get actionLabel {
    final npc = selectedNpc, q = selectedQuest;
    if (npc == null || q == null) {
      return '대화';
    }
    if (q.phase == ForestQuestPhase.completed) {
      return '완료';
    }
    if (q.phase == ForestQuestPhase.failed) {
      return '재시도';
    }
    if (q.phase == ForestQuestPhase.ready) {
      return '보고';
    }
    if (q.phase == ForestQuestPhase.offered) {
      return '수락';
    }
    return switch (q.definition.kind) {
      ForestQuestKind.cleanse => '정화',
      ForestQuestKind.delivery =>
        npc.key == 'mira'
            ? q.hasParcel
                  ? '배달 중'
                  : '짐 받기'
            : '전달',
      ForestQuestKind.protection => q.protectionActive ? '보호 중' : '시작',
    };
  }

  String? get blockedReason {
    final npc = selectedNpc, q = selectedQuest;
    if (npc == null || q == null || !_canTalk(npc)) {
      return '의뢰인에게 더 가까이 가세요.';
    }
    if (q.phase == ForestQuestPhase.completed) {
      return '이미 완료한 의뢰입니다.';
    }
    if (npc.key == 'noah' && q.phase == ForestQuestPhase.offered) {
      return '마을의 보급원 미라에게 의뢰를 받으세요.';
    }
    if (npc.key == 'noah' &&
        q.phase == ForestQuestPhase.accepted &&
        !q.hasParcel) {
      return '보급원 미라에게 약초 꾸러미를 받으세요.';
    }
    if (npc.key == 'mira' &&
        (q.hasParcel || q.phase == ForestQuestPhase.ready)) {
      return '약초사 노아에게 꾸러미를 전달하고 보고하세요.';
    }
    if (q.protectionActive) {
      return '조사관을 지키고 습격자를 막아 주세요.';
    }
    if (q.phase == ForestQuestPhase.accepted &&
        q.definition.kind == ForestQuestKind.cleanse &&
        (q.altarKills < ForestQuestProgress.altarKillGoal ||
            !_siteClear('roots'))) {
      return '예배당 주변 적 ${q.altarKills}/${ForestQuestProgress.altarKillGoal} · 남은 적을 정리하세요.';
    }
    if (q.phase == ForestQuestPhase.accepted &&
        npc.key == 'noah' &&
        q.hasParcel &&
        !_siteClear('moon')) {
      return '오두막 주변의 적을 정리한 뒤 안전하게 약초를 전달하세요.';
    }
    if ((q.phase == ForestQuestPhase.accepted ||
            q.phase == ForestQuestPhase.failed) &&
        q.definition.kind == ForestQuestKind.protection &&
        !_siteClear('sun')) {
      return '조사 현장 주변의 적을 먼저 정리하세요.';
    }
    return null;
  }

  bool get actionEnabled => blockedReason == null;
  String get dialogue {
    final npc = selectedNpc, q = selectedQuest;
    if (npc == null || q == null) {
      return '의뢰인에게 말을 걸어 주세요.';
    }
    if (q.phase == ForestQuestPhase.completed) {
      return '도와주셔서 고맙습니다. 숲길에서 조심하세요.';
    }
    if (q.phase == ForestQuestPhase.failed) {
      return switch (q.failure) {
        ForestQuestFailure.defenderFallen =>
          '조사관이 쓰러져 조사를 중단했습니다. 다시 준비하면 6마리씩 다섯 차례, 총 30마리의 습격이 다시 시작됩니다.',
        ForestQuestFailure.abandoned =>
          '보호 구역을 벗어나 조사를 중단했습니다. 돌아와 다시 준비해 주세요.',
        _ => '습격자를 배치할 길이 막혀 조사를 중단했습니다. 현장을 정리한 뒤 다시 준비해 주세요.',
      };
    }
    return '${q.definition.description}\n\n${q.currentObjective}';
  }

  bool performAction() {
    if (!actionEnabled) {
      return false;
    }
    final npc = selectedNpc!, q = selectedQuest!;
    var changed = false;
    if (q.phase == ForestQuestPhase.offered) {
      changed = ledger.accept(npc.questId);
      if (changed) session.trackedSiteId = npc.questId;
    } else if (q.phase == ForestQuestPhase.ready) {
      final reward = ledger.claimReward(npc.questId);
      if (reward != null) {
        session.cleansedSites.add(npc.questId);
        session.progress.gold += reward.gold;
        final previousLevel = session.progress.level;
        session.progress.awardXp(reward.experience);
        session.syncLife();
        onLevelReward?.call(previousLevel);
        session.bubble(
          '${q.title} 완료 · +${reward.gold} 골드',
          npc.at - const ui.Offset(0, 85),
          _color(npc.questId),
        );
        if (session.trackedSiteId == npc.questId) {
          session.trackedSiteId = nearestIncompleteSite(
            WorldStage.forest,
            session.hero.body.center,
            cleansedSites: session.cleansedSites,
          )?.id;
        }
        session.completeStageIfReady();
        changed = true;
      }
    } else if (q.phase == ForestQuestPhase.failed) {
      changed = ledger.retryProtection() && _startProtection();
    } else {
      changed = switch (q.definition.kind) {
        ForestQuestKind.cleanse => ledger.cleanseAltar(),
        ForestQuestKind.delivery =>
          npc.key == 'mira' ? ledger.collectParcel() : ledger.deliverParcel(),
        ForestQuestKind.protection => _startProtection(),
      };
    }
    session.refresh();
    return changed;
  }

  bool _startProtection() {
    if (!ledger.beginProtection()) {
      return false;
    }
    if (!_fillProtectionWave()) return false;
    session.announce('조사관 보호 시작 · 90초 동안 6마리씩 다섯 차례, 총 30마리를 막으세요.');
    return true;
  }

  bool _fillProtectionWave() {
    final q = ledger['sun']!, at = defenderAt;
    if (!q.protectionActive || at == null) return false;
    final owned = {
      ..._threats.values.map((tag) => tag.token),
      ...session.dormantEnemies
          .where((raw) => raw['forestGuardAttempt'] == q.attempt)
          .map((raw) => raw['forestGuardToken'])
          .whereType<int>(),
    };
    final missing = q.activeThreatTokens
        .where((token) => !owned.contains(token))
        .toList();
    if (missing.isEmpty) return true;
    if (session.living + missing.length > CombatBalance.maxActiveEnemies) {
      return true;
    }
    for (final token in missing) {
      final angle =
          -.7 +
          (token % ForestQuestProgress.waveSize) *
              math.pi *
              2 /
              ForestQuestProgress.waveSize +
          (token ~/ ForestQuestProgress.waveSize) * .35;
      final kind = const [
        'goblin',
        'wolf',
        'goblin',
        'skeleton',
        'wolf',
        'cultist',
      ][token % ForestQuestProgress.waveSize];
      final enemy = session.spawnEnemy(
        kind,
        at + ui.Offset(math.cos(angle), math.sin(angle)) * 340,
        reserveSpacing: true,
      );
      if (enemy == null) {
        _fail(ForestQuestFailure.blocked);
        return false;
      }
      _threats[enemy] = _ForestThreat(token, q.attempt);
      enemy.encounterKey = null;
    }
    session.refresh();
    return true;
  }

  void _cleanupThreats() {
    for (final enemy in _threats.keys.toList()) {
      if (!enemy.isDead && !enemy.isRemoving) {
        enemy.combatReady = false;
        session.mobs.remove(enemy);
        session.enemySpacing.remove(enemy);
        enemy.removeFromParent();
      }
    }
    _threats.clear();
    session.dormantEnemies.removeWhere(
      (m) => m.containsKey('forestGuardToken'),
    );
  }

  void _fail(ForestQuestFailure reason) {
    ledger.failProtection(reason);
    _cleanupThreats();
    session.announce(
      reason == ForestQuestFailure.defenderFallen
          ? '조사관이 쓰러졌습니다. 의뢰인에게 다시 준비하세요.'
          : reason == ForestQuestFailure.abandoned
          ? '보호 구역을 벗어나 조사가 중단됐습니다.'
          : '현장에 습격자를 배치할 공간이 없습니다. 정리 후 다시 준비하세요.',
    );
    session.refresh();
  }

  void tick(double dt) {
    if (!enabled || !session.active || !dt.isFinite || dt <= 0) return;
    _npcFlash = math.max(0, _npcFlash - dt);
    final at = defenderAt;
    if (!protectionActive) return;
    if (at == null) {
      _fail(ForestQuestFailure.blocked);
      return;
    }
    if (!_fillProtectionWave()) return;
    ledger.advanceProtection(
      dt,
      defenderPresent:
          (session.hero.body.center - at).distance <= protectionRadius,
    );
    if (ledger['sun']!.phase == ForestQuestPhase.failed) {
      _cleanupThreats();
      session.announce('보호 구역을 벗어나 조사가 중단됐습니다.');
      session.refresh();
    }
  }

  void onEnemyDefeated(HuntEnemy enemy) {
    if (enabled &&
        !enemy.boss &&
        (enemy.body.center -
                    session.world.sites.firstWhere((s) => s.id == 'roots').at)
                .distance <
            1200) {
      ledger.recordAltarKill();
    }
    final tag = _threats.remove(enemy);
    if (tag == null) return;
    ledger.recordThreatDefeated(tag.token, attempt: tag.attempt);
    session.refresh();
  }

  /// Called after common debuff clocks, before ordinary leash/patrol logic.
  /// Return false when the hero intercepts so ordinary enemy combat handles it.
  bool updateThreat(HuntEnemy enemy, double dt) {
    final tag = _threats[enemy], at = defenderAt;
    if (tag == null ||
        at == null ||
        !protectionActive ||
        enemy.isDead ||
        enemy.isRemoving) {
      return false;
    }
    if (enemy.stun > 0 ||
        enemy.hurt > 0 ||
        session.barbarianUtilities.fearedFrom(enemy) != null ||
        session.barbarianUtilities.taunted(enemy)) {
      tag.windup = 0;
      return false;
    }
    if ((enemy.body.center - session.hero.body.center).distance < 100 &&
        session.world.clearEnemyLine(
          enemy.body.center,
          session.hero.body.center,
          const ui.Size(3, 3),
        )) {
      tag.windup = 0;
      return false;
    }
    // Cancel a hero attack whose clocks stop when switching to the scholar.
    if (enemy.meleeWindup > 0 ||
        enemy.windup > 0 ||
        enemy.pounceRemaining > 0) {
      enemy.meleeWindup = enemy.windup = 0;
      enemy.slamTarget = null;
      enemy.bossAttack = null;
      enemy.pounceGoal = null;
      if (enemy.pounceRemaining > 0) enemy.finishPounce();
      enemy.attackMotion.cancel();
    }
    enemy.returningHome = false;
    final delta = at - enemy.body.center;
    enemy.bearing = math.atan2(delta.dy, delta.dx);
    final direction = delta.distance > .01
        ? delta / delta.distance
        : const ui.Offset(1, 0);
    // The scholar's own solid footprint must not occlude the impact ray.
    final face = at - direction * 24;
    if (tag.windup > 0) {
      enemy.stop();
      tag.windup = math.max(0, tag.windup - dt);
      if (tag.windup == 0) {
        enemy.attackMotion.strike(EnemyAttackPose.melee, enemy.bearing);
        if (delta.distance <= 64 &&
            session.world.clearEnemyLine(
              enemy.body.center,
              face,
              const ui.Size(3, 3),
            )) {
          final amount = enemy.outgoingDamage(4);
          ledger.damageDefender(amount, attempt: tag.attempt);
          _npcFlash = .2;
          session.bubble(
            '-${amount.round()}',
            at - const ui.Offset(0, 75),
            const ui.Color(0xffff665b),
            combatAmount: -amount,
            target: scholar,
            follow: () => at - const ui.Offset(0, 75),
          );
          if (ledger['sun']!.phase == ForestQuestPhase.failed) {
            _fail(ForestQuestFailure.defenderFallen);
          }
        }
        enemy.attackClock = .8 * CombatBalance.gameSpeed;
      }
      return true;
    }
    if (delta.distance < 54 &&
        session.world.clearEnemyLine(
          enemy.body.center,
          face,
          const ui.Size(3, 3),
        )) {
      enemy.stop();
      if (enemy.attackClock <= 0) {
        tag.windup = .22 * CombatBalance.gameSpeed;
      }
      return true;
    }
    final before = enemy.position.toOffset();
    final goal =
        at -
        direction * 42 -
        ui.Offset(enemy.body.width / 2, enemy.body.height / 2);
    var toward = goal;
    if (!session.world.clearEnemyLine(before, goal, enemy.body.size)) {
      if (enemy.replan <= 0 ||
          enemy.routeGoal == null ||
          (enemy.routeGoal! - goal).distance > 24) {
        enemy.route = session.world.routeEnemy(before, goal, enemy.body.size);
        enemy.routeGoal = goal;
        enemy.replan = .6;
      }
      while (enemy.route.isNotEmpty &&
          (enemy.route.first - before).distance < 8) {
        enemy.route.removeAt(0);
      }
      if (enemy.route.isEmpty) {
        enemy.stop();
        return true;
      }
      toward = enemy.route.first;
    } else {
      enemy.route.clear();
      enemy.routeGoal = goal;
    }
    final travel = toward - before;
    final step = travel.distance < .01
        ? ui.Offset.zero
        : travel /
              travel.distance *
              math.min(
                enemy.speed * (enemy.slow > 0 ? .45 : 1) * dt,
                travel.distance,
              );
    enemy.stop();
    final next = session.moveEnemyBody(enemy, before, step, steer: true);
    enemy.position.setValues(next.dx, next.dy);
    enemy.velocity.setValues(
      (next.dx - before.dx) / dt,
      (next.dy - before.dy) / dt,
    );
    enemy.lastClearPosition = next;
    session.updateEnemySpacing(enemy);
    return true;
  }

  /// The raw dormant record owns the token until it wakes; this is not a kill.
  void forgetDormantEnemy(HuntEnemy enemy) {
    _threats.remove(enemy);
  }

  Map<String, dynamic> saveEnemyTags(HuntEnemy enemy) {
    final tag = _threats[enemy];
    return tag == null
        ? {}
        : {
            'forestGuardToken': tag.token,
            'forestGuardAttempt': tag.attempt,
            'forestGuardWindup': tag.windup,
          };
  }

  bool restoreEnemyTags(HuntEnemy enemy, Map raw) {
    final token = raw['forestGuardToken'], attempt = raw['forestGuardAttempt'];
    if (token == null && attempt == null) {
      return true;
    }
    final windup = raw['forestGuardWindup'] ?? 0;
    if (token is! int ||
        token < 0 ||
        token >= ForestQuestProgress.threatCount ||
        attempt is! int ||
        attempt != ledger['sun']!.attempt ||
        !protectionActive ||
        !ledger['sun']!.remainingThreatTokens.contains(token) ||
        windup is! num ||
        !windup.isFinite ||
        windup < 0 ||
        windup > .22 * CombatBalance.gameSpeed ||
        _threats.values.any((t) => t.attempt == attempt && t.token == token)) {
      return false;
    }
    _threats[enemy] = _ForestThreat(token, attempt, windup: windup.toDouble());
    return true;
  }

  bool restoreLedger(Object? raw, Iterable<String> completedSiteIds) {
    final parsed = ForestQuestLedger.fromSave(
      raw,
      completedSiteIds: completedSiteIds,
    );
    if (parsed == null) {
      return false;
    }
    ledger = parsed;
    _threats.clear();
    return true;
  }

  Map<String, dynamic> toSave() => ledger.toSave();
  void dispose() {
    for (final actor in _actors) {
      actor.removeFromParent();
    }
    _actors.clear();
    _threats.clear();
  }
}
