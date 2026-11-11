import 'package:flutter_test/flutter_test.dart';
import 'package:zoonl_live/main.dart';

void main() {
  testWidgets('home screen shows rooms and navigates between tabs', (tester) async {
    await tester.pumpWidget(const ZoonlLive());

    expect(find.text('Welcome to ZOONL LIVE'), findsOneWidget);
    expect(find.text('Global Music Room'), findsOneWidget);

    await tester.tap(find.text('Live').last);
    await tester.pumpAndSettle();
    expect(find.text('Find a room and join the conversation.'), findsOneWidget);
  });
}
