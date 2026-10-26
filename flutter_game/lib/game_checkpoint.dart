import 'dart:convert';
import 'dart:ui';
import 'adventure.dart';
import 'battle_effects.dart';
import 'game_art.dart';
import 'world_model.dart';
import 'encounters.dart';
import 'enemy_catalog.dart';

class GameCheckpoint {
  GameCheckpoint._(this.data, this.progress);
  final Map<String, dynamic> data;
  final Progress progress;
  String get summary =>
      '${WorldStage.values.firstWhere((s) => s.name == data['stage']).title} · Lv.${progress.level} ${progress.heroClass.title}';
  String encode() => jsonEncode(data);
  static GameCheckpoint? capture(Adventure session) {
    if (!session.ready || session.disposed || session.progress.hp <= 0) {
      return null;
    }
    final bosses = session.mobs.where(
      (mob) => mob.boss && !mob.isDead && !mob.isRemoving,
    );
    final boss = bosses.isEmpty ? null : bosses.first;
    return decode(
      jsonEncode({
        'boss': boss == null
            ? null
            : {
                'x': boss.position.x,
                'y': boss.position.y,
                'hp': boss.life.value,
                'maxHp': boss.life.max,
              },
        'encounterVersion': 1,
        'encounters': session.encounterAreas.values
            .map((a) => a.toSave())
            .toList(),
        'enemies': [
          ...session.dormantEnemies,
          ...session.mobs
              .where(
                (m) =>
                    !m.boss &&
                    !m.isDead &&
                    !m.isRemoving &&
                    !m.encounterDormant,
              )
              .map(session.saveEnemy),
        ],
        'version': 1,
        'balance': 2,
        'stage': session.world.stage.name,
        'stageStartKills': session.stageStartKills,
        'commissionStartKills': session.commissionStartKills,
        'timePath': session.timePath?.name,
        'commission': session.acceptedCommission,
        'sites': session.cleansedSites.toList(),
        'mounts': session.mounts
            .map(
              (m) => {
                'id': m.def.id,
                'x': m.at.dx,
                'y': m.at.dy,
                'angle': m.bearing,
              },
            )
            .toList(),
        'riding': session.riding?.def.id,
        'progress': session.progress.toSave(),
        'seed': session.world.seed,
        'x': session.hero.position.x,
        'y': session.hero.position.y,
        'elapsed': session.elapsed,
        'chests': session.openedChests.toList(),
        'memoryRewarded': session.memoryRewarded,
        'cooldowns': Map<String, double>.of(session.hero.cooldowns),
        'armor': session.hero.armorTime,
        'frenzy': session.hero.frenzyTime,
        'loot': session.loot
            .where((g) => !g.collected && !g.isRemoving)
            .map(
              (g) => {
                'item': g.item.toSave(),
                'x': g.position.x,
                'y': g.position.y,
                'age': g.age,
              },
            )
            .toList(),
      }),
    );
  }

  static GameCheckpoint? advance(Adventure session) {
    if (!session.stageCleared || session.defeated || session.disposed) {
      return null;
    }
    final next = switch (session.world.stage) {
      WorldStage.forest => WorldStage.sands,
      WorldStage.sands =>
        session.timePath == TimePath.past ? WorldStage.past : WorldStage.future,
      _ => null,
    };
    if (next == null) return null;
    final checkpoint = capture(session);
    if (checkpoint == null) return null;
    final data = checkpoint.data;
    final p = Progress.fromSave(session.progress.toSave())!
      ..bossDefeated = false;
    p.hp = p.maxHp;
    p.energy = p.maxEnergy;
    data.addAll({
      'stage': next.name,
      'stageStartKills': p.kills,
      'commissionStartKills': p.kills,
      'timePath': next == WorldStage.sands ? null : session.timePath?.name,
      'commission': null,
      'sites': <String>[],
      'chests': <int>[],
      'memoryRewarded': false,
      'progress': p.toSave(),
      'x': next.spawn.dx,
      'y': next.spawn.dy,
      'mounts': <dynamic>[],
      'riding': null,
      'boss': null,
      'encounters': <dynamic>[],
      'enemies': <dynamic>[],
      'cooldowns': <String, double>{},
      'armor': 0,
      'frenzy': 0,
    });
    final ground = data['loot'] as List;
    for (var i = 0; i < ground.length; i++) {
      ground[i]['x'] = next.spawn.dx + 100 + i % 5 * 24;
      ground[i]['y'] = next.spawn.dy + 180 + i ~/ 5 * 24;
      ground[i]['age'] = 0;
    }
    return decode(jsonEncode(data));
  }

