import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/presentation/hooks/use_synced_search_controller.dart';

class _Harness extends HookWidget {
  final String value;
  final void Function(TextEditingController) onController;

  const _Harness({required this.value, required this.onController});

  @override
  Widget build(BuildContext context) {
    final controller = useSyncedSearchController(value);
    onController(controller);
    return MaterialApp(
      home: Scaffold(body: TextField(controller: controller)),
    );
  }
}

void main() {
  group('useSyncedSearchController (BUG-0047)', () {
    testWidgets('seeds the controller with the initial value', (tester) async {
      late TextEditingController controller;
      await tester.pumpWidget(
        _Harness(value: 'soap', onController: (c) => controller = c),
      );

      expect(controller.text, 'soap');
      expect(find.text('soap'), findsOneWidget);
    });

    testWidgets('updates the visible text when value changes externally', (
      tester,
    ) async {
      late TextEditingController controller;
      await tester.pumpWidget(
        _Harness(value: 'soap', onController: (c) => controller = c),
      );
      expect(controller.text, 'soap');

      // Simulate the provider being reset elsewhere (e.g. leaving the
      // feature) by rebuilding with a new value — this is exactly what
      // ref.watch(searchProvider) picking up an external change looks
      // like from the hook's perspective.
      await tester.pumpWidget(
        _Harness(value: '', onController: (c) => controller = c),
      );

      expect(controller.text, isEmpty);
      expect(find.text('soap'), findsNothing);
    });

    testWidgets('does not fight the user while they are typing', (
      tester,
    ) async {
      late TextEditingController controller;
      await tester.pumpWidget(
        _Harness(value: '', onController: (c) => controller = c),
      );

      await tester.enterText(find.byType(TextField), 'ric');
      await tester.pump();

      // The field's own onChanged would normally propagate 'ric' back to
      // the provider, so a rebuild would see value == 'ric' == the
      // controller's own text already — no resync, cursor stays put.
      await tester.pumpWidget(
        _Harness(value: 'ric', onController: (c) => controller = c),
      );

      expect(controller.text, 'ric');
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
    });

    testWidgets('moves the cursor to the end on an externally-set value', (
      tester,
    ) async {
      late TextEditingController controller;
      await tester.pumpWidget(
        _Harness(value: '', onController: (c) => controller = c),
      );

      await tester.pumpWidget(
        _Harness(value: 'preset', onController: (c) => controller = c),
      );

      expect(controller.text, 'preset');
      expect(controller.selection, const TextSelection.collapsed(offset: 6));
    });
  });
}
