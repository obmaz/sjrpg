import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/world_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final world = AdventureWorld();
  Offset at(double u, double v) =>
      Offset(town.left + town.width * u, town.top + town.height * v);
  for (final size in [const Size(28, 24), const Size(44, 32)]) {
    for (final (name, start, end) in [
      ('east', at(.73, .52), at(1.18, .52)),
      ('west', at(.15, .34), at(-.18, .34)),
      ('north', at(.48, .07), at(.48, -.13)),
      ('south', at(.57, .88), at(.57, 1.15)),
    ]) {
      test('$name village gate admits a complete $size body', () {
        expect(world.clearLine(start, end, size), true);
        var current = start;
        final step = (end - start) / 100;
        for (var i = 0; i < 100; i++) {
          current = world.move(current, step, size);
          expect(world.blocked(current & size), false);
        }
        expect((current - end).distance, lessThan(.01));
        expect(world.clearLine(end, start, size), true);
      });
    }
  }
  test('fountain, shop and fences beside the east gate remain solid', () {
    for (final point in [
      at(.5, .245),
      at(.85, .25),
      at(.95, .4),
      at(.9, .72),
    ]) {
      expect(
        world.blocked(Rect.fromCenter(center: point, width: 12, height: 12)),
        true,
      );
    }
  });
}
