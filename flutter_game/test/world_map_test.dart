import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';
import 'package:guardian_new/world_map.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 420),
    const Size(844, 390),
  ]) {
    testWidgets(
      'map markers retain screen size and quest focus stays usable at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = Adventure(GameArt())..start(TestGame());
        s.pause();
        addTearDown(s.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: ExpandedWorldMap(session: s, onClose: () {}),
          ),
        );
        await tester.pumpAndSettle();
        final viewer = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        MapPainter painter() => tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<MapPainter>()
            .single;
        for (final label in ['전체 지도', '지도 확대하기', '지도 축소', '내 위치']) {
          await tester.tap(
            find.byTooltip(label).evaluate().isNotEmpty
                ? find.byTooltip(label)
                : find.text(label),
          );
          await tester.pumpAndSettle();
          if (label == '전체 지도') {
            expect(
              viewer.transformationController!.value.storage[0].abs(),
              lessThan(1),
            );
            expect(painter().markerScale, greaterThan(1));
          }
          expect(
            painter().markerScale *
                viewer.transformationController!.value.storage[0].abs(),
            closeTo(1, .001),
          );
        }
        final semantics = tester.ensureSemantics();
        final site = s.visibleSites.firstWhere(
          (site) => site.id != s.trackedSite?.id,
        );
        final before = s.hero.position.clone();
        await tester.tap(find.bySemanticsLabel('지도 목표 · ${site.name}'));
        await tester.pumpAndSettle();
        expect(s.trackedSite?.id, site.id);
        expect(s.hero.position, before);
        expect(
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .where((w) => w.properties.selected == true)
              .length,
          1,
        );
        final projected = Offset(
          site.at.dx / worldSize.width * 1200,
          site.at.dy / worldSize.height * 900,
        );
        final result = MatrixUtils.transformPoint(
          viewer.transformationController!.value,
          projected,
        );
        final viewport = tester.getSize(find.byType(InteractiveViewer));
        expect((Offset.zero & viewport).deflate(8).contains(result), true);
        await tester.tap(find.bySemanticsLabel('지도 목표 · ${site.name}'));
        await tester.pumpAndSettle();
        expect(s.trackedSite, null);
        expect(tester.takeException(), null);
        semantics.dispose();
      },
    );
  }
}
