import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/presentation/theme/app_scroll_behavior.dart';

void main() {
  group('AppScrollBehavior (WISH-0090)', () {
    test('adds mouse to the draggable pointer devices', () {
      final behavior = AppScrollBehavior();
      expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
      // Sanity check it didn't drop what Material already enables.
      expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
      expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
    });

    testWidgets('a mouse drag past the top can pull to refresh', (
      tester,
    ) async {
      var refreshed = false;

      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: AppScrollBehavior(),
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                refreshed = true;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: List.generate(
                  20,
                  (i) => ListTile(title: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      );

      // Flutter's default ScrollBehavior excludes PointerDeviceKind.mouse
      // from dragDevices, so a plain mouse drag wouldn't scroll — let
      // alone overscroll far enough to arm RefreshIndicator — without
      // AppScrollBehavior. This drag is exactly that gesture.
      final gesture = await tester.startGesture(
        const Offset(200, 200),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 400));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(refreshed, isTrue);
    });
  });
}
