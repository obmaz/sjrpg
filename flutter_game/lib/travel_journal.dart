import 'dart:convert';
import 'dart:ui';

import 'world_model.dart';

/// Visited wells and inactive scenes, without copies of the hero's progression.
class TravelJournal {
  final archives = <WorldStage, Map<String, dynamic>>{};
  final discovered = <WorldStage, Set<String>>{};

  bool discover(WorldStage stage, String id) {
    if (!wellSitesForStage(stage).any((site) => site.id == id)) return false;
    return discovered.putIfAbsent(stage, () => <String>{}).add(id);
  }

  bool hasDiscovered(WorldStage stage, String id) =>
      discovered[stage]?.contains(id) ?? false;

  Iterable<DiscoveredWell> get wells sync* {
    for (final stage in WorldStage.values) {
      for (final site in wellSitesForStage(stage)) {
        if (hasDiscovered(stage, site.id)) yield DiscoveredWell(stage, site.id);
      }
    }
  }

  DiscoveredWell? nearbyWell(
    AdventureWorld world,
    Offset center, {
    double range = 240,
  }) {
    QuestSite? nearest;
    var distance = range;
    for (final well in wellSitesForStage(world.stage, hubOrigin: world.spawn)) {
      final next = (well.at - center).distance;
      if (next < distance &&
          hasDiscovered(world.stage, well.id) &&
          world.clearLine(
            center,
            well.at + const Offset(0, 77),
            const Size(3, 3),
          )) {
        nearest = well;
        distance = next;
      }
    }
    return nearest == null ? null : DiscoveredWell(world.stage, nearest.id);
  }

  Map<String, dynamic> toSave() => {
    'version': 1,
    'archives': {
      for (final entry in archives.entries) entry.key.name: entry.value,
    },
    'discovered': {
      for (final entry in discovered.entries)
        entry.key.name: entry.value.toList(),
    },
  };

  void replaceWith(TravelJournal other) {
    archives
      ..clear()
      ..addAll({
        for (final entry in other.archives.entries)
          entry.key: copyScene(entry.value),
      });
    discovered
      ..clear()
      ..addAll({
        for (final entry in other.discovered.entries)
          entry.key: Set<String>.of(entry.value),
      });
  }

  static Map<String, dynamic> copyScene(Map<String, dynamic> scene) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(scene)) as Map);

  /// Geometry, quest order and enemy data are validated by GameCheckpoint.
  static TravelJournal fromSave(
    Object? value, {
    required WorldStage activeStage,
    required Map<String, dynamic> Function(
      WorldStage stage,
      Map<String, dynamic> raw,
    )
    validateScene,
  }) {
    final journal = TravelJournal();
    if (value == null) return journal;
    if (value is! Map || value['version'] != 1) {
      throw const FormatException('Invalid travel journal');
    }
    final archived = value['archives'], found = value['discovered'];
    if (archived is! Map || archived.length > 3 || found is! Map) {
      throw const FormatException('Invalid visited stages');
    }
    for (final entry in archived.entries) {
      final stage = WorldStage.values.firstWhere(
        (stage) => stage.name == entry.key,
      );
      if (stage == activeStage || entry.value is! Map) {
        throw const FormatException('Invalid inactive stage');
      }
      journal.archives[stage] = validateScene(
        stage,
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    if (found.length > WorldStage.values.length) {
      throw const FormatException('Invalid well stages');
    }
    for (final entry in found.entries) {
      final stage = WorldStage.values.firstWhere(
        (stage) => stage.name == entry.key,
      );
      if (stage != activeStage && !journal.archives.containsKey(stage)) {
        throw const FormatException('A well must belong to a visited stage');
      }
      final ids = entry.value;
      final sites = wellSitesForStage(stage);
      if (ids is! List ||
          ids.length > sites.length ||
          ids.toSet().length != ids.length ||
          ids.any((id) => id is! String || !sites.any((s) => s.id == id))) {
        throw const FormatException('Invalid discovered wells');
      }
      journal.discovered[stage] = ids.cast<String>().toSet();
    }
    return journal;
  }
}

class DiscoveredWell {
  const DiscoveredWell(this.stage, this.id);
  final WorldStage stage;
  final String id;
  QuestSite get site => siteAt();
  QuestSite siteAt({Offset? hubOrigin}) => wellSitesForStage(
    stage,
    hubOrigin: hubOrigin,
  ).firstWhere((site) => site.id == id);
}

List<QuestSite> wellSitesForStage(WorldStage stage, {Offset? hubOrigin}) => [
  QuestSite(
    'hub',
    switch (stage) {
      WorldStage.forest => '마을 분수',
      WorldStage.sands => '야영지 우물',
      WorldStage.past => '왕국의 샘',
      WorldStage.future => '중앙 회복정',
    },
    '모험의 거점',
    (hubOrigin ?? stage.spawn) +
        (stage == WorldStage.forest
                ? const Offset(0, -55)
                : const Offset(-280, -100)) *
            worldScale,
    stage.sanctuaryColor,
  ),
  ...sitesForStage(stage),
];

// Fixed origins of saves created before explicit layout metadata was recorded.
const legacyHubOrigins = <List<double>>[
  [2880, 2291.25],
  [5400, 6450],
  [17100, 12900],
  [9300, 18150],
];
