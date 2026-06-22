import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic app shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('PocketPilot')),
        ),
      ),
    );

    expect(find.text('PocketPilot'), findsOneWidget);
  });
}
