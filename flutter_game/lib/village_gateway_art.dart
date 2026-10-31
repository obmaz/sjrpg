import 'dart:ui';
import 'authored_settlement.dart';

abstract final class VillageGatewayArt {
  static const nativeSize = Size(1304, 1221);
  static const ground = Offset(744, 1104);
  static const passageSpan = 380.0;
  static Offset anchor(AuthoredSettlement village) =>
      village.point(const Offset(.505, .85));
  static double get scale => AuthoredSettlement.extent * .105 / passageSpan;
  static Offset point(AuthoredSettlement village, Offset pixel) =>
      anchor(village) + (pixel - ground) * scale;
  static Rect bounds(AuthoredSettlement village) {
    final p = point(village, Offset.zero);
    return Rect.fromLTWH(
      p.dx,
      p.dy,
      nativeSize.width * scale,
      nativeSize.height * scale,
    );
  }

  static Iterable<List<Offset>> solids(AuthoredSettlement village) sync* {
    for (final polygon in const [
      [
        Offset(324, 1124),
        Offset(454, 1204),
        Offset(579, 1184),
        Offset(579, 1094),
        Offset(424, 1044),
      ],
      [
        Offset(974, 1044),
        Offset(1164, 1094),
        Offset(1244, 1044),
        Offset(1194, 984),
        Offset(1004, 964),
      ],
      [
        Offset(154, 994),
        Offset(304, 1064),
        Offset(404, 1044),
        Offset(304, 944),
      ],
      [
        Offset(544, 1144),
        Offset(619, 1084),
        Offset(619, 1044),
        Offset(544, 1104),
      ],
      [
        Offset(854, 964),
        Offset(984, 1054),
        Offset(1004, 1024),
        Offset(864, 934),
      ],
    ]) {
      yield [for (final p in polygon) point(village, p)];
    }
  }
}
