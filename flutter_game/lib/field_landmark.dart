import 'dart:ui';

import 'stage_content.dart';

/// One large, authored terrain formation. The same footprint is used by
/// movement, projectiles, spatial indexing and the flat map contour.
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
