/// Owned vehicles and their condition travel with the hero between stages.
class MountCondition {
  MountCondition({this.durability = 100, this.hits = 0, this.fallen = false});
  double durability;
  int hits;
  bool fallen;
  Map<String, dynamic> toSave() => {
    'durability': durability,
    'hits': hits,
    'fallen': fallen,
  };
}

class MountProgress {
  static const types = {'horse', 'bicycle', 'motor', 'boat'};
  final ownedIds = <String>{};
  final _conditions = <String, MountCondition>{};
  int motorLevel = 0, motorAmmo = 0;
  static String canonical(String id) =>
      const {
        'boat-west',
        'boat-ruins',
        'boat-marsh',
        'boat-east',
        'boat-south',
        'boat-coast',
      }.contains(id)
      ? 'boat'
      : id;
  bool owns(String id) => ownedIds.contains(canonical(id));
  MountCondition stateFor(String id) =>
      _conditions.putIfAbsent(canonical(id), MountCondition.new);
  Map<String, dynamic> toSave() => {
    'version': 1,
    'owned': ownedIds.toList()..sort(),
    'motorLevel': motorLevel,
    'motorAmmo': motorAmmo,
    'conditions': {for (final id in ownedIds) id: stateFor(id).toSave()},
  };
  static MountProgress fromSave(dynamic raw) {
    final result = MountProgress();
    if (raw == null) return result;
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['owned'] is! List ||
        (raw['owned'] as List).length > types.length ||
        raw['motorLevel'] is! int ||
        raw['motorLevel'] < 0 ||
        raw['motorLevel'] > 3 ||
        raw['motorAmmo'] is! int ||
        raw['motorAmmo'] < 0 ||
        raw['motorAmmo'] > 12 ||
        raw['conditions'] is! Map) {
      throw const FormatException('Invalid owned mounts');
    }
    for (final id in raw['owned'] as List) {
      if (id is! String || !types.contains(id) || !result.ownedIds.add(id)) {
        throw const FormatException('Invalid owned mount type');
      }
    }
    result.motorLevel = raw['motorLevel'];
    result.motorAmmo = raw['motorAmmo'];
    if (!result.owns('motor') &&
        (result.motorLevel != 0 || result.motorAmmo != 0)) {
      throw const FormatException('Unowned motorcycle equipment');
    }
    final conditions = raw['conditions'] as Map;
    if (conditions.keys.any((id) => !result.ownedIds.contains(id))) {
      throw const FormatException('Unowned mount condition');
    }
    for (final id in result.ownedIds) {
      final state = conditions[id];
      if (state is! Map ||
          state['durability'] is! num ||
          !(state['durability'] as num).isFinite ||
          state['durability'] < 0 ||
          state['durability'] > 100 ||
          state['hits'] is! int ||
          state['hits'] < 0 ||
          state['hits'] > 3 ||
          state['fallen'] is! bool ||
          id != 'horse' && (state['hits'] != 0 || state['fallen'] != false) ||
          id == 'horse' &&
              (state['fallen'] != (state['hits'] == 3) ||
                  state['fallen'] && state['durability'] != 0)) {
        throw const FormatException('Invalid mount condition');
      }
      result._conditions[id] = MountCondition(
        durability: (state['durability'] as num).toDouble(),
        hits: state['hits'],
        fallen: state['fallen'],
      );
    }
    return result;
  }
}
