import 'package:flutter/material.dart';

import '../models/recipe.dart';

/// Editable list of a recipe's ingredients — tap a row to edit it in
/// place, or use the trailing button to remove it (BUG-0048).
class RecipeIngredientsSection extends StatelessWidget {
  final List<Ingredient> ingredients;
  final VoidCallback onAdd;
  final void Function(int index) onEdit;
  final void Function(int index) onRemove;

  const RecipeIngredientsSection({
    super.key,
    required this.ingredients,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        ...ingredients.asMap().entries.map(
          (entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              [
                if (entry.value.quantity != null)
                  entry.value.quantity!.toString(),
                if (entry.value.unit != null) entry.value.unit,
                entry.value.name,
              ].join(' '),
            ),
            onTap: () => onEdit(entry.key),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: () => onRemove(entry.key),
            ),
          ),
        ),
      ],
    );
  }
}
