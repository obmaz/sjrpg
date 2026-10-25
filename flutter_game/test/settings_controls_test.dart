import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/settings_controls.dart';

void main() {
  testWidgets(
    'a setting responds to touch and keyboard, but not while disabled',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var enabled = true, value = true, changes = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return GameSettingToggle(
                  label: '타격 진동',
                  subtitle: '공격 적중 · 피격 · 스킬 사용',
                  value: value,
                  icon: Icons.vibration,
                  onChanged: enabled
                      ? (next) => setState(() {
                          value = next;
                          changes++;
                        })
                      : null,
                );
              },
            ),
          ),
        ),
      );
      final control = find.bySemanticsLabel('타격 진동');
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(value, false);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(value, true);
      expect(changes, 2);
      update(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(changes, 2);
      expect(tester.takeException(), null);
      semantics.dispose();
    },
  );
  for (final size in [const Size(320, 420), const Size(844, 390)]) {
    testWidgets(
      'a long installation notice scrolls above fixed confirmation at $size',
      (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => GameNoticeDialog(
                      title: '앱 설치 안내',
                      icon: Icons.install_mobile,
                      message: List.filled(
                        18,
                        '브라우저 메뉴에서 홈 화면에 추가를 선택하세요.',
                      ).join('\n'),
                    ),
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(find.text('앱 설치 안내'), findsOneWidget);
        expect(find.bySemanticsLabel('앱 설치 안내'), findsOneWidget);
        final confirm = find.bySemanticsLabel('확인');
        final rect = tester.getRect(confirm);
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(confirm), rect);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(find.text('앱 설치 안내'), findsNothing);
        expect(tester.takeException(), null);
        semantics.dispose();
      },
    );
  }
}
