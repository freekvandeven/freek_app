import 'package:flutter/material.dart';

import '../models/recipe.dart';

/// Editable, reorderable list of a recipe's instruction steps with add and
/// per-row remove.
class RecipeInstructionsSection extends StatelessWidget {
  final List<RecipeInstruction> instructions;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final ReorderCallback onReorder;

  const RecipeInstructionsSection({
    super.key,
    required this.instructions,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Instructions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: instructions.length,
          onReorderItem: onReorder,
          itemBuilder: (context, index) => ListTile(
            key: ValueKey(index),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: CircleAvatar(
              radius: 12,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
            ),
            title: Text(
              instructions[index].text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: instructions[index].imageUrl != null
                ? Text(
                    instructions[index].imageUrl!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  )
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: () => onRemove(index),
            ),
          ),
        ),
      ],
    );
  }
}
