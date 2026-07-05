import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/widgets/fullscreen_image_viewer.dart';
import '../../../presentation/widgets/image_upload_preview_dialog.dart';
import '../../../presentation/widgets/star_rating.dart';
import '../../../services/image_upload_service.dart';
import '../../../utils/decimal_input.dart';
import '../../settings/providers/currency_providers.dart';
import '../models/catalog_item.dart';
import '../providers/catalog_providers.dart';

class CatalogEditPage extends ConsumerStatefulWidget {
  final String? itemId;
  const CatalogEditPage({super.key, this.itemId});

  @override
  ConsumerState<CatalogEditPage> createState() => _CatalogEditPageState();
}

class _CatalogEditPageState extends ConsumerState<CatalogEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _linkController = TextEditingController();
  final _searchAliasesController = TextEditingController();

  List<String> _savedImageUrls = [];
  List<({Uint8List bytes, String fileName})> _pendingImages = [];
  final List<String> _removedImageUrls = [];
  bool _isUploading = false;
  bool _isLoading = true;
  double? _rating;

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
    final item = await ref.read(catalogServiceProvider).getItem(widget.itemId!);
    if (item != null && mounted) {
      setState(() {
        _titleController.text = item.title;
        _descriptionController.text = item.description ?? '';
        _priceController.text = item.price != null
            ? ref
                  .read(currencyConverterProvider)
                  .fromEur(item.price!)
                  .toStringAsFixed(2)
            : '';
        _linkController.text = item.link ?? '';
        _searchAliasesController.text = item.searchAliases ?? '';
        _savedImageUrls = List.of(item.imageUrls);
        _rating = item.rating;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _linkController.dispose();
    _searchAliasesController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.itemId != null;

  Future<void> _pickImage() async {
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
            const PasteFromClipboardTile(),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final uploader = ref.read(imageUploadServiceProvider);
    final picked = await resolveImageSource(context, source, uploader);
    if (picked == null || !mounted) return;

    final result = await showImageUploadPreviewDialog(
      context: context,
      originalBytes: picked.bytes,
      fileName: picked.fileName,
      sourcePath: picked.sourcePath,
    );
    if (result == null || !mounted) return;
    await result.maybeRemoveSourceFromDevice();

    setState(() {
      _pendingImages = [
        ..._pendingImages,
        (bytes: result.bytes, fileName: result.fileName),
      ];
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);

    try {
      final uploader = ref.read(imageUploadServiceProvider);

      // Upload pending images
      for (final pending in _pendingImages) {
        final url = await uploader.uploadImageBytes(
          pending.bytes,
          fileName: pending.fileName,
          folder: 'catalog',
        );
        _savedImageUrls.add(url);
      }
      _pendingImages = [];

      // Delete removed images
      for (final url in _removedImageUrls) {
        await uploader.deleteImage(url);
      }

      final converter = ref.read(currencyConverterProvider);
      final price = _priceController.text.isNotEmpty
          ? converter.toEur(parseDecimal(_priceController.text) ?? 0)
          : null;

      final item = CatalogItem(
        id: widget.itemId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        price: price,
        link: _linkController.text.trim().isNotEmpty
            ? _linkController.text.trim()
            : null,
        imageUrls: _savedImageUrls,
        rating: _rating,
        searchAliases: _searchAliasesController.text.trim().isEmpty
            ? null
            : _searchAliasesController.text.trim(),
      );

      final notifier = ref.read(catalogListProvider.notifier);
      if (_isEditing) {
        await notifier.updateItem(item);
      } else {
        await notifier.addItem(item);
      }

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(_isEditing ? 'Edit Catalog Item' : 'New Catalog Item'),
        ),
      ),
      body: ResponsiveCenter(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
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
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price',
                  border: const OutlineInputBorder(),
                  prefixText: '${ref.watch(currencyConverterProvider).symbol} ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Link (URL)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
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
              const SizedBox(height: 16),

              Row(
                children: [
                  Text('Rating', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  StarRating(
                    value: _rating,
                    onChanged: (v) => setState(() => _rating = v),
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Images section
              Text('Images', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildImageGrid(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Add Image'),
              ),

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isUploading ? null : _save,
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Update' : 'Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final allImages = <Widget>[];

    for (int i = 0; i < _savedImageUrls.length; i++) {
      final url = _savedImageUrls[i];
      allImages.add(
        Stack(
          children: [
            GestureDetector(
              onTap: () => showFullscreenNetworkImage(context, url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _savedImageUrls.removeAt(i);
                    _removedImageUrls.add(url);
                  });
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    for (int i = 0; i < _pendingImages.length; i++) {
      allImages.add(
        Stack(
          children: [
            GestureDetector(
              onTap: () =>
                  showFullscreenMemoryImage(context, _pendingImages[i].bytes),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _pendingImages[i].bytes,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _pendingImages = List.of(_pendingImages)..removeAt(i);
                  });
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (allImages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No images added', style: TextStyle(color: Colors.grey)),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: allImages);
  }
}
