import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/widgets/pullable_center.dart';
import '../models/streaming_platform.dart';
import '../providers/streaming_platform_providers.dart';

class StreamingPlatformListPage extends ConsumerWidget {
  const StreamingPlatformListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = ref.watch(streamingPlatformsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Streaming Platforms')),
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(streamingPlatformsProvider.future),
          child: platforms.when(
            loading: () =>
                const PullableCenter(child: CircularProgressIndicator()),
            error: (e, _) => PullableCenter(child: Text('Error: $e')),
            data: (list) => list.isEmpty
                ? const PullableCenter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.subscriptions_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('No streaming platforms yet'),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: list.length,
                    itemBuilder: (context, index) =>
                        _PlatformTile(platform: list[index]),
                  ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/watchlist/platforms/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PlatformTile extends ConsumerWidget {
  final StreamingPlatform platform;
  const _PlatformTile({required this.platform});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleParts = [
      if (platform.quality != null) platform.quality!,
      if (platform.isSubscribed)
        'Subscribed'
      else if (platform.subscriptionEndedAt != null)
        'Subscription ended',
    ];

    return Dismissible(
      key: Key(platform.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Platform'),
          content: Text(
            'Delete "${platform.name}"? Entries linked to it keep their '
            'other platforms.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) => ref
          .read(streamingPlatformsProvider.notifier)
          .deletePlatform(platform.id),
      child: ListTile(
        leading: PlatformIcon(platform: platform),
        title: Text(platform.name),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(subtitleParts.join(' • ')),
        trailing: platform.vaultEntryId != null
            ? const Tooltip(
                message: 'Account linked to the password vault',
                child: Icon(Icons.lock_outline, size: 18),
              )
            : null,
        onTap: () => context.push('/watchlist/platforms/${platform.id}'),
      ),
    );
  }
}

/// Platform icon with a lettered fallback, shared by the management list
/// and the entry pages that show which platforms something is on.
class PlatformIcon extends StatelessWidget {
  final StreamingPlatform platform;
  final double size;
  const PlatformIcon({super.key, required this.platform, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: size / 2,
      child: Text(
        platform.name.isNotEmpty ? platform.name[0].toUpperCase() : '?',
      ),
    );
    if (platform.iconUrl == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: platform.iconUrl!,
        width: size,
        height: size,
        memCacheWidth: (size * 3).round(),
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
