import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veil/main.dart';

void main() {
  testWidgets('welcome asks only for a name, no password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    expect(find.byTooltip('Get started'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('No account needed'), findsOneWidget);
  });
}
