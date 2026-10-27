/// Per-enemy damage for the eligible enemies hit together, after target limits.
/// Props consume target slots but do not divide enemy damage.
double enemyGroupDamageScale(int targets) =>
    targets <= 1 ? 1 : .4 + 1.2 / (targets + 1);
