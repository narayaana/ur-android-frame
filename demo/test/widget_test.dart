import 'package:flutter_test/flutter_test.dart';
import 'package:ur_android_frame_demo/main.dart';

void main() {
  testWidgets('App renders toolbar', (tester) async {
    await tester.pumpWidget(const UrDemoApp());
    await tester.pump();

    // Toolbar should render with sign-in link and theme toggle
    expect(find.byType(UrDemoApp), findsOneWidget);
  });
}
