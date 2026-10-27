import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'actor_motion.dart';
import 'area_damage.dart';
import 'audio_settings.dart';
import 'battle_effects.dart';
import 'boss_attacks.dart';
import 'boss_sprite_mesh.dart';
import 'combat_balance.dart';
import 'combat_feedback.dart';
import 'crushing_blow_vfx.dart';
import 'destructible_chest.dart';
import 'device_settings.dart';
import 'effect_visibility.dart';
import 'encounter_beacon_art.dart';
import 'encounters.dart';
import 'enemy_catalog.dart';
import 'enemy_difficulty.dart';
import 'enemy_motion.dart';
import 'enemy_spacing.dart';
import 'game_art.dart';
import 'health_feedback.dart';
import 'loot_policy.dart';
import 'mobility_motion.dart';
import 'physical_aim_preview.dart';
import 'player_affliction_art.dart';
import 'player_afflictions.dart';
import 'ranked_vfx.dart';
import 'shop_content.dart';
import 'skill_aim.dart';
import 'spell_vfx.dart';
import 'travel_journal.dart';
import 'world_model.dart';

enum NearbyAction { shrine, mount, dismount, shop, talk, smith }

enum EnemyTrait {
  none(1, 1, ui.Color(0xffe87753)),
  armored(1.8, 1, ui.Color(0xffffca78)),
  swift(1.35, 1.2, ui.Color(0xffb3a0ff));

  const EnemyTrait(this.healthScale, this.speedScale, this.color);
  final double healthScale, speedScale;
  final ui.Color color;
}

class Adventure extends ChangeNotifier {
  Adventure(
    this.art, {
    int seed = 7829,
    WorldStage stage = WorldStage.forest,
    ui.Offset? hubOrigin,
    HeroClass heroClass = HeroClass.warrior,
    Progress? restoredProgress,
    DeviceSettings? device,
    AudioSettings? audio,
  }) : world = AdventureWorld(seed: seed, stage: stage, hubOrigin: hubOrigin),
       progress = restoredProgress ?? Progress(heroClass: heroClass),
       device = device ?? DeviceSettings.shared,
       audio = audio ?? AudioSettings.shared {
    timePath =
        stage.requiredPath ??
        (stage == WorldStage.convergence ? TimePath.past : null);
    hero = Guardian(this);
    trackedSiteId = stage.requiresContract
        ? null
        : nearestIncompleteSite(stage, hero.body.center)?.id;
    terrain = TerrainArt(world, art);
    for (var i = 0; i < travelMountDefs.length; i++) {
      final def = travelMountDefs[i];
      if (world.stage != WorldStage.forest &&
          def.waterOnly &&
          i - 3 >= world.lakes.length) {
        continue;
      }
      final desired = world.stage == WorldStage.forest
          ? initialMountPositions[i]
          : def.waterOnly
          ? world.lakes[(i - 3) % world.lakes.length].bounds.center
          : world.spawn + ui.Offset(-220 + i * 160, 280);

      if (def.waterOnly && !world.largeWater(desired)) continue;
      final topLeft = world.spawnNear(
        desired - ui.Offset(def.bodySize.width / 2, def.bodySize.height / 2),
        def.bodySize,
        waterOnly: def.waterOnly,
      );
      if (topLeft != null) {
        mounts.add(
          TravelMount(
            def,
            topLeft +
                ui.Offset(def.bodySize.width / 2, def.bodySize.height / 2),
          ),
        );
      }
    }
  }
  final GameArt art;
  final DeviceSettings device;
  final AudioSettings audio;
  final AdventureWorld world;
  late final Guardian hero;
  late final TerrainArt terrain;
  final Progress progress;
  PlayerAfflictions afflictions = PlayerAfflictions();
  final travelJournal = TravelJournal();
  bool saveFailed = false;
  final loot = <GroundLoot>[];
  final texts = <BattleText>[];
  final mounts = <TravelMount>[];
  TravelMount? riding;
  TravelMount? get nearbyMount {
    TravelMount? nearest;
    var best = double.infinity;
    for (final mount in mounts) {
      final distance = (hero.body.center - mount.at).distance;
      if (distance < (mount.def.waterOnly ? 230 : 120) &&
          distance < best &&
          world.clearBoardingLine(hero.body.center, mount.at)) {
        nearest = mount;
        best = distance;
      }
    }
    return nearest;
  }

  bool boardNearbyMount() {
    if (!active ||
        afflictions.movementBlocked ||
        riding != null ||
        hero.dashing > 0 ||
        hero.physicalAction) {
      return false;
    }
    final mount = nearbyMount;
    if (mount == null || mount.durability <= 0) return false;
    final body = ui.Rect.fromCenter(
      center: mount.at,
      width: mount.def.bodySize.width,
      height: mount.def.bodySize.height,
    );
    if (world.blocked(body, waterOnly: mount.def.waterOnly)) {
      announce('탈것 주변에 공간이 필요해요');
      return false;
    }
    if (mobs.any((m) => !m.isDead && !m.isRemoving && m.body.overlaps(body))) {
      announce('탈것 주변의 적을 먼저 정리하세요');
      return false;
    }
    releaseInput();
    riding = mount;
    hero.cancelSprint();
    hero.resizeBody(mount.def.bodySize, mount.at);
    hero.bearing = mount.bearing;
    hero.swing = hero.spin = 0;
    refresh();
    return true;
  }

  bool dismount({bool keepInput = false}) {
    final mount = riding;
    if (mount == null) return true;
    if (!active) return false;
    const size = Guardian.onFootSize;
    final center = hero.body.center;
    ui.Offset? at;
    for (var radius = 0.0; radius <= 220 && at == null; radius += 20) {
      for (var i = 0; i < (radius == 0 ? 1 : 16); i++) {
        final a = hero.bearing + i * math.pi / 8;
        final p = center + ui.Offset(math.cos(a), math.sin(a)) * radius;
        final body = ui.Rect.fromCenter(
          center: p,
          width: size.width,
          height: size.height,
        );
        final hull = ui.Rect.fromCenter(
          center: center,
          width: mount.def.bodySize.width,
          height: mount.def.bodySize.height,
        );
        if (!body.overlaps(hull) &&
            !world.blocked(body) &&
            world.clearBoardingLine(center, p) &&
            !mobs.any(
              (m) => !m.isDead && !m.isRemoving && m.body.overlaps(body),
            )) {
          at = p;
          break;
        }
      }
    }
    if (at == null) {
      releaseInput();
      announce(mount.def.waterOnly ? '물가에서 내려 주세요' : '내릴 공간이 부족합니다');
      return false;
    }
    mount.at = center;
    if (!keepInput) releaseInput();
    riding = null;
    hero.resizeBody(size, at);
    refresh();
    return true;
  }

  TravelMount? get serviceMount => riding ?? nearbyMount;
  bool repairMount() {
    final mount = serviceMount;
    if (disposed ||
        defeated ||
        mount == null ||
        mount.repairCost <= 0 ||
        progress.gold < mount.repairCost) {
      return false;
    }
    progress.gold -= mount.repairCost;
    mount.durability = 100;
    refresh();
    return true;
  }

  void wearMount(double amount) {
    if (!active) return;
    final mount = riding;
    if (mount == null) return;
    final before = mount.durability;
    mount.wear(amount);
    if (before > 0 && mount.durability <= 0) {
      announce('탈것 내구도 소진 · 저속 이동 가능 · 설정에서 보수');
      refresh();
    } else if (before > 20 && mount.durability <= 20) {
      announce('탈것 내구도 부족 · 설정에서 보수하세요');
      refresh();
    }
  }

  bool ensureOnFoot() => riding == null || dismount(keepInput: true);

  Set<int> get openedChests => world.openedChests;
  final _chests = <DestructibleChest>{};
  void registerChest(DestructibleChest chest) => _chests.add(chest);
  void unregisterChest(DestructibleChest chest) => _chests.remove(chest);
  final cleansedSites = <String>{};
  String? trackedSiteId;
  QuestSite? get trackedSite {
    for (final site in visibleSites) {
      if (site.id == trackedSiteId && canTrackSite(site)) return site;
    }
    return null;
  }

  ChapterContract? get stageContract => chapterContract(world.stage, timePath);
  bool get chapterContractAccepted =>
      !world.stage.requiresContract ||
      stageContract != null && acceptedCommission == stageContract!.id;
  bool get canAcceptChapterContract =>
      world.stage.requiresContract &&
      !disposed &&
      !defeated &&
      !chapterContractAccepted &&
      stageContract != null &&
      (hero.body.center - world.elderAt).distance < 150 &&
      world.clearLine(hero.body.center, world.elderAt, const ui.Size(3, 3));
  bool acceptChapterContract() {
    if (!canAcceptChapterContract) return false;
    acceptedCommission = stageContract!.id;
    trackedSiteId = nearestIncompleteSite(
      world.stage,
      hero.body.center,
      cleansedSites: cleansedSites,
    )?.id;
    commissionStartKills = progress.kills;
    refresh();
    return true;
  }

  bool canTrackSite(QuestSite site) {
    if (disposed ||
        defeated ||
        cleansedSites.contains(site.id) ||
        !visibleSites.any((s) => s.id == site.id)) {
      return false;
    }
    if (!chapterContractAccepted) return false;
    if (world.stage != WorldStage.sands) return true;
    final q = timeCommissions.firstWhere((q) => q.id == site.id);
    return acceptedCommission == site.id || canAcceptCommission(q);
  }

  bool toggleTrackedSite(QuestSite site) {
    if (disposed || defeated) return false;
    if (trackedSite?.id == site.id) {
      trackedSiteId = null;
      refresh();
      return true;
    }
    if (!canTrackSite(site)) return false;
    trackedSiteId = site.id;
    refresh();
    return true;
  }

  int stageStartKills = 0, commissionStartKills = 0;
  TimePath? timePath;
  String? acceptedCommission;
  double _nextBossSpawn = 0;
  int get stageKills => math.max(0, progress.kills - stageStartKills);
  List<QuestSite> get visibleSites => world.stage == WorldStage.sands
      ? timeCommissions
            .where((q) => timePath != null && q.path == timePath)
            .map((q) => q.site)
            .toList()
      : world.sites;
  CommissionDef? get currentCommission {
    for (final q in timeCommissions) {
      if (q.id == acceptedCommission) return q;
    }
    return null;
  }

  bool canAcceptCommission(CommissionDef q) =>
      !disposed &&
      !defeated &&
      world.stage == WorldStage.sands &&
      acceptedCommission == null &&
      (timePath == null ? q.step == 0 : q.path == timePath) &&
      !cleansedSites.contains(q.id) &&
      (q.step == 0 ||
          timeCommissions.any(
            (previous) =>
                previous.path == q.path &&
                previous.step == q.step - 1 &&
                cleansedSites.contains(previous.id),
          ));
  TimeQuestGiver? get nearbyTimeGiver {
    if (world.stage != WorldStage.sands) return null;
    TimeQuestGiver? nearest;
    var distance = 135.0;
    for (final giver in timeQuestGivers) {
      final at = giver.atOrigin(world.spawn);
      final d = (hero.body.center - at).distance;
      if (d < distance &&
          world.clearLine(hero.body.center, at, const ui.Size(3, 3))) {
        distance = d;
        nearest = giver;
      }
    }
    return nearest;
  }

  bool acceptCommission(CommissionDef q) {
    if (!timeCommissions.contains(q) || !canAcceptCommission(q)) return false;
    if (timePath == null && nearbyTimeGiver?.path != q.path) return false;
    timePath = q.path;
    acceptedCommission = q.id;
    trackedSiteId = q.id;
    commissionStartKills = progress.kills;
    refresh();
    return true;
  }

  bool get mandatoryQuestsComplete => mandatoryStageObjectivesComplete(
    world.stage,
    path: timePath,
    commission: acceptedCommission,
    cleansedSites: cleansedSites,
    requiredSiteIds: world.sites.map((site) => site.id),
  );
  bool get stageCleared => progress.bossDefeated && mandatoryQuestsComplete;
  QuestSite? get nearbySite {
    if (!chapterContractAccepted) return null;
    for (final site in visibleSites) {
      if (world.stage == WorldStage.sands && site.id != acceptedCommission) {
        continue;
      }
      if (!cleansedSites.contains(site.id) &&
          (hero.body.center - site.at).distance < 115 &&
          world.clearLine(hero.body.center, site.at, const ui.Size(3, 3))) {
        return site;
      }
    }
    return null;
  }

  bool cleanseNearbySite() {
    if (!active || riding != null) return false;
    final site = nearbySite;
    if (site == null) return false;
    if (mobs.any(
      (m) =>
          m.combatReady &&
          !m.isDead &&
          !m.isRemoving &&
          (m.body.center - site.at).distance < 155,
    )) {
      announce('주변의 적을 먼저 물리치세요');
      return false;
    }
    final commission = currentCommission;
    if (commission != null &&
        progress.kills - commissionStartKills < commission.goal) {
      announce(
        '주변 위협 ${math.min(commission.goal, progress.kills - commissionStartKills)} / ${commission.goal}',
      );
      return false;
    }
    cleansedSites.add(site.id);
    if (trackedSiteId == site.id) {
      trackedSiteId = nearestIncompleteSite(
        world.stage,
        hero.body.center,
        cleansedSites: cleansedSites,
      )?.id;
    }
    if (commission != null) {
      acceptedCommission = null;
      progress.gainXp(50 + commission.step * 20);
      syncLife();
    }
    progress.gold += 40;
    bubble(
      '${site.name} 정화 · +40 골드',
      site.at - const ui.Offset(0, 80),
      site.color,
    );
    game?.add(RuneBurst(this, site.at, site.color, radius: 85));
    completeStageIfReady();
    refresh();
    return true;
  }

  void completeStageIfReady() {
    if (disposed || defeated || progress.hp <= 0 || !stageCleared) return;
    progress.awardSkillResetTicket(world.stage);
    if (won) return;
    combatFeedback.finish();
    won = true;
    audio.stop();
    releaseInput();
    game?.pauseEngine();
  }

  bool memoryRewarded = false;
  int get recoveredMemories => world.stage != WorldStage.forest
      ? 0
      : stageMemories
            .where((memory) => openedChests.contains(memory.chest))
            .length;
  String notice = "";
  double noticeTime = 0, combatTime = 0;
  int get skillPoints => progress.skillPoints;
  static final chestLocations = stageChests;
  List<ui.Offset> get stageChestLocations => world.chests;
  final mobs = <HuntEnemy>[];
  final attackSources = <String>{};
  BonfireGameInterface? game;
  bool ready = false,
      paused = false,
      defeated = false,
      won = false,
      bossSummoned = false,
      disposed = false;
  double cameraOffsetY = 0;
  ui.Size? viewportSize;
  Vector2 get cameraFocus =>
      hero.position + hero.size / 2 + Vector2(0, cameraOffsetY) + cameraImpact;
  late final combatFeedback = CombatFeedback(
    game: () => game,
    active: () => active,
    visible: (at) {
      final view = viewportSize;
      if (view == null) return (at - hero.body.center).distance <= 750;
      return ui.Rect.fromCenter(
        center: cameraFocus.toOffset(),
        width: view.width,
        height: view.height,
      ).inflate(70).contains(at);
    },
  );
  double impactTime = 0, impactStrength = 0;
  Vector2 get cameraImpact {
    if (ui
        .PlatformDispatcher
        .instance
        .accessibilityFeatures
        .disableAnimations) {
      return Vector2.zero();
    }
    final fade = (impactTime / .14).clamp(0.0, 1.0);
    final phase = (.14 - impactTime) * 110;
    return Vector2(
      math.sin(phase) * impactStrength * fade,
      math.cos(phase * 1.3) * impactStrength * fade * .6,
    );
  }

  void kickCamera(double strength) {
    if (!active) return;
    impactStrength = math.max(impactStrength, strength.clamp(0, 2.4));
    impactTime = .14;
  }

  double elapsed = 0, waveTime = 0, notifyTime = 0;
  double lastPackSpawn = -10;
  ui.Offset lastPack = arrival;
  int combo = 0, rageStrike = -1;
  int buildRevision = 0;
  int _successfulPacks = 0;
  final encounterAreas = <String, EncounterArea>{};
  final _encounterStones = <EncounterStone>{};
  final dormantEnemies = <Map<String, dynamic>>[];
  bool restoredEncounters = false;
  double lastEnemyWake = -1;
  ui.Offset lastEnemyWakeAt = ui.Offset.zero;
  String get encounterKey => EncounterArea.keyAt(hero.body.center);
  bool areaHasEnemies(String key) =>
      mobs.any(
        (m) =>
            !m.boss &&
            !m.isDead &&
            !m.isRemoving &&
            !m.encounterDormant &&
            m.encounterKey == key,
      ) ||
      dormantEnemies.any((m) => m['area'] == key);
  Iterable<EncounterArea> get exhaustedAreas =>
      encounterAreas.values.where((a) => a.waves >= EncounterArea.waveLimit);
  Map<String, dynamic> saveEnemy(HuntEnemy m) => {
    'kind': m.kind,
    'trait': m.trait.name,
    'tier': m.tier.name,
    'power': m.power.toSave(),
    'wardPhase': m.wardPhase,
    'area': m.encounterKey,
    'x': m.position.x,
    'y': m.position.y,
    'hp': m.life.value,
    'maxHp': m.life.max,
  };
  void wakeEnemies() {
    if (elapsed - lastEnemyWake < .5 &&
        (hero.body.center - lastEnemyWakeAt).distance < 240) {
      return;
    }
    lastEnemyWake = elapsed;
    lastEnemyWakeAt = hero.body.center;
    var capacity = CombatBalance.maxActiveEnemies - living;
    if (capacity <= 0 || dormantEnemies.isEmpty) return;
    var attempts = 0;
    for (final raw in List<Map<String, dynamic>>.of(dormantEnemies)) {
      if (capacity <= 0 || attempts >= 16) break;
      final at = ui.Offset(
        (raw['x'] as num).toDouble(),
        (raw['y'] as num).toDouble(),
      );
      if ((at - hero.body.center).distanceSquared > 1100 * 1100) continue;
      attempts++;
      final mob = spawnEnemy(
        raw['kind'] as String,
        at,
        trait: EnemyTrait.values.firstWhere((t) => t.name == raw['trait']),
        tier: EnemyTier.values.firstWhere((t) => t.name == raw['tier']),
        power: EnemyPowerSave.fromSave(raw['power']),
      );
      if (mob == null) {
        // Retry other survivors first if terrain or a crowd blocks this body.
        dormantEnemies.remove(raw);
        dormantEnemies.add(raw);
        continue;
      }
      capacity--;
      mob.encounterKey = raw['area'] as String?;
      mob.wardPhase = (raw['wardPhase'] as num).toDouble();
      mob.life.initial((raw['maxHp'] as num).toDouble());
      mob.life.update((raw['hp'] as num).toDouble());
      dormantEnemies.remove(raw);
    }
  }

