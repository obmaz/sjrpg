import 'package:flutter/material.dart';

import 'panel_controls.dart';

class NearbyControl {
  const NearbyControl({
    required this.label,
    required this.icon,
    required this.onTap,
    this.condition,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double? condition;
}

/// The compact action row and its guide occupy separate touch targets.
class NearbyControls extends StatelessWidget {
  const NearbyControls({
    required this.actions,
    this.horizontal = false,
    super.key,
  });
  final List<NearbyControl> actions;
  final bool horizontal;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (actions.isEmpty) return const SizedBox.shrink();
      final iconsOnly =
          horizontal && constraints.maxWidth / actions.length < 88;
      Widget button(NearbyControl action) => SizedBox(
        height: 44,
        child: Stack(
          fit: StackFit.expand,
          children: [
            iconsOnly
                ? GameIconButton(
                    label: action.label,
                    icon: action.icon,
                    onTap: action.onTap,
                  )
                : GameAction(
                    action.label,
                    icon: action.icon,
                    fontSize: 14,
                    onTap: action.onTap,
                  ),
            if (action.condition != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 4,
                child: LinearProgressIndicator(
                  value: action.condition!.clamp(0, 1),
                  minHeight: 2,
                  semanticsLabel: '탈것 내구도',
                  semanticsValue: '${(action.condition! * 100).ceil()}%',
                ),
              ),
          ],
        ),
      );
      if (horizontal) {
        return Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: button(actions[i])),
            ],
          ],
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            SizedBox(width: double.infinity, child: button(actions[i])),
          ],
        ],
      );
    },
  );
}
