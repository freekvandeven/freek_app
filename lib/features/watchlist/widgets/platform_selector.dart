import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/streaming_platform_list_page.dart' show PlatformIcon;
import '../providers/streaming_platform_providers.dart';

/// Multi-select of the streaming platforms an entry is available on
/// (WISH-0099). Selecting nothing is normal — plenty of entries are not
/// on any subscription the user has.
class PlatformSelector extends ConsumerWidget {
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const PlatformSelector({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = ref.watch(streamingPlatformsProvider).valueOrNull ?? [];

    if (platforms.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.subscriptions_outlined),
        title: const Text('No platforms configured'),
        subtitle: const Text('Add one to link this entry to it'),
        trailing: TextButton(
          onPressed: () => context.push('/watchlist/platforms/new'),
          child: const Text('Add'),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final platform in platforms)
          FilterChip(
            avatar: PlatformIcon(platform: platform, size: 24),
            label: Text(platform.name),
            selected: selectedIds.contains(platform.id),
            onSelected: (selected) => onChanged(
              selected
                  ? [...selectedIds, platform.id]
                  : selectedIds.where((id) => id != platform.id).toList(),
            ),
          ),
      ],
    );
  }
}

/// Row of platform icons for an entry, resolving ids through the platform
/// map. Silently skips ids whose platform has been deleted.
class PlatformIcons extends ConsumerWidget {
  final List<String> platformIds;
  final double size;

  const PlatformIcons({super.key, required this.platformIds, this.size = 20});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (platformIds.isEmpty) return const SizedBox.shrink();
    final byId = ref.watch(streamingPlatformsByIdProvider);
    final platforms = platformIds.map((id) => byId[id]).nonNulls.toList();
    if (platforms.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      children: [
        for (final platform in platforms)
          Tooltip(
            message: platform.name,
            child: PlatformIcon(platform: platform, size: size),
          ),
      ],
    );
  }
}
