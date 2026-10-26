import 'dart:convert';
import 'dart:ui';

import 'adventure.dart';
import 'battle_effects.dart';
import 'encounters.dart';
import 'enemy_catalog.dart';
import 'game_art.dart';
import 'travel_journal.dart';
import 'world_model.dart';

class GameCheckpoint {
  GameCheckpoint._(this.data, this.progress);
  final Map<String, dynamic> data;
  final Progress progress;
  String get summary =>
      '${WorldStage.values.firstWhere((s) => s.name == data['stage']).title} · Lv.${progress.level} ${progress.heroClass.title}';
  String encode() => jsonEncode(data);
  // One active scene and at most three inactive scenes, each with its own budget.
  static const _maximumEncodedLength = 8000000;
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
        'mapVersion': 2,
        'balance': 3,
        'stage': session.world.stage.name,
        'stageStartKills': session.stageStartKills,
        'commissionStartKills': session.commissionStartKills,
        'timePath': session.timePath?.name,
        'commission': session.acceptedCommission,
        'sites': session.cleansedSites.toList(),
        'trackedSite': session.trackedSite?.id,
        'mounts': session.mounts
            .map(
              (m) => {
                'id': m.def.id,
                'x': m.at.dx,
                'y': m.at.dy,
                'angle': m.bearing,
                'durability': m.durability,
              },
            )
            .toList(),
        'riding': session.riding?.def.id,
        'progress': session.progress.toSave(),
        'seed': session.world.seed,
        'hubOrigin': [session.world.spawn.dx, session.world.spawn.dy],
        'travel': session.travelJournal.toSave(),
        'x': session.hero.position.x,
        'y': session.hero.position.y,
        'elapsed': session.elapsed,
        'chests': session.openedChests.toList(),
        'memoryRewarded': session.memoryRewarded,
        'cooldowns': Map<String, double>.of(session.hero.cooldowns),
        'attackClock': session.hero.attackClock,
        'dodgeClock': session.hero.dodgeClock,
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
    final journal = _readTravel(data, checkpoint.progress);
    final archivedNext = journal.archives.remove(next);
    final source = TravelJournal.copyScene(_scene(data));
    if (archivedNext != null) {
      journal.archives[session.world.stage] = source;
      final restored = _enterScene(data, archivedNext)
        ..['travel'] = journal.toSave();
      return decode(jsonEncode(restored));
    }
    // The original chapter transition carries ground loot forward exactly once.
    source['loot'] = <dynamic>[];
    journal.archives[session.world.stage] = source;
    final p = Progress.fromSave(session.progress.toSave())!
      ..bossDefeated = false;
    p.hp = p.maxHp;
    p.energy = p.maxEnergy;
    data.addAll({
      'stage': next.name,
      'hubOrigin': [next.arrival.dx, next.arrival.dy],
      'travel': journal.toSave(),
      'stageStartKills': p.kills,
      'commissionStartKills': p.kills,
      'timePath': next == WorldStage.sands ? null : session.timePath?.name,
      'commission': null,
      'sites': <String>[],
      'trackedSite': null,
      'chests': <int>[],
      'memoryRewarded': false,
      'progress': p.toSave(),
      'x': next.arrival.dx,
      'y': next.arrival.dy,
      'mounts': <dynamic>[],
      'riding': null,
      'boss': null,
      'encounters': <dynamic>[],
      'enemies': <dynamic>[],
      'cooldowns': <String, double>{},
      'attackClock': 0,
      'dodgeClock': 0,
      'armor': 0,
      'frenzy': 0,
    });
    final ground = data['loot'] as List;
    for (var i = 0; i < ground.length; i++) {
      ground[i]['x'] = next.arrival.dx + 100 + i % 5 * 24;
      ground[i]['y'] = next.arrival.dy + 180 + i ~/ 5 * 24;
      ground[i]['age'] = 0;
    }
    return decode(jsonEncode(data));
  }

  static GameCheckpoint? decode(String? text) => _decode(text);

  static GameCheckpoint? _decode(String? text) {
    if (text == null || text.length > _maximumEncodedLength) return null;
    try {
      return _decodeData(Map<String, dynamic>.from(jsonDecode(text) as Map));
    } catch (_) {
      return null;
    }
  }

  // These maps belong to the detached JSON snapshot, never the live session.
  // Inactive scenes need the same validation without another JSON roundtrip.
  static GameCheckpoint? _decodeData(
    Map<String, dynamic> data, {
    bool includeTravel = true,
  }) {
    try {
      if (data['version'] != 1) return null;
      final mapVersion = data['mapVersion'] ?? 1;
      if (mapVersion != 1 && mapVersion != 2) return null;
      if (mapVersion == 1) {
        void scale(Map raw) {
          for (final key in ['x', 'y']) {
            final value = raw[key];
            if (value is num) raw[key] = value * worldScale;
          }
        }

        scale(data);
        for (final key in ['mounts', 'enemies', 'encounters', 'loot']) {
          final list = data[key];
          if (list is List) {
            for (final raw in list) {
              if (raw is Map) scale(raw);
            }
          }
        }
        if (data['boss'] is Map) scale(data['boss'] as Map);
        final mounts = data['mounts'];
        if (data['riding'] != null && mounts is List) {
          for (final raw in mounts) {
            if (raw is Map &&
                raw['id'] == data['riding'] &&
                raw['x'] is num &&
                raw['y'] is num) {
              final def = travelMountDefs
                  .where((d) => d.id == raw['id'])
                  .firstOrNull;
              if (def != null) {
                data['x'] = (raw['x'] as num) - def.bodySize.width / 2;
                data['y'] = (raw['y'] as num) - def.bodySize.height / 2;
              }
            }
          }
        }
      }
      data['mapVersion'] = 2;
      final progress = Progress.fromSave(data['progress']);
      if (progress == null || progress.hp <= 0) return null;
      final balance = data['balance'] ?? 1;
      if (balance is! int || balance < 1 || balance > 3) return null;
      final stage = WorldStage.values.firstWhere(
        (s) => s.name == (data['stage'] ?? 'forest'),
      );
      data['stage'] = stage.name;
      final origin = data['hubOrigin'] ?? legacyHubOrigins[stage.index];
      if (origin is! List ||
          origin.length != 2 ||
          origin[0] is! num ||
          origin[1] is! num ||
          !(origin[0] as num).isFinite ||
          !(origin[1] as num).isFinite ||
          origin[0] < 0 ||
          origin[1] < 0 ||
          origin[0] > worldSize.width ||
          origin[1] > worldSize.height) {
        return null;
      }
      final hubOrigin = Offset(
        (origin[0] as num).toDouble(),
        (origin[1] as num).toDouble(),
      );
      if (!stage.supportsHubOrigin(hubOrigin)) return null;
      data['hubOrigin'] = List<num>.from(origin);
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
      data['attackClock'] ??= 0;
      data['dodgeClock'] ??= 0;
      if (!number(data['attackClock'], 60) ||
          !number(data['dodgeClock'], 1.5)) {
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
        final maximum =
            skill.cooldown * (balance >= 3 ? Progress.skillCooldownScale : 1);
        if (skill.passive || !number(entry.value, maximum)) return null;
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
      final tracked = data['trackedSite'];
      // Navigation is cosmetic: stale targets never invalidate an otherwise valid save.
      data['trackedSite'] =
          tracked is String &&
              availableSites.any((s) => s.id == tracked) &&
              !sites.contains(tracked)
          ? tracked
          : null;
      final mounts = data['mounts'] ?? <dynamic>[];
      if (mounts is! List || mounts.length > travelMountDefs.length) {
        return null;
      }
      final ids = <String>{};
      for (final mount in mounts) {
        if (mount is Map) mount['durability'] ??= 100;
        if (mount is! Map ||
            !travelMountDefs.any((d) => d.id == mount['id']) ||
            !ids.add(mount['id'] as String) ||
            !number(mount['durability'], 100) ||
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
      if (balance < 3) {
        for (final raw in [...enemies, ?boss]) {
          raw['hp'] = (raw['hp'] as num) * monsterHealthScale;
          raw['maxHp'] = (raw['maxHp'] as num) * monsterHealthScale;
        }
        final cooldowns = data['cooldowns'] as Map;
        for (final id in cooldowns.keys.toList()) {
          cooldowns[id] = (cooldowns[id] as num) * Progress.skillCooldownScale;
        }
      }
      data['balance'] = 3;
      if (includeTravel) {
        data['travel'] = _readTravel(data, progress).toSave();
      } else {
        data.remove('travel');
      }
      return GameCheckpoint._(data, progress);
    } catch (_) {
      return null;
    }
  }

  static const _sceneKeys = {
    'stage',
    'seed',
    'hubOrigin',
    'x',
    'y',
    'timePath',
    'commission',
    'sites',
    'trackedSite',
    'mounts',
    'riding',
    'chests',
    'memoryRewarded',
    'boss',
    'encounterVersion',
    'encounters',
    'enemies',
    'loot',
  };

  static Map<String, dynamic> _scene(Map<String, dynamic> data) => {
    for (final key in _sceneKeys)
      if (data.containsKey(key)) key: data[key],
    'bossDefeated': (data['progress'] as Map)['bossDefeated'],
    'stageKills': (data['progress'] as Map)['kills'] - data['stageStartKills'],
    'commissionKills':
        (data['progress'] as Map)['kills'] - data['commissionStartKills'],
  };

  static Map<String, dynamic> _enterScene(
    Map<String, dynamic> current,
    Map<String, dynamic> scene,
  ) {
    final progress = Map<String, dynamic>.from(current['progress'] as Map)
      ..['bossDefeated'] = scene['bossDefeated'];
    return {
      for (final entry in current.entries)
        if (entry.key != 'travel') entry.key: entry.value,
      if (!scene.containsKey('hubOrigin'))
        'hubOrigin':
            legacyHubOrigins[WorldStage.values
                .firstWhere((stage) => stage.name == scene['stage'])
                .index],
      for (final key in _sceneKeys)
        if (scene.containsKey(key)) key: scene[key],
      'progress': progress,
      'stageStartKills': progress['kills'] - scene['stageKills'],
      'commissionStartKills': progress['kills'] - scene['commissionKills'],
    };
  }

  static TravelJournal _readTravel(
    Map<String, dynamic> data,
    Progress progress,
  ) {
    final active = WorldStage.values.firstWhere((s) => s.name == data['stage']);
    final journal = TravelJournal.fromSave(
      data['travel'],
      activeStage: active,
      validateScene: (stage, raw) {
        if (_sceneKeys
                .where((key) => key != 'hubOrigin')
                .any((key) => !raw.containsKey(key)) ||
            raw.keys.any(
              (key) =>
                  !_sceneKeys.contains(key) &&
                  !const {
                    'bossDefeated',
                    'stageKills',
                    'commissionKills',
                  }.contains(key),
            ) ||
            raw['stage'] != stage.name ||
            raw['stageKills'] is! int ||
            raw['commissionKills'] is! int ||
            raw['bossDefeated'] is! bool) {
          throw const FormatException('Invalid archived scene');
        }
        final decoded = _decodeData(
          _enterScene(data, raw),
          includeTravel: false,
        );
        if (decoded == null) {
          throw const FormatException('Invalid archived scene');
        }
        return _scene(decoded.data);
      },
    );
    if (data['travel'] == null) {
      // Every older chapter started at its hub before discovery was recorded.
      journal.discover(active, 'hub');
      for (final id in data['sites'] as List) {
        journal.discover(active, id as String);
      }
    }
    final scenes = [data, ...journal.archives.values];
    final paths = scenes.map((s) => s['timePath']).whereType<String>().toSet();
    if (paths.length > 1) {
      throw const FormatException(
        'Visited stages disagree about the chosen era',
      );
    }
    final identities = progress.inventory.map((g) => g.serial).toSet();
    var groundItems = 0;
    for (final scene in scenes) {
      for (final raw in scene['loot'] as List) {
        final serial = ((raw as Map)['item'] as Map)['serial'];
        if (serial is! int || !identities.add(serial)) {
          throw const FormatException(
            'Duplicated equipment across visited stages',
          );
        }
        groundItems++;
      }
    }
    if (groundItems > 128) {
      throw const FormatException('Visited scene budget exceeded');
    }
    return journal;
  }

  static GameCheckpoint? warp(
    Adventure session,
    WorldStage destination,
    String wellId,
  ) {
    if (!session.ready ||
        session.disposed ||
        session.defeated ||
        session.won ||
        session.riding != null ||
        !session.travelJournal.hasDiscovered(destination, wellId)) {
      return null;
    }
    if (session.travelJournal.nearbyWell(
          session.world,
          session.hero.body.center,
        ) ==
        null) {
      return null;
    }
    final saved = capture(session);
    if (saved == null) return null;
    final journal = _readTravel(saved.data, saved.progress);
    final current = session.world.stage;
    final targetScene = destination == current
        ? _scene(saved.data)
        : journal.archives[destination];
    if (targetScene == null) return null;
    final source = TravelJournal.copyScene(_scene(saved.data));
    final scene = TravelJournal.copyScene(targetScene);
    journal.archives.remove(destination);
    if (destination != current) journal.archives[current] = source;
    final data = _enterScene(saved.data, scene);
    final hub = scene['hubOrigin'] as List;
    final well = wellSitesForStage(
      destination,
      hubOrigin: Offset((hub[0] as num).toDouble(), (hub[1] as num).toDouble()),
    ).firstWhere((site) => site.id == wellId);
    data.addAll({
      'x': well.at.dx - 14,
      'y': well.at.dy + 65,
      'riding': null,
      'travel': journal.toSave(),
    });
    return decode(jsonEncode(data));
  }

  Adventure restore(GameArt art) {
    final session = Adventure(
      art,
      seed: data['seed'] as int,
      stage: WorldStage.values.firstWhere((s) => s.name == data['stage']),
      restoredProgress: Progress.fromSave(progress.toSave())!,
      hubOrigin: Offset(
        (data['hubOrigin'][0] as num).toDouble(),
        (data['hubOrigin'][1] as num).toDouble(),
      ),
    );
    session.travelJournal.replaceWith(_readTravel(data, progress));
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
    session.trackedSiteId = data['trackedSite'] as String?;
    // Broken chests must stop blocking before saved mounts and hero positions
    // are validated; the hero may have walked through the remains before saving.
    session.openedChests.addAll((data['chests'] as List).cast<int>());
    for (final entry in data['mounts'] as List) {
      final existing = session.mounts.where((m) => m.def.id == entry['id']);
      if (existing.isEmpty) continue;
      final mount = existing.first;
      mount.durability = (entry['durability'] as num).toDouble();
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
        Guardian.onFootSize,
        session.world.spawn + const Offset(14, 12),
      );
    }
    session.hero.position.setValues(safe.dx, safe.dy);
    session.riding?.at = session.hero.body.center;
    session.hero.lastClearPosition = safe;
    session.hero.invulnerable = .75;
    session.elapsed = (data['elapsed'] as num).toDouble();
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
    session.hero.attackClock = (data['attackClock'] as num).toDouble();
    session.hero.dodgeClock = (data['dodgeClock'] as num).toDouble();
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
