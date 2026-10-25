import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:bonfire/bonfire.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'game_art.dart';
import 'world_model.dart';
import 'battle_effects.dart';
import 'device_settings.dart';
import 'skill_aim.dart';
import 'spell_vfx.dart';

enum NearbyAction { chest, exit, shrine, mount, dismount, shop, talk }

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
    HeroClass heroClass = HeroClass.warrior,
    Progress? restoredProgress,
    DeviceSettings? device,
  }) : world = AdventureWorld(seed: seed),
       progress = restoredProgress ?? Progress(heroClass: heroClass),
       device = device ?? DeviceSettings.shared {
    hero = Guardian(this);
    terrain = TerrainArt(world, art);
    for (var i = 0; i < travelMountDefs.length; i++) {
      final def = travelMountDefs[i], desired = initialMountPositions[i];
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
  final AdventureWorld world;
  late final Guardian hero;
  late final TerrainArt terrain;
  final Progress progress;
  final loot = <GroundLoot>[];
  final texts = <BattleText>[];
  final mounts = <TravelMount>[];
  TravelMount? riding;
  TravelMount? get nearbyMount {
    for (final mount in mounts) {
      if ((hero.body.center - mount.at).distance <
              (mount.def.waterOnly ? 230 : 120) &&
          world.clearBoardingLine(hero.body.center, mount.at)) {
        return mount;
      }
    }
    return null;
  }

  bool boardNearbyMount() {
    if (!active || riding != null || hero.dashing > 0) return false;
    final mount = nearbyMount;
    if (mount == null) return false;
    final body = ui.Rect.fromCenter(
      center: mount.at,
      width: mount.def.bodySize.width,
      height: mount.def.bodySize.height,
    );
    if (world.blocked(body, waterOnly: mount.def.waterOnly) ||
        mobs.any((m) => !m.isDead && !m.isRemoving && m.body.overlaps(body))) {
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

  bool ensureOnFoot() => riding == null || dismount(keepInput: true);

  final openedChests = <int>{};
  final cleansedSites = <String>{};
  bool get mandatoryQuestsComplete =>
      questSites.every((q) => cleansedSites.contains(q.id));
  bool get stageCleared => progress.bossDefeated && mandatoryQuestsComplete;
  QuestSite? get nearbySite {
    for (final site in questSites) {
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
    cleansedSites.add(site.id);
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
    releaseInput();
    game?.pauseEngine();
  }

  bool memoryRewarded = false;
  int get recoveredMemories => stageMemories
      .where((memory) => openedChests.contains(memory.chest))
      .length;
  String notice = "";
  double noticeTime = 0, combatTime = 0;
  int get skillPoints => progress.skillPoints;
  static const chestLocations = stageChests;
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
    final fade = (impactTime / .14).clamp(0.0, 1.0);
    final phase = (.14 - impactTime) * 110;
    return Vector2(
      math.sin(phase) * impactStrength * fade,
      math.cos(phase * 1.3) * impactStrength * fade * .6,
    );
  }

  void kickCamera(double strength) {
    if (!active) return;
    impactStrength = math.max(impactStrength, strength.clamp(0, 1.5));
    impactTime = .14;
  }

  double elapsed = 0, waveTime = 0, notifyTime = 0;
  double lastPackSpawn = -10;
  ui.Offset lastPack = arrival;
  int combo = 0, rageStrike = -1;
  int buildRevision = 0;
  int _successfulPacks = 0;
  final random = math.Random(52);
  bool get active => ready && !disposed && !paused && !defeated && !won;
  String get region => world.areaName(hero.position.toOffset());
  NearbyAction? get nearbyAction {
    if (riding != null) return NearbyAction.dismount;
    if (nearbySite != null) return NearbyAction.shrine;
    if (nearbyChest != null) return NearbyAction.chest;
    if (nearbyExit != null) return NearbyAction.exit;
    if (nearbyMount != null) return NearbyAction.mount;
    final at = hero.position.toOffset();
    final shop = (at - const ui.Offset(3952, 2984)).distance;
    final talk = (at - const ui.Offset(3660, 2952)).distance;
    if (talk < 135 && (shop >= 165 || talk < shop)) return NearbyAction.talk;
    if (shop < 165) return NearbyAction.shop;
    return null;
  }

  StageExit? get nearbyExit {
    for (final exit in stageExits) {
      if ((hero.body.center - ui.Offset(exit.x, exit.y)).distance < 115) {
        return exit;
      }
    }
    return null;
  }

  int? get nearbyChest {
    for (var i = 0; i < chestLocations.length; i++) {
      if (!openedChests.contains(i) &&
          (hero.body.center - chestLocations[i]).distance < 110 &&
          world.clearLine(
            hero.body.center,
            chestLocations[i],
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
    announce('첫 스테이지 정화 완료 · 네 방향의 출구를 둘러보세요');
  }

  void openChest() {
    final index = nearbyChest;
    if (!active || index == null) return;
    device.pulse(FeedbackKind.loot);
    openedChests.add(index);
    progress.gold += 18;
    progress.healingPotions++;
    dropGear(progress.rollLoot(random, chest: true), chestLocations[index]);
    bubble(
      '+18 골드 · 물약 +1',
      chestLocations[index] - const ui.Offset(0, 55),
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
      progress.energyPotions--;
      progress.energy = math.min(progress.maxEnergy, progress.energy + 60);
      bubble(
        '+60 ${progress.heroClass.resource}',
        hero.body.center - const ui.Offset(0, 80),
        const ui.Color(0xff9fdfff),
      );
    } else {
      if (progress.healingPotions <= 0 || progress.hp >= progress.maxHp) return;
      progress.healingPotions--;
      progress.hp = math.min(progress.maxHp, progress.hp + 55);
      syncLife();
      bubble(
        '+55 생명',
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

  int get living => mobs.where((m) => !m.isDead && !m.isRemoving).length;
  void holdAttack(String source, bool held) {
    if (held && active) {
      attackSources.add(source);
    } else {
      attackSources.remove(source);
    }
  }

  void releaseInput() {
    hero.aim = null;
    attackSources.clear();
    hero.onJoystickChangeDirectional(
      JoystickDirectionalEvent(directional: JoystickMoveDirectional.IDLE),
    );
    hero.stop();
  }

  void pause() {
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
    waveTime = 10;
    spawnPack(initial: (hero.position.toOffset() - arrival).distance < 220);
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
          !mob.boss &&
          (mob.position - hero.position).length > 1500) {
        mob.removeFromParent();
      }
    }
    if ((hero.position.toOffset() - lastPack).distance > 540) {
      waveTime = math.min(waveTime, 3);
      lastPack = hero.position.toOffset();
    }
    if (waveTime <= 0 && elapsed - lastPackSpawn >= 8) {
      spawnPack();
      waveTime = 10;
    }
    if (progress.kills >= stageKillGoal &&
        mandatoryQuestsComplete &&
        !bossSummoned &&
        !progress.bossDefeated) {
      final boss = spawnEnemy(
        'golem',
        hero.position.toOffset() + const ui.Offset(0, -310),
        boss: true,
      );
      if (boss != null) bossSummoned = true;
      if (boss != null) {
        bubble(
          '숲의 파수꾼이 깨어났습니다',
          hero.position.toOffset() - const ui.Offset(0, 85),
          const ui.Color(0xffffd176),
        );
      }
    }
    // The fountain sanctuary heals gradually, never after a fatal hit.
    if (progress.hp > 0 &&
        combatTime <= 0 &&
        (hero.position.toOffset() - const ui.Offset(3840, 3000)).distance <
            150) {
      progress.hp = math.min(progress.maxHp, progress.hp + dt * 4);
      hero.life.update(progress.hp);
    }
  }

  void spawnPack({bool initial = false}) {
    if (!active || living >= 40 || progress.bossDefeated) return;
    final at = hero.position.toOffset();
    if (town.contains(at) && at.dy < 3025 && !initial) return;
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
    var added = 0;
    for (var i = 0; i < 48 && added < count; i++) {
      final angle = hero.bearing + (i < 3 ? [0.0, 1.0, -1.0][i] : i * 2.4),
          r = 280.0 + (i % 5) * 38;
      final desired = initial
          ? ui.Offset(3780 + (i % 3) * 62, 3220 + (i % 2) * 50)
          : at + ui.Offset(math.cos(angle) * r, math.sin(angle) * r);
      final kind =
          (progress.level >= 3 || world.isSand(at)) &&
              (i == 0 || world.isSand(at) && i == 2)
          ? 'cultist'
          : ['goblin', 'wolf', 'skeleton'][(i + progress.level - 1) % 3];
      final trait = elitePack && added == eliteSlot
          ? ((_successfulPacks ~/ 3).isEven
                ? EnemyTrait.armored
                : EnemyTrait.swift)
          : EnemyTrait.none;
      if (spawnEnemy(kind, desired, trait: trait) != null) added++;
    }
    if (added > 0) {
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
    device.pulse(FeedbackKind.hurt);
    progress.hp = math.max(0, progress.hp - damage);
    hero.life.remove(damage);
    hero.invulnerable = .65;
    bubble(
      '-${damage.toInt()}',
      hero.position.toOffset() - const ui.Offset(0, 65),
      const ui.Color(0xffff8a72),
    );
    if (progress.hp <= 0) {
      defeated = true;
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
      hero.impactHold = heavy ? .045 : .03;
      hero.swing = math.min(hero.swing, .16);
      kickCamera(heavy ? 1.1 : .55);
      game?.add(
        ContactSpark(
          this,
          mob.body.center - const ui.Offset(0, 28),
          heavy: heavy,
        ),
      );
      progress.energy = math.min(
        progress.maxEnergy,
        progress.energy + progress.rageOnHit(protected: hero.armorTime > 0),
      );
    }
    device.pulse(mob.isDead ? FeedbackKind.kill : FeedbackKind.hit);
    mob.impactPose = (mob.anim / .15).floor() % 2;
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
      if (!mob.boss && progress.kills % 12 == 0) progress.healingPotions++;
      if (!mob.boss && progress.kills % 14 == 0) progress.energyPotions++;
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

  bool buyHeal() => progress.buy(20, () => progress.healingPotions += 2);
  Gear? buyGear(GearDef def) {
    if (disposed ||
        defeated ||
        !gearCatalog.contains(def) ||
        !def.usable(progress.heroClass) ||
        progress.inventory.length >= Progress.capacity) {
      return null;
    }
    Gear? bought;
    progress.buy(def.value, () {
      bought = progress.createGear(def);
      progress.inventory.add(bought!);
      progress.unseenGear.add(bought!.serial);
    });
    return bought;
  }

  bool buyEnergy() => progress.buy(18, () => progress.energyPotions += 2);
  bool buySword() => progress.buy(45, () => progress.swordDamage += 5);
  bool buyVitality() => progress.buy(60, () {
    progress.maxHp += 20;
    progress.hp = progress.maxHp;
    syncLife();
  });
  @override
  void dispose() {
    disposed = true;
    device.cancel();
    releaseInput();
    terrain.dispose();
    super.dispose();
  }
}

class Guardian extends Player with WithCollision {
  Guardian(this.session)
    : super(
        position: Vector2(arrival.dx, arrival.dy),
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
  void beginAim(int slot) {
    final def = session.progress.skillAt(slot);
    if (!session.active ||
        dashing > 0 ||
        def == null ||
        (cooldowns[def.id] ?? 0) > 0) {
      return;
    }
    if (!session.ensureOnFoot()) return;
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
    skill(slot: current.slot, manualAim: current.dragged ? current : null);
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
      invulnerable = 0;
  final cooldowns = <String, double>{};
  double armorTime = 0, frenzyTime = 0;
  double impactHold = 0;
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
    speed = session.riding?.def.speed ?? (frenzyTime > 0 ? 310 : 270);
    final before = position.toOffset();
    super.update(dt);
    var delta = position.toOffset() - before;
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
    lastClearPosition = p;
    // Follow the resolved body directly. Bonfire's smoothed follower can overshoot a dash.
    if (hasGameRef) gameRef.camera.position = session.cameraFocus;
    if (delta.distance > .1) {
      animationTime += dt;
      session.riding?.bearing = math.atan2(delta.dy, delta.dx);
    }
    session.riding?.at = body.center;
    attackClock = math.max(0, attackClock - dt);
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
    if (session.attackSources.isNotEmpty && attackClock <= 0) slash();
  }

  void slash() {
    if (!session.active || attackClock > 0 || dashing > 0) return;
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
    session.combo = (session.combo + 1) % 3;
    attackClock = session.progress.attackInterval * (frenzyTime > 0 ? .6 : 1);
    swing = .23;
    final p = session.progress;
    if (p.heroClass == HeroClass.mage) {
      session.game?.add(
        ArcaneBolt(
          session,
          body.center,
          angle,
          p.basicDamage,
          element: p.weapon.base.style,
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
    if (!session.active || dashing > 0 || !session.ensureOnFoot()) return;
    final p = session.progress;
    final def = p.skillAt(slot ?? (secondary ? 1 : 0));
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
    session.device.pulse(FeedbackKind.skill);
    p.energy -= def.cost;
    cooldowns[def.id] = def.cooldown;
    switch (def.id) {
      case 'warcry':
        armorTime = p.warcryDuration;
        areaStrike(
          session,
          body.center,
          170 + rank * 8,
          p.skillDamage(def),
          stun: 2,
          maxTargets: p.skillTargetLimit(def),
        );
        session.game?.add(
          SpellBurst(
            session,
            SpellClip.warcry,
            body.center,
            radius: 170 + rank * 8,
          ),
        );
      case 'whirlwind':
        spin = .5;
        session.game?.add(
          SpellBurst(session, SpellClip.whirlwind, body.center, radius: 175),
        );
        invulnerable = math.max(invulnerable, .35);
        session.game?.add(
          WhirlwindPulse(
            session,
            this,
            p.skillDamage(def),
            targetLimit: p.skillTargetLimit(def),
          ),
        );
      case 'frenzy':
        frenzyTime = 7;
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
        swing = .23;
        attackClock = math.max(attackClock, .35);
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
          RuneBurst(session, impact, const ui.Color(0xfff2cc8a), radius: 140),
        );
      case 'frostNova':
        final radius = 155.0 + rank * 15;
        areaStrike(
          session,
          body.center,
          radius,
          p.skillDamage(def),
          stun: 2,
          slow: 3,
          maxTargets: p.skillTargetLimit(def),
        );
        session.game?.add(
          SpellBurst(session, SpellClip.iceNova, body.center, radius: radius),
        );
      case 'iceArmor':
        armorTime = 12;
        session.game?.add(
          SpellBurst(session, SpellClip.iceNova, body.center, radius: 70),
        );
      case 'chainLightning':
        chainLightning(
          session,
          body.center,
          p.skillDamage(def),
          p.skillTargetLimit(def),
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
        session.game?.add(
          MeteorFall(
            session,
            body.center,
            target,
            p.skillDamage(def),
            targetLimit: p.skillTargetLimit(def),
          ),
        );
    }
    session.refresh();
  }

  void dodge() {
    if (!session.active || dodgeClock > 0 || !session.ensureOnFoot()) return;
    aim = null;
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
        swing > 0 ? attackBearing : bearing,
        swing > 0 ? (swing > .17 ? 0 : 1) : (animationTime / .13).floor() % 2,
        60,
        attack: swing > 0,
        opacity: invulnerable > 0 && ((invulnerable * 18).floor() % 2 == 0)
            ? .58
            : 1,
      );
    }
    if (swing > 0 && session.progress.heroClass == HeroClass.warrior) {
      final phase = 1 - swing / .23,
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
          attackBearing - 1.2 + phase * .9,
          1.6,
          false,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 7 * (1 - phase) + 1
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
          attackBearing - 1.1 + phase * .9,
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
      paintBattleAura(canvas, center, session.elapsed, frenzy: frenzyTime > 0);
    }
    if (armorTime > 0 && session.progress.heroClass == HeroClass.mage) {
      paintIceShield(canvas, center - const ui.Offset(0, 22), session.elapsed);
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
    if (spin > 0) paintWhirlwind(canvas, center, 1 - spin / .5);
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
             (boss
                 ? 1800
                 : kind == 'goblin'
                 ? 28
                 : kind == 'wolf'
                 ? 38
                 : 52) *
             (boss ? 1 : trait.healthScale),
         speed:
             (boss
                 ? 90
                 : kind == 'wolf'
                 ? 135
                 : 105) *
             (boss ? 1 : trait.speedScale),
       );
  final Adventure session;
  final String kind;
  final bool boss;
  final EnemyTrait trait;
  bool get isElite => !boss && trait != EnemyTrait.none;
  int impactPose = 0;
  bool rewarded = false, combatReady = false;
  double bearing = math.pi / 2,
      anim = 0,
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
    var before = position.toOffset();
    final target = session.hero.body.center - body.center;
    hurt = math.max(0, hurt - dt);
    stun = math.max(0, stun - dt);
    slow = math.max(0, slow - dt);
    attackClock -= dt;
    replan -= dt;
    slamClock -= dt;
    if (target.distance > 950) {
      stop();
      return;
    }
    if (stun > 0) {
      if (pounceRemaining > 0) finishPounce();
      if (windup > 0) {
        windup = 0;
        slamTarget = null;
        pounceGoal = null;
        slamClock = 4;
        if (kind == 'wolf' || kind == 'skeleton') {
          attackClock = math.max(attackClock, 1.2);
        }
      }
      stop();
      super.update(dt);
      return;
    }
    if (kind == 'wolf' && pounceRemaining > 0) {
      updatePounce(dt);
      return;
    }
    if (kind == 'wolf' && windup > 0) {
      stop();
      windup -= dt;
      if (windup <= 0 && pounceGoal != null) {
        final d = pounceGoal! - body.center;
        pounceBearing = math.atan2(d.dy, d.dx);
        bearing = pounceBearing;
        pounceDuration = math.min(240, d.distance) / 520;
        pounceRemaining = pounceDuration;
        slamTarget = null;
      }
      super.update(dt);
      return;
    }
    if (kind == 'skeleton' && windup > 0) {
      stop();
      windup -= dt;
      if (windup <= 0) {
        final angle = math.atan2(target.dy, target.dx);
        final difference = math.atan2(
          math.sin(angle - bearing),
          math.cos(angle - bearing),
        );
        if (target.distance < 100 &&
            difference.abs() < .85 &&
            session.world.clearLine(
              body.center,
              session.hero.body.center,
              const ui.Size(3, 3),
            )) {
          session.hurtHero(8);
        }
        session.game?.add(EnemySwipe(session, body.center, bearing));
        slamTarget = null;
        attackClock = 1.8;
      }
      super.update(dt);
      return;
    }
    if (kind == 'cultist' && windup > 0) {
      stop();
      windup -= dt;
      if (windup <= 0) {
        final locked = slamTarget;
        if (locked != null) {
          final toward = locked - body.center;
          session.game?.add(
            ShadowBolt(session, body.center, math.atan2(toward.dy, toward.dx)),
          );
        }
        slamTarget = null;
        attackClock = 2.8;
      }
      super.update(dt);
      return;
    }
    if (boss && windup > 0) {
      stop();
      windup -= dt;
      if (windup <= 0) {
        final at = slamTarget;
        if (at != null) {
          if ((session.hero.body.center - at).distance < 105 &&
              session.world.clearLine(
                body.center,
                session.hero.body.center,
                const ui.Size(3, 3),
              )) {
            session.hurtHero(24);
          }
          session.game?.add(
            RuneBurst(session, at, const ui.Color(0xffffad6b), radius: 105),
          );
        }
        slamTarget = null;
        slamClock = 5.5;
      }
      super.update(dt);
      return;
    }
    if (kind == 'wolf' &&
        attackClock <= 0 &&
        target.distance > 75 &&
        target.distance < 250 &&
        session.world.clearLine(
          position.toOffset(),
          session.hero.position.toOffset(),
          body.size,
        )) {
      bearing = math.atan2(target.dy, target.dx);
      pounceGoal =
          body.center +
          target / target.distance * math.min(240, target.distance);
      slamTarget = session.hero.body.center;
      windup = .42;
      stop();
      super.update(dt);
      return;
    }
    if (boss &&
        slamClock <= 0 &&
        target.distance < 340 &&
        session.world.clearLine(
          body.center,
          session.hero.body.center,
          const ui.Size(3, 3),
        )) {
      slamTarget = session.hero.body.center;
      windup = .85;
      stop();
      super.update(dt);
      return;
    }
    if (target.distance <
            (boss
                ? 64
                : kind == 'cultist'
                ? 280
                : kind == 'skeleton'
                ? 82
                : 42) &&
        session.world.clearLine(
          body.center,
          session.hero.body.center,
          const ui.Size(3, 3),
        )) {
      stop();
      if (attackClock <= 0) {
        if (kind == 'skeleton') {
          bearing = math.atan2(target.dy, target.dx);
          slamTarget = session.hero.body.center;
          windup = .5;
        } else if (kind == 'cultist') {
          bearing = math.atan2(target.dy, target.dx);
          slamTarget = session.hero.body.center;
          windup = .65;
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
      anim += dt;
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
    final distance = 520 * used * (slow > 0 ? .45 : 1);
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
        session.hurtHero(8);
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
    anim += used * 2.5;
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
    if (kind == 'wolf' && windup > 0 && pounceGoal != null) {
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
      canvas.drawPath(path, ui.Paint()..color = const ui.Color(0x44ef8b62));
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0xffefab78)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawLine(
        from,
        from + direction * (1 - windup / .42).clamp(0, 1),
        ui.Paint()
          ..color = const ui.Color(0xffffc38c)
          ..strokeWidth = 4
          ..strokeCap = ui.StrokeCap.round,
      );
    }
    if (kind == 'skeleton' && windup > 0) {
      final center = body.center - position.toOffset();
      final path = ui.Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          ui.Rect.fromCircle(center: center, radius: 100),
          bearing - .85,
          1.7,
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
    if (kind == 'cultist' && windup > 0) {
      canvas.drawOval(
        ui.Rect.fromCenter(center: feet, width: 58, height: 22),
        ui.Paint()
          ..color = const ui.Color(0x99d567b6)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      paintCombatEffect(
        session,
        canvas,
        feet - const ui.Offset(0, 26),
        3,
        const ui.Size.square(76),
        opacity: .4 + .6 * (1 - windup / .65),
      );
    }
    if (boss && windup > 0 && slamTarget != null) {
      final center = slamTarget! - position.toOffset(),
          t = (1 - windup / .85).clamp(0.0, 1.0);
      canvas.drawOval(
        ui.Rect.fromCenter(center: center, width: 210, height: 145),
        ui.Paint()..color = ui.Color.fromRGBO(255, 101, 65, .12 + t * .18),
      );
      canvas.drawOval(
        ui.Rect.fromCenter(center: center, width: 210, height: 145),
        ui.Paint()
          ..color = const ui.Color(0xffffb77c)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawArc(
        ui.Rect.fromCenter(center: center, width: 210, height: 145),
        -math.pi / 2,
        math.pi * 2 * t,
        false,
        ui.Paint()
          ..color = const ui.Color(0xffff7757)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 5,
      );
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
      final mark = ui.Offset(size.x / 2, boss ? -112 : -58);
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
    session.art.actor(
      canvas,
      kind,
      feet -
          ui.Offset(
            0,
            pounceRemaining > 0 && pounceDuration > 0
                ? math.sin(math.pi * (1 - pounceRemaining / pounceDuration)) *
                      15
                : 0,
          ),
      bearing,
      hurt > .08 ? impactPose : (anim / .15).floor() % 2,
      boss
          ? 125
          : kind == 'wolf'
          ? 55
          : 62,
      flash: hurt > .08 ? .75 : 0,
    );
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
        session.art.text(
          canvas,
          '숲의 파수꾼',
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
        prop.kind == 'tree' &&
        prop.body.bottom > hero.bottom &&
        prop.body.bottom - prop.drawSize.height < hero.bottom &&
        (prop.body.center.dx - hero.center.dx).abs() <
            prop.drawSize.width * .38;
    session.art.prop(canvas, prop, opacity: covers ? .4 : 1);
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
    position = merchant ? Vector2(3952, 2984) : Vector2(3660, 2952);
    size = Vector2(28, 24);
  }
  final Adventure session;
  final bool merchant;
  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (!merchant) {
      session.art.actor(
        canvas,
        'villager',
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