  bool strikeEncounterStone(double range) {
    if (!active || riding != null) return false;
    for (final area in exhaustedAreas) {
      if (areaHasEnemies(area.key) ||
          (area.stone - hero.body.center).distance > range + 20 ||
          !world.clearLine(hero.body.center, area.stone, const ui.Size(3, 3))) {
        continue;
      }
      hero.attackBearing = math.atan2(
        area.stone.dy - hero.body.center.dy,
        area.stone.dx - hero.body.center.dx,
      );
      area.stoneHits++;
      audio.play(EffectSound.impact);
      device.pulse(FeedbackKind.hit);
      kickCamera(.5);
      if (area.stoneHits >= 3) {
        area.waves = 0;
        area.stoneHits = 0;
        waveTime = 0;
        lastPackSpawn = elapsed - 10;
        bubble(
          '새로운 적의 기척',
          area.stone - const ui.Offset(0, 55),
          const ui.Color(0xffb4eee0),
        );
      }
      refresh();
      return true;
    }
    return false;
  }

  final random = math.Random(52);
  bool get active => ready && !disposed && !paused && !defeated && !won;
  bool get sheltered => world.sanctuary.protects(hero.body);
  bool get combatAllowed => active && !sheltered;
  String get region => world.areaName(hero.position.toOffset());
  bool get nearbyBlacksmith =>
      world.stage == WorldStage.forest &&
      (hero.body.center - world.blacksmithAt).distance < 155 &&
      world.clearLine(
        hero.body.center,
        world.blacksmithAt,
        const ui.Size(3, 3),
      );
  NearbyAction? get nearbyAction => nearbyActions.firstOrNull;
  List<NearbyAction> get nearbyActions {
    if (riding != null) return [NearbyAction.dismount];
    final actions = <NearbyAction>[
      if (nearbyBlacksmith) NearbyAction.smith,
      if (nearbyMount != null) NearbyAction.mount,
      if (nearbySite != null) NearbyAction.shrine,
    ];
    final at = hero.position.toOffset();
    final shop = (at - world.merchantAt).distance;
    final talk = world.stage == WorldStage.sands
        ? nearbyTimeGiver == null
              ? double.infinity
              : (at - nearbyTimeGiver!.atOrigin(world.spawn)).distance
        : (at - world.elderAt).distance;
    if (talk < 135 && (shop >= 165 || talk < shop)) {
      actions.add(NearbyAction.talk);
    } else if (shop < 165) {
      actions.add(NearbyAction.shop);
    }
    return actions;
  }

  int? get nearbyChest {
    final candidates = attackableChests(hero.body.center, 110);
    return candidates.isEmpty ? null : candidates.first;
  }

  void announce(String value) {
    notice = value;
    noticeTime = 3.5;
    refresh();
  }

  void continueExploring() {
    if (!won || defeated) return;
    won = false;
    resume();
    announce(
      world.stage.hasNextStage
          ? '의뢰 완료 · 여정에서 다음 의뢰를 확인하세요'
          : '균열 봉인 완료 · 남은 보물과 전투를 탐험하세요',
    );
  }

  void openChest() {
    final index = nearbyChest;
    if (index != null) breakChest(index);
  }

  bool breakChest(int index) {
    if (!active ||
        index < 0 ||
        index >= stageChestLocations.length ||
        !openedChests.add(index)) {
      return false;
    }
    audio.play(EffectSound.loot);
    device.pulse(FeedbackKind.loot);
    game?.add(ChestFragments(this, stageChestLocations[index]));
    final at = stageChestLocations[index];
    var content = chestContent(world.stage, index);
    // A safe settlement must never release enemies behind its fence.
    if (content == ChestContent.ambush &&
        world.sanctuary.protects(world.chestBody(index))) {
      content = ChestContent.coins;
    }
    final ambushed = content == ChestContent.ambush && _chestAmbush(at) > 0;
    final goldFound = content == ChestContent.ambush && !ambushed
        ? 6
        : content.gold;
    progress.gold += goldFound;
    final potionFound =
        content == ChestContent.supplies ||
        world.stage == WorldStage.forest && index == 0;
    if (potionFound) {
      progress.healingPotions++;
      progress.energyPotions++;
    }
    if (content == ChestContent.gear) {
      dropGear(progress.rollLoot(random, chest: true), at);
    }
    bubble(
      ambushed
          ? world.stage.usesCityArt
                ? '경비 드론 매복!'
                : '독사 매복!'
          : potionFound
          ? '+$goldFound 골드 · 물약 +2'
          : '+$goldFound 골드',
      at - const ui.Offset(0, 55),
      ambushed ? const ui.Color(0xffc5e894) : const ui.Color(0xffffd774),
    );
    if (!memoryRewarded && recoveredMemories == stageMemories.length) {
      memoryRewarded = true;
      progress.skillPoints++;
      bubble(
        '숲의 기억 · 스킬 포인트 +1',
        hero.body.center - const ui.Offset(0, 80),
        const ui.Color(0xffa8f2d2),
      );
    }
    refresh();
    return true;
  }

  int _chestAmbush(ui.Offset at) {
    const size = ui.Size(24, 22), half = ui.Offset(12, 11);
    final away = at - hero.body.center;
    final bearing = math.atan2(away.dy, away.dx);
    var added = 0;
    for (final turn in [-.75, .75]) {
      if (living >= CombatBalance.maxActiveEnemies) break;
      final desired =
          at +
          ui.Offset(math.cos(bearing + turn), math.sin(bearing + turn)) * 100 -
          half;
      final safe = world.spawnNear(
        desired,
        size,
        avoidSanctuary: true,
        occupied: (body) =>
            (body.center - hero.body.center).distanceSquared < 90 * 90 ||
            (body.center - at).distanceSquared > 240 * 240 ||
            !world.clearEnemyLine(body.center, at, const ui.Size(3, 3)) ||
            mobs.any(
              (m) =>
                  !m.isDead &&
                  !m.isRemoving &&
                  !m.encounterDormant &&
                  m.body.overlaps(body),
            ),
      );
      if (safe == null) continue;
      final enemy = spawnEnemy(
        world.stage.usesCityArt ? 'drone' : 'viper',
        safe,
      );
      if (enemy == null) continue;
      final key = EncounterArea.keyAt(at);
      if (!encounterAreas.containsKey(key)) {
        final area = EncounterArea(key, at);
        encounterAreas[key] = area;
        game?.add(EncounterStone(this, area));
      }
      enemy.encounterKey = key;
      // Even an adjacent chest gives time to read the emerging threat.
      enemy.attackClock = 1.2;
      added++;
    }
    return added;
  }

  List<int> attackableChests(
    ui.Offset origin,
    double range, {
    double? bearing,
    double halfAngle = math.pi,
  }) {
    final candidates =
        world
            .closedChestsNear(
              ui.Rect.fromCircle(center: origin, radius: range + 30),
            )
            .where((index) {
              final toward = stageChestLocations[index] - origin;
              if ((world.chestApproach(index, origin) - origin).distance >
                  range) {
                return false;
              }
              if (bearing != null &&
                  math
                          .atan2(
                            math.sin(
                              math.atan2(toward.dy, toward.dx) - bearing,
                            ),
                            math.cos(
                              math.atan2(toward.dy, toward.dx) - bearing,
                            ),
                          )
                          .abs() >
                      halfAngle) {
                return false;
              }
              if (world.chestBody(index).contains(origin)) return true;
              return world.clearLine(
                origin,
                world.chestApproach(index, origin),
                const ui.Size(3, 3),
              );
            })
            .toList()
          ..sort(
            (a, b) => (stageChestLocations[a] - origin).distanceSquared
                .compareTo((stageChestLocations[b] - origin).distanceSquared),
          );
    return candidates;
  }

  int strikeChests(
    ui.Offset origin,
    double range, {
    double? bearing,
    double halfAngle = math.pi,
    int maxTargets = 1,
  }) {
    if (!active || maxTargets <= 0) return 0;
    var broken = 0;
    for (final index in attackableChests(
      origin,
      range,
      bearing: bearing,
      halfAngle: halfAngle,
    ).take(maxTargets)) {
      if (breakChest(index)) broken++;
    }
    return broken;
  }

  void dropGear(Gear gear, ui.Offset at) {
    final item = GroundLoot(this, gear, at);
    if (loot.length >= 32) {
      loot.first.removeFromParent();
      loot.removeAt(0);
    }
    loot.add(item);
    game?.add(item);
  }

  void syncLife() {
    hero.life.initial(progress.maxHp);
    hero.life.update(progress.hp);
  }

  bool learn(SkillDef skill) {
    if (defeated || disposed || !progress.learn(skill)) return false;
    syncLife();
    refresh();
    return true;
  }

  bool resetSkills() {
    if (!ready || defeated || disposed || !progress.resetSkills()) return false;
    buildRevision++;
    releaseInput();
    hero.armorTime = hero.frenzyTime = hero.spin = 0;
    hero.cancelSprint();
    hero.impactHold = 0;
    hero.chargeTime = hero.heavyWindup = hero.swing = 0;
    hero.heavySkill = null;
    hero.chargeVictims.clear();
    syncLife();
    refresh();
    return true;
  }

  bool equip(Gear item) {
    if (defeated || disposed || !progress.equip(item)) return false;
    syncLife();
    refresh();
    return true;
  }

  void potion({bool energy = false}) {
    if (!active) return;
    if (energy) {
      if (progress.energyPotions <= 0 ||
          progress.energy >= progress.maxEnergy) {
        return;
      }
      final restored = math.min(
        CombatBalance.potionEnergy,
        progress.maxEnergy - progress.energy,
      );
      progress.energyPotions--;
      progress.energy = math.min(
        progress.maxEnergy,
        progress.energy + CombatBalance.potionEnergy,
      );
      bubble(
        '+${restored.ceil()} ${progress.heroClass.resource}',
        hero.body.center - const ui.Offset(0, 80),
        const ui.Color(0xff9fdfff),
      );
    } else {
      if (progress.healingPotions <= 0 || progress.hp >= progress.maxHp) return;
      final restored = math.min(
        CombatBalance.potionHealing,
        progress.maxHp - progress.hp,
      );
      progress.healingPotions--;
      progress.hp = math.min(
        progress.maxHp,
        progress.hp + CombatBalance.potionHealing,
      );
      syncLife();
      bubble(
        '+${restored.ceil()} 생명',
        hero.body.center - const ui.Offset(0, 80),
        const ui.Color(0xffffb6a0),
      );
    }
    refresh();
  }

  HuntEnemy? get nearbyBoss {
    for (final mob in mobs) {
      if (mob.boss &&
          !mob.isDead &&
          !mob.isRemoving &&
          (mob.body.center - hero.body.center).distance < 1300) {
        return mob;
      }
    }
    return null;
  }

  int get living => mobs
      .where((m) => !m.isDead && !m.isRemoving && !m.encounterDormant)
      .length;
  void holdAttack(String source, bool held) {
    if (held && active) {
      attackSources.add(source);
    } else {
      attackSources.remove(source);
    }
  }

  void releaseInput() {
    hero.aim = null;
    hero.queuedCast = null;
    attackSources.clear();
    hero.onJoystickChangeDirectional(
      JoystickDirectionalEvent(directional: JoystickMoveDirectional.IDLE),
    );
    hero.stop();
  }

  void pause() {
    combatFeedback.cancel();
    audio.stop();
    device.cancel();
    releaseInput();
    paused = true;
    game?.pauseEngine();
    refresh();
  }

  void resume() {
    if (defeated || won) return;
    paused = false;
    game?.resumeEngine();
    refresh();
  }

  void refresh() {
    if (!disposed) notifyListeners();
  }

  void start(BonfireGameInterface ref) {
    if (ready || disposed) return;
    game = ref;
    ready = true;
    for (final mob in List<HuntEnemy>.of(mobs)) {
      ref.add(mob);
    }
    for (final item in List<GroundLoot>.of(loot)) {
      ref.add(item);
    }
    for (final area in encounterAreas.values) {
      ref.add(EncounterStone(this, area));
    }
    wakeEnemies();
    waveTime = sheltered ? 0 : 10;
    if (!restoredEncounters) {
      spawnPack(
        initial: (hero.position.toOffset() - world.spawn).distance < 220,
      );
    }
    refresh();
  }

  void tick(double dt) {
    if (!active || dt <= 0) return;
    // Wards cleanse afflictions; elsewhere poison resolves before any healing.
    if (sheltered) afflictions.clear();
    final poisonTicks = afflictions.update(dt);
    for (var i = 0; i < poisonTicks && active; i++) {
      hurtHero(2 * afflictions.poisonPotency, periodic: true);
    }
    if (!active) return;
    impactTime = math.max(0, impactTime - dt);
    if (impactTime == 0) impactStrength = 0;
    elapsed += dt;
    noticeTime = math.max(0, noticeTime - dt);
    combatTime = math.max(0, combatTime - dt);
    progress.energy =
        (progress.energy +
                dt *
                    (progress.heroClass == HeroClass.mage
                        ? progress.manaRecovery
                        : combatTime > 0
                        ? 0
                        : -1))
            .clamp(0, progress.maxEnergy);
    for (final item in List<GroundLoot>.of(loot)) {
      item.tryCollect();
    }
    waveTime -= dt;
    if (sheltered) waveTime = 0;
    notifyTime -= dt;
    if (notifyTime <= 0) {
      notifyTime = .1;
      refresh();
    }
    // Exploration packs are recycled without rewards; bosses remain until defeated.
    for (final mob in List<HuntEnemy>.of(mobs)) {
      if (mob.combatReady &&
          !mob.isDead &&
          !mob.isRemoving &&
          !mob.encounterDormant &&
          !mob.boss &&
          (mob.position - hero.position).length > 1500) {
        dormantEnemies.add(saveEnemy(mob));
        mob.combatReady = false;
        mob.encounterDormant = true;
        mob.removeFromParent();
      }
    }
    wakeEnemies();
    if ((hero.position.toOffset() - lastPack).distance > 540) {
      waveTime = math.min(waveTime, 3);
      lastPack = hero.position.toOffset();
    }
    if (!sheltered && waveTime <= 0 && elapsed - lastPackSpawn >= 8) {
      spawnPack();
      waveTime = 10;
    }
    if (stageKills >= world.stage.killGoal &&
        mandatoryQuestsComplete &&
        !bossSummoned &&
        !progress.bossDefeated &&
        elapsed >= _nextBossSpawn) {
      _nextBossSpawn = elapsed + 1;
      final boss = spawnEnemy(
        'golem',
        hero.position.toOffset() + const ui.Offset(0, -310),
        boss: true,
      );
      if (boss != null) bossSummoned = true;
      if (boss != null) {
        bubble(
          '${world.stage.bossName} 출현',
          hero.position.toOffset() - const ui.Offset(0, 85),
          const ui.Color(0xffffd176),
        );
      }
    }
    // The fountain sanctuary heals gradually, never after a fatal hit.
    if (progress.hp > 0 &&
        combatTime <= 0 &&
        (hero.position.toOffset() - world.healAt).distance < 150) {
      progress.hp = math.min(progress.maxHp, progress.hp + dt * 4);
      hero.life.update(progress.hp);
    }
  }

  void spawnPack({bool initial = false}) {
    if (!combatAllowed ||
        living >= CombatBalance.maxActiveEnemies ||
        riding?.def.waterOnly == true) {
      return;
    }
    initial =
        initial ||
        (_successfulPacks == 0 &&
            progress.kills == 0 &&
            world.stage == WorldStage.forest);
    final at = hero.position.toOffset();
    final key = encounterKey;
    final existingArea = encounterAreas[key];
    if (existingArea != null && existingArea.waves >= EncounterArea.waveLimit) {
      return;
    }
    // Wake existing packs before spending another wave in this region.
    if (dormantEnemies.any((e) => e['area'] == key)) return;
    if (world.settlement.contains(at) &&
        at.dy < world.spawn.dy - 30 &&
        !initial) {
      return;
    }
    final count = math.min(
      CombatBalance.packSize(
        initial: initial,
        playerLevel: progress.level,
        living: living,
      ),
      CombatBalance.maxActiveEnemies - living,
    );
    final elitePack =
        !initial &&
        progress.kills >= 18 &&
        progress.level >= 3 &&
        _successfulPacks % 3 == 0 &&
        !mobs.any((m) => m.isElite && !m.isDead && !m.isRemoving);
    final eliteSlot = (_successfulPacks ~/ 3) % count;
    final population = biomeEnemies(
      world.stage,
      sand: world.isSand(at),
      wooded: world.isWooded(at),
      ruins: world.stage == WorldStage.sands
          ? world.sites.any((q) => (q.at - at).distance < 1300)
          : (at - world.spawn).distance > 900 &&
                world.clearings.any((c) => c.contains(at)),
    );
    var added = 0;
    for (var i = 0; i < 48 && added < count; i++) {
      final angle = hero.bearing + (i < 3 ? [0.0, 1.0, -1.0][i] : i * 2.4),
          r = 280.0 + (i % 5) * 38;
      final desired = initial
          ? at +
                ui.Offset(
                      math.cos(hero.bearing + const [-.55, 0.0, .55][i % 3]),
                      math.sin(hero.bearing + const [-.55, 0.0, .55][i % 3]),
                    ) *
                    (190 + (i % 2) * 55)
          : at + ui.Offset(math.cos(angle) * r, math.sin(angle) * r);
      final kind = initial && world.stage == WorldStage.forest
          ? ['goblin', 'wolf', 'goblin'][i % 3]
          : population[(i + progress.level) % population.length];
      final trait = elitePack && added == eliteSlot
          ? ((_successfulPacks ~/ 3).isEven
                ? EnemyTrait.armored
                : EnemyTrait.swift)
          : EnemyTrait.none;
      final unique =
          trait != EnemyTrait.none &&
          progress.kills >= 60 &&
          progress.level >= 4 &&
          (_successfulPacks ~/ 3) % 3 == 2;
      final mob = spawnEnemy(
        kind,
        desired,
        trait: trait,
        tier: unique ? EnemyTier.unique : null,
      );
      if (mob != null) {
        mob.encounterKey = key;
        added++;
      }
    }
    if (added > 0) {
      final area = existingArea ?? EncounterArea(key, hero.body.center);
      if (existingArea == null) {
        encounterAreas[key] = area;
        game?.add(EncounterStone(this, area));
      }
      area.waves++;
      _successfulPacks++;
      lastPackSpawn = elapsed;
    }
  }

  final enemySpacing = EnemySpacing<HuntEnemy>();
  double _enemySpacingTime = -1;
  int _enemySpacingCount = -1;

  void _syncEnemySpacing(HuntEnemy mover) {
    if (_enemySpacingTime == elapsed &&
        _enemySpacingCount == mobs.length &&
        enemySpacing.contains(mover)) {
      return;
    }
    enemySpacing.clear();
    for (final enemy in mobs) {
      if (!enemy.isDead && !enemy.isRemoving && !enemy.encounterDormant) {
        enemySpacing.update(
          enemy,
          enemy.body,
          personalSpace: enemy.personalSpace,
        );
      }
    }
    _enemySpacingTime = elapsed;
    _enemySpacingCount = mobs.length;
  }

