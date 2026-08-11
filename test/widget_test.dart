import 'package:flutter_test/flutter_test.dart';
import 'package:chatting/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChattingApp());
    expect(find.byType(ChattingApp), findsOneWidget);
  });
}
