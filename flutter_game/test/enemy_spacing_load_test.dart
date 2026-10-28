import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/enemy_spacing.dart';

void main() {
  test('squared spacing keeps the original linear tolerance under load', () {
    final spacing = EnemySpacing<int>();
    final random = math.Random(80);
    for (var i = 0; i < 20000; i++) {
      final a = Rect.fromLTWH(
        random.nextDouble() * 200,
        random.nextDouble() * 200,
        24,
        22,
      );
      final b = Rect.fromLTWH(
        random.nextDouble() * 200,
        random.nextDouble() * 200,
        48,
        40,
      );
      const sa = Size(44, 34), sb = Size(78, 58);
      spacing.update(0, a, personalSpace: sa);
      spacing.update(1, b, personalSpace: sb);
      final delta = i.isEven
          ? Offset(random.nextDouble() * 10, random.nextDouble() * 10)
          : const Offset(.0000001, -.0000001);
      final to = a.shift(delta);
      double linear(Rect body) {
        final d = body.center - b.center;
        final x = d.dx / ((sa.width + sb.width) / 2);
        final y = d.dy / ((sa.height + sb.height) / 2);
        return math.sqrt(x * x + y * y);
      }

      final after = linear(to);
      final original = after >= 1 || after >= linear(a) - .000001;
      expect(spacing.permitsPersonalSpace(0, a, to, 1), original);
    }
  });

  test('short-step broad phase preserves every exact contact decision', () {
    final random = math.Random(81);
    const body = Rect.fromLTWH(45000, 45000, 24, 22);
    var allChecks = 0, nearbyChecks = 0;
    for (var sample = 0; sample < 2000; sample++) {
      final delta = Offset(
        random.nextDouble() * 20 - 10,
        random.nextDouble() * 20 - 10,
      );
      final neighbors = List.generate(
        30,
        (_) => Rect.fromLTWH(
          body.left + random.nextDouble() * 180 - 90,
          body.top + random.nextDouble() * 180 - 90,
          random.nextBool() ? 24 : 48,
          random.nextBool() ? 22 : 40,
        ),
      );
      final reachable = body.inflate(delta.distance + .1);
      final nearby = neighbors.where(reachable.overlaps).toList();
      // Includes full, axis slide and tangential steering alternatives. Every
      // actual microstep stays within the full movement's distance envelope.
      for (final step in [
        delta,
        Offset(delta.dx, 0),
        Offset(0, delta.dy),
        Offset(-delta.dy, delta.dx),
      ]) {
        final to = body.shift(step);
        final original = neighbors.every((other) {
          allChecks++;
          return EnemySpacing.permits(body, to, other);
        });
        final filtered = nearby.every((other) {
          nearbyChecks++;
          return EnemySpacing.permits(body, to, other);
        });
        expect(filtered, original);
      }
    }
    expect(nearbyChecks, lessThan(allChecks * .4));
    if (const bool.fromEnvironment('CROWD_BENCHMARK')) {
      // ignore: avoid_print
      print('CONTACT_LOAD all_checks=$allChecks nearby_checks=$nearbyChecks');
    }
  });
}
