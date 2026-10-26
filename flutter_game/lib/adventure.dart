import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_settings.dart';
import 'battle_effects.dart';
import 'boss_attacks.dart';
import 'device_settings.dart';
import 'encounters.dart';
import 'enemy_catalog.dart';
import 'enemy_motion.dart';
import 'game_art.dart';
import 'ranked_vfx.dart';
import 'shop_content.dart';
import 'skill_aim.dart';
import 'spell_vfx.dart';
import 'world_model.dart';

enum NearbyAction { chest, shrine, mount, dismount, shop, talk }

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
    HeroClass heroClass = HeroClass.warrior,
    Progress? restoredProgress,
    DeviceSettings? device,
    AudioSettings? audio,
  }) : world = AdventureWorld(seed: seed, stage: stage),
       progress = restoredProgress ?? Progress(heroClass: heroClass),
       device = device ?? DeviceSettings.shared,
       audio = audio ?? AudioSettings.shared {
    if (stage == WorldStage.past) timePath = TimePath.past;
    if (stage == WorldStage.future) timePath = TimePath.future;
    hero = Guardian(this);
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
    if (!active || riding != null || hero.dashing > 0 || hero.physicalAction) {
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
    const size = ui.Size(28, 24);
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

  final openedChests = <int>{};
  final cleansedSites = <String>{};
  String? trackedSiteId;
  QuestSite? get trackedSite {
    for (final site in visibleSites) {
      if (site.id == trackedSiteId && canTrackSite(site)) return site;
    }
    return null;
  }

  bool canTrackSite(QuestSite site) {
    if (disposed ||
        defeated ||
        cleansedSites.contains(site.id) ||
        !visibleSites.any((s) => s.id == site.id)) {
      return false;
    }
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
            .where((q) => timePath == null ? q.step == 0 : q.path == timePath)
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
  bool acceptCommission(CommissionDef q) {
    if (!timeCommissions.contains(q) || !canAcceptCommission(q)) return false;
    timePath = q.path;
    acceptedCommission = q.id;
    commissionStartKills = progress.kills;
    refresh();
    return true;
  }

  bool get mandatoryQuestsComplete => world.stage == WorldStage.sands
      ? timePath != null &&
            timeCommissions
                .where((q) => q.path == timePath)
                .every((q) => cleansedSites.contains(q.id))
      : world.sites.every((q) => cleansedSites.contains(q.id));
  bool get stageCleared => progress.bossDefeated && mandatoryQuestsComplete;
  QuestSite? get nearbySite {
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
    if (trackedSiteId == site.id) trackedSiteId = null;
    if (commission != null) {
      acceptedCommission = null;
      progress.gainXp(50 + commission.step * 20);
      syncLife();
    }
    progress.gold += 40;
    progress.healingPotions++;
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
    if (!stageCleared || won) return;
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
    for (final raw in List<Map<String, dynamic>>.of(dormantEnemies)) {
      final at = ui.Offset(
        (raw['x'] as num).toDouble(),
        (raw['y'] as num).toDouble(),
      );
      if (living >= 40 || (at - hero.body.center).distance > 1100) continue;
      final mob = spawnEnemy(
        raw['kind'] as String,
        at,
        trait: EnemyTrait.values.firstWhere((t) => t.name == raw['trait']),
      );
      if (mob == null) continue;
      mob.encounterKey = raw['area'] as String?;
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
  String get region => world.areaName(hero.position.toOffset());
  NearbyAction? get nearbyAction {
    if (riding != null) return NearbyAction.dismount;
    if (nearbySite != null) return NearbyAction.shrine;
    if (nearbyChest != null) return NearbyAction.chest;
    if (nearbyMount != null) return NearbyAction.mount;
    final at = hero.position.toOffset();
    final shop = (at - world.merchantAt).distance;
    final talk = (at - world.elderAt).distance;
    if (talk < 135 && (shop >= 165 || talk < shop)) return NearbyAction.talk;
    if (shop < 165) return NearbyAction.shop;
    return null;
  }

  int? get nearbyChest {
    for (var i = 0; i < stageChestLocations.length; i++) {
      if (!openedChests.contains(i) &&
          (hero.body.center - stageChestLocations[i]).distance < 110 &&
          world.clearLine(
            hero.body.center,
            stageChestLocations[i],
            const ui.Size(3, 3),
          )) {
        return i;
      }
    }
    return null;
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
    if (!active || index == null) return;
    audio.play(EffectSound.loot);
    device.pulse(FeedbackKind.loot);
    openedChests.add(index);
    progress.gold += 18;
    final potionFound = openedChests.length % 4 == 1;
    if (potionFound) progress.healingPotions++;
    dropGear(
      progress.rollLoot(random, chest: true),
      stageChestLocations[index],
    );
    bubble(
      potionFound ? '+18 골드 · 물약 +1' : '+18 골드',
      stageChestLocations[index] - const ui.Offset(0, 55),
      const ui.Color(0xffffd774),
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
    if (defeated || disposed || !progress.resetSkills()) return false;
    buildRevision++;
    releaseInput();
    hero.armorTime = hero.frenzyTime = hero.spin = 0;
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
      final restored = math.min(60.0, progress.maxEnergy - progress.energy);
      progress.energyPotions--;
      progress.energy = math.min(progress.maxEnergy, progress.energy + 60);
      bubble(
        '+${restored.ceil()} ${progress.heroClass.resource}',
        hero.body.center - const ui.Offset(0, 80),
        const ui.Color(0xff9fdfff),
      );
    } else {
      if (progress.healingPotions <= 0 || progress.hp >= progress.maxHp) return;
      final restored = math.min(55.0, progress.maxHp - progress.hp);
      progress.healingPotions--;
      progress.hp = math.min(progress.maxHp, progress.hp + 55);
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
    waveTime = 10;
    if (!restoredEncounters) {
      spawnPack(
        initial: (hero.position.toOffset() - world.spawn).distance < 220,
      );
    }
    refresh();
  }

  void tick(double dt) {
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
    if (waveTime <= 0 && elapsed - lastPackSpawn >= 8) {
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
    if (!active || living >= 40 || riding?.def.waterOnly == true) {
      return;
    }
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
      initial
          ? 6
          : progress.level < 3
          ? 8
          : living < 12
          ? 12
          : 10,
      40 - living,
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
          ? world.spawn + ui.Offset(-60 + (i % 3) * 62, 165 + (i % 2) * 50)
          : at + ui.Offset(math.cos(angle) * r, math.sin(angle) * r);
      final kind = initial && world.stage == WorldStage.forest
          ? ['goblin', 'wolf', 'goblin'][i % 3]
          : population[(i + progress.level) % population.length];
      final trait = elitePack && added == eliteSlot
          ? ((_successfulPacks ~/ 3).isEven
                ? EnemyTrait.armored
                : EnemyTrait.swift)
          : EnemyTrait.none;
      final mob = spawnEnemy(kind, desired, trait: trait);
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

  HuntEnemy? spawnEnemy(
    String kind,
    ui.Offset desired, {
    bool boss = false,
    EnemyTrait trait = EnemyTrait.none,
  }) {
    final size = boss ? const ui.Size(48, 40) : const ui.Size(24, 22);
    final p = world.spawnNear(desired, size);
    if (p == null) return null;
    if (mobs.any(
      (e) =>
          !e.isDead &&
          !e.isRemoving &&
          !e.encounterDormant &&
          e.body.overlaps(
            ui.Rect.fromLTWH(p.dx, p.dy, size.width, size.height),
          ),
    )) {
      return null;
    }
    final enemy = HuntEnemy(
      this,
      kind,
      p,
      boss: boss,
      trait: boss ? EnemyTrait.none : trait,
    );
    enemy.life.initial(
      enemy.life.max * 2 * (1 + (progress.level - 1) * (boss ? .15 : .08)),
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
      same.first.removeFromParent();
      texts.remove(same.first);
    }
    texts.add(next);
    game?.add(next);
  }

  void hurtHero(double damage) {
    if (!active || hero.invulnerable > 0) return;
    combatTime = 5;
    damage = progress.mitigate(damage, protection: hero.protection);
    if (progress.weapon.gift == WeaponGift.guardian) damage *= .92;
    if (hero.armorTime > 0 && progress.heroClass == HeroClass.mage) {
      for (final mob in mobs.where(
        (m) => (m.body.center - hero.body.center).distance < 85,
      )) {
        mob.slow = math.max(mob.slow, 2);
      }
    }
    if (progress.heroClass == HeroClass.warrior) {
      progress.energy = math.min(progress.maxEnergy, progress.energy + 7);
    }
    audio.play(EffectSound.hurt);
    device.pulse(FeedbackKind.hurt);
    wearMount(math.max(1, damage * .6));
    progress.hp = math.max(0, progress.hp - damage);
    hero.life.remove(damage);
    hero.invulnerable = .65;
    hero.hurtFlash = .12;
    bubble(
      '-${damage.toInt()}',
      hero.position.toOffset() - const ui.Offset(0, 65),
      const ui.Color(0xffff8a72),
    );
    if (progress.hp <= 0) {
      defeated = true;
      audio.stop();
      releaseInput();
      game?.pauseEngine();
    }
    refresh();
  }

  void hit(
    HuntEnemy mob,
    double damage,
    ui.Offset impulse, {
    bool generateRage = false,
  }) {
    if (!active || !mob.combatReady || mob.isDead || mob.isRemoving) return;
    combatTime = 5;
    mob.life.remove(damage);
    if (progress.weapon.gift == WeaponGift.frost && !mob.isDead) {
      mob.slow = math.max(mob.slow, .8);
    }
    if (generateRage &&
        progress.heroClass == HeroClass.warrior &&
        rageStrike != hero.strikes) {
      rageStrike = hero.strikes;
      final heavy = progress.weapon.base.style == 'hammer' || combo == 0;
      hero.impactHold = heavy ? .055 : .035;
      hero.swing = math.min(hero.swing, .16);
      kickCamera(heavy ? 2.1 : .95);
      game?.add(
        ContactSpark(
          this,
          mob.body.center - const ui.Offset(0, 28),
          heavy: heavy,
          rank: progress.rank('cleave'),
          bearing: math.atan2(impulse.dy, impulse.dx),
        ),
      );
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
    final old = mob.position.toOffset(),
        p = world.move(old, impulse, mob.body.size);
    mob.position.setValues(p.dx, p.dy);
    bubble(
      '${damage.round()}',
      mob.position.toOffset() - ui.Offset(0, mob.boss ? 125 : 70),
      const ui.Color(0xffffedb4),
    );
    if (mob.isDead && !mob.rewarded) {
      mob.rewarded = true;
      final level = progress.level, goldBefore = progress.gold;
      progress.reward(boss: mob.boss, elite: mob.isElite);
      if (progress.weapon.gift == WeaponGift.renewal && progress.hp > 0) {
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
      if (mob.boss || mob.isElite || progress.kills % 20 == 0) {
        dropGear(
          progress.rollLoot(random, boss: mob.boss, elite: mob.isElite),
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
      if (!mob.boss && progress.kills % 36 == 0) progress.healingPotions++;
      if (!mob.boss && progress.kills % 48 == 0) progress.energyPotions++;
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
  }

  bool get canTrade => ready && !disposed && !defeated && progress.hp > 0;
  bool buyHeal() =>
      canTrade && progress.buy(20, () => progress.healingPotions += 2);
  ShopGearOffer gearOffer(GearDef def) => ShopGearOffer(def, world.stage);
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
      progress.inventory.add(bought!);
      progress.unseenGear.add(bought!.serial);
    });
    return bought;
  }

  bool buyEnergy() =>
      canTrade && progress.buy(18, () => progress.energyPotions += 2);
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
    disposed = true;
    audio.stop();
    device.cancel();
    releaseInput();
    terrain.dispose();
    super.dispose();
  }
}

class Guardian extends Player with WithCollision {
  Guardian(this.session)
    : super(
        position: Vector2(session.world.spawn.dx, session.world.spawn.dy),
        size: Vector2(24, 22),
        speed: 270,
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
    final def = session.progress.skillAt(slot);
    if (!session.active ||
        dashing > 0 ||
        physicalAction ||
        def == null ||
        (cooldowns[def.id] ?? 0) > 0) {
      return;
    }
    if (!session.ensureOnFoot()) return;
    queuedCast = null;
    aim = SkillAim(slot, def.id, bearing);
  }

  void moveAim(ui.Offset delta) {
    if (!session.active) {
      aim = null;
      return;
    }
    aim?.delta = delta;
  }

  void finishAim(bool cancelled) {
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
  double rollBearing = math.pi / 2;
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
  double impactHold = 0;
  double swingDuration = .23, castLock = 0, comboGrace = 0;
  int strikePose = 0;
  double chargeTime = 0, chargeAngle = 0, chargeDamage = 0, chargeSpeed = 900;
  double spinDuration = .5;
  int chargeCap = 0;
  final chargeVictims = <HuntEnemy>{};
  double heavyWindup = 0, heavyPower = 0, heavyAngle = 0;
  SkillDef? heavySkill;
  bool get physicalAction => chargeTime > 0 || heavyWindup > 0 || spin > 0;
  void heavyImpact() {
    final def = heavySkill;
    heavySkill = null;
    if (def == null || !session.active) return;
    final enemies =
        session.mobs.where((m) {
          final d = m.body.center - body.center;
          return m.combatReady &&
              !m.isDead &&
              !m.isRemoving &&
              d.distance < 185 &&
              math
                      .atan2(
                        math.sin(math.atan2(d.dy, d.dx) - heavyAngle),
                        math.cos(math.atan2(d.dy, d.dx) - heavyAngle),
                      )
                      .abs() <
                  1.05 &&
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
    for (final mob in enemies.take(session.progress.skillTargetLimit(def))) {
      session.hit(
        mob,
        heavyPower,
        ui.Offset(math.cos(heavyAngle), math.sin(heavyAngle)) * 48,
      );
      mob.stun = math.max(mob.stun, .55);
      session.game?.add(
        ContactSpark(
          session,
          mob.body.center - const ui.Offset(0, 25),
          heavy: true,
          rank: session.progress.rank('crushingBlow'),
          bearing: heavyAngle,
        ),
      );
    }
    session.game?.add(
      GroundStrike(
        session,
        body.center +
            ui.Offset(math.cos(heavyAngle), math.sin(heavyAngle)) * 80,
        rank: session.progress.rank('crushingBlow'),
        tempo: session.progress.skillTempo(def),
        bearing: heavyAngle,
        directional: true,
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
    if (aim != null) aim!.heldFor += dt;
    speed =
        session.riding?.speed ??
        (frenzyTime > 0 ? session.progress.frenzyMoveSpeed : 270);
    if (castLock > 0) speed *= .4;
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
          speed *
          1.9 *
          math.min(dt, dashing);
      dashing -= dt;
    }
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
      for (final mob in session.mobs.toList()) {
        if (chargeVictims.length >= chargeCap) {
          chargeTime = 0;
          break;
        }
        if (!mob.combatReady ||
            mob.isDead ||
            mob.isRemoving ||
            chargeVictims.contains(mob)) {
          continue;
        }
        final swept = ui.Rect.fromPoints(before, p).inflate(42);
        if (swept.overlaps(mob.body) &&
            session.world.clearLine(
              body.center,
              mob.body.center,
              const ui.Size(3, 3),
            )) {
          chargeVictims.add(mob);
          session.hit(
            mob,
            chargeDamage,
            ui.Offset(math.cos(chargeAngle), math.sin(chargeAngle)) * 45,
          );
          mob.stun = math.max(mob.stun, .4);
          session.game?.add(
            ContactSpark(
              session,
              mob.body.center - const ui.Offset(0, 22),
              heavy: true,
              rank: session.progress.rank('charge'),
            ),
          );
          session.kickCamera(.9);
        }
      }
      attackBearing = bearing = chargeAngle;
      strikePose = 1;
      swingDuration = .36;
      swing = .16;
    }
    if (heavyWindup > 0) {
      heavyWindup = math.max(0, heavyWindup - dt);
      if (heavyWindup == 0) heavyImpact();
    }
    lastClearPosition = p;
    // Follow the resolved body directly. Bonfire's smoothed follower can overshoot a dash.
    if (hasGameRef) gameRef.camera.position = session.cameraFocus;
    if (delta.distance > .1) {
      animationTime += dt;
      session.riding?.bearing = math.atan2(delta.dy, delta.dx);
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
    if (!session.active ||
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
                  !e.isDead &&
                  e.combatReady &&
                  !e.isRemoving &&
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
    attackBearing = angle;
    strikes++;
    if (comboGrace <= 0) session.combo = 0;
    strikePose = session.combo;
    session.combo = (session.combo + 1) % 3;
    comboGrace = 1.2;
    attackClock = math.max(
      .12,
      session.progress.attackInterval /
          (frenzyTime > 0 ? session.progress.frenzyAttackTempo : 1),
    );
    swingDuration = (strikePose == 2 ? .32 : .26) / session.progress.basicTempo;
    swing = swingDuration;
    final p = session.progress;
    if (p.heroClass == HeroClass.mage) {
      castLock = .26 / p.basicTempo;
      swingDuration = swing = .32 / p.basicTempo;
    }
    if (candidates.isEmpty &&
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
          : switch (p.weapon.base.style) {
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
          element: p.weapon.base.style,
          launchDelay: .13 / p.basicTempo,
          rank: p.rank('firebolt'),
          caster: this,
          explosive: p.rank('firebolt') >= 3,
          targetLimit: p.basicTargetLimit,
        ),
      );
      return;
    }

    final melee =
        session.mobs.where((mob) {
          if (!mob.combatReady || mob.isDead || mob.isRemoving) return false;
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
    for (final mob in melee.take(p.basicTargetLimit)) {
      final d = mob.body.center - body.center;
      final push = d.distance > 0
          ? d / d.distance * (p.weapon.base.style == 'hammer' ? 42 : 23)
          : const ui.Offset(0, 23);
      session.hit(
        mob,
        p.basicDamage * (session.combo == 0 ? 1.6 : 1),
        push,
        generateRage: true,
      );
    }
  }

  void skill({bool secondary = false, int? slot, SkillAim? manualAim}) {
    if (!session.active ||
        dashing > 0 ||
        physicalAction ||
        !session.ensureOnFoot()) {
      return;
    }
    final p = session.progress;
    final slotIndex = slot ?? (secondary ? 1 : 0);
    final def = p.skillAt(slotIndex);
    if (def == null) return;
    final rank = p.rank(def.id);
    if (!session.active || (cooldowns[def.id] ?? 0) > 0 || rank == 0) return;
    if (p.energy < def.cost) {
      session.bubble(
        '${p.heroClass.resource} 부족',
        body.center - const ui.Offset(0, 75),
        const ui.Color(0xffffc08d),
      );
      return;
    }
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
    }
    switch (def.id) {
      case 'charge':
        chargeAngle = manualAim?.angle ?? bearing;
        chargeDamage = p.skillDamage(def);
        chargeCap = p.skillTargetLimit(def);
        chargeVictims.clear();
        chargeTime = p.skillMotionTime(def);
        chargeSpeed = 324 / chargeTime;
        attackClock = math.max(attackClock, chargeTime + .06);
      case 'crushingBlow':
        heavyAngle = manualAim?.angle ?? bearing;
        heavyPower =
            p.skillDamage(def) *
            (1 +
                .8 *
                    ((manualAim?.heldFor ?? 0) / p.heavyChargeTime).clamp(
                      0,
                      1,
                    ));
        heavySkill = def;
        heavyWindup = p.skillMotionTime(def);
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
                      m.combatReady &&
                      !m.isDead &&
                      !m.isRemoving &&
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
          stun: .65 + rank * .08,
          slow: 1.5,
          maxTargets: p.skillTargetLimit(def),
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
          slow: p.novaSlowDuration,
          maxTargets: p.skillTargetLimit(def),
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
        (animationTime / .13).floor() % 2,
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
      session.art.actor(
        canvas,
        session.progress.heroClass == HeroClass.mage ? 'mage' : 'hero',
        feet,
        spin > 0
            ? bearing + (1 - spin / spinDuration) * math.pi * 4
            : swing > 0
            ? attackBearing
            : bearing,
        spin > 0
            ? 1
            : heavyWindup > 0 || aim?.id == 'crushingBlow'
            ? 0
            : swing > 0
            ? (swing > swingDuration * .58 ? 0 : 1)
            : (animationTime / .13).floor() % 2,
        60,
        attack: swing > 0 || spin > 0 || aim?.id == 'crushingBlow',
        comboPose: spin > 0 ? 1 : strikePose,
        flash: damageFlash,
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
      paintRankImpact(
        canvas,
        center,
        (session.elapsed * 3) % 1,
        session.progress.rank('crushingBlow'),
        const ui.Color(0xffffe0a4),
        radius: 28,
      );
      final held = aim?.heldFor ?? session.progress.heavyChargeTime;
      canvas.drawArc(
        ui.Rect.fromCenter(center: feet, width: 44, height: 18),
        -math.pi / 2,
        math.pi * 2 * (held / session.progress.heavyChargeTime).clamp(0, 1),
        false,
        ui.Paint()
          ..color = const ui.Color(0xffffd893)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    final currentAim = aim;
    if (currentAim != null) {
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

class HuntEnemy extends Enemy with WithCollision {
  HuntEnemy(
    this.session,
    this.kind,
    ui.Offset at, {
    this.boss = false,
    this.trait = EnemyTrait.none,
  }) : super(
         position: Vector2(at.dx, at.dy),
         size: boss ? Vector2(48, 40) : Vector2(24, 22),
         life:
             (boss ? 1800 : (enemyCatalog[kind]?.health ?? 52)) *
             (boss ? 1 : trait.healthScale),
         speed:
             (boss ? 90 : (enemyCatalog[kind]?.speed ?? 105)) *
             (boss ? 1 : trait.speedScale),
       );
  final Adventure session;
  final String kind;
  String? encounterKey;
  final bool boss;
  final EnemyTrait trait;
  bool get isElite => !boss && trait != EnemyTrait.none;
  bool get usesPounce => !boss && enemyCatalog[kind]?.pattern == 'pounce';
  bool get usesSweep => !boss && enemyCatalog[kind]?.pattern == 'sweep';
  bool get usesBolt => !boss && enemyCatalog[kind]?.pattern == 'bolt';
  double get pounceWarning => kind == 'scorpion' ? .58 : .42;
  double get pounceSpeed => kind == 'scorpion' ? 440 : 520;
  double get pounceRange => kind == 'scorpion' ? 200 : 240;
  double get sweepRange => kind == 'troll'
      ? 120
      : kind == 'cyber'
      ? 110
      : 100;
  double get sweepAngle => kind == 'troll'
      ? 1.05
      : kind == 'cyber'
      ? .95
      : .85;
  double get sweepWarning => kind == 'troll'
      ? .85
      : kind == 'cyber'
      ? .65
      : .5;
  double get sweepDamage => kind == 'troll'
      ? 14
      : kind == 'cyber'
      ? 10
      : 8;
  double get sweepRecovery => kind == 'troll'
      ? 2.6
      : kind == 'cyber'
      ? 2.1
      : 1.8;
  double get boltWarning => kind == 'gunner' ? .8 : .65;
  ui.Color get attackColor => kind == 'basilisk'
      ? const ui.Color(0xffb2df73)
      : kind == 'gunner' || kind == 'drone'
      ? const ui.Color(0xff7feafa)
      : kind == 'scorpion'
      ? const ui.Color(0xffbcda75)
      : const ui.Color(0xffefab78);
  int impactPose = 0;
  final motion = EnemyMotion();
  bool rewarded = false, combatReady = false, encounterDormant = false;
  double bearing = math.pi / 2,
      hurt = 0,
      attackClock = 1,
      replan = 0,
      stun = 0,
      slow = 0;
  List<ui.Offset> route = [];
  double slamClock = 4, windup = 0;
  double pounceRemaining = 0, pounceDuration = 0, pounceBearing = 0;
  ui.Offset? pounceGoal;
  ui.Offset? slamTarget;
  BossAttack? bossAttack;
  ui.Offset? routeGoal;
  ui.Offset? lastClearPosition;
  ui.Rect get body => ui.Rect.fromLTWH(position.x, position.y, size.x, size.y);
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
      if (session.world.blocked(body)) {
        final safe = lastClearPosition;
        if (safe != null) position.setValues(safe.dx, safe.dy);
      }
    });
  }

  @override
  void update(double dt) {
    if (!session.active || !combatReady || isDead || isRemoving) return;
    dt = math.min(dt, .05);
    final before = position.toOffset();
    _updateBehavior(dt);
    motion.update(
      dt,
      distance: (position.toOffset() - before).distance,
      bearing: bearing,
    );
  }

  void _updateBehavior(double dt) {
    var before = position.toOffset();
    final target = session.hero.body.center - body.center;
    hurt = math.max(0, hurt - dt);
    stun = math.max(0, stun - dt);
    slow = math.max(0, slow - dt);
    attackClock -= dt;
    replan -= dt;
    slamClock -= dt;
    if (target.distance > 950 && !(boss && windup > 0)) {
      stop();
      return;
    }
    if (stun > 0) {
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
        slamTarget = null;
      }
      super.update(dt);
      return;
    }
    if (usesSweep && windup > 0) {
      stop();
      windup -= dt;
      if (windup <= 0) {
        final angle = math.atan2(target.dy, target.dx);
        final difference = math.atan2(
          math.sin(angle - bearing),
          math.cos(angle - bearing),
        );
        if (target.distance < sweepRange &&
            difference.abs() < sweepAngle &&
            session.world.clearLine(
              body.center,
              session.hero.body.center,
              const ui.Size(3, 3),
            )) {
          session.hurtHero(sweepDamage);
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
        final locked = slamTarget;
        if (locked != null) {
          final toward = locked - body.center;
          session.game?.add(
            ShadowBolt(
              session,
              body.center,
              math.atan2(toward.dy, toward.dx),
              technological: kind == 'gunner' || kind == 'drone',
              venomous: kind == 'basilisk',
              damage: kind == 'gunner' ? 10 : 8,
            ),
          );
        }
        slamTarget = null;
        attackClock = kind == 'gunner' ? 3.2 : 2.8;
      }
      super.update(dt);
      return;
    }
    if (boss && windup > 0) {
      stop();
      windup -= dt;
      if (windup <= 0) {
        final attack = bossAttack;
        if (attack != null) {
          final hero = session.hero.body.center;
          if (attack.zones.any(
                (zone) =>
                    zone.contains(hero) &&
                    session.world.clearLine(
                      zone.center,
                      hero,
                      const ui.Size(3, 3),
                    ),
              ) &&
              session.world.clearLine(
                attack.origin,
                hero,
                const ui.Size(3, 3),
              )) {
            session.hurtHero(attack.damage);
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
        session.world.clearLine(
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
        target.distance <
            (session.world.stage == WorldStage.past ? 260 : 340) &&
        session.world.clearLine(
          body.center,
          session.hero.body.center,
          const ui.Size(3, 3),
        )) {
      slamTarget = session.hero.body.center;
      final attack = BossAttack.forStage(
        session.world.stage,
        body.center,
        slamTarget!,
        enraged: life.value < life.max * .5,
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
                ? (kind == 'gunner' ? 350 : 280)
                : usesSweep
                ? sweepRange - 18
                : 42) &&
        session.world.clearLine(
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
          session.hurtHero(
            boss
                ? 15
                : kind == 'wolf'
                ? 6
                : 4,
          );
        }
      }
    } else if (hurt <= 0) {
      var toward = session.hero.position.toOffset();
      final direct = session.world.clearLine(before, toward, body.size);
      if (!direct) {
        final targetMoved =
            routeGoal == null || (toward - routeGoal!).distance > 24;
        final blockedStep =
            route.isNotEmpty &&
            !session.world.clearLine(before, route.first, body.size);
        if ((replan <= 0 && (route.isEmpty || targetMoved)) || blockedStep) {
          route = session.world.route(before, toward, body.size);
          routeGoal = toward;
          replan = route.isEmpty ? 1.2 : .6;
        }
        while (route.isNotEmpty &&
            (route.first - before).distance < .05 &&
            session.world.clearLine(before, route.first, body.size)) {
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
      if (direct) {
        route.clear();
        replan = 0;
      }
      final delta = toward - before;
      bearing = math.atan2(delta.dy, delta.dx);
      moveByAngle(
        bearing,
        speed: math.min(
          speed * (slow > 0 ? .45 : 1),
          delta.distance / math.max(.001, dt),
        ),
      );
    } else {
      stop();
    }
    super.update(dt);
    final next = session.world.move(
      before,
      position.toOffset() - before,
      body.size,
    );
    position.setValues(next.dx, next.dy);
    lastClearPosition = next;
  }

  void finishPounce() {
    pounceRemaining = 0;
    pounceGoal = null;
    attackClock = math.max(attackClock, 3.2);
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
      final at = session.world.move(from, step, body.size);
      if ((at - from).distance < step.distance * .5) {
        finishPounce();
        break;
      }
      final candidate = ui.Rect.fromLTWH(at.dx, at.dy, size.x, size.y);
      if (candidate.overlaps(session.hero.body) &&
          session.world.clearLine(
            body.center,
            session.hero.body.center,
            const ui.Size(3, 3),
          )) {
        session.hurtHero(kind == 'scorpion' ? 10 : 8);
        finishPounce();
        break;
      }
      if (session.mobs.any(
        (other) =>
            other != this &&
            other.combatReady &&
            !other.isDead &&
            !other.isRemoving &&
            candidate.overlaps(other.body),
      )) {
        finishPounce();
        break;
      }
      position.setValues(at.dx, at.dy);
    }
    lastClearPosition = position.toOffset();
    if (pounceRemaining <= 0) finishPounce();
    super.update(dt);
  }

  @override
  void onRemove() {
    combatReady = false;
    session.mobs.remove(this);
    super.onRemove();
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final feet = ui.Offset(size.x / 2, size.y);
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
        ui.Paint()..color = trait.color.withValues(alpha: .16),
      );
      canvas.drawOval(
        ui.Rect.fromCenter(center: feet, width: 46, height: 17),
        ui.Paint()
          ..color = trait.color.withValues(alpha: .8)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5,
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
          ..color = const ui.Color(0xffffc38c)
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
      canvas.drawPath(path, ui.Paint()..color = const ui.Color(0x33f78669));
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0xffeaa085)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    if (usesBolt && windup > 0) {
      canvas.drawOval(
        ui.Rect.fromCenter(center: feet, width: 58, height: 22),
        ui.Paint()
          ..color =
              (kind == 'gunner' ? attackColor : const ui.Color(0xffd567b6))
                  .withValues(alpha: .6)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (kind == 'gunner') {
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
          feet - const ui.Offset(0, 26),
          5 + charge * 9,
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
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.rotate(motion.lean);
    canvas.scale(motion.scaleX, motion.scaleY);
    canvas.translate(-feet.dx, -feet.dy);
    session.art.actor(
      canvas,
      boss ? session.world.stage.bossActor : kind,
      feet -
          ui.Offset(
            0,
            pounceRemaining > 0 && pounceDuration > 0
                ? math.sin(math.pi * (1 - pounceRemaining / pounceDuration)) *
                      15
                : motion.lift,
          ),
      windup > 0 || pounceRemaining > 0 ? bearing : motion.facing,
      hurt > .08 ? impactPose : motion.phase,
      boss
          ? 125
          : isElite
          ? 76
          : kind == 'troll'
          ? 80
          : kind == 'wolf'
          ? 55
          : 62,
      flash: hurt > .08 ? .75 : 0,
    );
    canvas.restore();
    if (life.value < life.max || boss || isElite) {
      final width = boss
              ? 100.0
              : isElite
              ? 44.0
              : 36.0,
          y = boss ? -100.0 : -48.0;
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
            (width - 2) * life.value / life.max,
            4,
          ),
          const ui.Radius.circular(2),
        ),
        ui.Paint()..color = isElite ? trait.color : const ui.Color(0xffe87753),
      );
      if (isElite) {
        final at = ui.Offset(size.x / 2 - width / 2 - 8, y + 3);
        canvas.save();
        canvas.translate(at.dx, at.dy);
        if (trait == EnemyTrait.armored) {
          final shield = ui.Path()
            ..moveTo(-4, -5)
            ..lineTo(4, -5)
            ..lineTo(4, 0)
            ..quadraticBezierTo(4, 3, 0, 6)
            ..quadraticBezierTo(-4, 3, -4, 0)
            ..close();
          canvas.drawPath(shield, ui.Paint()..color = trait.color);
        } else {
          final paint = ui.Paint()
            ..color = trait.color
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

class WoodlandProp extends GameComponent {
  WoodlandProp(this.session, this.prop) {
    position = Vector2(prop.body.left, prop.body.top);
    size = Vector2(prop.body.width, prop.body.height);
  }
  final Adventure session;
  final WorldProp prop;
  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(-position.x, -position.y);
    final hero = session.hero.body;
    final covers =
        (prop.kind == 'tree' ||
            prop.kind.startsWith('city-') ||
            prop.kind.startsWith('ruin-')) &&
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
        merchant ? 'merchant' : 'villager',
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
    session.texts.remove(this);
    super.onRemove();
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    session.art.text(
      canvas,
      label,
      ui.Offset.zero,
      size: label.startsWith('+') ? 13 : 18,
      color: color.withValues(alpha: (remaining / .3).clamp(0, 1)),
    );
  }
}

class EncounterStone extends GameComponent {
  EncounterStone(this.session, this.area) {
    position = Vector2(area.stone.dx - 22, area.stone.dy - 48);
    size = Vector2(44, 48);
  }
  final Adventure session;
  final EncounterArea area;
  @override
  int get priority => area.stone.dy.toInt();
  @override
  void render(ui.Canvas canvas) {
    if (area.waves < EncounterArea.waveLimit) return;
    final ready = !session.areaHasEnemies(area.key);
    if (ready && (session.hero.body.center - area.stone).distance < 220) {
      session.art.text(
        canvas,
        '공격해 재소환 · ${area.stoneHits}/3',
        const ui.Offset(22, -14),
        size: 11,
        color: const ui.Color(0xffb9e9d9),
      );
    }
    canvas.drawOval(
      const ui.Rect.fromLTWH(-6, 34, 56, 18),
      ui.Paint()..color = const ui.Color(0x55000000),
    );
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
    final glow = ready
        ? const ui.Color(0xff9debd8)
        : const ui.Color(0xff52635e);
    canvas.drawPath(
      ui.Path()
        ..moveTo(23, 10)
        ..lineTo(16, 23)
        ..lineTo(23, 34)
        ..lineTo(30, 23)
        ..close(),
      ui.Paint()
        ..color = glow
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        ui.Offset(14 + i * 9, 40),
        2,
        ui.Paint()
          ..color = i < area.stoneHits ? glow : const ui.Color(0xff344b45),
      );
    }
  }
}
