import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../widgets/app_snackbar.dart';

/// Handle returned by [useAutosave]. Also carries the saved-baseline
/// bookkeeping the unsaved-changes guard needs (WISH-0079), since autosave
/// and the dirty check share one "last saved snapshot".
class AutosaveController {
  AutosaveController._({
    required bool Function() isDirty,
    required void Function() markClean,
    required Future<void> Function() autosaveNow,
  }) : _isDirty = isDirty,
       _markClean = markClean,
       _autosaveNow = autosaveNow;

  final bool Function() _isDirty;
  final void Function() _markClean;
  final Future<void> Function() _autosaveNow;

  /// True when the current snapshot differs from the saved baseline.
  /// False while no baseline exists yet (an existing item still loading).
  bool get isDirty => _isDirty();

  /// Records the current snapshot as the saved baseline. Call after
  /// loading an existing item and after a successful manual save.
  void markClean() => _markClean();

  /// Runs one autosave pass immediately — same throttle and no-op checks
  /// as a timer tick.
  Future<void> autosaveNow() => _autosaveNow();
}

/// Shared autosave machinery for edit pages (IMPR-0020): a periodic timer
/// driven by the user's autosave interval, snapshot comparison to skip
/// no-op saves, the BUG-0033 browser-throttle guard, baseline bookkeeping,
/// and the "Auto-saved" snackbar.
///
/// [snapshot] must be a pure function of the current form state. [save]
/// persists the form and returns false to skip (e.g. validation failed) —
/// the baseline only advances on a `true` return, and errors thrown by
/// [save] are swallowed so autosave never surfaces them (the manual save
/// path is responsible for reporting).
///
/// [intervalMinutes] of 0 (or [enabled] false) disables the timer; the
/// dirty tracking keeps working either way. Set [captureInitialBaseline]
/// on new-item pages so the empty form counts as clean; existing-item
/// pages call [AutosaveController.markClean] once their data is loaded.
AutosaveController useAutosave({
  required int intervalMinutes,
  required String Function() snapshot,
  required Future<bool> Function() save,
  bool enabled = true,
  bool captureInitialBaseline = false,
}) {
  final context = useContext();
  final baseline = useRef<String?>(null);
  final lastSavedAt = useRef<DateTime?>(null);
  // Latest-callback refs so the stable controller never closes over a
  // previous build's state.
  final snapshotRef = useRef(snapshot)..value = snapshot;
  final saveRef = useRef(save)..value = save;
  final intervalRef = useRef(intervalMinutes)..value = intervalMinutes;

  useEffect(() {
    if (captureInitialBaseline) {
      baseline.value ??= snapshotRef.value();
    }
    return null;
  }, const []);

  final controller = useMemoized(
    () => AutosaveController._(
      isDirty: () {
        final base = baseline.value;
        if (base == null) return false;
        return snapshotRef.value() != base;
      },
      markClean: () => baseline.value = snapshotRef.value(),
      autosaveNow: () async {
        if (!context.mounted) return;

        // Browser-throttled Timer.periodic ticks can pile up when the tab
        // is backgrounded and all fire when it regains focus (BUG-0033).
        // Skip any tick that arrives within 80% of the configured interval.
        final intervalMin = intervalRef.value;
        final last = lastSavedAt.value;
        if (intervalMin > 0 && last != null) {
          // clock.now() == DateTime.now() in production; fake-time aware
          // in widget tests so the guard is testable.
          final since = clock.now().difference(last);
          final minWait = Duration(milliseconds: intervalMin * 60 * 800);
          if (since < minWait) return;
        }

        // Skip if nothing has changed since the previous save.
        final snap = snapshotRef.value();
        if (snap == baseline.value) return;

        try {
          if (!await saveRef.value()) return;
          lastSavedAt.value = clock.now();
          baseline.value = snap;
          if (context.mounted) {
            context.showSuccessSnackbar(
              'Auto-saved',
              duration: const Duration(seconds: 2),
            );
          }
        } catch (_) {
          // Silently ignore autosave errors
        }
      },
    ),
  );

  useEffect(() {
    if (!enabled || intervalMinutes <= 0) return null;
    final timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => controller.autosaveNow(),
    );
    return timer.cancel;
  }, [enabled, intervalMinutes]);

  return controller;
}
