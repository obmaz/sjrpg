import 'dart:ui' as ui;
import 'package:bonfire/bonfire.dart';
import 'adventure.dart';
import 'effect_visibility.dart';
import 'quest_structure_art.dart';
import 'world_model.dart';

class ForestQuestStructure extends GameComponent with EffectVisibility {
  ForestQuestStructure(this.session, this.site) {
    position = Vector2(site.at.dx, site.at.dy);
    size = Vector2.all(1);
  }
  final Adventure session;
  final QuestSite site;
  @override
  ui.Rect get effectBounds =>
      ForestQuestStructureArt.drawBounds(site.id, site.at);
  @override
  int get priority => LayerPriority.getComponentPriority(
    (site.at.dy + (hasGameRef ? gameRef.map.renderPriorityOffsetY : 0)).floor(),
  );
  @override
  void render(ui.Canvas canvas) {
    final image = session.art.images[ForestQuestStructureArt.assetKey(site.id)];
    if (image == null || session.disposed) return;
    final bounds = effectBounds;
    final hidden =
        session.hero.body.bottom < site.at.dy &&
        bounds.overlaps(session.hero.body);
    canvas.save();
    canvas.translate(-position.x, -position.y);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      bounds,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.medium
        ..color = ui.Color.fromRGBO(255, 255, 255, hidden ? .5 : 1),
    );
    canvas.restore();
  }
}
