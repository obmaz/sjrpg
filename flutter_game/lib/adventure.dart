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

enum NearbyAction { chest, exit, shop, talk }

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
  }
  final GameArt art;
  final DeviceSettings device;
  final AdventureWorld world;
  late final Guardian hero;
  late final TerrainArt terrain;
  final Progress progress;
  final loot = <GroundLoot>[];
  final texts = <BattleText>[];
  final openedChests = <int>{};
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
      hero.position + hero.size / 2 + Vector2(0, cameraOffsetY);
  double elapsed = 0, waveTime = 0, notifyTime = 0;
  ui.Offset lastPack = arrival;
  int combo = 0, rageStrike = -1;
  final random = math.Random(52);
  bool get active => ready && !disposed && !paused && !defeated && !won;
  String get region => world.areaName(hero.position.toOffset());
  NearbyAction? get nearbyAction {
    if (nearbyChest != null) return NearbyAction.chest;
    if (nearbyExit != null) return NearbyAction.exit;
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
    waveTime = 4.5;
    spawnPack(initial: (hero.position.toOffset() - arrival).distance < 220);
    refresh();
  }

  void tick(double dt) {
    if (!active) return;
    elapsed += dt;
    noticeTime = math.max(0, noticeTime - dt);
    combatTime = math.max(0, combatTime - dt);
    progress.energy =
        (progress.energy +
                dt *
                    (progress.heroClass == HeroClass.mage
                        ? 9
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
      waveTime = 0;
      lastPack = hero.position.toOffset();
    }
    if (waveTime <= 0) {
      spawnPack();
      waveTime = 4.5;
    }
    if (progress.kills >= stageKillGoal && !bossSummoned) {
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
    if (!active || living >= 22 || progress.bossDefeated) return;
    final at = hero.position.toOffset();
    if (town.contains(at) && at.dy < 3025 && !initial) return;
    final count = math.min(living < 8 ? 5 : 4, 22 - living);
    var added = 0;
    for (var i = 0; i < 18 && added < count; i++) {
      final angle = hero.bearing + (i < 3 ? [0.0, 1.0, -1.0][i] : i * 2.4),
          r = 240.0 + (i % 3) * 55;
      final desired = initial
          ? ui.Offset(3780 + (i % 3) * 62, 3220 + (i % 2) * 50)
          : at + ui.Offset(math.cos(angle) * r, math.sin(angle) * r);
      final kind =
          (progress.level >= 3 || world.isSand(at)) &&
              (i == 0 || world.isSand(at) && i == 2)
          ? 'cultist'
          : ['goblin', 'wolf', 'skeleton'][(i + progress.level - 1) % 3];
      if (spawnEnemy(kind, desired) != null) added++;
    }
  }

  HuntEnemy? spawnEnemy(String kind, ui.Offset desired, {bool boss = false}) {
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
    final enemy = HuntEnemy(this, kind, p, boss: boss);
    enemy.life.initial(
      enemy.life.max * (1 + (progress.level - 1) * (boss ? .15 : .08)),
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
    if (generateRage &&
        progress.heroClass == HeroClass.warrior &&
        rageStrike != hero.strikes) {
      rageStrike = hero.strikes;
      game?.add(ContactSpark(this, mob.body.center - const ui.Offset(0, 28)));
      progress.energy = math.min(progress.maxEnergy, progress.energy + 3);
    }
    device.pulse(mob.isDead ? FeedbackKind.kill : FeedbackKind.hit);
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
      final level = progress.level;
      progress.reward(boss: mob.boss);
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
      if (mob.boss || progress.kills % 3 == 0) {
        dropGear(progress.rollLoot(random, boss: mob.boss), mob.body.center);
      }
      if (!mob.boss && progress.kills % 12 == 0) progress.healingPotions++;
      if (!mob.boss && progress.kills % 14 == 0) progress.energyPotions++;
      bubble(
        '+${mob.boss ? 100 : 8} 골드',
        mob.position.toOffset() - const ui.Offset(0, 34),
        const ui.Color(0xffffd774),
      );
      mob.removeFromParent();
      if (mob.boss) {
        won = true;
        releaseInput();
        game?.pauseEngine();
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
  double get skillClock => cooldowns[session.progress.selectedSkill] ?? 0;
  set skillClock(double value) =>
      cooldowns[session.progress.selectedSkill] = value;
  double get protection => armorTime > 0
      ? (session.progress.heroClass == HeroClass.warrior
            ? .25 + session.progress.rank('warcry') * .025
            : .25 + session.progress.rank('iceArmor') * .05)
      : 0;
  int strikes = 0;
  double attackBearing = math.pi / 2;
  ui.Offset? lastClearPosition;
  ui.Rect get body => ui.Rect.fromLTWH(position.x, position.y, size.x, size.y);
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
    speed = frenzyTime > 0 ? 310 : 270;
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
    final p = session.world.move(before, delta, ui.Size(size.x, size.y));
    position.setValues(p.dx, p.dy);
    lastClearPosition = p;
    // Follow the resolved body directly. Bonfire's smoothed follower can overshoot a dash.
    if (hasGameRef) gameRef.camera.position = session.cameraFocus;
    if (delta.distance > .1) animationTime += dt;
    attackClock = math.max(0, attackClock - dt);
    swing = math.max(0, swing - dt);
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
        ),
      );
      return;
    }

    for (final mob in List<HuntEnemy>.of(session.mobs)) {
      final d = mob.body.center - body.center,
          diff = math.atan2(
            math.sin(math.atan2(d.dy, d.dx) - angle),
            math.cos(math.atan2(d.dy, d.dx) - angle),
          );
      if (d.distance < p.weapon.base.range + mob.size.x / 2 &&
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
          )) {
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
  }

  void skill({bool secondary = false, int? slot, SkillAim? manualAim}) {
    if (dashing > 0) return;
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
    final color = p.heroClass == HeroClass.warrior
        ? const ui.Color(0xffffcf81)
        : const ui.Color(0xff99e4ff);
    switch (def.id) {
      case 'warcry':
        armorTime = 6;
        areaStrike(
          session,
          body.center,
          170 + rank * 8,
          p.swordDamage * (1.0 + rank * .25),
          stun: 2,
        );
        session.game?.add(RuneBurst(session, body.center, color, radius: 190));
      case 'whirlwind':
        spin = .5;
        invulnerable = math.max(invulnerable, .35);
        session.game?.add(
          WhirlwindPulse(session, this, p.swordDamage * (1.1 + rank * .24)),
        );
      case 'frenzy':
        frenzyTime = 7;
        areaStrike(
          session,
          body.center,
          145,
          p.swordDamage * (1.2 + rank * .2),
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
          p.swordDamage * (1.8 + rank * .32),
          stun: .65 + rank * .08,
          slow: 1.5,
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
          p.swordDamage * (1.1 + rank * .3),
          stun: 2,
          slow: 3,
        );
        session.game?.add(
          RuneBurst(session, body.center, color, radius: radius, icy: true),
        );
      case 'iceArmor':
        armorTime = 12;
        session.game?.add(
          RuneBurst(session, body.center, color, radius: 70, icy: true),
        );
      case 'chainLightning':
        chainLightning(
          session,
          body.center,
          p.swordDamage * (1.5 + rank * .35),
          3 + rank,
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
            p.swordDamage * (3 + rank * .6),
          ),
        );
    }
    session.refresh();
  }

  void dodge() {
    if (!session.active || dodgeClock > 0) return;
    aim = null;
    session.device.pulse(FeedbackKind.dodge);
    rollBearing = bearing;
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
    if (dashing > 0) {
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
    if ((armorTime > 0 || frenzyTime > 0) &&
        session.art.images['combat-fx'] != null) {
      final image = session.art.images['combat-fx']!,
          cell = image.width / 4,
          index = frenzyTime > 0
              ? 5
              : session.progress.heroClass == HeroClass.mage
              ? 6
              : 0;
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH((index % 4) * cell, (index ~/ 4) * cell, cell, cell),
        ui.Rect.fromCenter(center: center, width: 110, height: 110),
        ui.Paint()..color = const ui.Color(0x99ffffff),
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
    if (spin > 0 && session.art.images['combat-fx'] != null) {
      final image = session.art.images['combat-fx']!, cell = image.width / 4;
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(cell, 0, cell, cell),
        ui.Rect.fromCenter(center: center, width: 330, height: 280),
        ui.Paint()
          ..color = ui.Color.fromRGBO(255, 255, 255, (spin / .5).clamp(0, 1)),
      );
    }
    if (spin > 0) {
      final phase = 1 - spin / .5;
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          ui.Rect.fromCircle(center: center, radius: 70 + phase * 90),
          i * math.pi * 2 / 3 + phase * 6,
          1.45,
          false,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = ui.Color.fromRGBO(122, 237, 219, 1 - phase),
        );
      }
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
  HuntEnemy(this.session, this.kind, ui.Offset at, {this.boss = false})
    : super(
        position: Vector2(at.dx, at.dy),
        size: boss ? Vector2(48, 40) : Vector2(24, 22),
        life: boss
            ? 1800
            : kind == 'goblin'
            ? 28
            : kind == 'wolf'
            ? 38
            : 52,
        speed: boss
            ? 90
            : kind == 'wolf'
            ? 135
            : 105,
      );
  final Adventure session;
  final String kind;
  final bool boss;
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
      if (windup > 0) {
        windup = 0;
        slamTarget = null;
        slamClock = 4;
      }
      stop();
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
                : 42) &&
        session.world.clearLine(
          body.center,
          session.hero.body.center,
          const ui.Size(3, 3),
        )) {
      stop();
      if (attackClock <= 0) {
        if (kind == 'cultist') {
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
      feet,
      bearing,
      (anim / .15).floor() % 2,
      boss
          ? 125
          : kind == 'wolf'
          ? 55
          : 62,
      opacity: hurt > 0 ? .7 : 1,
    );
    if (life.value < life.max || boss) {
      final width = boss ? 100.0 : 36.0, y = boss ? -100.0 : -48.0;
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
        ui.Paint()..color = const ui.Color(0xffe87753),
      );
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