  void updateEnemySpacing(HuntEnemy enemy) {
    if (enemy.isDead || enemy.isRemoving || enemy.encounterDormant) {
      enemySpacing.remove(enemy);
    } else {
      enemySpacing.update(
        enemy,
        enemy.body,
        personalSpace: enemy.personalSpace,
      );
    }
  }

  ui.Offset moveEnemyBody(
    HuntEnemy mover,
    ui.Offset from,
    ui.Offset delta, {
    bool steer = false,
    bool avoidHero = true,
    bool personalSpace = false,
  }) {
    if (delta.distanceSquared < .000001) return from;
    _syncEnemySpacing(mover);
    final size = mover.body.size, original = from & size;
    final search = original.expandToInclude(original.shift(delta)).inflate(64);
    final neighbors = enemySpacing
        .query(search)
        .where(
          (other) =>
              other != mover &&
              !other.isDead &&
              !other.isRemoving &&
              !other.encounterDormant,
        )
        .toList(growable: false);
    final hasOverlap = neighbors.any(
      (other) => original.overlaps(enemySpacing.bodyOf(other)),
    );
    final enforceSpace = (steer || personalSpace) && !hasOverlap;
    final heroBody = hero.body;
    final heroInWay = avoidHero && search.overlaps(heroBody);
    final storedPosition = Vector2.zero();
    ui.Offset stored(ui.Offset at) {
      // Validate Bonfire's actual Float32 endpoint while preserving the double
      // accumulator between geometric substeps. Only the final result is stored.
      storedPosition.setValues(at.dx, at.dy);
      return storedPosition.toOffset();
    }

    if (neighbors.isEmpty && !heroInWay) {
      final next = stored(world.moveEnemy(from, delta, size));
      if (!world.blocksEnemy(next & size)) return next;
    }
    if (steer) delta = enemySpacing.steer(mover, original, delta, neighbors);
    final steps = math.max(1, (delta.distance / 6).ceil());
    final step = delta / steps.toDouble();
    var at = from;
    bool permits(ui.Offset before, ui.Offset after) {
      final beforeBody = stored(before) & size,
          afterBody = stored(after) & size;
      if (world.blocksEnemy(afterBody)) return false;
      if (heroInWay && !EnemySpacing.permits(beforeBody, afterBody, heroBody)) {
        return false;
      }
      for (final other in neighbors) {
        if (!EnemySpacing.permits(
              beforeBody,
              afterBody,
              enemySpacing.bodyOf(other),
            ) ||
            enforceSpace &&
                !enemySpacing.permitsPersonalSpace(
                  mover,
                  beforeBody,
                  afterBody,
                  other,
                )) {
          return false;
        }
      }
      return true;
    }

    for (var i = 0; i < steps; i++) {
      final next = world.moveEnemy(at, step, size);
      if (permits(at, next)) {
        at = next;
        continue;
      }
      final before = at;
      if (step.dx.abs() > .0001) {
        final horizontal = world.moveEnemy(at, ui.Offset(step.dx, 0), size);
        if (permits(at, horizontal)) at = horizontal;
      }
      if (step.dy.abs() > .0001) {
        final vertical = world.moveEnemy(at, ui.Offset(0, step.dy), size);
        if (permits(at, vertical)) at = vertical;
      }
      if (steer && (at - before).distanceSquared < .0001) {
        final side = enemySpacing.preferredSide(mover);
        for (var turn = 0; turn < 4; turn++) {
          final sign = turn.isEven ? side : -side;
          final flank = turn < 2
              ? ui.Offset(step.dx - step.dy * sign, step.dy + step.dx * sign) *
                    .7071067811865476
              : ui.Offset(-step.dy * sign, step.dx * sign);
          final alternative = world.moveEnemy(at, flank, size);
          if ((alternative - at).distanceSquared > .0001 &&
              permits(at, alternative)) {
            at = alternative;
            break;
          }
        }
      }
    }
    return stored(at);
  }

  void settleEnemy(HuntEnemy mover, double dt) {
    _syncEnemySpacing(mover);
    final from = mover.body.topLeft;
    final neighbors = enemySpacing
        .query(mover.body.inflate(64))
        .where(
          (other) =>
              other != mover &&
              !other.isDead &&
              !other.isRemoving &&
              !other.encounterDormant,
        )
        .toList(growable: false);
    final hasOverlap = neighbors.any(
      (other) => mover.body.overlaps(enemySpacing.bodyOf(other)),
    );
    var nudge = enemySpacing.separation(mover, mover.body, neighbors, 46 * dt);
    final away = mover.body.center - hero.body.center;
    if (mover.body.overlaps(hero.body)) {
      final direction = away.distanceSquared > .001
          ? away / away.distance
          : ui.Offset(0, enemySpacing.preferredSide(mover));
      nudge += direction * (46 * dt);
    } else if (!hasOverlap &&
        nudge.distanceSquared > .000001 &&
        away.distanceSquared > 1 &&
        away.distance <= mover.idleRange) {
      // Attacking rows spread around the hero instead of repeatedly stepping
      // out of range and lunging inward again.
      final tangent = ui.Offset(-away.dy, away.dx) / away.distance;
      var along = nudge.dx * tangent.dx + nudge.dy * tangent.dy;
      if (along.abs() < nudge.distance * .15) {
        along = nudge.distance * enemySpacing.preferredSide(mover);
      }
      final relative = away + tangent * along;
      nudge = relative / relative.distance * away.distance - away;
    }
    if (nudge.distanceSquared < .000001) return;
    final at = moveEnemyBody(mover, from, nudge, personalSpace: true);
    mover.position.setValues(at.dx, at.dy);
    updateEnemySpacing(mover);
    mover.lastClearPosition = at;
  }

  HuntEnemy? spawnEnemy(
    String kind,
    ui.Offset desired, {
    bool boss = false,
    EnemyTrait trait = EnemyTrait.none,
    EnemyTier? tier,
    EnemyPower? power,
  }) {
    final size = boss ? const ui.Size(48, 40) : const ui.Size(24, 22);
    final storedPosition = Vector2.zero();
    final p = world.spawnNear(
      desired,
      size,
      avoidSanctuary: true,
      occupied: (body) {
        storedPosition.setValues(body.left, body.top);
        final storedBody = ui.Rect.fromLTWH(
          storedPosition.x,
          storedPosition.y,
          body.width,
          body.height,
        );
        return world.blocksEnemy(storedBody) ||
            storedBody.overlaps(hero.body) ||
            mobs.any(
              (enemy) =>
                  !enemy.isDead &&
                  !enemy.isRemoving &&
                  !enemy.encounterDormant &&
                  enemy.body.overlaps(storedBody),
            );
      },
    );
    if (p == null) return null;
    final enemy = HuntEnemy(
      this,
      kind,
      p,
      boss: boss,
      trait: boss ? EnemyTrait.none : trait,
      tier: tier,
      power: power,
    );
    enemy.life.initial(
      enemy.life.max *
          2 *
          (1 + (progress.level - 1) * (boss ? .15 : .08)) *
          enemy.power.healthMultiplier,
    );
    mobs.add(enemy);
    game?.add(enemy);
    return enemy;
  }

  void bubble(String text, ui.Offset at, ui.Color color) {
    final next = BattleText(this, text, at, color);
    final same = texts.where((t) => t.isReward == next.isReward).toList();
    final limit = next.isReward ? 2 : 14;
    if (same.length >= limit) {
      same.first.releaseText();
      same.first.removeFromParent();
      texts.remove(same.first);
    }
    if (!next.isReward) {
      while (!next.placeWithoutOverlap(at, texts)) {
        final oldest = texts.firstWhere((t) => !t.isReward);
        oldest.releaseText();
        oldest.removeFromParent();
        texts.remove(oldest);
      }
    }
    texts.add(next);
    game?.add(next);
  }

  void hurtHero(
    double damage, {
    ui.Offset? origin,
    PlayerStatus? status,
    double statusPotency = 1,
    bool periodic = false,
    bool dispel = false,
  }) {
    if (!combatAllowed ||
        !periodic && hero.invulnerable > 0 ||
        origin != null && world.sanctuary.blocksRay(origin, hero.body.center)) {
      return;
    }
    combatTime = 5;
    damage = progress.mitigate(damage, protection: hero.protection);
    if (progress.hasGift(WeaponGift.guardian)) damage *= .92;
    if (!periodic &&
        hero.armorTime > 0 &&
        progress.heroClass == HeroClass.mage) {
      for (final mob in mobs.where(
        (m) => (m.body.center - hero.body.center).distance < 85,
      )) {
        mob.slow = math.max(mob.slow, 2);
      }
    }
    if (!periodic && progress.heroClass == HeroClass.warrior) {
      progress.energy = math.min(
        progress.maxEnergy,
        progress.energy + CombatBalance.rageOnDamage,
      );
    }
    if (!periodic) {
      audio.play(EffectSound.hurt);
      device.pulse(FeedbackKind.hurt);
      wearMount(math.max(1, damage * .6));
    }
    progress.hp = math.max(0, progress.hp - damage);
    if (damage > 0 && (!periodic || progress.hp <= 0)) hero.cancelSprint();
    hero.life.remove(damage);
    if (progress.hp > 0 &&
        dispel &&
        (hero.armorTime > 0 || hero.frenzyTime > 0)) {
      hero.armorTime = hero.frenzyTime = 0;
      bubble(
        '강화 해제',
        hero.body.center - const ui.Offset(0, 90),
        const ui.Color(0xffef92d8),
      );
    }
    if (!periodic) {
      hero.invulnerable = .65;
      hero.hurtFlash = .12;
    }
    if (progress.hp > 0 &&
        status != null &&
        afflictions.apply(status, potency: statusPotency)) {
      hero.interruptFor(status);
    }
    bubble(
      '-${damage.toInt()}',
      hero.position.toOffset() - const ui.Offset(0, 65),
      const ui.Color(0xffff8a72),
    );
    if (progress.hp <= 0) {
      defeated = true;
      combatFeedback.cancel();
      audio.stop();
      releaseInput();
      game?.pauseEngine();
    }
    refresh();
  }

  bool canHitEnemy(HuntEnemy mob, {ui.Offset? origin}) =>
      combatAllowed &&
      mob.combatReady &&
      !mob.isDead &&
      !mob.isRemoving &&
      !world.sanctuary.protects(mob.body) &&
      !world.sanctuary.blocksRay(hero.body.center, mob.body.center) &&
      !world.sanctuary.blocksRay(origin ?? hero.body.center, mob.body.center);

  bool hit(
    HuntEnemy mob,
    double damage,
    ui.Offset impulse, {
    bool generateRage = false,
    ui.Offset? origin,
    ImpactKind? impactKind,
    int? impactRank,
  }) {
    if (!damage.isFinite || damage <= 0 || !canHitEnemy(mob, origin: origin)) {
      return false;
    }
    combatTime = 5;
    damage *= mob.wardActive ? .65 : 1;
    final healthBefore = mob.life.value / mob.life.max;
    mob.life.remove(damage);
    mob.damageTrail.damage(healthBefore, mob.life.value / mob.life.max);
    final heavy =
        progress.weapon.base.style == 'hammer' ||
        combo == 0 ||
        progress.selectedBasic == 'heavyStrike';
    combatFeedback.accepted(
      AcceptedImpact(
        mob.body.center - const ui.Offset(0, 28),
        math.atan2(impulse.dy, impulse.dx),
        impactKind ??
            (progress.heroClass == HeroClass.mage
                ? ImpactKind.magic
                : generateRage && heavy
                ? ImpactKind.heavy
                : ImpactKind.melee),
        rank:
            impactRank ??
            (generateRage ? progress.rank(progress.selectedBasic) : 1),
      ),
    );
    if (progress.hasGift(WeaponGift.frost) && !mob.isDead) {
      mob.slow = math.max(mob.slow, .8);
    }
    if (generateRage &&
        progress.heroClass == HeroClass.warrior &&
        rageStrike != hero.strikes) {
      rageStrike = hero.strikes;
      // Pin the contact phase, not a fixed remaining duration: slow/heavy
      // attacks must keep the same follow-through when their tempo changes.
      hero.swing = math.min(hero.swing, hero.swingDuration * .5);
      kickCamera(heavy ? 2.1 : .95);
      progress.energy = math.min(
        progress.maxEnergy,
        progress.energy + progress.rageOnHit(protected: hero.armorTime > 0),
      );
    }
    audio.play(EffectSound.impact);
    device.pulse(mob.isDead ? FeedbackKind.kill : FeedbackKind.hit);
    mob.impactPose = mob.motion.phase;
    mob.motion.hit(impulse);
    mob.hurt = .14;
    mob.push(impulse);
    bubble(
      '${damage.round()}',
      mob.position.toOffset() - ui.Offset(0, mob.boss ? 125 : 70),
      const ui.Color(0xffffedb4),
    );
    if (mob.isDead && !mob.rewarded) {
      mob.rewarded = true;
      final level = progress.level, goldBefore = progress.gold;
      progress.reward(boss: mob.boss, elite: mob.isElite, unique: mob.isUnique);
      if (progress.hasGift(WeaponGift.renewal) && progress.hp > 0) {
        progress.hp = math.min(progress.maxHp, progress.hp + 4);
      }
      syncLife();
      if (progress.level > level) {
        bubble(
          'Lv.${progress.level}',
          hero.body.center - const ui.Offset(0, 85),
          const ui.Color(0xffffe4a1),
        );
        game?.add(
          RuneBurst(
            this,
            hero.body.center,
            const ui.Color(0xffffcf81),
            radius: 65,
          ),
        );
      }
      if (mob.boss ||
          mob.isElite ||
          progress.kills % ordinaryGearInterval == 0) {
        dropGear(
          progress.rollLoot(
            random,
            boss: mob.boss,
            elite: mob.isElite,
            unique: mob.isUnique,
          ),
          mob.body.center,
        );
      }
      if (mob.boss && world.stage == WorldStage.forest) {
        dropGear(
          progress.createGear(
            gearById('sentinel'),
            rarity: Rarity.unique,
            power: 3,
            vitality: 10,
          ),
          mob.body.center + const ui.Offset(28, 12),
        );
      }
      bubble(
        '+${progress.gold - goldBefore} 골드',
        mob.position.toOffset() - const ui.Offset(0, 34),
        const ui.Color(0xffffd774),
      );
      mob.removeFromParent();
      if (mob.boss) {
        completeStageIfReady();
      }
      refresh();
    }
    return true;
  }

  bool get canTrade => ready && !disposed && !defeated && progress.hp > 0;
  bool get canSmith => canTrade && nearbyBlacksmith;
  SmithQuote? smithQuote(Gear item) =>
      canSmith ? progress.smithQuote(item) : null;
  SmithResult? enhanceWeapon(SmithQuote quote) {
    if (!canSmith) return null;
    final result = progress.enhanceWeapon(quote, random);
    if (result != null) {
      syncLife();
      refresh();
    }
    return result;
  }

  bool buyHeal() =>
      canTrade &&
      progress.buy(
        CombatBalance.healingPotionPrice,
        () => progress.healingPotions += CombatBalance.potionBundleSize,
      );
  ShopGearOffer gearOffer(GearDef def) =>
      ShopGearOffer(def, world.stage, acquiredLevel: progress.level);
  Iterable<ShopGearOffer> get shopGearOffers =>
      progress.shopGear.map(gearOffer);
  Gear? buyGear(GearDef def, {int? expectedPrice}) {
    if (!canTrade ||
        !progress.shopGear.contains(def) ||
        !def.usable(progress.heroClass) ||
        progress.inventory.length >= Progress.capacity) {
      return null;
    }
    final offer = gearOffer(def);
    if (expectedPrice != null && expectedPrice != offer.price) return null;
    Gear? bought;
    progress.buy(offer.price, () {
      bought = offer.create(progress);
      progress.addOwnedGear(bought!);
      if (progress.isEquipped(bought!)) syncLife();
    });
    return bought;
  }

  bool buyEnergy() =>
      canTrade &&
      progress.buy(
        CombatBalance.resourcePotionPrice,
        () => progress.energyPotions += CombatBalance.potionBundleSize,
      );
  bool buySword({int? expectedPrice}) {
    final cost = progress.attackTrainingCost;
    if (!canTrade ||
        !progress.canTrainAttack ||
        expectedPrice != null && expectedPrice != cost) {
      return false;
    }
    return progress.buy(
      cost,
      () => progress.bonusAttack += Progress.attackTrainingPower,
    );
  }

  bool buyVitality({int? expectedPrice}) {
    final cost = progress.vitalityTrainingCost;
    if (!canTrade ||
        !progress.canTrainVitality ||
        expectedPrice != null && expectedPrice != cost) {
      return false;
    }
    return progress.buy(cost, () {
      progress.bonusHealth += 20;
      progress.hp = progress.maxHp;
      syncLife();
    });
  }

  @override
  void dispose() {
    combatFeedback.dispose();
    disposed = true;
    for (final text in texts) {
      text.releaseText();
    }
    for (final stone in _encounterStones) {
      stone.releaseHint();
    }
    _encounterStones.clear();
    for (final chest in _chests) {
      chest.releasePictures();
    }
    _chests.clear();
    audio.stop();
    device.cancel();
    releaseInput();
    terrain.dispose();
    super.dispose();
  }
}

class Guardian extends Player with WithCollision {
  static const onFootSize = ui.Size(28, 24);
  Guardian(this.session)
    : super(
        position: Vector2(session.world.spawn.dx, session.world.spawn.dy),
        size: Vector2(onFootSize.width, onFootSize.height),
        speed: CombatBalance.normalMoveSpeed,
        life: session.progress.maxHp,
      ) {
    setupMovementByJoystick(
      moveType: MovementByJoystickType.angle,
      intensityEnabled: true,
    );
  }
  final Adventure session;
  SkillAim? aim;
  ({int slot, String id, SkillAim? aim})? queuedCast;
  void beginAim(int slot) {
    if (session.afflictions.frozen) return;
    final def = session.progress.skillAt(slot);
    if (!session.combatAllowed ||
        dashing > 0 ||
        physicalAction ||
        def == null ||
        session.progress.rank(def.id) == 0 ||
        (cooldowns[def.id] ?? 0) > 0) {
      return;
    }
    if (def.id == 'charge' && session.afflictions.movementBlocked) return;
    if (!_hasSkillResource(def) || !session.ensureOnFoot()) return;
    queuedCast = null;
    aim = SkillAim(slot, def.id, bearing);
  }

  void moveAim(ui.Offset delta, {int? ownerSlot}) {
    if (ownerSlot != null && aim?.slot != ownerSlot) return;
    if (!session.active) {
      aim = null;
      return;
    }
    aim?.delta = delta;
  }

  void finishAim(bool cancelled, {int? ownerSlot}) {
    if (ownerSlot != null && aim?.slot != ownerSlot) return;
    final current = aim;
    aim = null;
    if (current == null ||
        cancelled ||
        current.cancelled ||
        session.progress.skillAt(current.slot)?.id != current.id) {
      return;
    }
    skill(
      slot: current.slot,
      manualAim: current.dragged || current.id == 'crushingBlow'
          ? current
          : null,
    );
  }

