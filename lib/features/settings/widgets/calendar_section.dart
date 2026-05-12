import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../calendar/providers/google_calendar_providers.dart';
import 'section_header.dart';

/// Only renders content when the user has connected Google Calendar.
class CalendarSection extends ConsumerWidget {
  const CalendarSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(googleCalendarConnectedProvider);
    if (!connected) return const SizedBox.shrink();
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('Calendar'),
        SwitchListTile(
          secondary: const Icon(Icons.calendar_month),
          title: const Text('Sync new events to Google Calendar'),
          subtitle: const Text(
            'Automatically push newly created events to your Google Calendar',
          ),
          value: user.settings.syncToGoogleCalendar,
          onChanged: (v) {
            final updated = user.copyWith(
              settings: user.settings.copyWith(syncToGoogleCalendar: v),
            );
            ref.read(authServiceProvider).updateProfile(updated);
          },
        ),
      ],
    );
  }
}
