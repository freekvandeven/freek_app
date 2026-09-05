import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:personal_app/presentation/widgets/app_snackbar.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../presentation/hooks/use_autosave.dart';
import '../../../presentation/widgets/image_attachment_picker.dart';
import '../../../presentation/widgets/image_attachment_strip.dart';
import '../../../presentation/widgets/image_upload_preview_dialog.dart';
import '../../../presentation/widgets/star_rating.dart';
import '../../../presentation/widgets/unsaved_changes_guard.dart';
import '../../../services/image_attachment_controller.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/log_service.dart';
import '../../../utils/decimal_input.dart';
import '../../auth/providers/auth_providers.dart';
import '../../catalog/models/catalog_item.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../gemini/providers/gemini_providers.dart';
import '../../gemini/services/gemini_service.dart';
import '../models/recipe.dart';
import '../providers/recipe_providers.dart';
import '../utils/autosave_snapshot.dart';
import '../utils/video_link_parser.dart';
import '../widgets/recipe_catalog_picker_sheet.dart';
import '../widgets/recipe_ingredients_section.dart';
import '../widgets/recipe_instructions_section.dart';
import '../widgets/recipe_picker_sheet.dart';

class RecipeEditPage extends StatefulHookConsumerWidget {
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
  final _searchAliasesController = TextEditingController();
  TextEditingController? _autocompleteTagController;
  List<Ingredient> _ingredients = [];
  List<RecipeInstruction> _instructions = [];
  List<String> _tags = [];
  final _images = ImageAttachmentController(folder: 'recipes');
  List<String> _videoLinks = [];
  List<String> _subRecipeIds = [];
  bool _isEditing = false;
  bool _isUploading = false;
  bool _isWip = false;
  double? _rating;
  Recipe? _existingRecipe;
  AutosaveController? _autosave;

  @override
  void initState() {
    super.initState();
    _images.addListener(_onImagesChanged);
    if (widget.recipeId != null) {
      _isEditing = true;
      _loadRecipe();
    }
  }

  /// Rebuild when images change so the strip and the unsaved-changes
  /// guard pick up the new image state.
  void _onImagesChanged() {
    if (mounted) setState(() {});
  }

