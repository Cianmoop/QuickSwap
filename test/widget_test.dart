import 'package:flutter_test/flutter_test.dart';
import 'package:quick_swap/main.dart';

void main() {
  testWidgets('QuickSwap home screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickSwapApp());
    expect(find.text('QuickSwap'), findsOneWidget);
    expect(find.text('发送照片 / 视频'), findsOneWidget);
    expect(find.text('接收照片 / 视频'), findsOneWidget);
  });
}
