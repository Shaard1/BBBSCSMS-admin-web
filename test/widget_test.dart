import 'package:barangay_admin_web/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin app builds with an injectable home', (tester) async {
    await tester.pumpWidget(
      const MyApp(
        home: Scaffold(
          body: Center(child: Text('Admin smoke test')),
        ),
      ),
    );

    expect(find.text('Admin smoke test'), findsOneWidget);
  });
}
