import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bonfire/bonfire.dart';

import 'adventure.dart';
import 'travel_journal.dart';
import 'world_model.dart';

const _portalFrames = [0, 1, 2, 3, 4, 5, 7, 6, 8, 9, 10, 11, 12, 13, 14, 15];
final _animations = Expando<SpriteAnimation>();

SpriteAnimation wellPortalAnimation(ui.Image image) {
  final cached = _animations[image];
  if (cached != null) return cached;
  final animation = SpriteAnimation.spriteList([
    for (final frame in _portalFrames)
      Sprite(
        image,
        srcPosition: Vector2(frame % 4 * 313.0, frame ~/ 4 * 313.0),
        srcSize: Vector2.all(313),
      ),
  ], stepTime: 1 / 30);
  _animations[image] = animation;
  return animation;
}

/// A visual portal and a tap target, with no physical collision body.
class WellPortal extends GameComponent with TapGesture {
  WellPortal(this.session, this.well, this.at, {required this.onOpen}) {
    position = Vector2(at.dx - 56, at.dy - 107);
    size = Vector2.all(112);
  }
  final Adventure session;
  final DiscoveredWell well;
  final ui.Offset at;
  final void Function() onOpen;

  bool get canUse =>
      session.active &&
      session.riding == null &&
      well.stage == session.world.stage &&
      session.travelJournal
              .nearbyWell(session.world, session.hero.body.center)
              ?.id ==
          well.id;

  @override
  int get priority => LayerPriority.getComponentPriority(
    (at.dy + (hasGameRef ? gameRef.map.renderPriorityOffsetY : 0)).floor(),
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final image = session.art.images['well-portal'];
    if (image == null || session.disposed) return;
    await add(
      SpriteAnimationComponent(
        animation: wellPortalAnimation(image),
        position: Vector2(56, 107),
        anchor: const Anchor(158 / 313, 299 / 313),
        size: Vector2.all(112),
        paint: ui.Paint()..filterQuality = ui.FilterQuality.medium,
      ),
    );
  }

  @override
  bool onTapDown(GestureEvent event) => canUse;

  @override
  void renderTree(ui.Canvas canvas) {
    if (hasGameRef) {
      final viewport = gameRef.camera.visibleWorldRect;
      if (viewport.isFinite &&
          !viewport.isEmpty &&
          !viewport.overlaps(toRect().inflate(2))) {
        return;
      }
    }
    super.renderTree(canvas);
  }

  @override
  void onTap() {
    if (canUse) onOpen();
  }
}

ui.Offset? wellPortalPosition(Adventure session, QuestSite well) {
  final approach = well.at + const ui.Offset(0, 77);
  bool available(ui.Offset at) =>
      !session.world.blocked(
        ui.Rect.fromCenter(center: at, width: 44, height: 36),
      ) &&
      session.world.clearLine(approach, at, const ui.Size(3, 3)) &&
      (at - session.world.merchantAt).distance > 70 &&
      (at - session.world.elderAt).distance > 70 &&
      !session.mounts.any((mount) => (mount.at - at).distance < 65) &&
      !session.stageChestLocations.indexed.any(
        (entry) =>
            !session.openedChests.contains(entry.$1) &&
            (entry.$2 - at).distance < 75,
      );
  for (final offset in const [
    ui.Offset(120, 72),
    ui.Offset(-120, 72),
    ui.Offset(155, 95),
    ui.Offset(-155, 95),
    ui.Offset(105, 130),
    ui.Offset(-105, 130),
  ]) {
    final at = well.at + offset;
    if (available(at)) return at;
  }
  for (var radius = 110.0; radius <= 210; radius += 25) {
    for (var i = 0; i < 16; i++) {
      final angle = math.pi * i / 8;
      final at = well.at + ui.Offset(math.cos(angle), math.sin(angle)) * radius;
      if (available(at)) return at;
    }
  }
  return null;
}

/// Discovery uses simulation time. Opening a menu pauses both this scan and
/// Flame's child animation tickers through the shared Bonfire game lifecycle.
class WellDiscoveryDirector extends GameComponent {
  WellDiscoveryDirector(
    this.session, {
    required this.onOpen,
    required this.onDiscovered,
  });
  final Adventure session;
  final void Function() onOpen, onDiscovered;
  final _portals = <String, WellPortal>{};
  double _untilScan = 0;

  @override
  void update(double dt) {
    if (!session.active || !hasGameRef) return;
    _untilScan -= dt.clamp(0, .1);
    if (_untilScan > 0) return;
    _untilScan = .15;
    var found = false;
    final stage = session.world.stage;
    for (final well in wellSitesForStage(
      stage,
      hubOrigin: session.world.spawn,
    )) {
      if ((well.at - session.hero.body.center).distance < 240 &&
          session.world.clearLine(
            session.hero.body.center,
            well.at + const ui.Offset(0, 77),
            const ui.Size(3, 3),
          )) {
        found = session.travelJournal.discover(stage, well.id) || found;
      }
      if (!_portals.containsKey(well.id) &&
          session.travelJournal.hasDiscovered(stage, well.id)) {
        final at = wellPortalPosition(session, well);
        if (at != null) {
          final portal = WellPortal(
            session,
            DiscoveredWell(stage, well.id),
            at,
            onOpen: onOpen,
          );
          _portals[well.id] = portal;
          gameRef.add(portal);
        }
      }
    }
    if (found) {
      session.refresh();
      onDiscovered();
    }
    super.update(dt);
  }

  @override
  void onRemove() {
    for (final portal in _portals.values) {
      portal.removeFromParent();
    }
    _portals.clear();
    super.onRemove();
  }
}
