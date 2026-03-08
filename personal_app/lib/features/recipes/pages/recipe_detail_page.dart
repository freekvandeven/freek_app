import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/recipe.dart';
import '../providers/recipe_providers.dart';

class RecipeDetailPage extends ConsumerWidget {
  final String recipeId;
  const RecipeDetailPage({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipeListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return recipesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (recipes) {
        final recipe = recipes.where((r) => r.id == recipeId).firstOrNull;
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Recipe not found')),
          );
        }
        return _buildDetail(context, ref, recipe, colorScheme);
      },
    );
  }

  Widget _buildDetail(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
    ColorScheme colorScheme,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            icon: Icon(
              recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: recipe.isFavorite ? Colors.red : null,
            ),
            onPressed: () =>
                ref.read(recipeListProvider.notifier).toggleFavorite(recipe),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/recipes/${recipe.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Recipe'),
                  content: Text('Delete "${recipe.title}"?'),
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
              );
              if (confirm == true && context.mounted) {
                await ref
                    .read(recipeListProvider.notifier)
                    .deleteRecipe(recipe.id);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (recipe.description != null) ...[
            Text(
              recipe.description!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Metadata row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (recipe.servings != null)
                _infoChip(Icons.people, '${recipe.servings} servings'),
              if (recipe.prepTimeMinutes != null)
                _infoChip(
                  Icons.timer_outlined,
                  '${recipe.prepTimeMinutes} min prep',
                ),
              if (recipe.cookTimeMinutes != null)
                _infoChip(
                  Icons.local_fire_department,
                  '${recipe.cookTimeMinutes} min cook',
                ),
            ],
          ),

          if (recipe.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: recipe.tags
                  .map(
                    (t) => Chip(
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],

          // Ingredients
          if (recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...recipe.ingredients.map(
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, size: 8),
                    const SizedBox(width: 8),
                    Text(
                      [
                        if (i.quantity != null) _formatQuantity(i.quantity!),
                        if (i.unit != null) i.unit,
                        i.name,
                      ].join(' '),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Instructions
          if (recipe.instructions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Instructions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            ...recipe.instructions.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            ),
          ],

          // Notes
          if (recipe.notes != null) ...[
            const SizedBox(height: 24),
            Text('Notes', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Text(recipe.notes!),
          ],

          // Source
          if (recipe.source != null) ...[
            const SizedBox(height: 24),
            Text(
              'Source: ${recipe.source}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)],
    );
  }

  String _formatQuantity(double q) {
    return q == q.roundToDouble() ? q.toInt().toString() : q.toString();
  }
}
