import 'package:calistrack/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the Today tab with a five-destination nav',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CalisTrackApp()));
    await tester.pumpAndSettle();

    // Today is the initial tab.
    expect(find.text("Today's workout will appear here."), findsOneWidget);

    // All five destinations are present.
    for (final label in [
      'Today',
      'Programs',
      'Progress',
      'Skills',
      'Profile',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    // Tapping Programs navigates.
    await tester.tap(find.text('Programs'));
    await tester.pumpAndSettle();
    expect(
      find.text('Preset and AI-generated programs will appear here.'),
      findsOneWidget,
    );
  });
}
