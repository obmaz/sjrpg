import 'dart:ui';
import 'world_model.dart';

/// Finite encounters belong to a fixed area, even when enemies chase the hero.
class EncounterArea {
  EncounterArea(this.key, this.stone, {this.waves = 0});
  static const span = 4096.0, waveLimit = 3;
  final String key;
  final Offset stone;
  int waves;
  int stoneHits = 0;
  static String keyAt(Offset p) =>
      '${(p.dx / span).floor()}:${(p.dy / span).floor()}';
  Map<String, dynamic> toSave() => {
    'key': key,
    'x': stone.dx,
    'y': stone.dy,
    'waves': waves,
  };
  static EncounterArea fromSave(Map raw) {
    final key = raw['key'];
    final x = raw['x'], y = raw['y'], waves = raw['waves'];
    if (key is! String ||
        x is! num ||
        y is! num ||
        !x.isFinite ||
        !y.isFinite ||
        x < 0 ||
        y < 0 ||
        x > worldSize.width ||
        y > worldSize.height ||
        waves is! int ||
        waves < 0 ||
        waves > waveLimit ||
        key != keyAt(Offset(x.toDouble(), y.toDouble()))) {
      throw const FormatException('Invalid encounter area');
    }
    return EncounterArea(key, Offset(x.toDouble(), y.toDouble()), waves: waves);
  }
}
