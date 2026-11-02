import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veil/config.dart';
import 'package:veil/screens/legal_screen.dart';

void main() {
  test('both documents carry the version recorded in consent', () {
    for (final d in LegalDoc.values) {
      final text = File(d.asset).readAsStringSync();
      expect(text, contains('Version ${Config.policyVersion}'), reason: d.asset);
    }
  });

  testWidgets('privacy policy renders headings and the retention table', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen(doc: LegalDoc.privacy)));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('The short version'), findsOneWidget);
    final tableHeader = find.text('Kept until', findRichText: true);
    await tester.scrollUntilVisible(tableHeader, 300);
    expect(tableHeader, findsOneWidget);
    expect(find.text('How long it is kept'), findsOneWidget);
  });
}
