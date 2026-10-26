import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/adventure.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/world_map.dart';
import 'package:guardian_new/world_model.dart';
import 'support/test_game.dart';

void main() {
  for (final size in [
    const Size(390, 720),
    const Size(320, 420),
    const Size(844, 390),
  ]) {
    testWidgets('zoomed map fills its viewport near all corners at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = Adventure(GameArt())..start(TestGame());
      session.pause();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ExpandedWorldMap(session: session, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final viewer = find.byType(InteractiveViewer);
      void expectCoverage() {
        final widget = tester.widget<InteractiveViewer>(viewer);
        final viewport = tester.getSize(viewer);
        final bounds = MatrixUtils.transformRect(
          widget.transformationController!.value,
          const Rect.fromLTWH(0, 0, 1200, 900),
        );
        expect(bounds.left, lessThanOrEqualTo(12.01));
        expect(bounds.top, lessThanOrEqualTo(12.01));
        expect(bounds.right, greaterThanOrEqualTo(viewport.width - 12.01));
        expect(bounds.bottom, greaterThanOrEqualTo(viewport.height - 12.01));
      }

      for (final position in [
        const Offset(5, 5),
        Offset(worldSize.width - 50, 5),
        Offset(5, worldSize.height - 50),
        Offset(worldSize.width - 50, worldSize.height - 50),
      ]) {
        session.hero.position.setValues(position.dx, position.dy);
        await tester.tap(find.text('내 위치'));
        await tester.pumpAndSettle();
        expectCoverage();
      }
      for (final delta in [
        const Offset(2000, 1800),
        const Offset(-4000, -3600),
      ]) {
        await tester.drag(viewer, delta);
        await tester.pumpAndSettle();
        expectCoverage();
      }
      await tester.tap(find.byTooltip('지도 축소'));
      await tester.pumpAndSettle();
      expectCoverage();
      await tester.tap(find.text('전체 지도'));
      await tester.pumpAndSettle();
      final widget = tester.widget<InteractiveViewer>(viewer);
      final bounds = MatrixUtils.transformRect(
        widget.transformationController!.value,
        const Rect.fromLTWH(0, 0, 1200, 900),
      );
      expect(bounds.center.dx, closeTo(tester.getSize(viewer).width / 2, .01));
      expect(bounds.center.dy, closeTo(tester.getSize(viewer).height / 2, .01));
      expect(tester.takeException(), null);
    });
  }
}
