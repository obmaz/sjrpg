import 'dart:ui';

import 'landmark_terrace.dart';
import 'stage_content.dart';

/// One authored formation. Placement includes its apron and walkable top;
/// movement separates open ramps, cliff faces and permanent stone or timber.
class FieldLandmark {
  const FieldLandmark(
    this.stage,
    this.index,
    this.name,
    this.center,
    this.side,
  );
  final WorldStage stage;
  final int index;
  final String name;
  final Offset center;
  final double side;
  String get imageKey => 'landmarks-${stage.name}';
  LandmarkTerrace? get terrace => LandmarkTerrace.forArt(stage, index);
  Offset artPoint(Offset point) => drawBounds.topLeft + point * (side / 768);
  List<Offset> artPolygon(List<Offset> points) => points.map(artPoint).toList();
  Rect get walkBounds {
    var result = footprint;
    for (final point in terrace?.outline ?? const <Offset>[]) {
      final at = artPoint(point);
      result = result.expandToInclude(Rect.fromLTWH(at.dx, at.dy, 0, 0));
    }
    return result;
  }

  double get terraceDepth => walkBounds.top;
  Rect get footprint =>
      Rect.fromCenter(center: center, width: side * .72, height: side * .30);
  Rect get drawBounds => Rect.fromLTWH(
    footprint.center.dx - side / 2,
    // The packed sprite ends 32px above its 768px cell edge. Keep that
    // transparent gutter below the physical ground contact, not above it.
    footprint.bottom - side + side * (32 / 768),
    side,
    side,
  );

  /// Coordinates measured in each 768px forest cell. Painted grass, loose leaf
  /// litter and transparent corners are not part of the raised obstacle.
  List<Offset> get solidOutline {
    if (stage != WorldStage.forest) {
      return [
        footprint.topLeft,
        footprint.topRight,
        footprint.bottomRight,
        footprint.bottomLeft,
      ];
    }
    final points = const [
      [
        Offset(240, 520),
        Offset(410, 495),
        Offset(598, 575),
        Offset(634, 650),
        Offset(540, 701),
        Offset(390, 716),
        Offset(225, 672),
        Offset(176, 602),
      ],
      [
        Offset(240, 480),
        Offset(500, 470),
        Offset(642, 550),
        Offset(664, 626),
        Offset(532, 708),
        Offset(310, 720),
        Offset(142, 633),
        Offset(152, 560),
      ],
      [
        Offset(225, 520),
        Offset(480, 500),
        Offset(617, 565),
        Offset(628, 640),
        Offset(526, 695),
        Offset(336, 696),
        Offset(172, 626),
      ],
      [
        Offset(250, 510),
        Offset(493, 505),
        Offset(629, 573),
        Offset(648, 637),
        Offset(527, 703),
        Offset(326, 713),
        Offset(145, 632),
        Offset(167, 568),
      ],
    ][index];
    return [
      for (final point in points) drawBounds.topLeft + point * (side / 768),
    ];
  }

  FieldLandmark at(Offset point) =>
      FieldLandmark(stage, index, name, point, side);

  static const names = <WorldStage, List<String>>{
    WorldStage.forest: ['고목의 뿌리', '화강암 능선', '쓰러진 거목', '이끼 돌무리'],
    WorldStage.sands: ['붉은 사암 대지', '거수의 화석', '묻힌 수도교', '바람의 돌문'],
    WorldStage.past: ['무너진 원형극장', '왕국의 수도교', '옛 성채', '태양 신전터'],
    WorldStage.future: ['추락 수송선', '침묵의 안테나', '끊어진 고가도로', '폐쇄 집광장'],
    WorldStage.tombs: ['왕의 영묘', '쓰러진 왕의 얼굴', '잊힌 봉분', '망자의 계단'],
    WorldStage.foundry: ['멈춘 터빈', '폐선 도크', '무너진 냉각탑', '녹슨 배관장'],
    WorldStage.convergence: ['시간의 고목', '결정 능선', '두 시대의 교각', '천체의 고리'],
  };
}
