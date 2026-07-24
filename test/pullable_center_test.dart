import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/presentation/widgets/pullable_center.dart';

void main() {
  group('PullableCenter (WISH-0090)', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PullableCenter(child: Text('No items yet'))),
        ),
      );

      expect(find.text('No items yet'), findsOneWidget);
    });

    testWidgets('is pullable via mouse drag even though the child is tiny', (
      tester,
    ) async {
      var refreshed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                refreshed = true;
              },
              // A single short Text would never overflow the viewport on
              // its own — RefreshIndicator can't fire on a non-scrollable,
              // so without PullableCenter's internal ListView this drag
              // would do nothing at all (WISH-0090).
              child: const PullableCenter(child: Text('Empty')),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 200));
      await gesture.moveBy(const Offset(0, 400));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(refreshed, isTrue);
    });
  });
}
