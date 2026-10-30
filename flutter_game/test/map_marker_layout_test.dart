import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/map_marker_layout.dart';

void main() {
  for (final round in [true, false]) {
    for (final unit in [1.0, 3.0, 6.0]) {
      test('all marker edges stay inside map: round=$round zoomUnit=$unit', () {
        final bounds = const Rect.fromLTWH(0, 0, 1200, 900);
        final markers = [
          for (final (index, point) in [
            const Offset(-50, -50),
            const Offset(1200, 0),
            const Offset(1200, 950),
            const Offset(0, 900),
          ].indexed)
            MapMarker('$index', point, 11 * unit),
        ];
        final groups = MapMarkerLayout(
          bounds,
          round: round,
          unit: unit,
        ).layout(markers);
        expect(groups.expand((g) => g.items).map((m) => m.id).toSet(), {
          '0',
          '1',
          '2',
          '3',
        });
        for (final group in groups) {
          if (round) {
            expect(
              (group.center - bounds.center).distance + group.radius,
              lessThanOrEqualTo(bounds.shortestSide / 2 - 3 * unit),
            );
          } else {
            expect(
              bounds.contains(
                group.center - Offset(group.radius, group.radius),
              ),
              true,
            );
            expect(
              bounds.contains(
                group.center + Offset(group.radius, group.radius),
              ),
              true,
            );
          }
        }
      });
    }
  }
  test(
    'nearby services merge into one exact count and split when zoomed in',
    () {
      const bounds = Rect.fromLTWH(0, 0, 1200, 900);
      const markers = [
        MapMarker('shop', Offset(100, 80), 10),
        MapMarker('heal', Offset(128, 80), 10),
        MapMarker('smith', Offset(156, 80), 10),
      ];
      expect(
        const MapMarkerLayout(bounds, round: false).layout(markers).length,
        3,
      );
      final out = const MapMarkerLayout(bounds, round: false, unit: 5).layout([
        for (final marker in markers)
          MapMarker(marker.id, marker.anchor, marker.radius * 5),
      ]);
      expect(out.length, 1);
      expect(out.single.items.length, 3);
      expect(out.single.center.dy, greaterThanOrEqualTo(out.single.radius));
    },
  );
  test(
    'a numeric group leaves the player arrow visible and cannot overflow a corner',
    () {
      const bounds = Rect.fromLTWH(0, 0, 85, 85);
      final groups = const MapMarkerLayout(bounds, round: true).layout([
        const MapMarker('a', Offset(42.5, 42.5), 5),
        const MapMarker('b', Offset(42.5, 42.5), 5),
      ], hero: bounds.center);
      expect(groups.single.items.length, 2);
      expect((groups.single.center - bounds.center).distance, greaterThan(12));
    },
  );
  test(
    'an overview corner keeps its numeric group clear of the player after clamping',
    () {
      const bounds = Rect.fromLTWH(0, 0, 1200, 900), hero = Offset(100, 80);
      final groups = const MapMarkerLayout(bounds, round: false, unit: 4)
          .layout([
            const MapMarker('shop', Offset(75, 60), 40),
            const MapMarker('heal', Offset(90, 65), 40),
          ], hero: hero);
      expect(groups.length, 1);
      expect(
        (groups.single.center - hero).distance,
        greaterThanOrEqualTo(groups.single.radius + 24 - .01),
      );
      expect(
        groups.single.center.dy - groups.single.radius,
        greaterThanOrEqualTo(0),
      );
    },
  );
}
