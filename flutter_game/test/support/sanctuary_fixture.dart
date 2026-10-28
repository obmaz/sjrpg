import 'package:bonfire/bonfire.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/world_model.dart';

/// A painted open gate, measured where its road crosses the actual safety line.
({Offset boundary, Offset outward}) safetyGate(AdventureWorld world) {
  final road = world.authoredSettlement.gatePaths.last;
  final from = road.first, to = road.last;
  final outward = (to - from) / (to - from).distance;
  var inside = from, outside = to;
  for (var i = 0; i < 60; i++) {
    final mid = Offset.lerp(inside, outside, .5)!;
    if (world.sanctuary.protects(mid & Size.zero)) {
      inside = mid;
    } else {
      outside = mid;
    }
  }
  return (boundary: Offset.lerp(inside, outside, .5)!, outward: outward);
}

/// Finds a real sloped safety edge whose legal double body rounds inside it.
/// The full 24×22 body, terrain, and geometric movement must all permit the
/// unrounded candidate; only the actual Float32 commit may invalidate it.
({Offset desired, Offset from}) precisionWardContact(Adventure session) {
  final world = session.world;
  final bounds = world.sanctuary.boundaryPath.getBounds();
  const size = Size(24, 22);
  Offset stored(Offset at) => Vector2(at.dx, at.dy).toOffset();
  for (var y = bounds.top; y < bounds.bottom; y += .73) {
    y = stored(Offset(0, y)).dy;
    var left = bounds.left, right = bounds.right + 1;
    for (var i = 0; i < 55; i++) {
      final x = (left + right) / 2;
      if (world.sanctuary.protects(Offset(x, y) & size)) {
        left = x;
      } else {
        right = x;
      }
    }
    final desired = Offset(right + .0000001, y);
    final from = stored(desired + const Offset(2, 0));
    if (world.blocksEnemy(desired & size) ||
        !world.blocksEnemy(stored(desired) & size) ||
        world.blocksEnemy(from & size)) {
      continue;
    }
    final geometric = world.moveEnemy(from, desired - from, size);
    if (!world.blocksEnemy(geometric & size) &&
        world.blocksEnemy(stored(geometric) & size)) {
      return (desired: desired, from: from);
    }
  }
  throw StateError('Painted safety edge must expose a Float32 body contact');
}
