import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/sanctuary.dart';

void main() {
  const ward = Sanctuary(Offset(1000, 1000), 360);
  test(
    'protection includes body edges and corners, not just actor centers',
    () {
      expect(ward.protects(const Rect.fromLTWH(1345, 988, 28, 24)), true);
      expect(ward.protects(const Rect.fromLTWH(1361, 988, 28, 24)), false);
      expect(ward.protects(const Rect.fromLTWH(1240, 1240, 30, 30)), true);
      expect(ward.protects(const Rect.fromLTWH(1260, 1260, 30, 30)), false);
    },
  );
  test(
    'rays cannot cross or graze the protected boundary in either direction',
    () {
      expect(
        ward.blocksRay(const Offset(400, 1000), const Offset(1600, 1000)),
        true,
      );
      expect(
        ward.blocksRay(const Offset(1600, 1000), const Offset(400, 1000)),
        true,
      );
      expect(
        ward.blocksRay(const Offset(400, 1360), const Offset(1600, 1360)),
        true,
      );
      expect(
        ward.blocksRay(const Offset(400, 1365), const Offset(1600, 1365)),
        false,
      );
      expect(
        ward.blocksRay(
          const Offset(400, 1365),
          const Offset(1600, 1365),
          padding: 6,
        ),
        true,
      );
      expect(
        ward.blocksRay(const Offset(900, 1000), const Offset(900, 1000)),
        true,
      );
    },
  );
  test('old enemy positions move outside with room for their whole body', () {
    for (final size in [const Size(24, 22), const Size(48, 40)]) {
      for (final center in [
        const Offset(1000, 1000),
        const Offset(1200, 1000),
      ]) {
        final start = center - Offset(size.width / 2, size.height / 2);
        final relocated = ward.outside(start, size);
        expect(ward.protects(relocated & size), false);
        expect(ward.outside(relocated, size), relocated);
      }
    }
  });
}