  ui.Offset aimedImpact(double angle, double distance) =>
      session.world.move(
        body.center - const ui.Offset(3, 3),
        ui.Offset(math.cos(angle), math.sin(angle)) * distance,
        const ui.Size(6, 6),
        avoidSanctuary: true,
      ) +
      const ui.Offset(3, 3);
  ui.Offset meteorAimImpact(SkillAim current) => aimedImpact(
    current.angle,
    current.distanceWithin(
      session.viewportSize,
      cameraOffsetY: session.cameraOffsetY,
      screenOrigin: hasGameRef
          ? gameRef.camera
                .worldToScreen(Vector2(body.center.dx, body.center.dy))
                .toOffset()
          : null,
    ),
  );
  void interruptFor(PlayerStatus status) {
    if (status == PlayerStatus.root || status == PlayerStatus.freeze) {
      chargeTime = dashing = 0;
      cancelSprint();
    }
    if (status == PlayerStatus.freeze) {
      aim = null;
      queuedCast = null;
      heavyWindup = swing = 0;
      heavySkill = null;
    }
  }

  double rollBearing = math.pi / 2;
  final runMotion = RunMotion();
  bool movingThisFrame = false;
  double bearing = math.pi / 2,
      animationTime = 0,
      attackClock = 0,
      swing = 0,
      spin = 0,
      dodgeClock = 0,
      dashing = 0,
      invulnerable = 0,
      hurtFlash = 0;
  final cooldowns = <String, double>{};
  double armorTime = 0, frenzyTime = 0;
  double _mobilityClock = 0;
  double get mobilityClock => _mobilityClock;
  double sprintTime = 0;

  void cancelSprint() => sprintTime = 0;

  void restoreMobility(double remainingCooldown, double remainingSprint) {
    final p = session.progress;
    final maximum = p.skillCooldown(p.mobilitySkill, atRank: 1);
    _mobilityClock = remainingCooldown.isFinite
        ? remainingCooldown.clamp(0, maximum)
        : 0;
    sprintTime =
        p.heroClass == HeroClass.warrior &&
            p.rank(p.mobilitySkill.id) > 0 &&
            session.riding == null &&
            !session.afflictions.movementBlocked &&
            remainingSprint.isFinite
        ? remainingSprint.clamp(0, math.min(p.mobilityDuration, _mobilityClock))
        : 0;
  }

  bool useMobility() {
    final p = session.progress, def = session.progress.mobilitySkill;
    if (!session.active ||
        session.afflictions.movementBlocked ||
        p.level < def.requiredLevel ||
        p.rank(def.id) <= 0 ||
        _mobilityClock > 0 ||
        dashing > 0 ||
        physicalAction ||
        !session.ensureOnFoot()) {
      return false;
    }
    final before = position.toOffset();
    ui.Offset? landing;
    if (p.heroClass == HeroClass.mage) {
      landing = blinkLanding(
        session.world,
        before,
        body.size,
        bearing,
        p.mobilityRange,
        occupied: (candidate) => session.mobs.any(
          (m) =>
              !m.isDead &&
              !m.isRemoving &&
              !m.encounterDormant &&
              m.body.overlaps(candidate),
        ),
      );
      if (landing == null) return false;
    }
    aim = null;
    queuedCast = null;
    chargeTime = heavyWindup = spin = swing = dashing = impactHold = castLock =
        0;
    heavySkill = null;
    chargeVictims.clear();
    chargeChests.clear();
    if (landing != null) stop();
    _mobilityClock = p.mobilityCooldown;
    final origin = body.center;
    if (landing == null) {
      sprintTime = p.mobilityDuration;
      session.game?.add(
        MobilityVisual(session, origin, origin, sprinting: true),
      );
    } else {
      position.setValues(landing.dx, landing.dy);
      lastClearPosition = landing;
      movingThisFrame = false;
      attackBearing = bearing;
      strikePose = 0;
      swingDuration = p.skillMotionTime(def);
      swing = swingDuration;
      if (hasGameRef) gameRef.camera.position = session.cameraFocus;
      session.game?.add(MobilityVisual(session, origin, body.center));
    }
    session.audio.play(EffectSound.dodge);
    session.device.pulse(FeedbackKind.dodge);
    session.refresh();
    return true;
  }

  double impactHold = 0;
  double swingDuration = .23, castLock = 0, comboGrace = 0;
  int strikePose = 0;
  double chargeTime = 0, chargeAngle = 0, chargeDamage = 0, chargeSpeed = 900;
  double spinDuration = .5;
  int chargeCap = 0;
  final chargeVictims = <HuntEnemy>{};
  final chargeChests = <int>{};
  double heavyWindup = 0, heavyPower = 0, heavyAngle = 0, heavyCharge = 0;
  final _heavyChargeArt = CrushingChargeArt();
  SkillDef? heavySkill;
  bool get physicalAction => chargeTime > 0 || heavyWindup > 0 || spin > 0;
  void heavyImpact() {
    final def = heavySkill;
    heavySkill = null;
    if (def == null || !session.active) return;
    final enemies =
        session.mobs.where((m) {
          final d = m.body.center - body.center;
          return session.canHitEnemy(m) &&
              d.distance < crushingBlowRange &&
              math
                      .atan2(
                        math.sin(math.atan2(d.dy, d.dx) - heavyAngle),
                        math.cos(math.atan2(d.dy, d.dx) - heavyAngle),
                      )
                      .abs() <
                  crushingBlowHalfAngle &&
              session.world.clearLine(
                body.center,
                m.body.center,
                const ui.Size(3, 3),
              );
        }).toList()..sort(
          (a, b) => (a.body.center - body.center).distance.compareTo(
            (b.body.center - body.center).distance,
          ),
        );
    final selected = enemies
        .take(session.progress.skillTargetLimit(def))
        .toList();
    final multiplier = enemyGroupDamageScale(selected.length);
    for (final mob in selected) {
      if (!session.canHitEnemy(mob)) continue;
      session.hit(
        mob,
        heavyPower * multiplier,
        ui.Offset(math.cos(heavyAngle), math.sin(heavyAngle)) * 48,
        impactKind: ImpactKind.heavy,
        impactRank: session.progress.rank('crushingBlow'),
      );
      mob.applyStun(.55);
    }
    session.strikeChests(
      body.center,
      crushingBlowRange,
      bearing: heavyAngle,
      halfAngle: crushingBlowHalfAngle,
      maxTargets: session.progress.skillTargetLimit(def) - selected.length,
    );
    session.game?.add(
      CrushingBlowVisual(
        session,
        body.center,
        rank: session.progress.rank('crushingBlow'),
        charge: heavyCharge,
        tempo: session.progress.skillTempo(def),
        bearing: heavyAngle,
      ),
    );
    session.audio.play(EffectSound.impact);
    session.device.pulse(FeedbackKind.hit);
    session.kickCamera(enemies.isEmpty ? .3 : 2.4);
    attackBearing = heavyAngle;
    strikePose = 2;
    swingDuration = .36 / session.progress.skillTempo(def);
    swing = .18 / session.progress.skillTempo(def);
    impactHold = enemies.isEmpty ? 0 : .06;
  }

  double get effectiveBasicTempo =>
      session.progress.basicTempo * session.afflictions.attackTempo;

  double get skillClock => cooldowns[session.progress.selectedSkill] ?? 0;
  set skillClock(double value) =>
      cooldowns[session.progress.selectedSkill] = value;
  double get protection => armorTime > 0
      ? session.progress.skillProtection(
          session.progress.heroClass == HeroClass.warrior
              ? 'warcry'
              : 'iceArmor',
        )
      : 0;
  int strikes = 0;
  double attackBearing = math.pi / 2;
  ui.Offset? lastClearPosition;
  ui.Rect get body => ui.Rect.fromLTWH(position.x, position.y, size.x, size.y);
  void resizeBody(ui.Size next, ui.Offset center) {
    size.setValues(next.width, next.height);
    position.setValues(center.dx - next.width / 2, center.dy - next.height / 2);
    for (final box in children.whereType<RectangleHitbox>()) {
      box.size.setFrom(size);
    }
    lastClearPosition = position.toOffset();
    if (hasGameRef) gameRef.camera.position = session.cameraFocus;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (session.disposed || !hasGameRef || isRemoving) return;
    await add(RectangleHitbox(size: size));
    lastClearPosition = position.toOffset();
    collision.onMovementBlockedListener((other, data) {
      if (session.world.blocked(
        body,
        waterOnly: session.riding?.def.waterOnly ?? false,
      )) {
        final safe = lastClearPosition;
        if (safe != null) position.setValues(safe.dx, safe.dy);
      }
      if (hasGameRef) gameRef.camera.position = session.cameraFocus;
    });
  }

  @override
  void onJoystickChangeDirectional(JoystickDirectionalEvent event) {
    if (!session.active && event.directional != JoystickMoveDirectional.IDLE) {
      return;
    }
    if (event.directional != JoystickMoveDirectional.IDLE) {
      bearing = event.isKeyboard ? event.directional.radAngle : event.radAngle;
    } else {
      // Bonfire consumes directional input after integrating old velocity.
      // Release it now even when hitstop prevents a zero-dt input update.
      stop();
    }
    super.onJoystickChangeDirectional(event);
  }

  @override
  void onJoystickAction(JoystickActionEvent event) {
    final held = event.event != ActionEvent.UP;
    if (event.id == LogicalKeyboardKey.space ||
        event.id == LogicalKeyboardKey.keyJ) {
      session.holdAttack('key:${event.id}', held);
    }
    if (held &&
        (event.id == LogicalKeyboardKey.keyK ||
            event.id == LogicalKeyboardKey.keyN)) {
      skill();
    }
    if (held && event.id == LogicalKeyboardKey.keyL) skill(secondary: true);
    if (held && event.id == LogicalKeyboardKey.keyO) skill(slot: 2);
    if (held && event.id == LogicalKeyboardKey.keyP) skill(slot: 3);
    if (held && event.id == LogicalKeyboardKey.shiftLeft) dodge();
    if (held && event.id == LogicalKeyboardKey.keyM) useMobility();
    if (held && event.id == LogicalKeyboardKey.digit1) session.potion();
    if (held && event.id == LogicalKeyboardKey.digit2) {
      session.potion(energy: true);
    }
    super.onJoystickAction(event);
  }

  @override
  void update(double dt) {
    dt = math.min(dt, .05);
    if (!session.active) {
      stop();
      return;
    }
    if (dt <= 0) return;
    if (aim != null) aim!.heldFor += dt;
    final ordinarySpeed = frenzyTime > 0
        ? math.min(session.progress.frenzyMoveSpeed, 155.0)
        : CombatBalance.normalMoveSpeed;
    final sprintFraction = math.min(dt, sprintTime) / dt;
    var unhinderedSpeed =
        session.riding?.speed ??
        ordinarySpeed +
            (CombatBalance.sprintMoveSpeed - ordinarySpeed) * sprintFraction;
    if (castLock > 0) unhinderedSpeed *= .4;
    final previousSpeed = speed;
    speed = unhinderedSpeed * session.afflictions.movementScale;
    // Bonfire integrates old velocity before reading the held joystick again.
    // Apply the speed transition to that velocity so a previous boost cannot
    // leak into the next simulation step.
    if (previousSpeed > 0 && previousSpeed != speed && !velocity.isZero()) {
      velocity = velocity * (speed / previousSpeed);
    }
    final before = position.toOffset();
    super.update(dt);
    var delta = position.toOffset() - before;
    if (heavyWindup > 0) delta = ui.Offset.zero;
    if (chargeTime > 0) {
      delta =
          ui.Offset(math.cos(chargeAngle), math.sin(chargeAngle)) *
          chargeSpeed *
          math.min(dt, chargeTime);
    }
    if (dashing > 0) {
      delta =
          ui.Offset(math.cos(rollBearing), math.sin(rollBearing)) *
          CombatBalance.sprintMoveSpeed *
          1.9 *
          math.min(dt, dashing);
      dashing -= dt;
    }
    if (session.afflictions.movementBlocked) delta = ui.Offset.zero;
    final p = session.world.move(
      before,
      delta,
      ui.Size(size.x, size.y),
      waterOnly: session.riding?.def.waterOnly ?? false,
    );
    position.setValues(p.dx, p.dy);
    session.wearMount((p - before).distance / 350);
    if (chargeTime > 0) {
      chargeTime = math.max(0, chargeTime - dt);
      if ((p - before).distance < delta.distance * .25) chargeTime = 0;
      for (final index in session.attackableChests(
        body.center,
        72,
        bearing: chargeAngle,
        halfAngle: .85,
      )) {
        if (chargeVictims.length + chargeChests.length >= chargeCap) break;
        if (session.breakChest(index)) chargeChests.add(index);
      }
      final swept = ui.Rect.fromPoints(before, p).inflate(42);
      final contacts = session.mobs
          .where(
            (mob) =>
                session.canHitEnemy(mob) &&
                !chargeVictims.contains(mob) &&
                swept.overlaps(mob.body) &&
                session.world.clearLine(
                  body.center,
                  mob.body.center,
                  const ui.Size(3, 3),
                ),
          )
          .take(
            math.max(0, chargeCap - chargeVictims.length - chargeChests.length),
          )
          .toList();
      // Only contacts in this simulation step share damage. Later contacts do
      // not retroactively change damage already dealt by this moving attack.
      final multiplier = enemyGroupDamageScale(contacts.length);
      for (final mob in contacts) {
        chargeVictims.add(mob);
        if (!session.hit(
          mob,
          chargeDamage * multiplier,
          ui.Offset(math.cos(chargeAngle), math.sin(chargeAngle)) * 45,
          impactKind: ImpactKind.heavy,
          impactRank: session.progress.rank('charge'),
        )) {
          continue;
        }
        mob.applyStun(.4);
        session.kickCamera(.9);
      }
      if (chargeVictims.length + chargeChests.length >= chargeCap) {
        chargeTime = 0;
      }
      attackBearing = bearing = chargeAngle;
      strikePose = 1;
      swingDuration = .36;
      swing = chargeTime > 0 ? .16 : 0;
    }
    if (heavyWindup > 0) {
      heavyWindup = math.max(0, heavyWindup - dt);
      if (heavyWindup == 0) heavyImpact();
    }
    lastClearPosition = p;
    // Follow the resolved body directly. Bonfire's smoothed follower can overshoot a dash.
    if (hasGameRef) gameRef.camera.position = session.cameraFocus;
    final travelled = p - before;
    final distance = travelled.distance;
    movingThisFrame = distance > 1e-6;
    if (movingThisFrame) {
      runMotion.advance(distance);
      animationTime += distance / math.max(1, speed);
      session.riding?.bearing = math.atan2(travelled.dy, travelled.dx);
    }
    session.riding?.at = body.center;
    attackClock = math.max(0, attackClock - dt);
    castLock = math.max(0, castLock - dt);
    comboGrace = math.max(0, comboGrace - dt);
    final held = math.min(dt, impactHold);
    impactHold = math.max(0, impactHold - dt);
    swing = math.max(0, swing - (dt - held));
    spin = math.max(0, spin - dt);
    for (final id in cooldowns.keys.toList()) {
      cooldowns[id] = math.max(0, cooldowns[id]! - dt);
    }
    armorTime = math.max(0, armorTime - dt);
    frenzyTime = math.max(0, frenzyTime - dt);
    sprintTime = math.max(0, sprintTime - dt);
    _mobilityClock = math.max(0, _mobilityClock - dt);
    if (session.riding != null || session.afflictions.movementBlocked) {
      cancelSprint();
    }
    dodgeClock = math.max(0, dodgeClock - dt);
    invulnerable = math.max(0, invulnerable - dt);
    hurtFlash = math.max(0, hurtFlash - dt);
    final queued = queuedCast;
    if (queued != null && castLock <= 0 && dashing <= 0 && !physicalAction) {
      queuedCast = null;
      if (session.progress.skillAt(queued.slot)?.id == queued.id) {
        skill(slot: queued.slot, manualAim: queued.aim);
      }
    }
    if (session.attackSources.isNotEmpty && attackClock <= 0) slash();
  }

