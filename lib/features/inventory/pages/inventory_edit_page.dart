import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/app_snackbar.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/widgets/image_attachment_picker.dart';
import '../../../presentation/widgets/image_attachment_strip.dart';
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
import '../../settings/providers/currency_providers.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../utils/shared_image_guard.dart';
import '../widgets/transfer_quantity_dialog.dart';

class InventoryEditPage extends ConsumerStatefulWidget {
  final String? itemId;
  const InventoryEditPage({super.key, this.itemId});

  @override
  ConsumerState<InventoryEditPage> createState() => _InventoryEditPageState();
}

class _InventoryEditPageState extends ConsumerState<InventoryEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _locationController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _searchAliasesController = TextEditingController();

  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  // Null means "fill not tracked" (WISH-0078). 0–100 when set.
  int? _fillPercent;
  bool _isOpened = false;
  final _images = ImageAttachmentController(folder: 'inventory');
  bool _isUploading = false;
  bool _isLoading = true;
  bool _isScanning = false;
  String? _catalogItemId;
  CatalogItem? _linkedCatalogItem;
  String _initialSnapshot = '';

  @override
  void initState() {
    super.initState();
    _images.addListener(_onImagesChanged);
    if (widget.itemId != null) {
      _loadItem();
    } else {
      // Pre-fill the user's default location for new items so they
      // don't have to pick the same room every time (WISH-0084). Done
      // before the snapshot so an untouched form still counts as clean.
      _locationController.text =
          ref.read(currentUserProvider)?.settings.defaultInventoryLocation ??
          '';
      _isLoading = false;
      _initialSnapshot = _snapshot();
    }
  }

  /// Rebuild when images change so the strip, the snackbar state, and the
  /// unsaved-changes guard all pick up the new image state.
  void _onImagesChanged() {
    if (mounted) setState(() {});
  }

  /// Stable concatenation of the form fields used as a dirty-check
  /// baseline for the unsaved-changes guard (WISH-0079).
  String _snapshot() => [
    _nameController.text,
    _descriptionController.text,
    _categoryController.text,
    _locationController.text,
    _quantityController.text,
    _priceController.text,
    _barcodeController.text,
    _searchAliasesController.text,
    _purchaseDate?.toIso8601String() ?? '',
    _expiryDate?.toIso8601String() ?? '',
    _fillPercent ?? '',
    _isOpened,
    _images.dirtySignature,
    _catalogItemId ?? '',
  ].join('|');

  bool get _isDirty => _initialSnapshot != _snapshot();

  Future<void> _loadItem() async {
    final item = await ref
        .read(inventoryServiceProvider)
        .getItem(widget.itemId!);
    if (item != null && mounted) {
      setState(() {
        _nameController.text = item.name;
        _descriptionController.text = item.description ?? '';
        _categoryController.text = item.category ?? '';
        _locationController.text = item.location ?? '';
        _quantityController.text = item.quantity.toString();
        _priceController.text = item.purchasePrice != null
            ? ref
                  .read(currencyConverterProvider)
                  .fromEur(item.purchasePrice!)
                  .toStringAsFixed(2)
            : '';
        _barcodeController.text = item.barcode ?? '';
        _searchAliasesController.text = item.searchAliases ?? '';
        _purchaseDate = item.purchaseDate;
        _expiryDate = item.expiryDate;
        _images.seed(item.imageUrls);
        _catalogItemId = item.catalogItemId;
        _fillPercent = item.fillPercent;
        _isOpened = item.isOpened;
        _isLoading = false;
      });
      _initialSnapshot = _snapshot();
      // Load linked catalog item
      if (item.catalogItemId != null) {
        final catalogItem = await ref
            .read(catalogServiceProvider)
            .getItem(item.catalogItemId!);
        if (catalogItem != null && mounted) {
          setState(() => _linkedCatalogItem = catalogItem);
        }
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _images.removeListener(_onImagesChanged);
    _images.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    _searchAliasesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);
    try {
      final uploader = ref.read(imageUploadServiceProvider);
      await _images.uploadPending(uploader);

      final item = InventoryItem(
        id: widget.itemId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
        purchasePrice: _priceController.text.trim().isNotEmpty
            ? ref
                  .read(currencyConverterProvider)
                  .toEur(parseDecimal(_priceController.text) ?? 0)
            : null,
        purchaseDate: _purchaseDate,
        expiryDate: _expiryDate,
        imageUrls: _images.savedUrls,
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        catalogItemId: _catalogItemId,
        fillPercent: _fillPercent,
        isOpened: _isOpened,
        searchAliases: _searchAliasesController.text.trim().isEmpty
            ? null
            : _searchAliasesController.text.trim(),
      );

      final notifier = ref.read(inventoryListProvider.notifier);
      if (widget.itemId != null) {
        await notifier.updateItem(item);
      } else {
        await notifier.addItem(item);
      }

      // Delete removed images from Storage — skipping URLs another
      // item still references, since transfer-to-new-item copies image
      // URLs between items (WISH-0088).
      if (_images.removedUrls.isNotEmpty) {
        await _images.deleteRemoved(
          uploader,
          deletable: imageUrlsSafeToDelete(
            allItems: await ref.read(inventoryServiceProvider).getItems(),
            excludeItemId: widget.itemId,
            candidateUrls: _images.removedUrls,
          ),
        );
      }

      // Mark form clean so the unsaved-changes guard lets the post-
      // save pop through unprompted (WISH-0079).
      _initialSnapshot = _snapshot();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Save failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _openTransferDialog() async {
    final wasDirty = _isDirty;
    final transferred = await showTransferQuantityDialog(
      context,
      fixedFromItemId: widget.itemId!,
    );
    if (transferred != true || !mounted) return;
    // The transfer changed this item's quantity in Firestore — sync the
    // form field so a later Save doesn't write the stale value back.
    final fresh = await ref
        .read(inventoryServiceProvider)
        .getItem(widget.itemId!);
    if (fresh == null || !mounted) return;
    setState(() => _quantityController.text = fresh.quantity.toString());
    // Keep the discard-changes guard honest: a clean form stays clean
    // (the quantity change is already persisted), a dirty form stays
    // dirty.
    if (!wasDirty) _initialSnapshot = _snapshot();
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${_nameController.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(inventoryListProvider.notifier)
                  .deleteItem(widget.itemId!);
              if (mounted) context.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanWithAi() async {
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

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final mimeType = image.mimeType ?? 'image/jpeg';
    await _analyzeImageWithAi(bytes, mimeType);
  }

  /// Runs the Gemini image analysis and applies the result — split out of
  /// [_scanWithAi] so a failure's retry action can re-run this with the
  /// already-captured [bytes] instead of making the user retake the photo
  /// (BUG-0049).
  Future<void> _analyzeImageWithAi(Uint8List bytes, String mimeType) async {
    setState(() => _isScanning = true);
    try {
      final service = ref.read(geminiServiceProvider);
      final result = await service.analyzeInventoryImage(
        bytes,
        mimeType,
        categories: ref.read(inventoryCategoriesProvider).valueOrNull ?? [],
        locations: ref.read(inventoryLocationsProvider).valueOrNull ?? [],
      );

      if (result != null && mounted) {
        setState(() {
          if (result['name'] is String && _nameController.text.isEmpty) {
            _nameController.text = result['name'] as String;
          }
          if (result['description'] is String &&
              _descriptionController.text.isEmpty) {
            _descriptionController.text = result['description'] as String;
          }
          if (result['category'] is String &&
              _categoryController.text.isEmpty) {
            _categoryController.text = result['category'] as String;
          }
          if (result['quantity'] is int) {
            _quantityController.text = (result['quantity'] as int).toString();
          }
          if (result['purchasePrice'] is num && _priceController.text.isEmpty) {
            _priceController.text = (result['purchasePrice'] as num)
                .toStringAsFixed(2);
          }
          if (result['barcode'] is String && _barcodeController.text.isEmpty) {
            _barcodeController.text = result['barcode'] as String;
          }
          if (result['location'] is String &&
              _locationController.text.isEmpty) {
            _locationController.text = result['location'] as String;
          }
          if (result['expiryDate'] is String && _expiryDate == null) {
            final parsed = DateTime.tryParse(result['expiryDate'] as String);
            if (parsed != null) _expiryDate = parsed;
          }
        });
        context.showSuccessSnackbar('Fields filled from image analysis');
      } else if (mounted) {
        context.showSnackbar(
          'Could not extract item details from image',
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _analyzeImageWithAi(bytes, mimeType),
          ),
        );
      }
    } on GeminiRateLimitException catch (e) {
      if (mounted) {
        context.showSnackbar(
          humanizeGeminiRateLimit(e),
          duration: const Duration(seconds: 8),
        );
      }
    } catch (e, st) {
      LogService.instance.error('Inventory AI scan failed: $e\n$st');
      if (mounted) {
        context.showErrorSnackbar(
          'AI scan failed: $e',
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _analyzeImageWithAi(bytes, mimeType),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemId != null;
    final categories = ref.watch(inventoryCategoriesProvider).valueOrNull ?? [];
    final locations = ref.watch(inventoryLocationsProvider).valueOrNull ?? [];

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: QuickActionsTitle(
            child: Text(isEditing ? 'Edit Item' : 'New Item'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Scaffold(
        appBar: AppBar(
          title: QuickActionsTitle(
            child: Text(isEditing ? 'Edit Item' : 'New Item'),
          ),
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: 'Transfer quantity',
                onPressed: _isUploading ? null : _openTransferDialog,
              ),
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete item',
                onPressed: _isUploading ? null : _confirmDelete,
              ),
            IconButton(
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner),
              tooltip: 'Scan with AI',
              onPressed: _isScanning ? null : _scanWithAi,
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
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Catalog item link
                _buildCatalogLinkSection(),
                const SizedBox(height: 16),

                // Category autocomplete
                Autocomplete<String>(
                  initialValue: TextEditingValue(
                    text: _categoryController.text,
                  ),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return categories;
                    return categories.where(
                      (c) => c.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ),
                    );
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) {
                        controller.addListener(
                          () => _categoryController.text = controller.text,
                        );
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                  onSelected: (v) => _categoryController.text = v,
                ),
                const SizedBox(height: 16),

                // Location autocomplete
                Autocomplete<String>(
                  initialValue: TextEditingValue(
                    text: _locationController.text,
                  ),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return locations;
                    return locations.where(
                      (l) => l.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ),
                    );
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) {
                        controller.addListener(
                          () => _locationController.text = controller.text,
                        );
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(),
                            hintText: 'e.g. Kitchen, Garage, Office',
                          ),
                        );
                      },
                  onSelected: (v) => _locationController.text = v,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Price',
                          border: const OutlineInputBorder(),
                          prefixText:
                              '${ref.watch(currencyConverterProvider).symbol} ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fill % — optional indicator for half-empty bottles /
                // bags / sauces without changing the integer quantity
                // (WISH-0078). Off by default; turning the switch on
                // reveals a slider that defaults to 100.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Track fill percentage'),
                  subtitle: Text(
                    _fillPercent == null
                        ? 'Off — useful for half-empty bags, almost-empty sauces'
                        : 'Currently $_fillPercent% full',
                  ),
                  value: _fillPercent != null,
                  onChanged: (on) {
                    setState(() => _fillPercent = on ? 100 : null);
                  },
                ),
                if (_fillPercent != null)
                  Slider(
                    value: _fillPercent!.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '$_fillPercent%',
                    onChanged: (v) => setState(() => _fillPercent = v.round()),
                  ),
                if (_fillPercent != null) const SizedBox(height: 16),

                // Opened status — independent of fill percentage, for when
                // the user just wants a simple opened/unopened flag
                // (WISH-0089).
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Opened'),
                  subtitle: const Text('Mark as opened / in active use'),
                  value: _isOpened,
                  onChanged: (v) => setState(() => _isOpened = v ?? false),
                ),
                const SizedBox(height: 16),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    _purchaseDate != null
                        ? DateFormat.yMMMd().format(_purchaseDate!)
                        : 'No purchase date',
                  ),
                  subtitle: const Text('Purchase Date'),
                  trailing: _purchaseDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _purchaseDate = null),
                        )
                      : null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _purchaseDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _purchaseDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),

                // Expiry date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_busy),
                  title: Text(
                    _expiryDate != null
                        ? DateFormat.yMMMd().format(_expiryDate!)
                        : 'No expiry date',
                  ),
                  subtitle:
                      _expiryDate != null &&
                          _expiryDate!.isBefore(DateTime.now())
                      ? Text(
                          'Expired',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      : const Text('Expiry Date'),
                  trailing: _expiryDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _expiryDate = null),
                        )
                      : null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _expiryDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Images
                Text('Images', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                ImageAttachmentStrip(controller: _images),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => pickImageInto(
                    context,
                    ref.read(imageUploadServiceProvider),
                    _images,
                  ),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add image'),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Barcode / Serial Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _searchAliasesController,
                  decoration: const InputDecoration(
                    labelText: 'Nicknames',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sell_outlined),
                    helperText:
                        'Extra search words, separated by space, comma or '
                        'period. Not shown in lists.',
                    helperMaxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogLinkSection() {
    if (_linkedCatalogItem != null) {
      return Card(
        child: ListTile(
          leading: _linkedCatalogItem!.imageUrls.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: _linkedCatalogItem!.imageUrls.first,
                    width: 40,
                    height: 40,
                    memCacheWidth: 120,
                    fit: BoxFit.cover,
                  ),
                )
              : const CircleAvatar(child: Icon(Icons.auto_stories)),
          title: Text(_linkedCatalogItem!.title),
          subtitle: const Text('Linked catalog item'),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _catalogItemId = null;
                _linkedCatalogItem = null;
              });
            },
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _showCatalogPicker,
      icon: const Icon(Icons.auto_stories),
      label: const Text('Link Catalog Item'),
    );
  }

  Future<void> _showCatalogPicker() async {
    final catalogItems = await ref.read(catalogServiceProvider).getItems();

    if (!mounted || catalogItems.isEmpty) {
      if (mounted) {
        context.showSnackbar('No catalog items available');
      }
      return;
    }

    final picked = await showModalBottomSheet<CatalogItem>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CatalogPickerSheet(items: catalogItems),
    );

    if (picked != null && mounted) {
      setState(() {
        _catalogItemId = picked.id;
        _linkedCatalogItem = picked;
        // Add catalog images to item (referencing same URLs — no storage duplication)
        if (picked.imageUrls.isNotEmpty && _images.isEmpty) {
          for (final url in picked.imageUrls) {
            _images.addSavedUrl(url);
          }
        }
        // Auto-fill name if empty
        if (_nameController.text.isEmpty) {
          _nameController.text = picked.title;
        }
        if (_descriptionController.text.isEmpty && picked.description != null) {
          _descriptionController.text = picked.description!;
        }
        if (_priceController.text.isEmpty && picked.price != null) {
          _priceController.text = picked.price!.toStringAsFixed(2);
        }
      });
    }
  }
}

class _CatalogPickerSheet extends StatefulWidget {
  final List<CatalogItem> items;
  const _CatalogPickerSheet({required this.items});

  @override
  State<_CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends State<_CatalogPickerSheet> {
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
                            memCacheWidth: 120,
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
