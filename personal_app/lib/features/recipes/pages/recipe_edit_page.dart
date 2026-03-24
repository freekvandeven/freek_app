import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/image_upload_service.dart';
import '../models/recipe.dart';
import '../providers/recipe_providers.dart';
import '../utils/video_link_parser.dart';

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
  TextEditingController? _autocompleteTagController;
  List<Ingredient> _ingredients = [];
  List<RecipeInstruction> _instructions = [];
  List<String> _tags = [];
  List<String> _images = [];
  int _primaryImageIndex = 0;
  List<String> _videoLinks = [];
  bool _isEditing = false;
  bool _isUploading = false;

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
        _tags = recipe.tags.map((t) => t.toLowerCase()).toList();
        _images = List.from(recipe.images);
        _primaryImageIndex = recipe.primaryImageIndex;
        _videoLinks = List.from(recipe.videoLinks);
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

    // Check for unsaved tag text.
    final tagCtrl = _autocompleteTagController ?? _tagController;
    final pendingTag = tagCtrl.text.trim().toLowerCase();
    if (pendingTag.isNotEmpty) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved Tag'),
          content: Text(
            'You typed "$pendingTag" in the tag field but didn\'t add it. '
            'Would you like to add it before saving?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'add'),
              child: const Text('Add Tag'),
            ),
          ],
        ),
      );
      if (action == null || action == 'cancel') return;
      if (action == 'add') _addTag();
    }

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
          images: _images,
          primaryImageIndex: _primaryImageIndex,
          videoLinks: _videoLinks,
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
        images: _images,
        primaryImageIndex: _primaryImageIndex,
        videoLinks: _videoLinks,
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
    final imgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Step'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Instruction'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: imgCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Step image (optional)',
                      hintText: 'URL or upload',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.upload),
                  tooltip: 'Upload image',
                  onPressed: () async {
                    try {
                      final service = ref.read(imageUploadServiceProvider);
                      final url = await service.pickAndUploadImage(
                        folder: 'recipes',
                      );
                      if (url != null) imgCtrl.text = url;
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Upload failed: $e')),
                        );
                      }
                    }
                  },
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
              if (ctrl.text.trim().isNotEmpty) {
                final imgUrl = imgCtrl.text.trim();
                setState(
                  () => _instructions.add(
                    RecipeInstruction(
                      text: ctrl.text.trim(),
                      imageUrl: imgUrl.isEmpty ? null : imgUrl,
                    ),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addImage() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload from gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                await _uploadImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(ctx);
                await _captureImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Enter URL'),
              onTap: () {
                Navigator.pop(ctx);
                _addImageByUrl();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadImage() async {
    setState(() => _isUploading = true);
    try {
      final service = ref.read(imageUploadServiceProvider);
      final url = await service.pickAndUploadImage(folder: 'recipes');
      if (url != null && mounted) {
        setState(() => _images.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _captureImage() async {
    setState(() => _isUploading = true);
    try {
      final service = ref.read(imageUploadServiceProvider);
      final url = await service.captureAndUploadImage(folder: 'recipes');
      if (url != null && mounted) {
        setState(() => _images.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _addImageByUrl() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Image URL'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Image URL',
            hintText: 'https://...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _images.add(ctrl.text.trim()));
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
    final ctrl = _autocompleteTagController ?? _tagController;
    final text = ctrl.text.trim().toLowerCase();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() => _tags.add(text));
      ref.read(availableTagsProvider.notifier).addTag(text);
    }
    ctrl.clear();
  }

  void _addVideoLink() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Video Link'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Video URL',
            hintText: 'https://youtube.com/watch?v=...',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                setState(() => _videoLinks.add(url));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(_isEditing ? 'Edit Recipe' : 'New Recipe'),
        ),
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
                  child: Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      final input = textEditingValue.text.toLowerCase().trim();
                      if (input.isEmpty) return const Iterable<String>.empty();
                      final available =
                          ref.read(availableTagsProvider).valueOrNull ?? [];
                      return available.where(
                        (t) => t.contains(input) && !_tags.contains(t),
                      );
                    },
                    onSelected: (tag) {
                      if (!_tags.contains(tag)) {
                        setState(() => _tags.add(tag));
                        ref.read(availableTagsProvider.notifier).addTag(tag);
                      }
                      _autocompleteTagController?.clear();
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          _autocompleteTagController = controller;
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Add tag',
                            ),
                            onSubmitted: (_) => _addTag(),
                          );
                        },
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
                  _instructions[index].text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: _instructions[index].imageUrl != null
                    ? Text(
                        _instructions[index].imageUrl!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      )
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () =>
                      setState(() => _instructions.removeAt(index)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Images
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Images', style: Theme.of(context).textTheme.titleMedium),
                _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: _addImage,
                        icon: const Icon(Icons.add_photo_alternate, size: 18),
                        label: const Text('Add'),
                      ),
              ],
            ),
            if (_images.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _primaryImageIndex = index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: _images[index],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        ),
                        if (index == _primaryImageIndex)
                          Positioned(
                            top: 2,
                            left: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Primary',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _images.removeAt(index);
                                if (_primaryImageIndex >= _images.length) {
                                  _primaryImageIndex = _images.isEmpty
                                      ? 0
                                      : _images.length - 1;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Video Links
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Videos', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _addVideoLink,
                  icon: const Icon(Icons.video_library, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            ..._videoLinks.asMap().entries.map((entry) {
              final info = VideoLinkParser.parse(entry.value);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  info.platform == VideoPlatform.youtube
                      ? Icons.play_circle_fill
                      : Icons.ondemand_video,
                  color: info.platform == VideoPlatform.youtube
                      ? Colors.red
                      : null,
                ),
                title: Text(
                  VideoLinkParser.platformLabel(info.platform),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () =>
                      setState(() => _videoLinks.removeAt(entry.key)),
                ),
              );
            }),

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