  void slash() {
    final p = session.progress;
    final basic = p.basicSkill;
    final propRange = session.progress.heroClass == HeroClass.mage
        ? 540.0
        : session.progress.weapon.base.range;
    final props = session.attackableChests(body.center, propRange);
    if (!session.active ||
        session.afflictions.frozen ||
        !session.combatAllowed && props.isEmpty ||
        attackClock > 0 ||
        castLock > 0 ||
        dashing > 0 ||
        physicalAction ||
        aim?.id == 'crushingBlow') {
      return;
    }
    if (!session.ensureOnFoot()) return;
    var angle = bearing;
    final candidates =
        session.mobs
            .where(
              (e) =>
                  session.canHitEnemy(e) &&
                  (e.body.center - body.center).distance <
                      (session.progress.heroClass == HeroClass.mage
                          ? 540
                          : 165) &&
                  session.world.clearLine(
                    body.center,
                    e.body.center,
                    const ui.Size(3, 3),
                  ),
            )
            .toList()
          ..sort(
            (a, b) => (a.body.center - body.center).distance.compareTo(
              (b.body.center - body.center).distance,
            ),
          );
    if (candidates.isNotEmpty) {
      final d = candidates.first.body.center - body.center;
      angle = math.atan2(d.dy, d.dx);
      if (velocity.length < 5) bearing = angle;
    }
    if (props.isNotEmpty &&
        (candidates.isEmpty ||
            (session.stageChestLocations[props.first] - body.center)
                    .distanceSquared <
                (candidates.first.body.center - body.center).distanceSquared)) {
      final d = session.stageChestLocations[props.first] - body.center;
      angle = math.atan2(d.dy, d.dx);
      if (velocity.length < 5) bearing = angle;
    }
    attackBearing = angle;
    strikes++;
    if (comboGrace <= 0) session.combo = 0;
    strikePose = basic.id == 'heavyStrike'
        ? 2
        : basic.id == 'quickCut'
        ? strikes % 2
        : session.combo;
    session.combo = basic.id == 'cleave' || p.heroClass == HeroClass.mage
        ? (session.combo + 1) % 3
        : 1;
    attackClock =
        math.max(
          CombatBalance.minimumStrikeInterval,
          session.progress.attackInterval /
              (frenzyTime > 0 ? session.progress.frenzyAttackTempo : 1),
        ) /
        session.afflictions.attackTempo;
    // Slow weapons and attack debuffs must still reach the next combo strike.
    // Once this scheduled attack becomes ready, only a short idle margin remains.
    comboGrace = math.max(1.2, attackClock + .25);
    swingDuration = (strikePose == 2 ? .32 : .26) / effectiveBasicTempo;
    swing = swingDuration;
    if (p.heroClass == HeroClass.mage) {
      castLock = .26 / effectiveBasicTempo;
      swingDuration = swing = .32 / effectiveBasicTempo;
    }
    if (candidates.isEmpty &&
        props.isEmpty &&
        session.strikeEncounterStone(
          p.heroClass == HeroClass.mage ? 300 : p.weapon.base.range,
        )) {
      return;
    }
    session.audio.play(
      p.heroClass == HeroClass.warrior
          ? (p.weapon.base.style == 'hammer'
                ? EffectSound.impact
                : EffectSound.slash)
          : switch (p.basicElement) {
              'ice' => EffectSound.ice,
              'lightning' => EffectSound.lightning,
              _ => EffectSound.fire,
            },
    );
    if (p.heroClass == HeroClass.mage) {
      session.game?.add(
        ArcaneBolt(
          session,
          body.center,
          angle,
          p.basicDamage,
          element: p.basicElement,
          launchDelay: .13 / effectiveBasicTempo,
          rank: p.rank(basic.id),
          caster: this,
          explosive: p.basicTargetLimit > 1,
          targetLimit: p.basicTargetLimit,
          propOnly: session.sheltered,
        ),
      );
      return;
    }

    final melee =
        session.mobs.where((mob) {
          if (!session.canHitEnemy(mob)) return false;
          final d = mob.body.center - body.center;
          final diff = math.atan2(
            math.sin(math.atan2(d.dy, d.dx) - angle),
            math.cos(math.atan2(d.dy, d.dx) - angle),
          );
          return d.distance < p.weapon.base.range + mob.size.x / 2 &&
              diff.abs() <
                  (p.weapon.base.style == 'spear'
                      ? .5
                      : p.weapon.base.style == 'axe'
                      ? 1.5
                      : 1.25) &&
              session.world.clearLine(
                body.center,
                mob.body.center,
                const ui.Size(3, 3),
              );
        }).toList()..sort(
          (a, b) => (a.body.center - body.center).distance.compareTo(
            (b.body.center - body.center).distance,
          ),
        );
    final targets = <({HuntEnemy? mob, int? chest, double distance})>[
      for (final mob in melee)
        (
          mob: mob,
          chest: null,
          distance: (mob.body.center - body.center).distanceSquared,
        ),
      for (final index in session.attackableChests(
        body.center,
        p.weapon.base.range,
        bearing: angle,
        halfAngle: p.weapon.base.style == 'spear'
            ? .5
            : p.weapon.base.style == 'axe'
            ? 1.5
            : 1.25,
      ))
        (
          mob: null,
          chest: index,
          distance: (session.stageChestLocations[index] - body.center)
              .distanceSquared,
        ),
    ]..sort((a, b) => a.distance.compareTo(b.distance));
    final selected = targets.take(p.basicTargetLimit).toList();
    final multiplier = enemyGroupDamageScale(
      selected
          .where((t) => t.mob != null && session.canHitEnemy(t.mob!))
          .length,
    );
    final damage =
        p.basicDamage *
        (basic.id == 'cleave' && session.combo == 0 ? 1.6 : 1) *
        multiplier;
    for (final target in selected) {
      final mob = target.mob;
      if (mob == null) {
        session.breakChest(target.chest!);
        continue;
      }
      final d = mob.body.center - body.center;
      final push = d.distance > 0
          ? d /
                d.distance *
                (basic.id == 'heavyStrike'
                    ? 38
                    : basic.id == 'quickCut'
                    ? 14
                    : p.weapon.base.style == 'hammer'
                    ? 42
                    : 23)
          : const ui.Offset(0, 23);
      if (session.hit(mob, damage, push, generateRage: true) &&
          basic.id == 'heavyStrike' &&
          !mob.isDead) {
        mob.applyStun(.12 + p.rank(basic.id) * .025);
      }
    }
  }

  bool _hasSkillResource(SkillDef def) {
    if (session.progress.energy >= def.cost) return true;
    session.bubble(
      '${session.progress.heroClass.resource} 부족',
      body.center - const ui.Offset(0, 75),
      const ui.Color(0xffffc08d),
    );
    return false;
  }

  void skill({bool secondary = false, int? slot, SkillAim? manualAim}) {
    if (!session.combatAllowed ||
        session.afflictions.frozen ||
        dashing > 0 ||
        physicalAction) {
      return;
    }
    final p = session.progress;
    final slotIndex = slot ?? (secondary ? 1 : 0);
    final def = p.skillAt(slotIndex);
    if (def == null ||
        def.id == 'charge' && session.afflictions.movementBlocked) {
      return;
    }
    final rank = p.rank(def.id);
    if (!session.active || (cooldowns[def.id] ?? 0) > 0 || rank == 0) return;
    if (!_hasSkillResource(def) || !session.ensureOnFoot()) return;
    if (castLock > 0) {
      queuedCast = (slot: slotIndex, id: def.id, aim: manualAim);
      return;
    }
    queuedCast = null;
    session.audio.play(switch (def.id) {
      'warcry' || 'frenzy' => EffectSound.warcry,
      'frostNova' || 'iceArmor' => EffectSound.ice,
      'chainLightning' => EffectSound.lightning,
      'meteor' => EffectSound.fire,
      'seismicSlam' => EffectSound.impact,
      _ => EffectSound.slash,
    });
    session.device.pulse(FeedbackKind.skill);
    p.energy -= def.cost;
    cooldowns[def.id] = p.skillCooldown(def);
    if (p.heroClass == HeroClass.mage) {
      castLock = p.skillMotionTime(def);
      attackClock = math.max(attackClock, castLock);
      swingDuration = swing = castLock;
      attackBearing = manualAim?.angle ?? bearing;
    } else if (def.id == 'warcry' || def.id == 'frenzy') {
      castLock = p.skillMotionTime(def);
      attackClock = math.max(attackClock, castLock);
      swingDuration = swing = castLock;
      attackBearing = bearing;
      strikePose = 2;
    }
    switch (def.id) {
      case 'charge':
        chargeAngle = manualAim?.angle ?? bearing;
        attackBearing = chargeAngle;
        strikePose = 1;
        swingDuration = .36;
        swing = .16;
        chargeDamage = p.skillDamage(def);
        chargeCap = p.skillTargetLimit(def);
        chargeVictims.clear();
        chargeChests.clear();
        chargeTime = p.skillMotionTime(def);
        chargeSpeed = 324 / chargeTime;
        attackClock = math.max(attackClock, chargeTime + .06);
      case 'crushingBlow':
        heavyAngle = manualAim?.angle ?? bearing;
        heavyCharge = ((manualAim?.heldFor ?? 0) / p.heavyChargeTime).clamp(
          0,
          1,
        );
        heavyPower = p.skillDamage(def) * (1 + .8 * heavyCharge);
        heavySkill = def;
        heavyWindup = p.skillMotionTime(def);
        session.game?.add(
          CrushingBlowWindup(
            session,
            this,
            rank: rank,
            charge: heavyCharge,
            bearing: heavyAngle,
            duration: heavyWindup,
          ),
        );
        attackClock = math.max(attackClock, heavyWindup + .3);
        attackBearing = heavyAngle;
        strikePose = 2;
        swingDuration = swing = .66;
      case 'warcry':
        armorTime = p.warcryDuration;
        areaStrike(
          session,
          body.center,
          170 + rank * 8,
          p.skillDamage(def),
          stun: p.warcryStun,
          maxTargets: p.skillTargetLimit(def),
          impactRank: rank,
        );
        session.game?.add(
          SpellBurst(
            session,
            SpellClip.warcry,
            body.center,
            radius: 170 + rank * 8,
            rank: rank,
            tempo: p.skillTempo(def),
          ),
        );
      case 'whirlwind':
        spinDuration = p.skillMotionTime(def);
        spin = spinDuration;
        swing = 0;
        session.game?.add(
          SteelWhirlwind(session, this, rank: rank, duration: spinDuration),
        );
        attackClock = math.max(attackClock, spinDuration);
        invulnerable = math.max(invulnerable, spinDuration * .7);
        session.game?.add(
          WhirlwindPulse(
            session,
            this,
            p.skillDamage(def),
            targetLimit: p.skillTargetLimit(def),
            rank: rank,
            duration: spinDuration,
          ),
        );
      case 'frenzy':
        frenzyTime = p.frenzyDuration;
        areaStrike(
          session,
          body.center,
          145,
          p.skillDamage(def),
          maxTargets: p.skillTargetLimit(def),
          impactRank: rank,
        );
        session.game?.add(
          RuneBurst(
            session,
            body.center,
            const ui.Color(0xffffa15e),
            radius: 145,
            rank: rank,
            tempo: p.skillTempo(def),
          ),
        );
      case 'seismicSlam':
        var angle = manualAim?.angle ?? bearing;
        final targets =
            session.mobs
                .where(
                  (m) =>
                      session.canHitEnemy(m) &&
                      (m.body.center - body.center).distance < 260 &&
                      session.world.clearLine(
                        body.center,
                        m.body.center,
                        const ui.Size(3, 3),
                      ),
                )
                .toList()
              ..sort(
                (a, b) => (a.body.center - body.center).distance.compareTo(
                  (b.body.center - body.center).distance,
                ),
              );
        if (manualAim == null && velocity.length < 5 && targets.isNotEmpty) {
          final toward = targets.first.body.center - body.center;
          angle = math.atan2(toward.dy, toward.dx);
          bearing = angle;
        }
        attackBearing = angle;
        strikePose = 2;
        swingDuration = p.skillMotionTime(def);
        swing = swingDuration * .55;
        attackClock = math.max(attackClock, p.skillMotionTime(def) + .12);
        final impact = aimedImpact(angle, 100);
        areaStrike(
          session,
          impact,
          125 + rank * 6,
          p.skillDamage(def),
          impactKind: ImpactKind.heavy,
          stun: .65 + rank * .08,
          slow: 1.5,
          maxTargets: p.skillTargetLimit(def),
          impactRank: rank,
        );
        session.game?.add(
          GroundStrike(
            session,
            impact,
            rank: rank,
            tempo: p.skillTempo(def),
            bearing: angle,
          ),
        );
      case 'frostNova':
        final radius = 155.0 + rank * 15;
        areaStrike(
          session,
          body.center,
          radius,
          p.skillDamage(def),
          stun: 2,
          impactKind: ImpactKind.ice,
          slow: p.novaSlowDuration,
          maxTargets: p.skillTargetLimit(def),
          impactRank: rank,
        );
        session.game?.add(
          SpellBurst(
            session,
            SpellClip.iceNova,
            body.center,
            radius: radius,
            rank: rank,
            tempo: p.skillTempo(def),
          ),
        );
      case 'iceArmor':
        armorTime = p.iceArmorDuration;
        session.game?.add(
          SpellBurst(
            session,
            SpellClip.iceNova,
            body.center,
            radius: 70,
            rank: rank,
            tempo: p.skillTempo(def),
          ),
        );
      case 'chainLightning':
        chainLightning(
          session,
          body.center,
          p.skillDamage(def),
          p.skillTargetLimit(def),
          rank: rank,
        );
      case 'meteor':
        var target =
            body.center + ui.Offset(math.cos(bearing), math.sin(bearing)) * 190;
        final near =
            session.mobs
                .where(
                  (m) =>
                      !m.isDead &&
                      (m.body.center - body.center).distance < 450 &&
                      session.world.clearLine(
                        body.center,
                        m.body.center,
                        const ui.Size(3, 3),
                      ),
                )
                .toList()
              ..sort(
                (a, b) => (a.body.center - body.center).distance.compareTo(
                  (b.body.center - body.center).distance,
                ),
              );
        if (manualAim != null) {
          target = meteorAimImpact(manualAim);
        } else if (near.isNotEmpty) {
          target = near.first.body.center;
        }
        attackBearing = math.atan2(
          target.dy - body.center.dy,
          target.dx - body.center.dx,
        );
        session.game?.add(
          MeteorFall(
            session,
            body.center,
            target,
            p.skillDamage(def),
            targetLimit: p.skillTargetLimit(def),
            rank: rank,
            tempo: p.skillTempo(def),
          ),
        );
    }
    session.refresh();
  }

  void dodge() {
    if (!session.active ||
        session.afflictions.movementBlocked ||
        dodgeClock > 0 ||
        physicalAction ||
        !session.ensureOnFoot()) {
      return;
    }
    aim = null;
    queuedCast = null;
    session.audio.play(EffectSound.dodge);
    session.device.pulse(FeedbackKind.dodge);
    rollBearing = bearing;
    impactHold = 0;
    swing = 0;
    dashing = .32;
    dodgeClock = 1.5;
    invulnerable = .32;
    session.refresh();
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final feet = ui.Offset(size.x / 2, size.y),
        center = ui.Offset(size.x / 2, size.y - 8);
    final crushingAim = aim?.id == 'crushingBlow' ? aim : null;
    canvas.drawOval(
      ui.Rect.fromCenter(center: feet - ui.Offset(0, 2), width: 36, height: 13),
      ui.Paint()..color = const ui.Color(0x6642c8ba),
    );
    canvas.drawOval(
      ui.Rect.fromCenter(center: feet - ui.Offset(0, 2), width: 36, height: 13),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const ui.Color(0xaaafffe3),
    );
    if (invulnerable > 0) {
      final pulse = .5 + .5 * math.sin(invulnerable * math.pi * 2 / .65);
      final guard = ui.Rect.fromCenter(
        center: feet - const ui.Offset(0, 2),
        width: 40 + pulse * 3,
        height: 16 + pulse * 2,
      );
      canvas.drawOval(
        guard,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const ui.Color(
            0xffb5fff0,
          ).withValues(alpha: .3 + pulse * .35),
      );
      canvas.drawArc(
        guard,
        session.elapsed * 4,
        math.pi * .65,
        false,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const ui.Color(
            0xffe6fff7,
          ).withValues(alpha: .55 + pulse * .25),
      );
    }
    final damageFlash = (hurtFlash / .12).clamp(0.0, 1.0) * .65;
    final mount = session.riding;
    if (mount != null) {
      session.art.actor(
        canvas,
        mount.def.artKey,
        feet,
        mount.bearing,
        movingThisFrame ? (animationTime / .13).floor() % 2 : 0,
        mount.def.waterOnly ? 48 : 62,
      );
      canvas.save();
      final lift = mount.def.waterOnly ? 8.0 : 20.0;
      canvas.clipRect(
        ui.Rect.fromLTRB(
          feet.dx - 36,
          feet.dy - 90,
          feet.dx + 36,
          feet.dy - lift - 14,
        ),
      );
      session.art.actor(
        canvas,
        session.progress.heroClass == HeroClass.mage ? 'mage' : 'hero',
        feet - ui.Offset(0, lift),
        mount.bearing,
        0,
        46,
        flash: damageFlash,
      );
      canvas.restore();
    } else if (dashing > 0) {
      session.art.roll(
        canvas,
        feet,
        rollBearing,
        ((1 - dashing / .32) * 4).floor(),
        mage: session.progress.heroClass == HeroClass.mage,
      );
    } else {
      final actionProgress = spin > 0
          ? 1 - spin / spinDuration
          : chargeTime > 0
          ? 1 -
                chargeTime /
                    session.progress.skillMotionTime(
                      session.progress.skills.firstWhere(
                        (s) => s.id == 'charge',
                      ),
                    )
          : heavyWindup > 0 && heavySkill != null
          ? .25 * heavyCharge +
                (.5 - .25 * heavyCharge) *
                    (1 -
                        heavyWindup /
                            session.progress.skillMotionTime(heavySkill!))
          : crushingAim != null
          ? .25 *
                (crushingAim.heldFor / session.progress.heavyChargeTime).clamp(
                  0.0,
                  1.0,
                )
          : swing > 0 && swingDuration > 0
          ? 1 - swing / swingDuration
          : 0.0;
      session.art.actor(
        canvas,
        session.progress.heroClass == HeroClass.mage ? 'mage' : 'hero',
        feet,
        spin > 0
            ? bearing + (1 - spin / spinDuration) * math.pi * 4
            : crushingAim != null
            ? crushingAim.angle
            : swing > 0
            ? attackBearing
            : bearing,
        spin > 0
            ? 1
            : heavyWindup > 0 || aim?.id == 'crushingBlow'
            ? 0
            : swing > 0
            ? (swing > swingDuration * .58 ? 0 : 1)
            : movingThisFrame
            ? runMotion.phaseFor(
                session.art.runFrameCount(
                  session.progress.heroClass == HeroClass.mage
                      ? 'mage'
                      : 'hero',
                ),
              )
            : 0,
        60,
        moving: movingThisFrame,
        attack: swing > 0 || spin > 0 || aim?.id == 'crushingBlow',
        comboPose: spin > 0
            ? 1
            : crushingAim != null
            ? 2
            : strikePose,
        flash: damageFlash,
        actionProgress: actionProgress.clamp(0.0, 1.0),
      );
    }
    if (swing > 0 &&
        heavyWindup <= 0 &&
        spin <= 0 &&
        session.progress.heroClass == HeroClass.warrior) {
      final phase = 1 - swing / swingDuration,
          rect = ui.Rect.fromCircle(
            center: center,
            radius: session.progress.weapon.base.range * .58,
          );
      final style = session.progress.weapon.base.style,
          direction = ui.Offset(
            math.cos(attackBearing),
            math.sin(attackBearing),
          );
      if (style == 'spear') {
        final tip =
            center +
            direction * session.progress.weapon.base.range * (.5 + phase * .45);
        canvas.drawLine(
          center + direction * 15,
          tip,
          ui.Paint()
            ..color = ui.Color.fromRGBO(212, 248, 255, 1 - phase)
            ..strokeWidth = 4 * (1 - phase) + 1
            ..strokeCap = ui.StrokeCap.round,
        );
        canvas.drawCircle(
          tip,
          3,
          ui.Paint()
            ..color = const ui.Color(0xfffff4c7).withValues(alpha: 1 - phase),
        );
      } else if (style == 'hammer') {
        final at = center + direction * 65;
        canvas.drawOval(
          ui.Rect.fromCenter(
            center: at,
            width: 20 + phase * 72,
            height: 14 + phase * 40,
          ),
          ui.Paint()
            ..color = const ui.Color(0xffffc47d).withValues(alpha: 1 - phase)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - phase) + 1,
        );
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          canvas.drawLine(
            at +
                ui.Offset(math.cos(angle), math.sin(angle)) * (12 + phase * 10),
            at +
                ui.Offset(math.cos(angle), math.sin(angle)) * (18 + phase * 35),
            ui.Paint()
              ..color = const ui.Color(0xffffdf94).withValues(alpha: 1 - phase)
              ..strokeWidth = 2,
          );
        }
      } else {
        canvas.drawArc(
          rect,
          attackBearing +
              (strikePose == 1 ? 1.2 - phase * 2.1 : -1.2 + phase * .9),
          1.6,
          false,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth =
                (7 + math.max(0, session.progress.rank('cleave') - 1) * 1.3) *
                    (1 - phase) +
                1
            ..strokeCap = ui.StrokeCap.round
            ..color =
                (session.progress.weapon.base.style == 'hammer'
                        ? const ui.Color(0xffffbd6c)
                        : session.progress.weapon.base.style == 'axe'
                        ? const ui.Color(0xffffdfa3)
                        : const ui.Color(0xffcbf8ff))
                    .withValues(alpha: (1 - phase) * .9),
        );
        canvas.drawArc(
          rect.deflate(5),
          attackBearing +
              (strikePose == 1 ? 1.1 - phase * 2.1 : -1.1 + phase * .9),
          1.3,
          false,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = ui.Color.fromRGBO(255, 249, 213, 1 - phase),
        );
      }
    }
    if (session.progress.heroClass == HeroClass.warrior &&
        (armorTime > 0 || frenzyTime > 0)) {
      paintBattleAura(
        canvas,
        center,
        session.elapsed,
        frenzy: frenzyTime > 0,
        rank: session.progress.rank(frenzyTime > 0 ? 'frenzy' : 'warcry'),
      );
    }
    if (armorTime > 0 && session.progress.heroClass == HeroClass.mage) {
      paintIceShield(
        canvas,
        center - const ui.Offset(0, 22),
        session.elapsed,
        rank: session.progress.rank('iceArmor'),
      );
    }
    if (armorTime > 0 || frenzyTime > 0) {
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: feet - const ui.Offset(0, 22),
          width: 54,
          height: 72,
        ),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = session.progress.heroClass == HeroClass.mage
              ? const ui.Color(0x9979dfff)
              : const ui.Color(0x99ffce83),
      );
    }
    if (spin > 0) {
      final angle = bearing + (1 - spin / spinDuration) * math.pi * 4;
      canvas.drawArc(
        ui.Rect.fromCircle(center: center, radius: 49),
        angle - 1.6,
        1.5,
        false,
        ui.Paint()
          ..color = const ui.Color(0xffe8f5ee)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = ui.StrokeCap.round,
      );
    }
    if (chargeTime > 0) {
      paintRankImpact(
        canvas,
        center,
        (session.elapsed * 7) % 1,
        session.progress.rank('charge'),
        const ui.Color(0xffffd9a0),
        radius: 36,
      );
    }
    if (aim?.id == 'crushingBlow' || heavyWindup > 0) {
      final charge = crushingAim == null
          ? heavyCharge
          : (crushingAim.heldFor / session.progress.heavyChargeTime).clamp(
              0.0,
              1.0,
            );
      _heavyChargeArt.paint(
        canvas,
        center,
        bearing: crushingAim?.angle ?? heavyAngle,
        charge: charge,
        time: session.elapsed,
        rank: session.progress.rank('crushingBlow'),
      );
      canvas.drawArc(
        ui.Rect.fromCenter(center: feet, width: 44, height: 18),
        -math.pi / 2,
        math.pi * 2 * charge,
        false,
        ui.Paint()
          ..color = const ui.Color(0xffffd893)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    paintPlayerAfflictions(canvas, feet, session.afflictions, session.elapsed);
    final currentAim = aim;
    if (currentAim?.id == 'crushingBlow' || currentAim?.id == 'charge') {
      paintPhysicalAimPreview(
        canvas,
        body.center - position.toOffset(),
        currentAim!,
        bearing: currentAim.id == 'charge' && !currentAim.dragged
            ? bearing
            : currentAim.angle,
      );
    } else if (currentAim != null) {
      final origin = body.center - position.toOffset();
      final target =
          (currentAim.id == 'meteor'
              ? meteorAimImpact(currentAim)
              : aimedImpact(currentAim.angle, 100)) -
          position.toOffset();
      final color = currentAim.cancelled
          ? const ui.Color(0xffff817e)
          : const ui.Color(0xff9deee4);
      final radius = currentAim.dragged
          ? currentAim.id == 'meteor'
                ? 175.0
                : 125.0 + session.progress.rank('seismicSlam') * 6
          : 55.0;
      final at = currentAim.dragged ? target : origin;
      if (currentAim.dragged) {
        canvas.drawLine(
          origin,
          target,
          ui.Paint()
            ..color = color.withValues(alpha: .7)
            ..strokeWidth = 2,
        );
      }
      canvas.drawCircle(
        at,
        radius,
        ui.Paint()..color = color.withValues(alpha: .10),
      );
      canvas.drawCircle(
        at,
        radius,
        ui.Paint()
          ..color = color.withValues(alpha: .85)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (var i = 0; i < 4; i++) {
        final angle = i * math.pi / 2;
        final vector = ui.Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          at + vector * (radius - 9),
          at + vector * (radius + 7),
          ui.Paint()
            ..color = color
            ..strokeWidth = 3,
        );
      }
    }
  }
}

