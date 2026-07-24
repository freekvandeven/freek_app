import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';
import 'package:personal_app/presentation/widgets/star_rating.dart';
import 'package:personal_app/presentation/widgets/wip_badge.dart';

import '../../../presentation/hooks/use_synced_search_controller.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/recipe.dart';
import '../providers/recipe_providers.dart';

class RecipeListPage extends HookConsumerWidget {
  const RecipeListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(filteredRecipesProvider);
    final favOnly = ref.watch(recipeFavoritesOnlyProvider);
    final wipOnly = ref.watch(recipeWipOnlyProvider);
    final search = ref.watch(recipeSearchProvider);
    final searchController = useSyncedSearchController(search);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Recipes')),
        actions: [
          IconButton(
            tooltip: 'WIP only',
            icon: Icon(
              Icons.construction,
              color: wipOnly ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () =>
                ref.read(recipeWipOnlyProvider.notifier).state = !wipOnly,
          ),
          IconButton(
            icon: Icon(favOnly ? Icons.favorite : Icons.favorite_border),
            onPressed: () =>
                ref.read(recipeFavoritesOnlyProvider.notifier).state = !favOnly,
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search recipes...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              ref.read(recipeSearchProvider.notifier).state =
                                  '',
                        )
                      : null,
                ),
                onChanged: (v) =>
                    ref.read(recipeSearchProvider.notifier).state = v,
              ),
            ),
            _buildTagChips(context, ref),
            Expanded(
              child: recipesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (recipes) => recipes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu_rounded,
                              size: 64,
                              color: colorScheme.onSurfaceVariant.withAlpha(
                                100,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No recipes yet',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: recipes.length,
                        itemBuilder: (context, index) =>
                            _RecipeCard(recipe: recipes[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recipes/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTagChips(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(recipeTagsProvider);
    final selected = ref.watch(recipeTagFilterProvider);
    if (tags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: tags
            .map(
              (tag) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(tag),
                  selected: selected == tag,
                  onSelected: (v) =>
                      ref.read(recipeTagFilterProvider.notifier).state = v
                      ? tag
                      : null,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final showImages =
        ref.watch(currentUserProvider)?.settings.showImagePreviews ?? true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/recipes/${recipe.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (showImages && recipe.primaryImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: recipe.primaryImageUrl!,
                    width: 56,
                    height: 56,
                    memCacheWidth: 168,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                      Icons.restaurant_menu,
                      size: 56,
                      color: colorScheme.onSurfaceVariant.withAlpha(60),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (recipe.isWip) ...[
                          const SizedBox(width: 6),
                          const WipBadge(),
                        ],
                      ],
                    ),
                    if (recipe.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        recipe.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (recipe.totalTimeMinutes != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
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
                    if (recipe.rating != null) ...[
                      const SizedBox(height: 4),
                      StarRating(
                        value: recipe.rating,
                        size: 14,
                        showNumeric: false,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: recipe.isFavorite ? Colors.red : null,
                ),
                onPressed: () => ref
                    .read(recipeListProvider.notifier)
                    .toggleFavorite(recipe),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
