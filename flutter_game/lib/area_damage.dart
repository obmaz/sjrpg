import 'dart:ui';

/// Per-enemy damage for the eligible enemies hit together, after target limits.
/// Props consume target slots but do not divide enemy damage.
double enemyGroupDamageScale(int targets) =>
    targets <= 1 ? 1 : .4 + 1.2 / (targets + 1);

/// Range is measured to the physical target body, not a guessed circular
/// radius. Wide bosses and tall bodies therefore use the same reach in every
/// direction as their actual collision shape.
double distanceToTargetBody(Offset origin, Rect body) =>
    (origin -
            Offset(
              origin.dx.clamp(body.left, body.right),
              origin.dy.clamp(body.top, body.bottom),
            ))
        .distance;
