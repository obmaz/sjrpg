import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_new/install_controls.dart';

void main() {
  testWidgets('unsupported install opens useful manual instructions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InstallControls())),
    );
    await tester.tap(find.text('앱 설치'));
    await tester.pumpAndSettle();
    expect(find.text('앱 설치 안내'), findsOneWidget);
    expect(find.textContaining('홈 화면에 추가'), findsNWidgets(2));
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('앱 설치 안내'), findsNothing);
  });
}
