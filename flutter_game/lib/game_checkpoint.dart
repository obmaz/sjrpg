import 'dart:convert';
import 'dart:ui';
import 'adventure.dart';
import 'battle_effects.dart';
import 'game_art.dart';
import 'world_model.dart';

class GameCheckpoint {
  GameCheckpoint._(this.data, this.progress);
  final Map<String, dynamic> data;
  final Progress progress;
  String get summary =>
      'Lv.${progress.level} ${progress.heroClass.title} · ${progress.kills} 처치';
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
        'version': 1,
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

  static GameCheckpoint? decode(String? text) {
    if (text == null || text.length > 100000) return null;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(text) as Map);
      if (data['version'] != 1) return null;
      final progress = Progress.fromSave(data['progress']);
      if (progress == null || progress.hp <= 0) return null;
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
      if (chests.length > stageChests.length ||
          chests.toSet().length != chests.length ||
          chests.any((c) => c is! int || c < 0 || c >= stageChests.length)) {
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
      return GameCheckpoint._(data, progress);
    } catch (_) {
      return null;
    }
  }

  Adventure restore(GameArt art) {
    final session = Adventure(
      art,
      seed: data['seed'] as int,
      restoredProgress: Progress.fromSave(progress.toSave())!,
    );
    final desired = Offset(
      (data['x'] as num).toDouble(),
      (data['y'] as num).toDouble(),
    );
    final at =
        session.world.spawnNear(desired, session.hero.body.size) ?? arrival;
    session.hero.position.setValues(at.dx, at.dy);
    session.hero.lastClearPosition = at;
    session.hero.invulnerable = .75;
    session.elapsed = (data['elapsed'] as num).toDouble();
    session.openedChests.addAll((data['chests'] as List).cast<int>());
    session.memoryRewarded = data['memoryRewarded'] as bool;
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
