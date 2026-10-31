import 'dart:ui';

import 'field_landmark.dart';
import 'field_landscape.dart';
import 'world_model.dart';

/// A restrained, top-down reading of the actual world. No scene photographs,
/// textures, particles or small random props enter either map view.
class TerrainMapPlan {
  TerrainMapPlan(this.world, this.landscape, this.water, this.dryGround);
  final AdventureWorld world;
  final FieldLandscape landscape;
  final Path water, dryGround;
  late final _landmarkContours = {
    for (final landmark in world.landmarks) landmark: _contour(landmark),
  };
  bool _wooded(FieldLandmark landmark) =>
      world.stage == WorldStage.forest &&
          (landmark.index == 0 || landmark.index == 2) ||
      world.stage == WorldStage.convergence && landmark.index == 0;
  Path _contour(FieldLandmark landmark) {
    if (landmark.stage == WorldStage.forest) {
      return Path()..addPolygon(landmark.solidOutline, true);
    }
    final b = landmark.footprint;
    if (_wooded(landmark)) return Path()..addOval(b);
    if (world.stage == WorldStage.future || world.stage == WorldStage.foundry) {
      return Path()
        ..addRRect(RRect.fromRectAndRadius(b, const Radius.circular(22)));
    }
    return Path()..addPolygon([
      Offset(b.left + b.width * .12, b.top),
      Offset(b.left + b.width * .65, b.top),
      Offset(b.right, b.top + b.height * .35),
      Offset(b.right - b.width * .08, b.bottom),
      Offset(b.left + b.width * .24, b.bottom),
      Offset(b.left, b.center.dy),
    ], true);
  }

  Color _surface(FieldGround kind) => switch (kind) {
    FieldGround.meadow => const Color(0xff637756),
    FieldGround.desert => const Color(0xffa18b67),
    FieldGround.stone => const Color(0xff858477),
    FieldGround.industrial => const Color(0xff45555a),
  };

  void paint(Canvas canvas, Rect view, {required double unitsPerPixel}) {
    canvas.drawRect(
      Offset.zero & worldSize,
      Paint()..color = world.stage.mapColor,
    );
    for (final region in landscape.regions) {
      if (!region.bounds.overlaps(view)) continue;
      canvas.drawPath(region.path, Paint()..color = _surface(region.ground));
    }
    for (final wood in world.woods) {
      if (wood.bounds.overlaps(view)) {
        canvas.drawPath(wood.path, Paint()..color = const Color(0xff465f49));
      }
    }
    for (final clearing in world.clearings) {
      if (clearing.bounds.overlaps(view)) {
        canvas.drawPath(
          clearing.path,
          Paint()..color = world.stage.clearingColor,
        );
      }
    }
    for (final sand in world.sandFields) {
      if (sand.bounds.overlaps(view)) {
        canvas.drawPath(
          sand.path,
          Paint()
            ..color = world.stage == WorldStage.tombs
                ? const Color(0xff9a9484)
                : const Color(0xffb09b72),
        );
      }
    }
    canvas.drawPath(
      water,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unitsPerPixel * 1.4
        ..color = const Color(0xff989e87),
    );
    canvas.drawPath(water, Paint()..color = const Color(0xff426b75));
    canvas.save();
    canvas.clipPath(dryGround, doAntiAlias: false);
    for (final trail in world.trails) {
      if (!trail.bounds.inflate(trail.width).overlaps(view)) continue;
      canvas.drawPath(
        trail.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = trail.width.clamp(
            unitsPerPixel * .9,
            unitsPerPixel * 2.4,
          )
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xffc0b28c),
      );
    }
    canvas.drawRect(world.settlement, Paint()..color = const Color(0xffa39779));
    canvas.restore();
    // Bridges cross the real water mask, so their plan must be painted after
    // leaving the dry-land clip, just as their world artwork is.
    for (final bridge in world.bridges) {
      canvas.drawRect(bridge, Paint()..color = const Color(0xffc0b28c));
    }

    for (final landmark in world.landmarks) {
      if (!landmark.footprint.overlaps(view)) continue;
      final body = _landmarkContours[landmark]!;
      canvas.drawPath(
        body,
        Paint()
          ..color = _wooded(landmark)
              ? const Color(0xff354e3b)
              : const Color(0xff646258),
      );
      canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unitsPerPixel * .8
          ..color = const Color(0xffb7ae91),
      );
      // A single contour suggests a raised formation without copying its art.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          landmark.footprint.deflate(landmark.footprint.height * .22),
          const Radius.circular(40),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unitsPerPixel * .65
          ..color = const Color(0xff96917c),
      );
    }

    final settlement = world.authoredSettlement;
    canvas.save();
    canvas.clipPath(world.sanctuary.boundaryPath);
    for (final gate in settlement.gatePaths) {
      canvas.drawLine(
        gate.first,
        world.healAt,
        Paint()
          ..color = const Color(0xffc0b28c)
          ..strokeWidth = 100
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final building in world.settlementCollision) {
      canvas.drawPath(building.path, Paint()..color = const Color(0xff5d5c50));
      canvas.drawPath(
        building.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unitsPerPixel * .7
          ..color = const Color(0xffc2b697),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: world.healAt, width: 180, height: 140),
      Paint()..color = const Color(0xff527b83),
    );
    canvas.restore();
  }
}