  /// True when the form has unsaved edits — drives the unsaved-changes
  /// confirmation on back nav (WISH-0079).
  bool get _isDirty => _autosave?.isDirty ?? false;

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
        _images.seed(recipe.images, primaryIndex: recipe.primaryImageIndex);
        _videoLinks = List.from(recipe.videoLinks);
        _subRecipeIds = List.from(recipe.subRecipeIds);
        _isWip = recipe.isWip;
        _rating = recipe.rating;
        _searchAliasesController.text = recipe.searchAliases ?? '';
      });
      _autosave?.markClean();
    }
  }

  String _autosaveSnapshot() => recipeAutosaveSnapshot(
    title: _titleController.text,
    description: _descriptionController.text,
    servings: _servingsController.text,
    prepTime: _prepTimeController.text,
    cookTime: _cookTimeController.text,
    source: _sourceController.text,
    notes: _notesController.text,
    ingredients: _ingredients,
    instructions: _instructions,
    tags: _tags,
    savedImageUrls: _images.savedUrls,
    primaryImageIndex: _images.primaryIndex,
    videoLinks: _videoLinks,
    subRecipeIds: _subRecipeIds,
    isWip: _isWip,
    searchAliases: _searchAliasesController.text,
  );

  /// Persist step for [useAutosave]: returns false while there's nothing
  /// to save yet (recipe not loaded) or validation fails, so the hook
  /// keeps the baseline untouched.
  Future<bool> _autosavePersist() async {
    if (_existingRecipe == null) return false;
    if (!_formKey.currentState!.validate()) return false;

    final description = _descriptionController.text.trim();
    final source = _sourceController.text.trim();
    final notes = _notesController.text.trim();
    final aliases = _searchAliasesController.text.trim();

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
      images: _images.savedUrls,
      primaryImageIndex: _images.primaryIndex,
      videoLinks: _videoLinks,
      subRecipeIds: _subRecipeIds,
      isWip: _isWip,
      source: source.isEmpty ? null : source,
      clearSource: source.isEmpty,
      notes: notes.isEmpty ? null : notes,
      clearNotes: notes.isEmpty,
      searchAliases: aliases.isEmpty ? null : aliases,
      clearSearchAliases: aliases.isEmpty,
    );
    await ref.read(recipeListProvider.notifier).updateRecipe(updated);
    return true;
  }

  @override
  void dispose() {
    _images.removeListener(_onImagesChanged);
    _images.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    _searchAliasesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirmUnsavedTag()) return;

    setState(() => _isUploading = true);
    try {
      final uploader = ref.read(imageUploadServiceProvider);
      await _images.uploadPending(uploader);
      await _persistRecipe();
      await _images.deleteRemoved(uploader);
      // Mark form clean so the unsaved-changes guard lets the post-
      // save pop through unprompted (WISH-0079).
      _autosave?.markClean();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Save failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Prompts the user when there's untagged text still in the tag field.
  /// Returns true to continue saving, false to abort.
  Future<bool> _confirmUnsavedTag() async {
    final tagCtrl = _autocompleteTagController ?? _tagController;
    final pendingTag = tagCtrl.text.trim().toLowerCase();
    if (pendingTag.isEmpty) return true;
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
    if (action == null || action == 'cancel') return false;
    if (action == 'add') _addTag();
    return true;
  }

  /// Build a fresh [Recipe] from the current form state (used for the
  /// "new recipe" path).
  Recipe _newRecipeFromForm() {
    final description = _descriptionController.text.trim();
    final source = _sourceController.text.trim();
    final notes = _notesController.text.trim();
    final aliases = _searchAliasesController.text.trim();
    return Recipe(
      title: _titleController.text.trim(),
      description: description.isEmpty ? null : description,
      servings: int.tryParse(_servingsController.text),
      prepTimeMinutes: int.tryParse(_prepTimeController.text),
      cookTimeMinutes: int.tryParse(_cookTimeController.text),
      ingredients: _ingredients,
      instructions: _instructions,
      tags: _tags,
      images: _images.savedUrls,
      primaryImageIndex: _images.primaryIndex,
      videoLinks: _videoLinks,
      subRecipeIds: _subRecipeIds,
      isWip: _isWip,
      source: source.isEmpty ? null : source,
      notes: notes.isEmpty ? null : notes,
      rating: _rating,
      searchAliases: aliases.isEmpty ? null : aliases,
    );
  }

  /// Build an updated copy of [existing] from the current form state.
  Recipe _existingRecipeFromForm(Recipe existing) {
    final description = _descriptionController.text.trim();
    final source = _sourceController.text.trim();
    final notes = _notesController.text.trim();
    final aliases = _searchAliasesController.text.trim();
    return existing.copyWith(
      title: _titleController.text.trim(),
      description: description.isEmpty ? null : description,
      clearDescription: description.isEmpty,
      servings: int.tryParse(_servingsController.text),
      prepTimeMinutes: int.tryParse(_prepTimeController.text),
      cookTimeMinutes: int.tryParse(_cookTimeController.text),
      ingredients: _ingredients,
      instructions: _instructions,
      tags: _tags,
      images: _images.savedUrls,
      primaryImageIndex: _images.primaryIndex,
      videoLinks: _videoLinks,
      subRecipeIds: _subRecipeIds,
      isWip: _isWip,
      source: source.isEmpty ? null : source,
      clearSource: source.isEmpty,
      notes: notes.isEmpty ? null : notes,
      clearNotes: notes.isEmpty,
      rating: _rating,
      clearRating: _rating == null,
      searchAliases: aliases.isEmpty ? null : aliases,
      clearSearchAliases: aliases.isEmpty,
    );
  }

  Future<void> _persistRecipe() async {
    final notifier = ref.read(recipeListProvider.notifier);
    if (!_isEditing) {
      await notifier.addRecipe(_newRecipeFromForm());
      return;
    }
    final existing = await ref
        .read(recipeServiceProvider)
        .getRecipe(widget.recipeId!);
    if (existing == null) return;
    await notifier.updateRecipe(_existingRecipeFromForm(existing));
  }

  void _addIngredient() => _showIngredientDialog();

  /// Opens the same dialog as [_addIngredient] pre-filled with the
  /// ingredient at [editIndex], replacing it in place on save instead of
  /// appending a new one (BUG-0048).
  void _editIngredient(int editIndex) =>
      _showIngredientDialog(editIndex: editIndex);

  void _showIngredientDialog({int? editIndex}) {
    final isEditing = editIndex != null;
    final existing = isEditing ? _ingredients[editIndex] : null;
    final nameCtrl = TextEditingController(text: existing?.name);
    final qtyCtrl = TextEditingController(
      text: existing?.quantity != null
          ? formatDecimal(existing!.quantity!)
          : '',
    );
    final unitCtrl = TextEditingController(text: existing?.unit);
    String? catalogItemId = existing?.catalogItemId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Ingredient' : 'Add Ingredient'),
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
                        RecipeCatalogPickerSheet(items: catalogItems),
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
                final ingredient = Ingredient(
                  name: nameCtrl.text.trim(),
                  quantity: parseDecimal(qtyCtrl.text),
                  unit: unitCtrl.text.trim().isEmpty
                      ? null
                      : unitCtrl.text.trim(),
                  catalogItemId: catalogItemId,
                );
                setState(() {
                  if (isEditing) {
                    _ingredients[editIndex] = ingredient;
                  } else {
                    _ingredients.add(ingredient);
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: Text(isEditing ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _addInstruction() => _showInstructionDialog();

  /// Opens the same dialog as [_addInstruction] pre-filled with the step
  /// at [editIndex], replacing it in place on save instead of appending
  /// a new one (BUG-0048).
  void _editInstruction(int editIndex) =>
      _showInstructionDialog(editIndex: editIndex);

  void _showInstructionDialog({int? editIndex}) {
    final isEditing = editIndex != null;
    final existing = isEditing ? _instructions[editIndex] : null;
    final ctrl = TextEditingController(text: existing?.text);
    final imgCtrl = TextEditingController(text: existing?.imageUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Step' : 'Add Step'),
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
                      final source = await showModalBottomSheet<String>(
                        context: context,
                        builder: (sctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Gallery'),
                                onTap: () => Navigator.pop(sctx, 'gallery'),
                              ),
                              const PasteFromClipboardTile(),
                            ],
                          ),
                        ),
                      );
                      if (source == null || !mounted) return;
                      final picked = await resolveImageSource(
                        context,
                        source,
                        service,
                      );
                      if (picked == null || !mounted) return;
                      final result = await showImageUploadPreviewDialog(
                        context: context,
                        originalBytes: picked.bytes,
                        fileName: picked.fileName,
                        sourcePath: picked.sourcePath,
                      );
                      if (result == null) return;
                      await result.maybeRemoveSourceFromDevice();
                      final url = await service.uploadImageBytes(
                        result.bytes,
                        fileName: result.fileName,
                        folder: 'recipes',
                      );
                      imgCtrl.text = url;
                    } catch (e) {
                      if (mounted) {
                        context.showErrorSnackbar('Upload failed: $e');
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
                final instruction = RecipeInstruction(
                  text: ctrl.text.trim(),
                  imageUrl: imgUrl.isEmpty ? null : imgUrl,
                );
                setState(() {
                  if (isEditing) {
                    _instructions[editIndex] = instruction;
                  } else {
                    _instructions.add(instruction);
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: Text(isEditing ? 'Save' : 'Add'),
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
                await _addImageFrom('gallery');
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(ctx);
                await _addImageFrom('camera');
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('Paste from clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await _addImageFrom('clipboard');
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

  Future<void> _addImageFrom(String source) {
    final service = ref.read(imageUploadServiceProvider);
    // Gallery goes through the multi-select flow so the user can pick and
    // crop several photos in one visit to their gallery (WISH-0096).
    if (source == 'gallery') {
      return addImagesFromGallery(context, service, _images);
    }
    return addImageFromSource(context, service, _images, source);
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
                _images.addSavedUrl(ctrl.text.trim());
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
    final ready = await configureGeminiForCurrentSettings(ref);
    if (!ready) {
      if (mounted) {
        context.showSnackbar(
          'Gemini is not configured. Set up an API key or sign in '
          'with Google in Settings → AI.',
        );
      }
      return;
    }
    final geminiService = ref.read(geminiServiceProvider);

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

    await _generateWithAi(geminiService, prompt);
  }

  /// Runs the "Create with AI" request and handles the result — split out
  /// of [_createWithAi] so a failure's retry action can re-run this with
  /// the same [prompt] instead of making the user retype it (BUG-0049).
  Future<void> _generateWithAi(
    GeminiService geminiService,
    String prompt,
  ) async {
    setState(() => _isUploading = true);
    try {
      final data = await geminiService.generateRecipe(prompt);
      if (!mounted) return;
      if (data == null) {
        context.showErrorSnackbar(
          'Failed to generate recipe. See Settings → Developer for details.',
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _generateWithAi(geminiService, prompt),
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
        context.showSnackbar(
          message,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'View limits',
            onPressed: () => launchUrl(Uri.parse('https://ai.dev/rate-limit')),
          ),
        );
      }
    } catch (e, st) {
      LogService.instance.error('Recipe AI flow failed unexpectedly: $e\n$st');
      if (mounted) {
        context.showErrorSnackbar(
          'Recipe AI failed: $e',
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _generateWithAi(geminiService, prompt),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _editWithAi() async {
    final ready = await configureGeminiForCurrentSettings(ref);
    if (!ready) {
      if (mounted) {
        context.showSnackbar(
          'Gemini is not configured. Set up an API key or sign in '
          'with Google in Settings → AI.',
        );
      }
      return;
    }
    final geminiService = ref.read(geminiServiceProvider);

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

    await _editRecipeWithAi(geminiService, instruction);
  }

  /// Runs the "Edit with AI" request and handles the result — split out of
  /// [_editWithAi] so a failure's retry action can re-run this with the
  /// same [instruction] instead of making the user retype it (BUG-0049).
  Future<void> _editRecipeWithAi(
    GeminiService geminiService,
    String instruction,
  ) async {
    setState(() => _isUploading = true);
    try {
      final existing = _currentRecipeAiData();
      final data = await geminiService.editRecipe(existing, instruction);
      if (!mounted) return;
      if (data == null) {
        context.showErrorSnackbar(
          'Failed to edit recipe with AI. See Settings → Developer for details.',
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _editRecipeWithAi(geminiService, instruction),
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
        context.showSnackbar(
          message,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'View limits',
            onPressed: () => launchUrl(Uri.parse('https://ai.dev/rate-limit')),
          ),
        );
      }
    } catch (e, st) {
      LogService.instance.error('Recipe edit AI flow failed: $e\n$st');
      if (mounted) {
        context.showErrorSnackbar(
          'Recipe AI failed: $e',
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _editRecipeWithAi(geminiService, instruction),
          ),
        );
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
        context.showSnackbar('No other recipes available to link');
      }
      return;
    }
    final picked = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      builder: (c) => RecipePickerSheet(items: candidates),
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
    _autosave = useAutosave(
      intervalMinutes:
          ref.watch(currentUserProvider)?.settings.autosaveIntervalMinutes ?? 0,
      enabled: _isEditing,
      captureInitialBaseline: !_isEditing,
      snapshot: _autosaveSnapshot,
      save: _autosavePersist,
    );
    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Scaffold(
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
        body: SafeArea(
          top: false,
          child: ResponsiveCenter(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Title is required'
                        : null,
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
                          decoration: const InputDecoration(
                            labelText: 'Servings',
                          ),
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
                                ref.read(availableTagsProvider).valueOrNull ??
                                [];
                            return available.where(
                              (t) => t.contains(input) && !_tags.contains(t),
                            );
                          },
                          onSelected: (tag) {
                            if (!_tags.contains(tag)) {
                              setState(() => _tags.add(tag));
                              ref
                                  .read(availableTagsProvider.notifier)
                                  .addTag(tag);
                            }
                            _autocompleteTagController?.clear();
                          },
                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
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
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addTag,
                      ),
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
                                onDeleted: () =>
                                    setState(() => _tags.remove(t)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 16),

                  RecipeIngredientsSection(
                    ingredients: _ingredients,
                    onAdd: _addIngredient,
                    onEdit: _editIngredient,
                    onRemove: (i) => setState(() => _ingredients.removeAt(i)),
                  ),
                  const SizedBox(height: 16),

                  RecipeInstructionsSection(
                    instructions: _instructions,
                    onAdd: _addInstruction,
                    onEdit: _editInstruction,
                    onRemove: (i) => setState(() => _instructions.removeAt(i)),
                    onReorder: (int oldIdx, int newIdx) {
                      // onReorderItem (Flutter >=3.41) already adjusts the
                      // target index for the removed source item, so we
                      // don't need the old `if (newIdx > oldIdx) newIdx--`
                      // dance here.
                      setState(() {
                        final item = _instructions.removeAt(oldIdx);
                        _instructions.insert(newIdx, item);
                      });
                    },
                  ),
                  const SizedBox(height: 16),

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
                  ImageAttachmentStrip(
                    controller: _images,
                    thumbnailSize: 80,
                    showPrimaryBadge: true,
                    onTapImage: _images.setPrimary,
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _searchAliasesController,
                    decoration: const InputDecoration(
                      labelText: 'Nicknames',
                      helperText:
                          'Extra search words, separated by space, comma or '
                          'period. Not shown in lists.',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Rating',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        StarRating(
                          value: _rating,
                          onChanged: (v) => setState(() => _rating = v),
                          size: 28,
                        ),
                      ],
                    ),
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
        ),
      ),
    );
  }
}