/// Keeps a short local route around a stalled crowd until its corners clear.
class _LocalCrowdIntent {
  double blocked = 0, cooldown = 0, remaining = 0;
  final points = <ui.Offset>[];
  final failed = <HuntEnemy, ui.Offset>{};
  ui.Offset? heroGoal;
  AdventureWorld? world;
  int terrain = -1;

  bool get active => points.isNotEmpty;
  void reset(HuntEnemy m, {bool failure = false, bool terminal = false}) {
    if (active) {
      m.route.clear();
      m.routeGoal = null;
    }
    if (failure) {
      // Snapshot the current local obstruction at failure, not its old
      // positions from admission. New blockers may have entered the corridor.
      remember(m, nearby(m));
      cooldown = 1.2;
    } else if (active || terminal) {
      failed.clear();
    }
    points.clear();
    blocked = 0;
    remaining = 0;
  }

  void remember(HuntEnemy m, Iterable<HuntEnemy> blockers) {
    failed.clear();
    for (final other in blockers) {
      failed[other] = other.body.center;
    }
    heroGoal = m.session.hero.position.toOffset();
    world = m.session.world;
    terrain = m.session.world.openedChests.length;
  }

  bool sceneChanged(HuntEnemy m) {
    if (world != m.session.world ||
        terrain != m.session.world.openedChests.length ||
        heroGoal == null ||
        (m.session.hero.position.toOffset() - heroGoal!).distance > 24) {
      return true;
    }
    return failed.entries.any(
      (e) =>
          e.key.isDead ||
          e.key.isRemoving ||
          !m.session.mobs.contains(e.key) ||
          (e.key.body.center - e.value).distance >=
              math.max(6, e.key.body.shortestSide / 4),
    );
  }

  double q(HuntEnemy m, ui.Offset center, HuntEnemy other) {
    final d = center - other.body.center;
    final x = d.dx / ((m.personalSpace.width + other.personalSpace.width) / 2);
    final y =
        d.dy / ((m.personalSpace.height + other.personalSpace.height) / 2);
    return math.sqrt(x * x + y * y);
  }

  bool softStep(HuntEnemy m, ui.Offset from, ui.Offset to, HuntEnemy other) {
    final a = q(m, from, other), b = q(m, to, other);
    return b >= 1 || b >= a - .000001;
  }

  bool hardSegment(ui.Offset a, ui.Offset b, ui.Rect exclusion) {
    final d = b - a;
    var lo = 0.0, hi = 1.0;
    for (final row in [
      (a.dx, d.dx, exclusion.left, exclusion.right),
      (a.dy, d.dy, exclusion.top, exclusion.bottom),
    ]) {
      if (row.$2 == 0) {
        if (row.$1 <= row.$3 || row.$1 >= row.$4) return true;
      } else {
        final t0 = (row.$3 - row.$1) / row.$2, t1 = (row.$4 - row.$1) / row.$2;
        lo = math.max(lo, math.min(t0, t1));
        hi = math.min(hi, math.max(t0, t1));
      }
      if (lo >= hi) return true;
    }
    return hi <= 0 || lo >= 1;
  }

  bool segment(
    HuntEnemy m,
    ui.Offset from,
    ui.Offset to,
    List<HuntEnemy> others, {
    bool toHero = false,
  }) {
    if (!m.session.world.clearEnemyLine(from, to, m.body.size)) return false;
    final half = ui.Offset(m.body.width / 2, m.body.height / 2),
        a = from + half,
        b = to + half;
    if (!toHero &&
        !hardSegment(
          a,
          b,
          ui.Rect.fromCenter(
            center: m.session.hero.body.center,
            width: m.body.width + m.session.hero.body.width,
            height: m.body.height + m.session.hero.body.height,
          ),
        )) {
      return false;
    }
    for (final other in others) {
      if (!hardSegment(
        a,
        b,
        ui.Rect.fromCenter(
          center: other.body.center,
          width: m.body.width + other.body.width,
          height: m.body.height + other.body.height,
        ),
      )) {
        return false;
      }
      final reachX = (m.personalSpace.width + other.personalSpace.width) / 2,
          reachY = (m.personalSpace.height + other.personalSpace.height) / 2;
      final u = ui.Offset(
            (a.dx - other.body.center.dx) / reachX,
            (a.dy - other.body.center.dy) / reachY,
          ),
          v = ui.Offset((b.dx - a.dx) / reachX, (b.dy - a.dy) / reachY);
      final before = u.distanceSquared, dot = u.dx * v.dx + u.dy * v.dy;
      if (before < 1) {
        if (dot < 0) return false;
      } else {
        final t = v.distanceSquared == 0
            ? 0.0
            : (-dot / v.distanceSquared).clamp(0.0, 1.0);
        if ((u + v * t).distanceSquared < 1) return false;
      }
    }
    return true;
  }

  ui.Rect envelope(HuntEnemy mover, HuntEnemy other) => ui.Rect.fromCenter(
    center: other.body.center,
    width: mover.personalSpace.width + other.personalSpace.width,
    height: mover.personalSpace.height + other.personalSpace.height,
  );
  List<HuntEnemy> nearby(HuntEnemy m) {
    final s = m.session;
    s._syncEnemySpacing(m);
    return s.enemySpacing
        .query(m.body.inflate(96))
        .where(
          (e) => e != m && !e.isDead && !e.isRemoving && !e.encounterDormant,
        )
        .take(28)
        .toList();
  }

  void plan(HuntEnemy m, ui.Offset desired) {
    final others = nearby(m), from = m.position.toOffset();
    final probe =
        Vector2(from.dx + desired.dx, from.dy + desired.dy).toOffset() &
        m.body.size;
    final blockers = others
        .where(
          (e) =>
              !EnemySpacing.permits(m.body, probe, e.body) ||
              !softStep(m, m.body.center, probe.center, e),
        )
        .toList();
    if (blockers.isEmpty) return;
    remember(m, blockers);
    final cluster = <HuntEnemy>{...blockers};
    var bounds = envelope(m, blockers.first);
    for (final e in blockers.skip(1)) {
      bounds = bounds.expandToInclude(envelope(m, e));
    }
    var grew = true;
    while (grew) {
      grew = false;
      for (final other in others) {
        if (!cluster.contains(other) && envelope(m, other).overlaps(bounds)) {
          cluster.add(other);
          bounds = bounds.expandToInclude(envelope(m, other));
          grew = true;
        }
      }
    }
    remember(m, cluster);
    final margin = m.body.shortestSide / 2;
    bounds = bounds.inflate(margin);
    final half = ui.Offset(m.body.width / 2, m.body.height / 2);
    final corners = [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomRight,
      bounds.bottomLeft,
    ].map((p) => Vector2(p.dx - half.dx, p.dy - half.dy).toOffset()).toList();
    final side = m.session.enemySpacing.preferredSide(m).toInt(),
        hero = m.session.hero.position.toOffset();
    List<ui.Offset>? chosen;
    var chosenLength = double.infinity;
    for (final direction in [side, -side]) {
      for (var start = 0; start < 4; start++) {
        if (!segment(m, from, corners[start], others)) continue;
        final candidate = <ui.Offset>[];
        var at = from, length = 0.0;
        for (var count = 0; count < 3; count++) {
          final goal = corners[(start + direction * count) % 4];
          if (!segment(m, at, goal, others)) break;
          candidate.add(goal);
          length += (goal - at).distance;
          at = goal;
          if (segment(m, at, hero, cluster.toList(), toHero: true) &&
              length < chosenLength) {
            chosen = List.of(candidate);
            chosenLength = length;
          }
        }
      }
      if (chosen != null) break;
    }
    if (chosen == null) {
      // Any nearby body may reject an exterior leg, even when it does not
      // belong to the connected cluster that supplied the route's corners.
      remember(m, others);
      cooldown = 1.2;
      blocked = 0;
      return;
    }
    points.addAll(chosen);
    remaining = (chosenLength / (m.speed * (m.slow > 0 ? .45 : 1)) * 1.5 + .4)
        .clamp(1.2, 6.0);
    blocked = 0;
    m.route.clear();
    m.routeGoal = null;
  }

  void advance(HuntEnemy m, double dt) {
    cooldown = math.max(0, cooldown - dt);
    if (!active) return;
    remaining -= dt;
    if (heroGoal == null ||
        (m.session.hero.position.toOffset() - heroGoal!).distance > 24 ||
        world != m.session.world ||
        terrain != m.session.world.openedChests.length) {
      reset(m);
      return;
    }
    if (remaining <= 0) {
      reset(m, failure: true);
      return;
    }
    while (points.isNotEmpty &&
        (points.first - m.position.toOffset()).distance <
            m.body.shortestSide / 4) {
      points.removeAt(0);
    }
    if (points.isEmpty) {
      blocked = 0;
      m.route.clear();
      m.routeGoal = null;
      failed.clear();
    }
  }

  void observe(
    HuntEnemy m,
    double dt,
    ui.Offset from,
    ui.Offset desired,
    ui.Offset accepted,
  ) {
    if (active) return;
    if ((accepted - from).distanceSquared >= .0001) {
      blocked = 0;
      return;
    }
    final expected = m.session.world.moveEnemy(from, desired, m.body.size);
    final stored = Vector2(expected.dx, expected.dy).toOffset();
    if ((stored - from).distanceSquared <= .0001 ||
        m.session.world.blocksEnemy(stored & m.body.size)) {
      blocked = 0;
      return;
    }
    blocked += dt;
    if (blocked >= .4 && cooldown <= 0 && (failed.isEmpty || sceneChanged(m))) {
      plan(m, desired);
    }
  }
}

class HuntEnemy extends Enemy with WithCollision, EffectVisibility {
  HuntEnemy(
    this.session,
    this.kind,
    ui.Offset at, {
    this.boss = false,
    this.trait = EnemyTrait.none,
    EnemyTier? tier,
    EnemyPower? power,
  }) : tier = boss
           ? EnemyTier.normal
           : tier ??
                 (trait == EnemyTrait.none
                     ? EnemyTier.normal
                     : EnemyTier.elite),
       super(
         position: Vector2(at.dx, at.dy),
         size: boss ? Vector2(48, 40) : Vector2(24, 22),
         life:
             (boss ? 1800 : (enemyCatalog[kind]?.health ?? 52)) *
             (boss ? 1 : trait.healthScale) *
             monsterHealthScale,
         speed:
             (boss ? 90 : (enemyCatalog[kind]?.speed ?? 105)) *
             (boss ? 1 : trait.speedScale),
       ) {
    this.power =
        power ??
        EnemyPower.forSpawn(
          stage: session.world.stage,
          origin: session.world.spawn,
          at: body.center,
          tier: this.tier,
          boss: boss,
        );
  }
  final Adventure session;
  final String kind;
  String? encounterKey;
  final bool boss;
  final EnemyTrait trait;
  final _localIntent = _LocalCrowdIntent();
  final EnemyTier tier;
  late final EnemyPower power;
  double outgoingDamage(double base) =>
      base * power.damageMultiplier * CombatBalance.enemyDamageScale;
  bool get isElite => !boss && tier != EnemyTier.normal;
  bool get isUnique => !boss && tier == EnemyTier.unique;
  ui.Color get tierColor => isUnique ? const ui.Color(0xffd3a1ff) : trait.color;
  double wardPhase = 0;
  bool get wardWarning => isUnique && wardPhase >= 4 && wardPhase < 5;
  bool get wardActive => isUnique && wardPhase >= 5 && wardPhase < 7;
  EnemyDef? get definition => enemyCatalog[kind];
  bool get lowProfile => !boss && (definition?.lowProfile ?? false);
  bool get technological => definition?.technological ?? false;
  bool get usesPounce => !boss && definition?.pattern == 'pounce';
  bool get usesSweep => !boss && definition?.pattern == 'sweep';
  bool get usesBolt => !boss && definition?.pattern == 'bolt';
  double get pounceWarning =>
      definition?.attackWarning ??
      switch (kind) {
        'scorpion' => .58,
        'viper' => .55,
        _ => .42,
      };
  double get pounceSpeed =>
      definition?.attackSpeed ??
      switch (kind) {
        'scorpion' => 440,
        'viper' => 420,
        _ => 520,
      };
  double get pounceRange =>
      definition?.attackRange ??
      switch (kind) {
        'scorpion' => 200,
        'viper' => 170,
        _ => 240,
      };
  double get sweepRange =>
      definition?.attackRange ??
      (kind == 'troll'
          ? 120
          : kind == 'cyber'
          ? 110
          : 100);
  double get sweepAngle => kind == 'troll'
      ? 1.05
      : kind == 'cyber'
      ? .95
      : .85;
  double get sweepWarning =>
      definition?.attackWarning ??
      (kind == 'troll'
          ? .85
          : kind == 'cyber'
          ? .65
          : .5);
  double get sweepDamage =>
      definition?.attackDamage ??
      (kind == 'troll'
          ? 14
          : kind == 'cyber'
          ? 10
          : 8);
  double get sweepRecovery =>
      definition?.attackRecovery ??
      (kind == 'troll'
          ? 2.6
          : kind == 'cyber'
          ? 2.1
          : 1.8);
  double get boltWarning =>
      definition?.attackWarning ?? (kind == 'gunner' ? .8 : .65);
  ui.Color get attackColor =>
      definition?.attackColor ??
      (kind == 'basilisk' || kind == 'viper'
          ? const ui.Color(0xffb2df73)
          : kind == 'gunner' || kind == 'drone'
          ? const ui.Color(0xff7feafa)
          : kind == 'scorpion'
          ? const ui.Color(0xffbcda75)
          : const ui.Color(0xffefab78));
  int impactPose = 0;
  ui.Size get personalSpace => boss
      ? const ui.Size(78, 58)
      : kind == 'troll'
      ? const ui.Size(58, 42)
      : lowProfile
      ? const ui.Size(50, 32)
      : isElite
      ? const ui.Size(48, 38)
      : const ui.Size(44, 34);
  double get idleRange => boss
      ? 64
      : usesBolt
      ? (definition?.attackRange ?? (kind == 'gunner' ? 350 : 280))
      : usesSweep
      ? sweepRange - 18
      : 42;
  double get mass =>
      (boss
          ? 2.6
          : kind == 'troll'
          ? 1.9
          : kind == 'mummy'
          ? 1.4
          : kind == 'boar'
          ? 1.35
          : kind == 'cyber'
          ? 1.3
          : kind == 'crystal-beetle'
          ? 1.5
          : 1.0) *
      (isUnique
          ? 1.25
          : isElite
          ? 1.12
          : 1.0);
  late final motion = EnemyMotion(mass: mass);
  late final inertia = EnemyInertia(mass: mass);
  final attackMotion = EnemyAttackMotion();
  double meleeWindup = 0;
  double get meleeWarning => boss ? .26 : .2;
  double get meleeReach => boss ? 64 : 42;
  double get anticipation {
    if (meleeWindup > 0) return 1 - meleeWindup / meleeWarning;
    if (windup <= 0) return 0;
    final duration = usesPounce
        ? pounceWarning
        : usesSweep
        ? sweepWarning
        : usesBolt
        ? boltWarning
        : bossAttack?.warningTime ?? 1;
    return (1 - windup / duration).clamp(0.0, 1.0);
  }

