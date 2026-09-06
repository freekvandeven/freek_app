import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/widgets/api_key_vault_dialog.dart';
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

  Future<void> _edit(BuildContext context, WidgetRef ref) {
    return showApiKeyVaultDialog(
      context: context,
      ref: ref,
      initialValue: ref.read(tmdbApiKeyProvider).valueOrNull ?? '',
      spec: const ApiKeyVaultSpec(
        serviceName: 'TMDB',
        dialogTitle: 'TMDB API key',
        fieldLabel: 'API key (v3 auth)',
        vaultEntryTitle: 'TMDB API Key',
        vaultMatch: 'tmdb',
        vaultEntryUrl: 'https://www.themoviedb.org/settings/api',
        description:
            'IMDb has no free public API, so the watchlist uses TMDB to '
            'look titles up — including by their IMDb code. Create a free '
            'API key at themoviedb.org under Settings → API.',
      ),
      onSaved: (key) async {
        await ref.read(tmdbApiKeyServiceProvider).setApiKey(key);
        ref.invalidate(tmdbApiKeyProvider);
      },
    );
  }
}
