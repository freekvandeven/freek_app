import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../auth/providers/auth_providers.dart';
import '../widgets/account_section.dart';
import '../widgets/ai_section.dart';
import '../widgets/appearance_section.dart';
import '../widgets/calendar_section.dart';
import '../widgets/data_section.dart';
import '../widgets/preferences_section.dart';
import '../widgets/profile_section.dart';
import '../widgets/storage_section.dart';
import '../widgets/watchlist_section.dart';
import '../widgets/widgets_section.dart';

/// Thin composition page — each section lives in its own widget under
/// `../widgets/` so they can be edited and tested in isolation.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const QuickActionsTitle(child: Text('Settings'))),
      body: ResponsiveCenter(
        child: ListView(
          children: const [
            ProfileSection(),
            AppearanceSection(),
            PreferencesSection(),
            CalendarSection(),
            DataSection(),
            StorageSection(),
            AiSection(),
            WatchlistSection(),
            WidgetsSection(),
            AccountSection(),
          ],
        ),
      ),
    );
  }
}