  bool get preparingAttack => meleeWindup > 0 || windup > 0;
  final damageTrail = DamageTrail();
  ui.Offset _knockback = ui.Offset.zero;
  double _knockbackTime = 0;

  void push(ui.Offset impulse) {
    if (impulse == ui.Offset.zero) return;
    final next = _knockback + impulse / mass;
    final limit = 80 / mass;
    _knockback = next.distance > limit ? next / next.distance * limit : next;
    _knockbackTime = .16 * math.sqrt(mass);
  }

  void _updateKnockback(double dt) {
    if (_knockbackTime <= 0) return;
    _knockbackTime = math.max(0, _knockbackTime - dt);
    final step = _knockbackTime == 0
        ? _knockback
        : _knockback * (1 - math.exp(-30 / math.sqrt(mass) * dt));
    _knockback -= step;
    final at = session.moveEnemyBody(this, position.toOffset(), step);
    position.setValues(at.dx, at.dy);
    session.updateEnemySpacing(this);
    lastClearPosition = at;
  }

  bool rewarded = false, combatReady = false, encounterDormant = false;
  double bearing = math.pi / 2,
      hurt = 0,
      attackClock = 1,
      replan = 0,
      stun = 0,
      slow = 0;
  List<ui.Offset> route = [];
  double slamClock = 4, windup = 0;
  int bossSequence = 0;
  double bossControlGuard = 0;
  bool applyStun(double baseDuration) {
    if (!baseDuration.isFinite ||
        baseDuration <= 0 ||
        !session.canHitEnemy(this) ||
        boss && bossControlGuard > 0) {
      return false;
    }
    final duration = boss ? math.min(.7, baseDuration * .35) : baseDuration;
    stun = math.max(stun, duration);
    if (boss) bossControlGuard = duration + 8;
    return true;
  }

  double pounceRemaining = 0, pounceDuration = 0, pounceBearing = 0;
  ui.Offset? pounceGoal;
  ui.Offset? slamTarget;
  BossAttack? bossAttack;
  ui.Offset? routeGoal;
  ui.Offset? lastClearPosition;
  ui.Rect get body => ui.Rect.fromLTWH(position.x, position.y, size.x, size.y);
  @override
  ui.Rect get effectBounds {
    // Include the tallest sprite, recoil, status marks and boss name plate.
    var bounds = body.inflate(boss ? 180 : 130);
    if (windup > 0) {
      if (usesPounce && pounceGoal != null) {
        bounds = bounds.expandToInclude(
          ui.Rect.fromPoints(body.center, pounceGoal!).inflate(16),
        );
      }
      if (usesSweep) {
        bounds = bounds.expandToInclude(
          ui.Rect.fromCircle(center: body.center, radius: sweepRange + 3),
        );
      }
      if (usesBolt && technological) {
        final tip =
            body.center + ui.Offset(math.cos(bearing), math.sin(bearing)) * 260;
        bounds = bounds.expandToInclude(
          ui.Rect.fromPoints(body.center, tip).inflate(3),
        );
      }
    }
    return bounds;
  }

  @override
  void renderCulled(ui.Canvas canvas) {
    // Enemy's base render refreshes Bonfire's cached isVisible value. Keep its
    // normal transform as well, for the engine's optional vision debugging.
    decorator.applyChain(super.render, canvas);
  }

  @override
  void onMount() {
    super.onMount();
    combatReady = true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (session.disposed || !hasGameRef || isRemoving) return;
    await add(RectangleHitbox(size: size));
    lastClearPosition = position.toOffset();
    collision.onMovementBlockedListener((other, data) {
      if (session.world.blocksEnemy(body)) {
        final safe = lastClearPosition;
        if (safe != null) position.setValues(safe.dx, safe.dy);
      }
      session.updateEnemySpacing(this);
    });
  }

  @override
  void update(double dt) {
    if (isDead || isRemoving) {
      _localIntent.reset(this, terminal: true);
      return;
    }
    if (!session.active || !combatReady || dt <= 0) {
      return;
    }
    dt = math.min(dt, .05);
    wardPhase = (wardPhase + dt) % 8;
    attackMotion.update(dt);
    _updateKnockback(dt);
    final before = position.toOffset();
    _updateBehavior(dt);
    if (preparingAttack ||
        pounceRemaining > 0 ||
        hurt > 0 ||
        stun > 0 ||
        _knockbackTime > 0 ||
        isDead) {
      _localIntent.reset(this);
    }
    if (velocity.isZero()) inertia.stop();
    if ((velocity.isZero() ||
            (position.toOffset() - before).distanceSquared < .0001) &&
        !preparingAttack &&
        pounceRemaining <= 0 &&
        hurt <= 0 &&
        _knockbackTime <= 0 &&
        stun <= 0 &&
        !session.sheltered &&
        (body.center - session.hero.body.center).distanceSquared < 950 * 950) {
      session.settleEnemy(this, dt);
    }
    damageTrail.update(dt, life.value / life.max);
    motion.update(
      dt,
      distance: (position.toOffset() - before).distance,
      bearing: bearing,
    );
  }

  void _updateBehavior(double dt) {
    var before = position.toOffset();
    final target = session.hero.body.center - body.center;
    final intentEligible =
        !boss &&
        target.distance > idleRange + 80 &&
        target.distance < 950 &&
        !session.sheltered &&
        hurt <= 0 &&
        stun <= 0 &&
        _knockbackTime <= 0 &&
        !preparingAttack &&
        pounceRemaining <= 0;
    if (intentEligible) {
      _localIntent.advance(this, dt);
    } else {
      _localIntent.reset(this);
    }
    var ordinaryPursuit = false;
    hurt = math.max(0, hurt - dt);
    stun = math.max(0, stun - dt);
    bossControlGuard = math.max(0, bossControlGuard - dt);
    slow = math.max(0, slow - dt);
    attackClock -= dt;
    replan -= dt;
    slamClock -= dt;
    if (session.sheltered) {
      stop();
      meleeWindup = 0;
      attackMotion.cancel();
      if (pounceRemaining > 0) finishPounce();
      windup = 0;
      slamTarget = null;
      bossAttack = null;
      route.clear();
      routeGoal = null;
      attackClock = math.max(attackClock, .35);
      slamClock = math.max(slamClock, 1);
      return;
    }
    if (target.distance > 950 && !(boss && windup > 0)) {
      stop();
      meleeWindup = 0;
      return;
    }
    if (stun > 0) {
      meleeWindup = 0;
      attackMotion.cancel();
      if (pounceRemaining > 0) finishPounce();
      if (windup > 0) {
        windup = 0;
        slamTarget = null;
        bossAttack = null;
        pounceGoal = null;
        slamClock = 4;
        attackClock = math.max(attackClock, 1.2);
      }
      stop();
      super.update(dt);
      return;
    }
    if (meleeWindup > 0) {
      stop();
      meleeWindup = math.max(0, meleeWindup - dt);
      if (meleeWindup == 0) {
        attackMotion.strike(EnemyAttackPose.melee, bearing);
        final angle = math.atan2(target.dy, target.dx);
        final difference = math.atan2(
          math.sin(angle - bearing),
          math.cos(angle - bearing),
        );
        if (target.distance < meleeReach &&
            difference.abs() < math.pi / 2 &&
            session.world.clearEnemyLine(
              body.center,
              session.hero.body.center,
              const ui.Size(3, 3),
            )) {
          session.hurtHero(
            outgoingDamage(
              boss
                  ? 15
                  : kind == 'wolf'
                  ? 6
                  : 4,
            ),
            origin: body.center,
            status: definition?.onHitStatus,
            statusPotency: outgoingDamage(1),
          );
        }
      }
      super.update(dt);
      return;
    }
    if (usesPounce && pounceRemaining > 0) {
      updatePounce(dt);
      return;
    }
    if (usesPounce && windup > 0) {
      stop();
      windup -= dt;
      if (windup <= 0 && pounceGoal != null) {
        final d = pounceGoal! - body.center;
        pounceBearing = math.atan2(d.dy, d.dx);
        bearing = pounceBearing;
        pounceDuration = math.min(pounceRange, d.distance) / pounceSpeed;
        pounceRemaining = pounceDuration;
        attackMotion.strike(EnemyAttackPose.pounce, bearing);
        slamTarget = null;
      }
      super.update(dt);
      return;
    }
    if (usesSweep && windup > 0) {
      stop();
      windup -= dt;
      if (windup <= 0) {
        attackMotion.strike(EnemyAttackPose.sweep, bearing);
        final angle = math.atan2(target.dy, target.dx);
        final difference = math.atan2(
          math.sin(angle - bearing),
          math.cos(angle - bearing),
        );
        if (target.distance < sweepRange &&
            difference.abs() < sweepAngle &&
            session.world.clearEnemyLine(
              body.center,
              session.hero.body.center,
              const ui.Size(3, 3),
            )) {
          session.hurtHero(
            outgoingDamage(sweepDamage),
            origin: body.center,
            status: definition?.onHitStatus,
            statusPotency: outgoingDamage(1),
          );
        }
        session.game?.add(
          EnemySwipe(
            session,
            body.center,
            bearing,
            radius: sweepRange * .8,
            halfAngle: sweepAngle,
          ),
        );
        slamTarget = null;
        attackClock = sweepRecovery;
      }
      super.update(dt);
      return;
    }
    if (usesBolt && windup > 0) {
      stop();
      windup -= dt;
      if (windup <= 0) {
        attackMotion.strike(EnemyAttackPose.bolt, bearing);
        final locked = slamTarget;
        if (locked != null) {
          final toward = locked - body.center;
          session.game?.add(
            ShadowBolt(
              session,
              body.center,
              math.atan2(toward.dy, toward.dx),
              technological: technological,
              venomous: kind == 'basilisk',
              status: definition?.onHitStatus,
              statusPotency: outgoingDamage(1),
              damage: outgoingDamage(
                definition?.attackDamage ?? (kind == 'gunner' ? 10 : 8),
              ),
            ),
          );
        }
        slamTarget = null;
        attackClock =
            definition?.attackRecovery ?? (kind == 'gunner' ? 3.2 : 2.8);
      }
      super.update(dt);
      return;
    }
    if (boss && windup > 0) {
      stop();
      windup -= dt;
      if (windup <= 0) {
        attackMotion.strike(EnemyAttackPose.slam, bearing);
        final attack = bossAttack;
        if (attack != null) {
          final hero = session.hero.body.center;
          if (attack.zones.any(
                (zone) =>
                    zone.contains(hero) &&
                    session.world.clearEnemyLine(
                      zone.center,
                      hero,
                      const ui.Size(3, 3),
                    ),
              ) &&
              session.world.clearEnemyLine(
                attack.origin,
                hero,
                const ui.Size(3, 3),
              )) {
            session.hurtHero(
              outgoingDamage(attack.damage),
              origin: attack.origin,
              status: attack.power.status,
              dispel: attack.power == BossPower.dispel,
            );
          }
          session.game?.add(
            BossAttackVisual(session, this, attack, impact: true),
          );
        }
        bossAttack = null;
        slamTarget = null;
        slamClock = attack?.recovery ?? 5.5;
      }
      super.update(dt);
      return;
    }
    if (usesPounce &&
        attackClock <= 0 &&
        target.distance > 75 &&
        target.distance < pounceRange + 10 &&
        session.world.clearEnemyLine(
          position.toOffset(),
          session.hero.position.toOffset(),
          body.size,
        )) {
      bearing = math.atan2(target.dy, target.dx);
      pounceGoal =
          body.center +
          target / target.distance * math.min(pounceRange, target.distance);
      slamTarget = session.hero.body.center;
      windup = pounceWarning;
      stop();
      super.update(dt);
      return;
    }
    if (boss &&
        slamClock <= 0 &&
        target.distance < 620 &&
        session.world.clearEnemyLine(
          body.center,
          session.hero.body.center,
          const ui.Size(3, 3),
        )) {
      bearing = math.atan2(target.dy, target.dx);
      slamTarget = session.hero.body.center;
      // Ranged heroes must still face an aimed attack outside the old melee
      // strike's reach. Skip only that short strike; do not idle on it forever.
      final sequence = bossSequence == 0 && target.distance > 300
          ? 1
          : bossSequence;
      bossSequence = (sequence + 1) % BossPower.values.length;
      final attack = BossAttack.forStage(
        session.world.stage,
        body.center,
        slamTarget!,
        enraged: life.value < life.max * .5,
        sequence: sequence,
      );
      bossAttack = attack;
      windup = attack.warningTime;
      session.game?.add(BossAttackVisual(session, this, attack));
      stop();
      super.update(dt);
      return;
    }
    if (target.distance <
            (boss
                ? 64
                : usesBolt
                ? (definition?.attackRange ?? (kind == 'gunner' ? 350 : 280))
                : usesSweep
                ? sweepRange - 18
                : 42) &&
        session.world.clearEnemyLine(
          body.center,
          session.hero.body.center,
          const ui.Size(3, 3),
        )) {
      stop();
      if (attackClock <= 0) {
        if (usesSweep) {
          bearing = math.atan2(target.dy, target.dx);
          slamTarget = session.hero.body.center;
          windup = sweepWarning;
        } else if (usesBolt) {
          bearing = math.atan2(target.dy, target.dx);
          slamTarget = session.hero.body.center;
          windup = boltWarning;
        } else {
          attackClock = boss ? 1.05 : 1.3;
          bearing = math.atan2(target.dy, target.dx);
          meleeWindup = meleeWarning;
        }
      }
    } else if (hurt <= 0 && _knockbackTime <= 0) {
      ordinaryPursuit = true;
      var toward = session.hero.position.toOffset();
      final direct = session.world.clearEnemyLine(before, toward, body.size);
      if (_localIntent.active) {
        toward = _localIntent.points.first;
      } else if (!direct) {
        final targetMoved =
            routeGoal == null || (toward - routeGoal!).distance > 24;
        final blockedStep =
            route.isNotEmpty &&
            !session.world.clearEnemyLine(before, route.first, body.size);
        if ((replan <= 0 && (route.isEmpty || targetMoved)) || blockedStep) {
          route = session.world.routeEnemy(before, toward, body.size);
          routeGoal = toward;
          replan = route.isEmpty ? 1.2 : .6;
        }
        while (route.isNotEmpty &&
            (route.first - before).distance < .05 &&
            session.world.clearEnemyLine(before, route.first, body.size)) {
          before = route.removeAt(0);
          position.setValues(before.dx, before.dy);
        }
        if (route.isNotEmpty) {
          toward = route.first;
        } else {
          stop();
          super.update(dt);
          return;
        }
      }
      if (direct && !_localIntent.active) {
        route.clear();
        replan = 0;
      }
      final delta = toward - before;
      bearing = math.atan2(delta.dy, delta.dx);
      final pace = math.min(
        speed * (slow > 0 ? .45 : 1),
        delta.distance / math.max(.001, dt),
      );
      final step = inertia.advance(
        delta.distance > .001 ? delta / delta.distance * pace : ui.Offset.zero,
        dt,
      );
      moveByAngle(
        math.atan2(step.dy, step.dx),
        speed: step.distance / math.max(.001, dt),
      );
    } else {
      stop();
    }
    super.update(dt);
    final intendedStep = position.toOffset() - before;
    final next = session.moveEnemyBody(
      this,
      before,
      intendedStep,
      steer: hurt <= 0 && !velocity.isZero(),
    );
    if ((next - before).distanceSquared < .0001) inertia.stop();
    position.setValues(next.dx, next.dy);
    session.updateEnemySpacing(this);
    lastClearPosition = next;
    if (ordinaryPursuit && intentEligible) {
      _localIntent.observe(this, dt, before, intendedStep, next);
    }
  }

  void finishPounce() {
    pounceRemaining = 0;
    pounceGoal = null;
    attackClock = math.max(attackClock, definition?.attackRecovery ?? 3.2);
    stop();
  }

  void updatePounce(double dt) {
    stop();
    final used = math.min(dt, pounceRemaining);
    pounceRemaining -= used;
    final distance = pounceSpeed * used * (slow > 0 ? .45 : 1);
    final steps = math.max(1, (distance / 6).ceil());
    final step =
        ui.Offset(math.cos(pounceBearing), math.sin(pounceBearing)) *
        (distance / steps);
    for (var i = 0; i < steps; i++) {
      final from = position.toOffset();
      final at = session.moveEnemyBody(this, from, step, avoidHero: false);
      if ((at - from).distance < step.distance * .5) {
        finishPounce();
        break;
      }
      final candidate = ui.Rect.fromLTWH(at.dx, at.dy, size.x, size.y);
      if (candidate.overlaps(session.hero.body) &&
          session.world.clearEnemyLine(
            body.center,
            session.hero.body.center,
            const ui.Size(3, 3),
          )) {
        session.hurtHero(
          outgoingDamage(
            definition?.attackDamage ??
                (kind == 'scorpion'
                    ? 10
                    : kind == 'viper'
                    ? 6
                    : 8),
          ),
          origin: body.center,
          status: definition?.onHitStatus,
          statusPotency: outgoingDamage(1),
        );
        finishPounce();
        break;
      }
      position.setValues(at.dx, at.dy);
      session.updateEnemySpacing(this);
    }
    lastClearPosition = position.toOffset();
    if (pounceRemaining <= 0) finishPounce();
    super.update(dt);
  }

