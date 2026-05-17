import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sonlite/main.dart';

void main() {
  testWidgets('SonLite app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SonLiteApp()),
    );
    expect(find.byType(MaterialApp), findsNothing);
  });
}
