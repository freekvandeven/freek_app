import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/calendar_providers.dart';
import '../providers/google_calendar_providers.dart';

/// Polls Google Calendar at a fixed interval and on app foreground so
/// edits made directly in Google Calendar are pulled back into linked
/// local Firestore events. A "first cut" pre-webhook implementation per
/// WISH-0066. Renders its [child] as-is.
class GoogleCalendarSyncTicker extends ConsumerStatefulWidget {
  final Widget child;
  const GoogleCalendarSyncTicker({super.key, required this.child});

  @override
  ConsumerState<GoogleCalendarSyncTicker> createState() =>
      _GoogleCalendarSyncTickerState();
}

class _GoogleCalendarSyncTickerState
    extends ConsumerState<GoogleCalendarSyncTicker>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(minutes: 15);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_pollInterval, (_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
    }
  }

  void _sync() {
    if (!mounted) return;
    if (!ref.read(googleCalendarConnectedProvider)) return;
    // Fire-and-forget; failures are logged inside the notifier.
    ref.read(calendarEventsProvider.notifier).syncFromGoogle();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
