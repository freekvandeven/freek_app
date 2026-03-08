import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/recipe.dart';
import '../providers/recipe_providers.dart';

class RecipeEditPage extends ConsumerStatefulWidget {
  final String? recipeId;
  const RecipeEditPage({super.key, this.recipeId});

  @override
  ConsumerState<RecipeEditPage> createState() => _RecipeEditPageState();
}

class _RecipeEditPageState extends ConsumerState<RecipeEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _servingsController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _sourceController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagController = TextEditingController();
  List<Ingredient> _ingredients = [];
  List<String> _instructions = [];
  List<String> _tags = [];
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      _isEditing = true;
      _loadRecipe();
    }
  }

  Future<void> _loadRecipe() async {
    final service = ref.read(recipeServiceProvider);
    final recipe = await service.getRecipe(widget.recipeId!);
    if (recipe != null && mounted) {
      setState(() {
        _titleController.text = recipe.title;
        _descriptionController.text = recipe.description ?? '';
        _servingsController.text = recipe.servings?.toString() ?? '';
        _prepTimeController.text = recipe.prepTimeMinutes?.toString() ?? '';
        _cookTimeController.text = recipe.cookTimeMinutes?.toString() ?? '';
        _sourceController.text = recipe.source ?? '';
        _notesController.text = recipe.notes ?? '';
        _ingredients = List.from(recipe.ingredients);
        _instructions = List.from(recipe.instructions);
        _tags = List.from(recipe.tags);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();
    final source = _sourceController.text.trim();
    final notes = _notesController.text.trim();

    if (_isEditing) {
      final service = ref.read(recipeServiceProvider);
      final existing = await service.getRecipe(widget.recipeId!);
      if (existing != null) {
        final updated = existing.copyWith(
          title: _titleController.text.trim(),
          description: description.isEmpty ? null : description,
          clearDescription: description.isEmpty,
          servings: int.tryParse(_servingsController.text),
          prepTimeMinutes: int.tryParse(_prepTimeController.text),
          cookTimeMinutes: int.tryParse(_cookTimeController.text),
          ingredients: _ingredients,
          instructions: _instructions,
          tags: _tags,
          source: source.isEmpty ? null : source,
          clearSource: source.isEmpty,
          notes: notes.isEmpty ? null : notes,
          clearNotes: notes.isEmpty,
        );
        await ref.read(recipeListProvider.notifier).updateRecipe(updated);
      }
    } else {
      final recipe = Recipe(
        title: _titleController.text.trim(),
        description: description.isEmpty ? null : description,
        servings: int.tryParse(_servingsController.text),
        prepTimeMinutes: int.tryParse(_prepTimeController.text),
        cookTimeMinutes: int.tryParse(_cookTimeController.text),
        ingredients: _ingredients,
        instructions: _instructions,
        tags: _tags,
        source: source.isEmpty ? null : source,
        notes: notes.isEmpty ? null : notes,
      );
      await ref.read(recipeListProvider.notifier).addRecipe(recipe);
    }

    if (mounted) context.pop();
  }

  void _addIngredient() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Ingredient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _ingredients.add(
                    Ingredient(
                      name: nameCtrl.text.trim(),
                      quantity: double.tryParse(qtyCtrl.text),
                      unit: unitCtrl.text.trim().isEmpty
                          ? null
                          : unitCtrl.text.trim(),
                    ),
                  );
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addInstruction() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Step'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Instruction'),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _instructions.add(ctrl.text.trim()));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() => _tags.add(text));
      _tagController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recipe' : 'New Recipe'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    decoration: const InputDecoration(labelText: 'Servings'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    decoration: const InputDecoration(labelText: 'Prep (min)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    decoration: const InputDecoration(labelText: 'Cook (min)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tags
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(labelText: 'Add tag'),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addTag),
              ],
            ),
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  children: _tags
                      .map(
                        (t) => Chip(
                          label: Text(t),
                          onDeleted: () => setState(() => _tags.remove(t)),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 16),

            // Ingredients
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ingredients',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            ..._ingredients.asMap().entries.map(
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
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () =>
                      setState(() => _ingredients.removeAt(entry.key)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Instructions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _addInstruction,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _instructions.length,
              onReorder: (old, newIdx) {
                setState(() {
                  if (newIdx > old) newIdx--;
                  final item = _instructions.removeAt(old);
                  _instructions.insert(newIdx, item);
                });
              },
              itemBuilder: (context, index) => ListTile(
                key: ValueKey(index),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 12,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                title: Text(
                  _instructions[index],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () =>
                      setState(() => _instructions.removeAt(index)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _sourceController,
              decoration: const InputDecoration(labelText: 'Source'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
