import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../presentation/widgets/image_upload_preview_dialog.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/log_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalog/models/catalog_item.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../gemini/providers/gemini_providers.dart';
import '../../gemini/services/gemini_service.dart';
import '../../settings/providers/settings_providers.dart';
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
  List<String> _savedImageUrls = [];
  List<({Uint8List bytes, String fileName})> _pendingImages = [];
  final List<String> _removedImageUrls = [];
  int _primaryImageIndex = 0;
  List<String> _videoLinks = [];
  List<String> _subRecipeIds = [];
  bool _isEditing = false;
  bool _isUploading = false;
  bool _isWip = false;
  Recipe? _existingRecipe;
  Timer? _autosaveTimer;

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
        _existingRecipe = recipe;
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
        _savedImageUrls = List.from(recipe.images);
        _primaryImageIndex = recipe.primaryImageIndex;
        _videoLinks = List.from(recipe.videoLinks);
        _subRecipeIds = List.from(recipe.subRecipeIds);
        _isWip = recipe.isWip;
      });
    }
    if (mounted) _setupAutosaveTimer();
  }

  void _setupAutosaveTimer() {
    _autosaveTimer?.cancel();
    final minutes =
        ref.read(currentUserProvider)?.settings.autosaveIntervalMinutes ?? 0;
    if (minutes > 0 && _isEditing) {
      _autosaveTimer = Timer.periodic(
        Duration(minutes: minutes),
        (_) => _autosave(),
      );
    }
  }

  Future<void> _autosave() async {
    if (!mounted || _existingRecipe == null) return;
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();
    final source = _sourceController.text.trim();
    final notes = _notesController.text.trim();

    try {
      final updated = _existingRecipe!.copyWith(
        title: _titleController.text.trim(),
        description: description.isEmpty ? null : description,
        clearDescription: description.isEmpty,
        servings: int.tryParse(_servingsController.text),
        prepTimeMinutes: int.tryParse(_prepTimeController.text),
        cookTimeMinutes: int.tryParse(_cookTimeController.text),
        ingredients: _ingredients,
        instructions: _instructions,
        tags: _tags,
        images: _savedImageUrls,
        primaryImageIndex: _primaryImageIndex,
        videoLinks: _videoLinks,
        subRecipeIds: _subRecipeIds,
        isWip: _isWip,
        source: source.isEmpty ? null : source,
        clearSource: source.isEmpty,
        notes: notes.isEmpty ? null : notes,
        clearNotes: notes.isEmpty,
      );
      await ref.read(recipeListProvider.notifier).updateRecipe(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // Silently ignore autosave errors
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
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

    setState(() => _isUploading = true);
    try {
      // Upload pending images
      final uploader = ref.read(imageUploadServiceProvider);
      for (final pending in _pendingImages) {
        final url = await uploader.uploadImageBytes(
          pending.bytes,
          fileName: pending.fileName,
          folder: 'recipes',
        );
        _savedImageUrls.add(url);
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
            images: _savedImageUrls,
            primaryImageIndex: _primaryImageIndex,
            videoLinks: _videoLinks,
            subRecipeIds: _subRecipeIds,
            isWip: _isWip,
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
          images: _savedImageUrls,
          primaryImageIndex: _primaryImageIndex,
          videoLinks: _videoLinks,
          subRecipeIds: _subRecipeIds,
          isWip: _isWip,
          source: source.isEmpty ? null : source,
          notes: notes.isEmpty ? null : notes,
        );
        await ref.read(recipeListProvider.notifier).addRecipe(recipe);
      }

      // Delete removed images from Storage
      for (final url in _removedImageUrls) {
        await uploader.deleteImage(url);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _addIngredient() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    String? catalogItemId;

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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final catalogItems = await ref
                      .read(catalogServiceProvider)
                      .getItems();
                  if (!ctx.mounted || catalogItems.isEmpty) return;
                  final picked = await showModalBottomSheet<CatalogItem>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (c) =>
                        _RecipeCatalogPickerSheet(items: catalogItems),
                  );
                  if (picked != null) {
                    nameCtrl.text = picked.title;
                    catalogItemId = picked.id;
                  }
                },
                icon: const Icon(Icons.auto_stories, size: 18),
                label: const Text('Pick from catalog'),
              ),
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
                      catalogItemId: catalogItemId,
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
                      final file = await service.pickImage();
                      if (file == null || !mounted) return;
                      final bytes = await file.readAsBytes();
                      if (!mounted) return;
                      final result = await showImageUploadPreviewDialog(
                        context: context,
                        originalBytes: bytes,
                        fileName: file.name,
                      );
                      if (result == null) return;
                      final url = await service.uploadImageBytes(
                        result.bytes,
                        fileName: result.fileName,
                        folder: 'recipes',
                      );
                      imgCtrl.text = url;
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
    final service = ref.read(imageUploadServiceProvider);
    final file = await service.pickImage();
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final result = await showImageUploadPreviewDialog(
      context: context,
      originalBytes: bytes,
      fileName: file.name,
    );
    if (result == null || !mounted) return;

    setState(() {
      _pendingImages = [
        ..._pendingImages,
        (bytes: result.bytes, fileName: result.fileName),
      ];
    });
  }

  Future<void> _captureImage() async {
    final service = ref.read(imageUploadServiceProvider);
    final file = await service.captureImage();
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final result = await showImageUploadPreviewDialog(
      context: context,
      originalBytes: bytes,
      fileName: file.name,
    );
    if (result == null || !mounted) return;

    setState(() {
      _pendingImages = [
        ..._pendingImages,
        (bytes: result.bytes, fileName: result.fileName),
      ];
    });
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
                setState(() => _savedImageUrls.add(ctrl.text.trim()));
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

  Future<void> _createWithAi() async {
    final geminiService = ref.read(geminiServiceProvider);
    final model = ref.read(geminiModelProvider);
    if (!geminiService.isConfigured) {
      final apiKey = await ref.read(geminiApiKeyServiceProvider).getApiKey();
      if (apiKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gemini API key not configured. Set it in Settings.',
              ),
            ),
          );
        }
        return;
      }
      geminiService.configure(apiKey, model: model);
    } else {
      geminiService.setModel(model);
    }

    if (!mounted) return;
    final promptCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Recipe with AI'),
        content: TextField(
          controller: promptCtrl,
          decoration: const InputDecoration(
            labelText: 'Describe the recipe',
            hintText: 'e.g. Classic French onion soup for 4 people',
          ),
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final prompt = promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final data = await geminiService.generateRecipe(prompt);
      if (!mounted) return;
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to generate recipe. See Settings → Developer for details.',
            ),
          ),
        );
        return;
      }
      _applyAiRecipeData(data);
    } on GeminiRateLimitException catch (e) {
      if (mounted) {
        final retry = e.retryAfter;
        final message = retry != null
            ? 'Gemini API rate limit reached. Try again in ${retry.inSeconds}s.'
            : 'Gemini API rate limit reached.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(message),
            action: SnackBarAction(
              label: 'View limits',
              onPressed: () =>
                  launchUrl(Uri.parse('https://ai.dev/rate-limit')),
            ),
          ),
        );
      }
    } catch (e, st) {
      LogService.instance.error('Recipe AI flow failed unexpectedly: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Recipe AI failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _editWithAi() async {
    final geminiService = ref.read(geminiServiceProvider);
    final model = ref.read(geminiModelProvider);
    if (!geminiService.isConfigured) {
      final apiKey = await ref.read(geminiApiKeyServiceProvider).getApiKey();
      if (apiKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gemini API key not configured. Set it in Settings.',
              ),
            ),
          );
        }
        return;
      }
      geminiService.configure(apiKey, model: model);
    } else {
      geminiService.setModel(model);
    }

    if (!mounted) return;
    final promptCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Recipe with AI'),
        content: TextField(
          controller: promptCtrl,
          decoration: const InputDecoration(
            labelText: 'Describe your changes',
            hintText: 'e.g. Make it vegetarian, double the servings',
          ),
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final instruction = promptCtrl.text.trim();
    if (instruction.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final existing = _currentRecipeAiData();
      final data = await geminiService.editRecipe(existing, instruction);
      if (!mounted) return;
      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to edit recipe with AI. See Settings → Developer for details.',
            ),
          ),
        );
        return;
      }
      _applyAiRecipeData(data);
    } on GeminiRateLimitException catch (e) {
      if (mounted) {
        final retry = e.retryAfter;
        final message = retry != null
            ? 'Gemini API rate limit reached. Try again in ${retry.inSeconds}s.'
            : 'Gemini API rate limit reached.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(message),
            action: SnackBarAction(
              label: 'View limits',
              onPressed: () =>
                  launchUrl(Uri.parse('https://ai.dev/rate-limit')),
            ),
          ),
        );
      }
    } catch (e, st) {
      LogService.instance.error('Recipe edit AI flow failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Recipe AI failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Map<String, dynamic> _currentRecipeAiData() {
    final description = _descriptionController.text.trim();
    final notes = _notesController.text.trim();
    final servings = int.tryParse(_servingsController.text);
    final prepTime = int.tryParse(_prepTimeController.text);
    final cookTime = int.tryParse(_cookTimeController.text);
    return {
      'title': _titleController.text.trim(),
      if (description.isNotEmpty) 'description': description,
      'servings': ?servings,
      'prepTimeMinutes': ?prepTime,
      'cookTimeMinutes': ?cookTime,
      'ingredients': _ingredients
          .map(
            (i) => {
              'name': i.name,
              if (i.quantity != null) 'quantity': i.quantity,
              if (i.unit != null && i.unit!.isNotEmpty) 'unit': i.unit,
            },
          )
          .toList(),
      'instructions': _instructions.map((i) => {'text': i.text}).toList(),
      if (_tags.isNotEmpty) 'tags': _tags,
      if (notes.isNotEmpty) 'notes': notes,
    };
  }

  void _applyAiRecipeData(Map<String, dynamic> data) {
    setState(() {
      _titleController.text =
          (data['title'] as String?) ?? _titleController.text;
      _descriptionController.text = (data['description'] as String?) ?? '';
      _servingsController.text = data['servings']?.toString() ?? '';
      _prepTimeController.text = data['prepTimeMinutes']?.toString() ?? '';
      _cookTimeController.text = data['cookTimeMinutes']?.toString() ?? '';
      _notesController.text = (data['notes'] as String?) ?? '';

      final rawIngredients = (data['ingredients'] as List?) ?? [];
      _ingredients = rawIngredients.map((i) {
        final m = i as Map<String, dynamic>;
        return Ingredient(
          name: m['name'] as String,
          quantity: (m['quantity'] as num?)?.toDouble(),
          unit: m['unit'] as String?,
        );
      }).toList();

      final rawInstructions = (data['instructions'] as List?) ?? [];
      _instructions = rawInstructions.map((i) {
        final m = i as Map<String, dynamic>;
        return RecipeInstruction(text: m['text'] as String);
      }).toList();

      final rawTags = (data['tags'] as List?) ?? [];
      _tags = rawTags.map((t) => t.toString().toLowerCase()).toList();
    });
  }

  Future<void> _addSubRecipe() async {
    final allRecipes = ref.read(recipeListProvider).valueOrNull ?? [];
    final candidates = allRecipes
        .where((r) => r.id != widget.recipeId && !_subRecipeIds.contains(r.id))
        .toList();
    if (!mounted || candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other recipes available to link')),
        );
      }
      return;
    }
    final picked = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _RecipePickerSheet(items: candidates),
    );
    if (picked != null) {
      setState(() => _subRecipeIds.add(picked.id));
    }
  }

  List<Widget> _buildSubRecipeTiles() {
    final allRecipes = ref.read(recipeListProvider).valueOrNull ?? [];
    return _subRecipeIds.asMap().entries.map((entry) {
      final recipe = allRecipes.where((r) => r.id == entry.value).firstOrNull;
      final title = recipe?.title ?? entry.value;
      return ListTile(
        key: ValueKey(entry.value),
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.link, size: 20),
        title: Text(title),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: () => setState(() => _subRecipeIds.removeAt(entry.key)),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(_isEditing ? 'Edit Recipe' : 'New Recipe'),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Create with AI',
              onPressed: _isUploading ? null : _createWithAi,
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: 'Edit with AI',
              onPressed: _isUploading ? null : _editWithAi,
            ),
          TextButton(
            onPressed: _isUploading ? null : _save,
            child: _isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: Form(
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
                      decoration: const InputDecoration(
                        labelText: 'Prep (min)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _cookTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Cook (min)',
                      ),
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
                        final input = textEditingValue.text
                            .toLowerCase()
                            .trim();
                        if (input.isEmpty) {
                          return const Iterable<String>.empty();
                        }
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
                  Text(
                    'Images',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: _addImage,
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_savedImageUrls.isNotEmpty || _pendingImages.isNotEmpty)
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _savedImageUrls.length + _pendingImages.length,
                    itemBuilder: (context, index) {
                      final isExisting = index < _savedImageUrls.length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _primaryImageIndex = index),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isExisting
                                    ? CachedNetworkImage(
                                        imageUrl: _savedImageUrls[index],
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.broken_image),
                                        ),
                                      )
                                    : Image.memory(
                                        _pendingImages[index -
                                                _savedImageUrls.length]
                                            .bytes,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                                    final totalCount =
                                        _savedImageUrls.length +
                                        _pendingImages.length;
                                    if (isExisting) {
                                      _removedImageUrls.add(
                                        _savedImageUrls[index],
                                      );
                                      _savedImageUrls.removeAt(index);
                                    } else {
                                      _pendingImages.removeAt(
                                        index - _savedImageUrls.length,
                                      );
                                    }
                                    final newTotal = totalCount - 1;
                                    if (_primaryImageIndex >= newTotal) {
                                      _primaryImageIndex = newTotal <= 0
                                          ? 0
                                          : newTotal - 1;
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
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),

              // Video Links
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Videos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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

              // Sub-recipes (components)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Components',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: _addSubRecipe,
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_subRecipeIds.isNotEmpty) ..._buildSubRecipeTiles(),
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
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Work in Progress'),
                subtitle: const Text('Mark this recipe as WIP'),
                value: _isWip,
                onChanged: (v) => setState(() => _isWip = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeCatalogPickerSheet extends StatefulWidget {
  final List<CatalogItem> items;
  const _RecipeCatalogPickerSheet({required this.items});

  @override
  State<_RecipeCatalogPickerSheet> createState() =>
      _RecipeCatalogPickerSheetState();
}

class _RecipeCatalogPickerSheetState extends State<_RecipeCatalogPickerSheet> {
  String _search = '';

  List<CatalogItem> get _filtered {
    if (_search.isEmpty) return widget.items;
    final q = _search.toLowerCase();
    return widget.items
        .where(
          (i) =>
              i.title.toLowerCase().contains(q) ||
              (i.description?.toLowerCase().contains(q) ?? false),
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
                hintText: 'Search catalog...',
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
                final item = _filtered[index];
                return ListTile(
                  leading: item.imageUrls.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrls.first,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(
                          child: Text(
                            item.title.isNotEmpty
                                ? item.title[0].toUpperCase()
                                : '?',
                          ),
                        ),
                  title: Text(item.title),
                  subtitle: item.description != null
                      ? Text(
                          item.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipePickerSheet extends StatefulWidget {
  final List<Recipe> items;
  const _RecipePickerSheet({required this.items});

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
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
