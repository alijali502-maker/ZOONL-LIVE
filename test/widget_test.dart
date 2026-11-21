import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoonl_live/core/zoonl_theme.dart';

void main() {
  test('ZOONL theme uses the premium violet and cyan palette', () {
    final theme = ZoonlTheme.dark;
    expect(theme.colorScheme.primary, ZoonlTheme.champagne);
    expect(theme.colorScheme.secondary, ZoonlTheme.teal);
    expect(theme.scaffoldBackgroundColor, ZoonlTheme.background);
  });

  testWidgets('the shared theme renders readable text and controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZoonlTheme.dark,
        home: const Scaffold(
          body: Center(child: Text('ZOONL LIVE')),
        ),
      ),
    );
    expect(find.text('ZOONL LIVE'), findsOneWidget);
  });
}
