import 'package:flutter_test/flutter_test.dart';
import 'package:mood_tracker/app/app.dart';

void main() {
  testWidgets('shows dashboard first and navigates between tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MoodTrackerApp());

    expect(find.text('Dashboard'), findsNWidgets(2));
    expect(find.text('Daily Log'), findsOneWidget);
    expect(find.text('Trends'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();

    expect(find.text('Mood'), findsOneWidget);
  });
}
