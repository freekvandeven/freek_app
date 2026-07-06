import 'package:flutter/material.dart';

import '../models/recipe.dart';

/// Bottom sheet that lets the user search existing recipes and pick one to
/// link as a sub-recipe. Pops the selected [Recipe], or null on dismiss.
class RecipePickerSheet extends StatefulWidget {
  final List<Recipe> items;
  const RecipePickerSheet({super.key, required this.items});

  @override
  State<RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<RecipePickerSheet> {
  String _search = '';

  List<Recipe> get _filtered {
    if (_search.isEmpty) return widget.items;
    final q = _search.toLowerCase();
    return widget.items
        .where(
          (r) =>
              r.title.toLowerCase().contains(q) ||
              (r.description?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search recipes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final recipe = _filtered[index];
                return ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: Text(recipe.title),
                  subtitle: recipe.description != null
                      ? Text(
                          recipe.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, recipe),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
