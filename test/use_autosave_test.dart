import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/presentation/hooks/use_autosave.dart';

class _Harness extends HookWidget {
  final int intervalMinutes;
  final bool enabled;
  final bool captureInitialBaseline;
  final String Function() snapshot;
  final Future<bool> Function() save;
  final void Function(AutosaveController) onController;

  const _Harness({
    required this.intervalMinutes,
    this.enabled = true,
    this.captureInitialBaseline = false,
    required this.snapshot,
    required this.save,
    required this.onController,
  });

  @override
  Widget build(BuildContext context) {
    onController(
      useAutosave(
        intervalMinutes: intervalMinutes,
        enabled: enabled,
        captureInitialBaseline: captureInitialBaseline,
        snapshot: snapshot,
        save: save,
      ),
    );
    return const SizedBox.shrink();
  }
}

void main() {
  late AutosaveController controller;

  Widget harness({
    int intervalMinutes = 5,
    bool enabled = true,
    bool captureInitialBaseline = false,
    required String Function() snapshot,
    required Future<bool> Function() save,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: _Harness(
          intervalMinutes: intervalMinutes,
          enabled: enabled,
          captureInitialBaseline: captureInitialBaseline,
          snapshot: snapshot,
          save: save,
          onController: (c) => controller = c,
        ),
      ),
    );
  }

  group('useAutosave (IMPR-0020)', () {
    testWidgets('isDirty stays false without a baseline until markClean', (
      tester,
    ) async {
      var snap = 'a';
      await tester.pumpWidget(
        harness(snapshot: () => snap, save: () async => true),
      );

      snap = 'b';
      expect(controller.isDirty, isFalse);

      controller.markClean();
      expect(controller.isDirty, isFalse);
      snap = 'c';
      expect(controller.isDirty, isTrue);
    });

    testWidgets('captureInitialBaseline makes the initial form the clean '
        'state', (tester) async {
      var snap = 'empty';
      await tester.pumpWidget(
        harness(
          captureInitialBaseline: true,
          snapshot: () => snap,
          save: () async => true,
        ),
      );

      expect(controller.isDirty, isFalse);
      snap = 'typed';
      expect(controller.isDirty, isTrue);
    });

    testWidgets('timer tick saves when the snapshot changed and shows the '
        'snackbar', (tester) async {
      var snap = 'a';
      var saves = 0;
      await tester.pumpWidget(
        harness(
          captureInitialBaseline: true,
          snapshot: () => snap,
          save: () async {
            saves++;
            return true;
          },
        ),
      );

      snap = 'b';
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();

      expect(saves, 1);
      expect(controller.isDirty, isFalse);
      expect(find.text('Auto-saved'), findsOneWidget);
    });

    testWidgets('timer tick skips when nothing changed', (tester) async {
      var saves = 0;
      await tester.pumpWidget(
        harness(
          captureInitialBaseline: true,
          snapshot: () => 'same',
          save: () async {
            saves++;
            return true;
          },
        ),
      );

      await tester.pump(const Duration(minutes: 15));
      expect(saves, 0);
      expect(find.text('Auto-saved'), findsNothing);
    });

    testWidgets('BUG-0033 throttle skips a second pass within 80% of the '
        'interval', (tester) async {
      var snap = 'a';
      var saves = 0;
      await tester.pumpWidget(
        harness(
          captureInitialBaseline: true,
          snapshot: () => snap,
          save: () async {
            saves++;
            return true;
          },
        ),
      );

      snap = 'b';
      await controller.autosaveNow();
      expect(saves, 1);

      snap = 'c';
      await controller.autosaveNow();
      expect(saves, 1);
      expect(controller.isDirty, isTrue);

      // 4 minutes = 80% of the 5-minute interval: allowed again.
      await tester.pump(const Duration(minutes: 4));
      await controller.autosaveNow();
      expect(saves, 2);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('save returning false keeps the baseline and shows no '
        'snackbar', (tester) async {
      var snap = 'a';
      await tester.pumpWidget(
        harness(
          captureInitialBaseline: true,
          snapshot: () => snap,
          save: () async => false,
        ),
      );

      snap = 'b';
      await controller.autosaveNow();
      await tester.pump();

      expect(controller.isDirty, isTrue);
      expect(find.text('Auto-saved'), findsNothing);
    });

    testWidgets('a throwing save is swallowed and keeps the baseline', (
      tester,
    ) async {
      var snap = 'a';
      await tester.pumpWidget(
        harness(
          captureInitialBaseline: true,
          snapshot: () => snap,
          save: () async => throw Exception('offline'),
        ),
      );

      snap = 'b';
      await controller.autosaveNow();
      await tester.pump();

      expect(controller.isDirty, isTrue);
      expect(find.text('Auto-saved'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no timer when disabled or interval is 0', (tester) async {
      var snap = 'a';
      var saves = 0;
      Future<bool> save() async {
        saves++;
        return true;
      }

      await tester.pumpWidget(
        harness(
          enabled: false,
          captureInitialBaseline: true,
          snapshot: () => snap,
          save: save,
        ),
      );
      snap = 'b';
      await tester.pump(const Duration(minutes: 30));
      expect(saves, 0);

      await tester.pumpWidget(
        harness(
          intervalMinutes: 0,
          captureInitialBaseline: true,
          snapshot: () => snap,
          save: save,
        ),
      );
      snap = 'c';
      await tester.pump(const Duration(minutes: 30));
      expect(saves, 0);
    });
  });
}
