import 'dart:ui';
import 'combat_balance.dart';
import 'world_model.dart';

/// Finite encounters belong to a fixed area, even when enemies chase the hero.
class EncounterArea {
  EncounterArea(
    this.key,
    this.stone, {
    this.waves = 0,
    this.charges = maxCharges,
    this.rechargeElapsed = 0,
  });
  static const span = 4096.0 * worldScale, waveLimit = 3;
  final String key;
  final Offset stone;
  int waves;
  static const maxCharges = 3;
  static const rechargeSeconds = 300 * CombatBalance.gameSpeed;
  int charges;
  double rechargeElapsed;
  Rect get body => Rect.fromCenter(center: stone, width: 36, height: 24);
  int get remainingSeconds => charges == maxCharges
      ? 0
      : CombatBalance.realSeconds(rechargeSeconds - rechargeElapsed).ceil();
  void recharge(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    if (charges == maxCharges) {
      rechargeElapsed = 0;
      return;
    }
    rechargeElapsed += dt;
    while (rechargeElapsed >= rechargeSeconds && charges < maxCharges) {
      charges++;
      rechargeElapsed -= rechargeSeconds;
    }
    if (charges == maxCharges) rechargeElapsed = 0;
  }

  static String keyAt(Offset p) =>
      '${(p.dx / span).floor()}:${(p.dy / span).floor()}';
  Map<String, dynamic> toSave() => {
    'key': key,
    'x': stone.dx,
    'y': stone.dy,
    'waves': waves,
    'charges': charges,
    'rechargeElapsed': rechargeElapsed,
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
    final charges = raw['charges'] ?? maxCharges;
    final recharge = raw['rechargeElapsed'] ?? 0;
    if (charges is! int ||
        charges < 0 ||
        charges > maxCharges ||
        recharge is! num ||
        !recharge.isFinite ||
        recharge < 0 ||
        recharge >= rechargeSeconds ||
        charges == maxCharges && recharge != 0) {
      throw const FormatException('Invalid encounter recharge');
    }
    return EncounterArea(
      key,
      Offset(x.toDouble(), y.toDouble()),
      waves: waves,
      charges: charges,
      rechargeElapsed: recharge.toDouble(),
    );
  }
}
