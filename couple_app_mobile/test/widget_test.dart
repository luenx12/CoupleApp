import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app_mobile/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CoupleApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
