import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adventure.dart';
import 'combat_numbers.dart';
import 'rpg_model.dart';

/// A flat, seven-dp vessel; the number sits beside it, never inside the fill.
class ResourceMeter extends StatelessWidget {
  const ResourceMeter(
    this.session, {
    this.height = 7,
    this.leadingInset = 0,
    super.key,
  });
  final Adventure session;
  final double height, leadingInset;
  static double minimumHeight(TextScaler scaler) =>
      math.max(12, scaler.scale(8.5) * 1.2);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, _) {
      final p = session.progress;
      final maximum = p.maxEnergy.isFinite && p.maxEnergy > 0
          ? p.maxEnergy
          : 1.0;
      final current = p.energy.isFinite ? p.energy.clamp(0.0, maximum) : 0.0;
      final label =
          '${p.heroClass.resource} ${CombatNumbers.resource(current, rounding: CombatRounding.down)}';
      return Semantics(
        label: '$label / ${CombatNumbers.resource(p.maxEnergy)}',
        excludeSemantics: true,
        child: SizedBox(
          height: minimumHeight(MediaQuery.textScalerOf(context)),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: leadingInset),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      key: const ValueKey('hud-resource-gauge'),
                      minHeight: height,
                      value: (current / maximum).clamp(0.0, 1.0),
                      color: p.heroClass == HeroClass.mage
                          ? const Color(0xff5796b0)
                          : const Color(0xffb37c50),
                      backgroundColor: const Color(0x99000000),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              SizedBox(
                width: 82,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 8.5,
                        height: 1,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