  static GameCheckpoint? decode(String? text) {
    if (text == null || text.length > 2000000) return null;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(text) as Map);
      if (data['version'] != 1) return null;
      final progress = Progress.fromSave(data['progress']);
      if (progress == null || progress.hp <= 0) return null;
      final stage = WorldStage.values.firstWhere(
        (s) => s.name == (data['stage'] ?? 'forest'),
      );
      data['stage'] = stage.name;
      final availableSites = sitesForStage(stage);
      final stageStart = data['stageStartKills'] ?? 0;
      final commissionStart = data['commissionStartKills'] ?? stageStart;
      if (stageStart is! int ||
          stageStart < 0 ||
          stageStart > progress.kills ||
          commissionStart is! int ||
          commissionStart < stageStart ||
          commissionStart > progress.kills) {
        return null;
      }
      data['stageStartKills'] = stageStart;
      data['commissionStartKills'] = commissionStart;
      final pathName = data['timePath'];
      final path = pathName == null
          ? null
          : TimePath.values.firstWhere((p) => p.name == pathName);
      if (stage == WorldStage.forest && path != null ||
          stage == WorldStage.past && path != TimePath.past ||
          stage == WorldStage.future && path != TimePath.future) {
        return null;
      }
      final commission = data['commission'];
      if (commission != null &&
          (stage != WorldStage.sands ||
              !timeCommissions.any(
                (q) => q.id == commission && q.path == path,
              ))) {
        return null;
      }
      final seed = data['seed'];
      if (seed is! int || seed < 0 || seed > 1000000000) return null;
      bool number(dynamic value, double max) =>
          value is num && value.isFinite && value >= 0 && value <= max;
      if (!number(data['x'], worldSize.width) ||
          !number(data['y'], worldSize.height) ||
          !number(data['elapsed'], 100000000) ||
          !number(data['armor'], 60) ||
          !number(data['frenzy'], 60)) {
        return null;
      }
      final chests = data['chests'] as List;
      final chestCount = stage == WorldStage.forest
          ? stageChests.length
          : 26 + 2 * availableSites.length;
      if (chests.length > chestCount ||
          chests.toSet().length != chests.length ||
          chests.any((c) => c is! int || c < 0 || c >= chestCount)) {
        return null;
      }
      if (data['memoryRewarded'] is! bool ||
          (data['memoryRewarded'] == true &&
              !stageMemories.every((m) => chests.contains(m.chest)))) {
        return null;
      }
      for (final entry in (data['cooldowns'] as Map).entries) {
        final skill = progress.skills.firstWhere((s) => s.id == entry.key);
        if (skill.passive || !number(entry.value, skill.cooldown)) return null;
      }
      final sites =
          data['sites'] ??
          (progress.bossDefeated
              ? availableSites.map((q) => q.id).toList()
              : <String>[]);
      if (sites is! List ||
          sites.length > availableSites.length ||
          sites.toSet().length != sites.length ||
          sites.any((id) => !availableSites.any((q) => q.id == id))) {
        return null;
      }
      if (stage == WorldStage.sands) {
        final branch = timeCommissions.where((q) => q.path == path).toList();
        if (sites.any((id) => !branch.any((q) => q.id == id))) return null;
        for (var i = 0; i < branch.length; i++) {
          if (sites.contains(branch[i].id) != (i < sites.length)) return null;
        }
        if (commission != null &&
            (sites.length >= branch.length ||
                branch[sites.length].id != commission)) {
          return null;
        }
      }
      data['sites'] = sites;
      final mounts = data['mounts'] ?? <dynamic>[];
      if (mounts is! List || mounts.length > travelMountDefs.length) {
        return null;
      }
      final ids = <String>{};
      for (final mount in mounts) {
        if (mount is! Map ||
            !travelMountDefs.any((d) => d.id == mount['id']) ||
            !ids.add(mount['id'] as String) ||
            !number(mount['x'], worldSize.width) ||
            !number(mount['y'], worldSize.height) ||
            mount['angle'] is! num ||
            !(mount['angle'] as num).isFinite ||
            (mount['angle'] as num).abs() > 100000) {
          return null;
        }
      }
      final riding = data['riding'];
      if (riding != null && (riding is! String || !ids.contains(riding))) {
        return null;
      }
      data['mounts'] = mounts;
      final balance = data['balance'] ?? 1;
      if (balance is! int || balance < 1 || balance > 2) return null;
      final boss = data['boss'];
      if (boss != null) {
        if (boss is! Map ||
            progress.bossDefeated ||
            !number(boss['x'], worldSize.width) ||
            !number(boss['y'], worldSize.height) ||
            !number(boss['hp'], 10000000) ||
            !number(boss['maxHp'], 10000000) ||
            boss['hp'] <= 0 ||
            boss['hp'] > boss['maxHp']) {
          return null;
        }
      }
      final loot = data['loot'] as List;
      if (loot.length > 32) return null;
      final identities = progress.inventory.map((g) => g.serial).toSet();
      for (final raw in loot) {
        final ground = raw as Map;
        final gear = Gear.fromSave(
          Map<String, dynamic>.from(ground['item'] as Map),
        );
        if (!identities.add(gear.serial) ||
            !number(ground['x'], worldSize.width) ||
            !number(ground['y'], worldSize.height) ||
            !number(ground['age'], 150)) {
          return null;
        }
      }
      if (balance < 2 && boss != null) {
        boss['hp'] = (boss['hp'] as num) * 2;
        boss['maxHp'] = (boss['maxHp'] as num) * 2;
      }
      final areas = data['encounters'] ?? <dynamic>[];
      final enemies = data['enemies'] ?? <dynamic>[];
      if (areas is! List ||
          areas.length > 120 ||
          enemies is! List ||
          enemies.length > 5000) {
        return null;
      }
      final keys = <String>{};
      for (final raw in areas) {
        final area = EncounterArea.fromSave(raw as Map);
        if (!keys.add(area.key)) return null;
      }
      for (final raw in enemies) {
        if (raw is! Map ||
            !enemyCatalog.containsKey(raw['kind']) ||
            !EnemyTrait.values.any((t) => t.name == raw['trait']) ||
            raw['area'] != null && !keys.contains(raw['area']) ||
            !number(raw['x'], worldSize.width) ||
            !number(raw['y'], worldSize.height) ||
            !number(raw['maxHp'], 10000000) ||
            !number(raw['hp'], 10000000) ||
            raw['hp'] <= 0 ||
            raw['hp'] > raw['maxHp']) {
          return null;
        }
      }
      data['encounters'] = areas;
      data['enemies'] = enemies;
      data['balance'] = 2;
      return GameCheckpoint._(data, progress);
    } catch (_) {
      return null;
    }
  }

  Adventure restore(GameArt art) {
    final session = Adventure(
      art,
      seed: data['seed'] as int,
      stage: WorldStage.values.firstWhere((s) => s.name == data['stage']),
      restoredProgress: Progress.fromSave(progress.toSave())!,
    );
    session.restoredEncounters = data['encounterVersion'] == 1;
    for (final raw in data['encounters'] as List) {
      final area = EncounterArea.fromSave(raw as Map);
      session.encounterAreas[area.key] = area;
    }
    session.dormantEnemies.addAll(
      (data['enemies'] as List).map((r) => Map<String, dynamic>.from(r as Map)),
    );
    session.stageStartKills = data['stageStartKills'] as int;
    session.commissionStartKills = data['commissionStartKills'] as int;
    session.timePath = data['timePath'] == null
        ? null
        : TimePath.values.firstWhere((p) => p.name == data['timePath']);
    session.acceptedCommission = data['commission'] as String?;
    for (final entry in data['mounts'] as List) {
      final existing = session.mounts.where((m) => m.def.id == entry['id']);
      if (existing.isEmpty) continue;
      final mount = existing.first;
      final at = Offset(
        (entry['x'] as num).toDouble(),
        (entry['y'] as num).toDouble(),
      );
      final body = Rect.fromCenter(
        center: at,
        width: mount.def.bodySize.width,
        height: mount.def.bodySize.height,
      );
      if (!session.world.blocked(body, waterOnly: mount.def.waterOnly)) {
        mount.at = at;
        mount.bearing = (entry['angle'] as num).toDouble();
      }
    }
    final riding = session.mounts.where((m) => m.def.id == data['riding']);
    if (riding.isNotEmpty) {
      session.riding = riding.first;
      session.hero.resizeBody(riding.first.def.bodySize, riding.first.at);
    }
    final desired = Offset(
      (data['x'] as num).toDouble(),
      (data['y'] as num).toDouble(),
    );
    final at = session.world.spawnNear(
      desired,
      session.hero.body.size,
      waterOnly: session.riding?.def.waterOnly ?? false,
    );
    final safe = at ?? session.world.spawn;
    if (at == null) {
      session.riding = null;
      session.hero.resizeBody(
        const Size(28, 24),
        session.world.spawn + const Offset(14, 12),
      );
    }
    session.hero.position.setValues(safe.dx, safe.dy);
    session.hero.lastClearPosition = safe;
    session.hero.invulnerable = .75;
    session.elapsed = (data['elapsed'] as num).toDouble();
    session.openedChests.addAll((data['chests'] as List).cast<int>());
    session.memoryRewarded = data['memoryRewarded'] as bool;
    session.cleansedSites.addAll((data['sites'] as List).cast<String>());
    session.bossSummoned = session.progress.bossDefeated;
    final savedBoss = data['boss'];
    if (savedBoss != null) {
      final boss = session.spawnEnemy(
        'golem',
        Offset(
          (savedBoss['x'] as num).toDouble(),
          (savedBoss['y'] as num).toDouble(),
        ),
        boss: true,
      );
      if (boss != null) {
        boss.life.initial((savedBoss['maxHp'] as num).toDouble());
        boss.life.update((savedBoss['hp'] as num).toDouble());
        session.bossSummoned = true;
      }
    }
    for (final entry in (data['cooldowns'] as Map).entries) {
      session.hero.cooldowns[entry.key as String] = (entry.value as num)
          .toDouble();
    }
    session.hero.armorTime = (data['armor'] as num).toDouble();
    session.hero.frenzyTime = (data['frenzy'] as num).toDouble();
    for (final raw in data['loot'] as List) {
      final ground = raw as Map;
      final item = GroundLoot(
        session,
        Gear.fromSave(Map<String, dynamic>.from(ground['item'] as Map)),
        Offset(
          (ground['x'] as num).toDouble(),
          (ground['y'] as num).toDouble(),
        ),
      )..age = (ground['age'] as num).toDouble();
      session.loot.add(item);
    }
    session.syncLife();
    return session;
  }
}