  @override
  void onRemove() {
    _localIntent.reset(this, terminal: true);
    combatReady = false;
    session.mobs.remove(this);
    session.enemySpacing.remove(this);
    super.onRemove();
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final feet = ui.Offset(size.x / 2, lowProfile ? size.y / 2 : size.y);
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: feet,
        width: boss ? 65 : 34,
        height: boss ? 22 : 12,
      ),
      ui.Paint()..color = const ui.Color(0x550d241b),
    );
    if (isElite) {
      canvas.drawOval(
        ui.Rect.fromCenter(center: feet, width: 46, height: 17),
        ui.Paint()..color = tierColor.withValues(alpha: .16),
      );
      canvas.drawOval(
        ui.Rect.fromCenter(center: feet, width: 46, height: 17),
        ui.Paint()
          ..color = tierColor.withValues(alpha: .8)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    if (wardWarning || wardActive) {
      final alpha = wardActive ? .8 : .25 + (wardPhase - 4) * .35;
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: feet - const ui.Offset(0, 23),
          width: 58,
          height: 78,
        ),
        ui.Paint()
          ..color = tierColor.withValues(alpha: alpha)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = wardActive ? 3 : 1.5,
      );
    }
    if (usesPounce && windup > 0 && pounceGoal != null) {
      final from = body.center - position.toOffset(),
          to = pounceGoal! - position.toOffset();
      final direction = to - from;
      final side = direction.distance > 0
          ? ui.Offset(-direction.dy, direction.dx) / direction.distance * 13
          : const ui.Offset(0, 13);
      final path = ui.Path()
        ..moveTo((from - side).dx, (from - side).dy)
        ..lineTo((to - side).dx, (to - side).dy)
        ..lineTo((to + side).dx, (to + side).dy)
        ..lineTo((from + side).dx, (from + side).dy)
        ..close();
      canvas.drawPath(
        path,
        ui.Paint()..color = attackColor.withValues(alpha: .26),
      );
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = attackColor
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawLine(
        from,
        from + direction * (1 - windup / pounceWarning).clamp(0, 1),
        ui.Paint()
          ..color =
              definition?.attackColor ??
              (kind == 'viper' ? attackColor : const ui.Color(0xffffc38c))
          ..strokeWidth = 4
          ..strokeCap = ui.StrokeCap.round,
      );
    }
    if (usesSweep && windup > 0) {
      final center = body.center - position.toOffset();
      final path = ui.Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          ui.Rect.fromCircle(center: center, radius: sweepRange),
          bearing - sweepAngle,
          sweepAngle * 2,
          false,
        )
        ..close();
      canvas.drawPath(
        path,
        ui.Paint()
          ..color =
              (definition?.attackColor?.withValues(alpha: .2) ??
              const ui.Color(0x33f78669)),
      );
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = definition?.attackColor ?? const ui.Color(0xffeaa085)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    if (usesBolt && windup > 0) {
      canvas.drawOval(
        ui.Rect.fromCenter(center: feet, width: 58, height: 22),
        ui.Paint()
          ..color = (technological ? attackColor : const ui.Color(0xffd567b6))
              .withValues(alpha: .6)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (technological) {
        final charge = (1 - windup / boltWarning).clamp(0.0, 1.0);
        final origin = body.center - position.toOffset();
        final aim = ui.Offset(math.cos(bearing), math.sin(bearing));
        canvas.drawLine(
          origin,
          origin + aim * (80 + charge * 180),
          ui.Paint()
            ..color = attackColor.withValues(alpha: .25 + charge * .4)
            ..strokeWidth = 1 + charge * 2,
        );
        canvas.drawCircle(
          lowProfile ? origin + aim * 18 : feet - const ui.Offset(0, 26),
          lowProfile ? 3 + charge * 5 : 5 + charge * 9,
          ui.Paint()..color = attackColor.withValues(alpha: .3 + charge * .5),
        );
      } else {
        paintCombatEffect(
          session,
          canvas,
          feet - const ui.Offset(0, 26),
          3,
          const ui.Size.square(76),
          opacity: .4 + .6 * (1 - windup / boltWarning),
        );
      }
    }
    if (stun > 0 || slow > 0) {
      final icy = slow > 0,
          color = icy ? const ui.Color(0xff9ce9ff) : const ui.Color(0xffffd67d);
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: feet,
          width: boss ? 70 : 42,
          height: boss ? 25 : 16,
        ),
        ui.Paint()..color = color.withValues(alpha: .35),
      );
      final mark = ui.Offset(size.x / 2, boss ? -140 : -58);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        canvas.drawLine(
          mark,
          mark + ui.Offset(math.cos(a) * 7, math.sin(a) * 7),
          ui.Paint()
            ..color = color
            ..strokeWidth = 2,
        );
      }
    }
    final anticipationOffset = preparingAttack
        ? ui.Offset(math.cos(bearing), math.sin(bearing)) * (-3 * anticipation)
        : attackMotion.offset;
    final releaseWindup = attackMotion.active
        ? (1 - (1 - attackMotion.remaining / EnemyAttackMotion.recovery) / .25)
              .clamp(0.0, 1.0)
        : 0.0;
    final bossPose = boss
        ? BossVisualPose(
            profile: switch (session.world.stage.bossActor) {
              'sand-warden' => BossMeshProfile.sandWarden,
              'ancient-king' => BossMeshProfile.ancientKing,
              'cyber-core' => BossMeshProfile.cyberCore,
              _ => BossMeshProfile.golem,
            },
            stride: motion.stride / (math.pi * 2),
            weight: preparingAttack || attackMotion.active ? 0 : motion.weight,
            windup: preparingAttack ? anticipation : releaseWindup,
            strike: attackMotion.extension,
            skill: bossAttack != null
                ? anticipation
                : attackMotion.pose == EnemyAttackPose.slam
                ? releaseWindup
                : 0,
            recoil: motion.recoil,
          )
        : null;
    canvas.save();
    if (!boss) {
      canvas.translate(feet.dx, feet.dy);
      canvas.rotate(motion.lean);
      canvas.scale(
        lowProfile ? 1 + motion.recoil * .035 : motion.scaleX,
        lowProfile ? 1 - motion.recoil * .04 : motion.scaleY,
      );
      canvas.translate(-feet.dx, -feet.dy);
    }
    session.art.actor(
      canvas,
      boss ? session.world.stage.bossActor : kind,
      boss
          ? feet
          : feet +
                anticipationOffset -
                ui.Offset(
                  0,
                  lowProfile
                      ? 0
                      : pounceRemaining > 0 && pounceDuration > 0
                      ? math.sin(
                              math.pi * (1 - pounceRemaining / pounceDuration),
                            ) *
                            15
                      : motion.lift,
                ),
      preparingAttack || pounceRemaining > 0
          ? bearing
          : attackMotion.active
          ? attackMotion.bearing
          : motion.facing,
      hurt > .08
          ? impactPose
          : preparingAttack
          ? 0
          : attackMotion.active
          ? 1
          : motion.phase,
      boss
          ? 125
          : isElite
          ? 76
          : definition?.renderHeight ?? 62,
      flash: hurt > .08 ? .75 : 0,
      bossPose: bossPose,
    );
    canvas.restore();
    attackMotion.paintMeleeTrace(
      canvas,
      feet - const ui.Offset(0, 19),
      attackColor,
      claws: const {
        'mummy',
        'wolf',
        'boar',
        'scorpion',
        'bonehound',
      }.contains(kind),
      large: boss,
    );
    if (life.value < life.max || boss || isElite) {
      final width = boss
              ? 100.0
              : isElite
              ? 44.0
              : 36.0,
          y = boss
              ? -100.0
              : lowProfile
              ? size.y / 2 - (isElite ? 76 : definition!.renderHeight) / 2 - 14
              : -48.0;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(size.x / 2 - width / 2, y, width, 6),
          const ui.Radius.circular(3),
        ),
        ui.Paint()..color = const ui.Color(0xcc241c18),
      );
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(
            size.x / 2 - width / 2 + 1,
            y + 1,
            (width - 2) * damageTrail.value,
            4,
          ),
          const ui.Radius.circular(2),
        ),
        ui.Paint()..color = const ui.Color(0xffffd895),
      );
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(
            size.x / 2 - width / 2 + 1,
            y + 1,
            (width - 2) * life.value / life.max,
            4,
          ),
          const ui.Radius.circular(2),
        ),
        ui.Paint()..color = isElite ? tierColor : const ui.Color(0xffe87753),
      );
      if (isElite) {
        final at = ui.Offset(size.x / 2 - width / 2 - 8, y + 3);
        canvas.save();
        canvas.translate(at.dx, at.dy);
        if (isUnique) {
          final crown = ui.Path()
            ..moveTo(-5, 3)
            ..lineTo(-6, -4)
            ..lineTo(-2, -1)
            ..lineTo(0, -6)
            ..lineTo(2, -1)
            ..lineTo(6, -4)
            ..lineTo(5, 3)
            ..close();
          canvas.drawPath(crown, ui.Paint()..color = tierColor);
        } else if (trait == EnemyTrait.armored) {
          final shield = ui.Path()
            ..moveTo(-4, -5)
            ..lineTo(4, -5)
            ..lineTo(4, 0)
            ..quadraticBezierTo(4, 3, 0, 6)
            ..quadraticBezierTo(-4, 3, -4, 0)
            ..close();
          canvas.drawPath(shield, ui.Paint()..color = tierColor);
        } else {
          final paint = ui.Paint()
            ..color = tierColor
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = ui.StrokeCap.round;
          for (final y in [-3.0, 3.0]) {
            canvas.drawLine(
              ui.Offset(-4, y + 2),
              ui.Offset.zero + ui.Offset(0, y - 2),
              paint,
            );
            canvas.drawLine(ui.Offset(0, y - 2), ui.Offset(4, y + 2), paint);
          }
        }
        canvas.restore();
      }
      if (boss) {
        final plate = ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(size.x / 2 - 74, y - 27, 148, 24),
          const ui.Radius.circular(6),
        );
        canvas.drawRRect(plate, ui.Paint()..color = const ui.Color(0xe810201f));
        canvas.drawRRect(
          plate,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const ui.Color(0x888eab71),
        );
        session.art.text(
          canvas,
          session.world.stage.bossName,
          ui.Offset(size.x / 2, y - 23),
          size: 14,
        );
      }
    }
  }
}

class LandscapeLayer extends GameComponent {
  LandscapeLayer(this.session) {
    position = Vector2.zero();
    size = Vector2(worldSize.width, worldSize.height);
  }
  final Adventure session;
  @override
  int get priority => 21;
  @override
  bool get isVisible => true;
  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final view = gameRef.camera.visibleWorldRect;
    if (view.left.isFinite &&
        view.top.isFinite &&
        view.width.isFinite &&
        view.width > 0) {
      session.terrain.render(canvas, view);
    }
  }
}

class WoodlandProp extends GameComponent with EffectVisibility {
  WoodlandProp(this.session, this.prop) {
    position = Vector2(prop.body.left, prop.body.top);
    size = Vector2(prop.body.width, prop.body.height);
  }
  final Adventure session;
  final WorldProp prop;
  @override
  ui.Rect get effectBounds {
    final feet = prop.body.bottomCenter;
    // Ruins and city props use square crops; natural props use drawSize.width.
    final width = math.max(prop.drawSize.width, prop.drawSize.height);
    return ui.Rect.fromLTWH(
      feet.dx - width / 2,
      feet.dy - prop.drawSize.height,
      width,
      prop.drawSize.height * 1.2,
    ).inflate(2);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(-position.x, -position.y);
    final hero = session.hero.body;
    final covers =
        (prop.kind == 'tree' ||
            prop.kind.startsWith('city-') ||
            prop.kind.startsWith('ruin-') ||
            prop.kind == 'blacksmith-forge') &&
        prop.body.bottom > hero.bottom &&
        prop.body.bottom - prop.drawSize.height < hero.bottom &&
        (prop.body.center.dx - hero.center.dx).abs() <
            prop.drawSize.width * .38;
    session.art.prop(
      canvas,
      prop,
      opacity: covers
          ? prop.kind == 'tree'
                ? .4
                : .55
          : 1,
    );
    canvas.restore();
  }

  @override
  bool get isVisible =>
      gameRef.camera.visibleWorldRect.overlaps(prop.body.inflate(230));
}

class WorldDirector extends GameComponent {
  WorldDirector(this.session);
  final Adventure session;
  final mountedProps = <WorldProp, WoodlandProp>{};
  double refreshTime = 0;
  @override
  bool get isVisible => true;
  @override
  void update(double dt) {
    super.update(dt);
    if (!session.ready) return;
    session.tick(math.min(dt, .05));
    refreshTime -= dt;
    if (refreshTime > 0) return;
    refreshTime = .35;
    final view = gameRef.camera.visibleWorldRect.inflate(230),
        visible = <WorldProp>{};
    for (
      var y = (view.top / 256).floor();
      y <= (view.bottom / 256).floor();
      y++
    ) {
      for (
        var x = (view.left / 256).floor();
        x <= (view.right / 256).floor();
        x++
      ) {
        visible.addAll(session.world.propBuckets['$x:$y'] ?? []);
      }
    }
    for (final prop in visible) {
      if (!mountedProps.containsKey(prop)) {
        final component = WoodlandProp(session, prop);
        mountedProps[prop] = component;
        gameRef.add(component);
      }
    }
    for (final prop in mountedProps.keys.toList()) {
      if (!visible.contains(prop)) {
        mountedProps.remove(prop)?.removeFromParent();
      }
    }
  }
}

class VillagePerson extends GameComponent {
  VillagePerson(this.session, this.merchant) {
    final at = merchant ? session.world.merchantAt : session.world.elderAt;
    position = Vector2(at.dx, at.dy);
    size = Vector2(28, 24);
  }
  final Adventure session;
  final bool merchant;
  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (!merchant || session.world.stage != WorldStage.forest) {
      session.art.actor(
        canvas,
        merchant ? 'merchant' : (session.stageContract?.actor ?? 'villager'),
        const ui.Offset(14, 24),
        math.pi / 2,
        0,
        64,
      );
      session.art.text(
        canvas,
        '!',
        const ui.Offset(14, -60),
        size: 22,
        color: const ui.Color(0xffffd371),
      );
    }
  }
}

class BattleText extends GameComponent {
  BattleText(this.session, this.label, ui.Offset at, this.color)
    : isReward = !RegExp(r'^-?\d+$').hasMatch(label) {
    position = Vector2(at.dx, at.dy);
    size = Vector2(160, 35);
  }
  final Adventure session;
  final String label;
  final bool isReward;
  final ui.Color color;
  double remaining = .9;
  ui.Paragraph? _paragraph;
  ui.Color? _paintedColor;
  double get textSize => label.startsWith('+') ? 13 : 18;
  ui.Rect get combatBounds => ui.Rect.fromLTWH(
    position.x - combatWidth / 2,
    position.y,
    combatWidth,
    24,
  );
  double get combatWidth => math.min(148, label.length * 12.0 + 6);

  bool placeWithoutOverlap(ui.Offset origin, List<BattleText> others) {
    final offset = combatWidth + 6;
    final occupied = others
        .where((t) => !t.isReward && !t.isRemoving && t.remaining > 0)
        .map((t) => t.combatBounds.inflate(2))
        .toList();
    final columns = combatWidth <= 66
        ? [0.0, -offset, offset]
        : [-offset / 2, offset / 2, 0.0];
    for (var row = 0; row < 6; row++) {
      for (final x in columns) {
        position.setValues(origin.dx + x, origin.dy - row * 28);
        final bounds = combatBounds.inflate(2);
        if (!occupied.any(bounds.overlaps)) {
          return true;
        }
      }
    }
    return false;
  }

  void releaseText() {
    _paragraph?.dispose();
    _paragraph = null;
    _paintedColor = null;
  }

  @override
  int get priority => 100000;
  @override
  bool get isVisible => true;
  @override
  void update(double dt) {
    if (!session.active) return;
    super.update(dt);
    remaining -= dt;
    position.y -= dt * 27;
    if (remaining <= 0) removeFromParent();
  }

  @override
  void onRemove() {
    releaseText();
    session.texts.remove(this);
    super.onRemove();
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (session.disposed || remaining <= 0 || isRemoving) return;
    final paintedColor = color.withValues(alpha: (remaining / .3).clamp(0, 1));
    if (_paragraph == null || _paintedColor != paintedColor) {
      releaseText();
      _paragraph = session.art.layoutText(
        label,
        size: textSize,
        color: paintedColor,
      );
      _paintedColor = paintedColor;
    }
    canvas.drawParagraph(_paragraph!, const ui.Offset(-80, 0));
  }
}

class EncounterStone extends GameComponent with EffectVisibility {
  EncounterStone(this.session, this.area) {
    session._encounterStones.add(this);
    position = Vector2(area.stone.dx - 22, area.stone.dy - 48);
    size = Vector2(44, 48);
  }
  final Adventure session;
  final EncounterArea area;
  final _spritePaint = ui.Paint();
  final _shadowPaint = ui.Paint()..color = const ui.Color(0x40000000);
  final _dotPaint = ui.Paint();
  final _hintBackingPaint = ui.Paint()..color = const ui.Color(0xa6000000);
  ui.Paragraph? _hint;
  ui.RRect? _hintBacking;
  int? _hintHits;

  @override
  int get priority => area.stone.dy.toInt();
  @override
  bool get isVisible => true;
  @override
  ui.Rect get effectBounds => EncounterBeaconArt.visualBounds.shift(area.stone);

  void releaseHint() {
    _hint?.dispose();
    _hint = null;
    _hintBacking = null;
    _hintHits = null;
  }

  @override
  void onRemove() {
    releaseHint();
    session._encounterStones.remove(this);
    super.onRemove();
  }

  @override
  void render(ui.Canvas canvas) {
    if (session.disposed || area.waves < EncounterArea.waveLimit) return;
    final ready = !session.areaHasEnemies(area.key);
    canvas.save();
    canvas.translate(22, 48);
    if (ready && (session.hero.body.center - area.stone).distance < 220) {
      if (_hint == null || _hintHits != area.stoneHits) {
        _hint?.dispose();
        _hint = session.art.layoutText(
          '공격해 재소환 · ${area.stoneHits}/3',
          size: 11,
          color: const ui.Color(0xffb9e9d9),
        );
        _hintBacking = ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(
            -_hint!.longestLine / 2 - 6,
            EncounterBeaconArt.hintTextOrigin.dy - 2,
            _hint!.longestLine + 12,
            _hint!.height + 4,
          ),
          const ui.Radius.circular(4),
        );
        _hintHits = area.stoneHits;
      }
      canvas.drawRRect(_hintBacking!, _hintBackingPaint);
      canvas.drawParagraph(_hint!, EncounterBeaconArt.hintTextOrigin);
    }
    canvas.drawOval(EncounterBeaconArt.shadowBounds, _shadowPaint);
    final image = session.art.images['encounter-beacons'];
    if (image != null) {
      EncounterBeaconArt.draw(
        canvas,
        image,
        session.world.stage,
        ready: ready,
        paint: _spritePaint,
      );
    } else {
      canvas.save();
      canvas.translate(-22, -48);
      _renderFallback(canvas, ready);
      canvas.restore();
    }
    final glow = ready
        ? const ui.Color(0xff9debd8)
        : const ui.Color(0xff52635e);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        ui.Offset(-9 + i * 9, 3),
        2,
        _dotPaint
          ..color = i < area.stoneHits ? glow : const ui.Color(0xff344b45),
      );
    }
    canvas.restore();
  }

  void _renderFallback(ui.Canvas canvas, bool ready) {
    final shape = ui.Path()
      ..moveTo(6, 44)
      ..lineTo(9, 8)
      ..lineTo(16, 0)
      ..lineTo(32, 2)
      ..lineTo(38, 44)
      ..close();
    canvas.drawPath(shape, ui.Paint()..color = const ui.Color(0xff677572));
    canvas.drawPath(
      shape,
      ui.Paint()
        ..color = const ui.Color(0xffa4b3a2)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      ui.Path()
        ..moveTo(23, 10)
        ..lineTo(16, 23)
        ..lineTo(23, 34)
        ..lineTo(30, 23)
        ..close(),
      ui.Paint()
        ..color = ready
            ? const ui.Color(0xff9debd8)
            : const ui.Color(0xff52635e)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}
