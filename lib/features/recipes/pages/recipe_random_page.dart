import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../presentation/widgets/fullscreen_image_viewer.dart';
import '../../../presentation/widgets/responsive_center.dart';
import '../models/recipe.dart';
import '../providers/recipe_providers.dart';

/// Picks a random recipe to help decide what to make today (WISH-0097).
/// WIP recipes are excluded from the pool — they're not finished/tested
/// yet, so surfacing one as "make this today" wouldn't be useful.
class RecipeRandomPage extends HookConsumerWidget {
  const RecipeRandomPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipeListProvider);
    final random = useMemoized(() => Random(), const []);
    final currentId = useState<String?>(null);

    final allRecipes = recipesAsync.valueOrNull ?? const <Recipe>[];
    final pool = allRecipes.where((r) => !r.isWip).toList();

    // Pick a recipe for this build: reuse the persisted pick if it's still
    // in the pool, otherwise fall back to a fresh random pick so there's
    // never a null/loading flash — the effect below then persists that
    // fallback pick so later rebuilds (e.g. a pool update) stay stable on
    // it instead of re-rolling every time.
    final persistedPick = pool
        .where((r) => r.id == currentId.value)
        .firstOrNull;
    final recipe =
        persistedPick ??
        (pool.isEmpty ? null : pool[random.nextInt(pool.length)]);

    useEffect(() {
      if (recipe != null && recipe.id != currentId.value) {
        currentId.value = recipe.id;
      }
      return null;
    }, [pool.length, currentId.value]);

    void shuffle() {
      if (pool.length <= 1) return;
      Recipe next;
      do {
        next = pool[random.nextInt(pool.length)];
      } while (next.id == currentId.value);
      currentId.value = next.id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Random Recipe')),
      body: ResponsiveCenter(
        padding: const EdgeInsets.all(16),
        child: recipesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (_) => pool.isEmpty
              ? _EmptyState(hasAnyRecipes: allRecipes.isNotEmpty)
              : _RandomRecipeCard(
                  recipe: recipe!,
                  canShuffle: pool.length > 1,
                  onShuffle: shuffle,
                ),
        ),
      ),
    );
  }
}

class _RandomRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool canShuffle;
  final VoidCallback onShuffle;

  const _RandomRecipeCard({
    required this.recipe,
    required this.canShuffle,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = recipe.primaryImageUrl;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                GestureDetector(
                  onTap: () => showFullscreenNetworkImage(context, imageUrl),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: 240,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox(
                      height: 240,
                      child: Center(child: Icon(Icons.broken_image, size: 48)),
                    ),
                  ),
                )
              else
                Container(
                  height: 240,
                  alignment: Alignment.center,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (recipe.description != null &&
                        recipe.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        recipe.description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (recipe.totalTimeMinutes != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.totalTimeMinutes} min',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Tooltip(
              message: canShuffle
                  ? 'Pick another random recipe'
                  : 'Add more recipes to shuffle',
              child: OutlinedButton.icon(
                onPressed: canShuffle ? onShuffle : null,
                icon: const Icon(Icons.shuffle),
                label: const Text('Try Another'),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => context.push('/recipes/${recipe.id}'),
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Make This'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasAnyRecipes;
  const _EmptyState({required this.hasAnyRecipes});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shuffle,
            size: 64,
            color: colorScheme.onSurfaceVariant.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            hasAnyRecipes
                ? 'All your recipes are still marked as work-in-progress'
                : 'No recipes yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (!hasAnyRecipes) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/recipes/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add a Recipe'),
            ),
          ],
        ],
      ),
    );
  }
}
