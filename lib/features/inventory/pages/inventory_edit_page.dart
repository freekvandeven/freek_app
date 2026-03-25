import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';

import '../../../presentation/widgets/image_upload_preview_dialog.dart';
import '../../../services/image_upload_service.dart';
import '../../gemini/providers/gemini_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../models/inventory_item.dart';
import '../providers/inventory_providers.dart';

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

  DateTime? _purchaseDate;
  DateTime? _expiryDate;
  List<String> _savedImageUrls = [];
  List<({Uint8List bytes, String fileName})> _pendingImages = [];
  final List<String> _removedImageUrls = [];
  bool _isUploading = false;
  bool _isLoading = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemId != null) {
      _loadItem();
    } else {
      _isLoading = false;
    }
  }

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
        _priceController.text = item.purchasePrice?.toStringAsFixed(2) ?? '';
        _barcodeController.text = item.barcode ?? '';
        _purchaseDate = item.purchaseDate;
        _expiryDate = item.expiryDate;
        _savedImageUrls = List.of(item.imageUrls);
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);
    try {
      // Upload pending images
      final uploader = ref.read(imageUploadServiceProvider);
      for (final pending in _pendingImages) {
        final url = await uploader.uploadImageBytes(
          pending.bytes,
          fileName: pending.fileName,
          folder: 'inventory',
        );
        _savedImageUrls.add(url);
      }

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
            ? double.tryParse(_priceController.text.trim())
            : null,
        purchaseDate: _purchaseDate,
        expiryDate: _expiryDate,
        imageUrls: _savedImageUrls,
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
      );

      final notifier = ref.read(inventoryListProvider.notifier);
      if (widget.itemId != null) {
        await notifier.updateItem(item);
      } else {
        await notifier.addItem(item);
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

  Future<void> _scanWithAi() async {
    final service = ref.read(geminiServiceProvider);
    final model = ref.read(geminiModelProvider);
    if (!service.isConfigured) {
      final apiKey = await ref.read(geminiApiKeyServiceProvider).getApiKey();
      service.configure(apiKey, model: model);
    } else {
      service.setModel(model);
    }
    if (!service.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configure a Gemini API key in Settings first'),
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _isScanning = true);
    try {
      final bytes = await image.readAsBytes();
      final mimeType = image.mimeType ?? 'image/jpeg';
      final result = await service.analyzeInventoryImage(bytes, mimeType);

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
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fields filled from image analysis')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract item details from image'),
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

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(isEditing ? 'Edit Item' : 'New Item'),
        ),
        actions: [
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
      body: Form(
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

            // Category autocomplete
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _categoryController.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return categories;
                return categories.where(
                  (c) => c.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
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
              initialValue: TextEditingValue(text: _locationController.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return locations;
                return locations.where(
                  (l) => l.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
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
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                      prefixText: '\u20AC ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
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
                  _expiryDate != null && _expiryDate!.isBefore(DateTime.now())
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
            if (_savedImageUrls.isNotEmpty || _pendingImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _savedImageUrls.length + _pendingImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isExisting = index < _savedImageUrls.length;
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isExisting
                              ? CachedNetworkImage(
                                  imageUrl: _savedImageUrls[index],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                              : Image.memory(
                                  _pendingImages[index - _savedImageUrls.length]
                                      .bytes,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (index < _savedImageUrls.length) {
                                  _removedImageUrls.add(_savedImageUrls[index]);
                                  _savedImageUrls = List.of(_savedImageUrls)
                                    ..removeAt(index);
                                } else {
                                  final pendingIndex =
                                      index - _savedImageUrls.length;
                                  _pendingImages = List.of(_pendingImages)
                                    ..removeAt(pendingIndex);
                                }
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addImage,
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
          ],
        ),
      ),
    );
  }

  Future<void> _addImage() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final uploader = ref.read(imageUploadServiceProvider);
    final file = source == 'gallery'
        ? await uploader.pickImage()
        : await uploader.captureImage();
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
}
