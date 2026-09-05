import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/watch_item.dart';
import '../providers/tmdb_providers.dart';
import '../services/tmdb_service.dart';

/// Type-ahead title search against TMDB (WISH-0100). Pops with the chosen
/// [TmdbSearchResult], or null if the user backs out.
Future<TmdbSearchResult?> showTmdbSearchSheet(BuildContext context) {
  return showModalBottomSheet<TmdbSearchResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TmdbSearchSheet(),
  );
}

class _TmdbSearchSheet extends HookConsumerWidget {
  const _TmdbSearchSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final query = useState('');
    final results = useState<AsyncValue<List<TmdbSearchResult>>>(
      const AsyncValue.data([]),
    );
    final service = ref.watch(tmdbServiceProvider);

    // Debounced so typing a title does not fire a request per keystroke.
    useEffect(() {
      final text = query.value.trim();
      if (text.isEmpty) {
        results.value = const AsyncValue.data([]);
        return null;
      }

      var cancelled = false;
      final timer = Timer(const Duration(milliseconds: 400), () async {
        results.value = const AsyncValue.loading();
        try {
          final found = await service.search(text);
          // A newer keystroke may have superseded this request while it
          // was in flight; its results would be stale.
          if (!cancelled) results.value = AsyncValue.data(found);
        } catch (e, st) {
          if (!cancelled) results.value = AsyncValue.error(e, st);
        }
      });

      return () {
        cancelled = true;
        timer.cancel();
      };
    }, [query.value]);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Search TMDB',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Start typing a title…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
              onChanged: (value) => query.value = value,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: results.value.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    e is TmdbAuthException ? e.message : 'Search failed: $e',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (list) {
                if (query.value.trim().isEmpty) {
                  return const _Hint('Search movies and series by title');
                }
                if (list.isEmpty) {
                  return const _Hint('No matches');
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final result = list[index];
                    return ListTile(
                      leading: _ResultPoster(result: result),
                      title: Text(result.title),
                      subtitle: Text(
                        [
                          result.type == WatchItemType.series
                              ? 'Series'
                              : 'Movie',
                          if (result.year != null) '${result.year}',
                        ].join(' • '),
                      ),
                      onTap: () => Navigator.of(context).pop(result),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ResultPoster extends StatelessWidget {
  final TmdbSearchResult result;
  const _ResultPoster({required this.result});

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      child: Icon(
        result.type == WatchItemType.series ? Icons.tv : Icons.movie,
        size: 20,
      ),
    );
    if (result.posterUrl == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: result.posterUrl!,
        width: 40,
        height: 40,
        memCacheWidth: 120,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
