import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/game_art.dart';
import 'package:guardian_new/game_ui.dart';

void main() {
  testWidgets('round combat buttons ignore their empty square corners', (
    tester,
  ) async {
    var taps = 0;
    final art = GameArt();
    addTearDown(art.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ActionButton(
            art: art,
            sprite: 'roundEmpty',
            label: '공격',
            showLabel: false,
            semanticLabel: '공격',
            size: 80,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    final button = find.byType(ActionButton);
    final rect = tester.getRect(button);
    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    expect(taps, 0);
    await tester.tapAt(rect.center);
    expect(taps, 1);
  });
}
