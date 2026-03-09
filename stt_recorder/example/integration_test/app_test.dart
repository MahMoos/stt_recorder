import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stt_recorder_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('example app', () {
    testWidgets('renders capture controls', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('Start Capture'), findsOneWidget);
      expect(find.text('Stop Capture'), findsOneWidget);
      expect(find.text('Cancel Capture'), findsOneWidget);
    });
  });
}
