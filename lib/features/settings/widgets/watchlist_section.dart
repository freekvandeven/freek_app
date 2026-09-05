import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/widgets/app_snackbar.dart';
import '../../watchlist/providers/tmdb_providers.dart';
import 'section_header.dart';

/// Watchlist settings — currently just the TMDB key used to fetch movie
/// and series details (WISH-0100).
class WatchlistSection extends ConsumerWidget {
  const WatchlistSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SettingsSectionHeader('Watchlist'), _TmdbApiKeyTile()],
    );
  }
}

class _TmdbApiKeyTile extends ConsumerWidget {
  const _TmdbApiKeyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(tmdbAvailableProvider);

    return ListTile(
      leading: const Icon(Icons.movie_filter_outlined),
      title: const Text('TMDB API key'),
      subtitle: Text(
        configured
            ? 'Configured — IMDb lookups and title search are enabled'
            : 'Not set — add one to fetch details from an IMDb code',
      ),
      trailing: configured
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove key',
              onPressed: () => _clear(context, ref),
            )
          : null,
      onTap: () => _edit(context, ref),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    await ref.read(tmdbApiKeyServiceProvider).clearApiKey();
    ref.invalidate(tmdbApiKeyProvider);
    if (context.mounted) {
      context.showSnackbar('TMDB API key removed');
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: ref.read(tmdbApiKeyProvider).valueOrNull ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TMDB API key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'IMDb has no free public API, so the watchlist uses TMDB to '
              'look titles up — including by their IMDb code. Create a free '
              'API key at themoviedb.org under Settings → API.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API key (v3 auth)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    await ref.read(tmdbApiKeyServiceProvider).setApiKey(controller.text.trim());
    ref.invalidate(tmdbApiKeyProvider);
    if (context.mounted) {
      context.showSuccessSnackbar('TMDB API key saved');
    }
  }
}
