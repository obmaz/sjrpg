import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/sanctuary.dart';

void main() {
  const square = [
    Offset(0, 0),
    Offset(100, 0),
    Offset(100, 100),
    Offset(0, 100),
  ];
  test(
    'painted outline protects the body inside but leaves ground beyond a wall hostile',
    () {
      final ward = Sanctuary.polygon(square);
      expect(ward.protects(const Rect.fromLTWH(40, 40, 20, 20)), true);
      expect(ward.protects(const Rect.fromLTWH(101, 40, 8, 8)), false);
      expect(ward.protects(const Rect.fromLTWH(99, 40, 8, 8)), true);
      expect(ward.protects(const Rect.fromLTWH(-10, -10, 120, 120)), true);
      expect(ward.boundaryPath.contains(const Offset(50, 50)), true);
      expect(ward.boundaryPath.contains(const Offset(110, 50)), false);
    },
  );
  test(
    'outside-to-outside attacks cannot cross the village and near-wall rays honor their real clearance',
    () {
      final ward = Sanctuary.polygon(square);
      expect(
        ward.blocksRay(const Offset(-10, 50), const Offset(110, 50)),
        true,
      );
      expect(
        ward.blocksRay(const Offset(110, 5), const Offset(110, 95)),
        false,
      );
      expect(
        ward.blocksRay(const Offset(110, 5), const Offset(110, 95), padding: 9),
        false,
      );
      expect(
        ward.blocksRay(
          const Offset(110, 5),
          const Offset(110, 95),
          padding: 10,
        ),
        true,
      );
      expect(ward.blocksRay(const Offset(-10, 0), const Offset(110, 0)), true);
      expect(ward.blocksRay(const Offset(50, 50), const Offset(50, 50)), true);
      expect(
        ward.blocksRay(const Offset(110, 50), const Offset(110, 50)),
        false,
      );
    },
  );
  test(
    'concave empty ground stays hostile instead of using an enclosing circle or bounds',
    () {
      final ward = Sanctuary.polygon(const [
        Offset(0, 0),
        Offset(100, 0),
        Offset(100, 40),
        Offset(40, 40),
        Offset(40, 100),
        Offset(0, 100),
      ]);
      expect(ward.protects(const Rect.fromLTWH(60, 60, 20, 20)), false);
      expect(ward.blocksRay(const Offset(60, 70), const Offset(90, 70)), false);
      expect(ward.protects(const Rect.fromLTWH(35, 60, 10, 10)), true);
      expect(ward.blocksRay(const Offset(80, -10), const Offset(80, 50)), true);
    },
  );
  test(
    'spawn projection clears the full body at the nearest wall in either winding order',
    () {
      for (final points in [square, square.reversed.toList()]) {
        final ward = Sanctuary.polygon(points);
        for (final size in const [Size(28, 24), Size(42, 36), Size(96, 80)]) {
          for (final center in const [
            Offset(50, 50),
            Offset(1, 1),
            Offset(99, 99),
            Offset(50, 2),
          ]) {
            final from = center - Offset(size.width / 2, size.height / 2);
            final outside = ward.outside(from, size);
            expect(ward.protects(outside & size), false);
            expect((outside - from).distance, lessThan(160));
            expect(ward.outside(outside, size), outside);
          }
        }
      }
    },
  );
  test('circle fixtures retain their original body and ray behavior', () {
    const ward = Sanctuary(Offset(50, 50), 40);
    expect(ward.protects(const Rect.fromLTWH(89, 45, 4, 4)), true);
    expect(ward.protects(const Rect.fromLTWH(91, 45, 4, 4)), false);
    expect(ward.blocksRay(const Offset(95, 20), const Offset(95, 80)), false);
    expect(
      ward.blocksRay(const Offset(95, 20), const Offset(95, 80), padding: 5),
      true,
    );
  });
  test('invalid outlines cannot create a poisoned geometry cache', () {
    expect(
      () => Sanctuary.polygon(const [Offset.zero, Offset(1, 1)]),
      throwsArgumentError,
    );
    expect(
      () => Sanctuary.polygon(const [
        Offset.zero,
        Offset(1, 1),
        Offset(double.nan, 0),
      ]),
      throwsArgumentError,
    );
  });
}
