import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/widgets/star_rating.dart';
import '../models/watch_item.dart';
import '../providers/watchlist_providers.dart';
import '../widgets/platform_selector.dart';
import '../widgets/seasons_editor.dart';

class WatchItemEditPage extends ConsumerStatefulWidget {
  final String? itemId;
  const WatchItemEditPage({super.key, this.itemId});

  @override
  ConsumerState<WatchItemEditPage> createState() => _WatchItemEditPageState();
}

class _WatchItemEditPageState extends ConsumerState<WatchItemEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imdbIdController = TextEditingController();
  final _yearController = TextEditingController();
  final _runtimeController = TextEditingController();
  final _posterUrlController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  final _reviewController = TextEditingController();

  WatchItemType _type = WatchItemType.movie;
  List<String> _platformIds = const [];
  List<Season> _seasons = const [];
  bool _watched = false;
  double? _rating;
  bool _isSaving = false;
  bool _isLoading = true;

  /// Fields the edit form does not own yet — carried through a save so
  /// editing an entry never drops its seasons or platform links (those
  /// are managed on their own screens).
  WatchItem? _existing;

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
        .read(watchlistServiceProvider)
        .getItem(widget.itemId!);
    if (!mounted) return;
    setState(() {
      if (item != null) {
        _existing = item;
        _titleController.text = item.title;
        _descriptionController.text = item.description ?? '';
        _imdbIdController.text = item.imdbId ?? '';
        _yearController.text = item.year?.toString() ?? '';
        _runtimeController.text = item.runtimeMinutes?.toString() ?? '';
        _posterUrlController.text = item.posterUrl ?? '';
        _sourceUrlController.text = item.sourceUrl ?? '';
        _reviewController.text = item.review ?? '';
        _type = item.type;
        _platformIds = item.platformIds;
        _seasons = item.seasons;
        _watched = item.watched;
        _rating = item.rating;
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imdbIdController.dispose();
    _yearController.dispose();
    _runtimeController.dispose();
    _posterUrlController.dispose();
    _sourceUrlController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.itemId != null;

  String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final existing = _existing;
      final item = WatchItem(
        id: widget.itemId,
        type: _type,
        title: _titleController.text.trim(),
        description: _trimmedOrNull(_descriptionController),
        imdbId: _trimmedOrNull(_imdbIdController),
        year: int.tryParse(_yearController.text.trim()),
        runtimeMinutes: int.tryParse(_runtimeController.text.trim()),
        posterUrl: _trimmedOrNull(_posterUrlController),
        sourceUrl: _trimmedOrNull(_sourceUrlController),
        platformIds: _platformIds,
        watched: _watched,
        watchedAt: _watched ? (existing?.watchedAt ?? DateTime.now()) : null,
        rating: _rating,
        review: _trimmedOrNull(_reviewController),
        seasons: _type == WatchItemType.series ? _seasons : const [],
        sortOrder: existing?.sortOrder ?? 0,
        createdAt: existing?.createdAt,
      );

      final notifier = ref.read(watchlistProvider.notifier);
      if (_isEditing) {
        await notifier.updateItem(item);
      } else {
        await notifier.addItem(item);
      }

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          child: Text(_isEditing ? 'Edit Entry' : 'New Entry'),
        ),
      ),
      body: ResponsiveCenter(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<WatchItemType>(
                segments: const [
                  ButtonSegment(
                    value: WatchItemType.movie,
                    label: Text('Movie'),
                    icon: Icon(Icons.movie),
                  ),
                  ButtonSegment(
                    value: WatchItemType.series,
                    label: Text('Series'),
                    icon: Icon(Icons.tv),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),

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

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _runtimeController,
                      decoration: InputDecoration(
                        labelText: 'Runtime (min)',
                        border: const OutlineInputBorder(),
                        helperText: _type == WatchItemType.series
                            ? 'Per episode'
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _imdbIdController,
                decoration: const InputDecoration(
                  labelText: 'IMDb code',
                  hintText: 'tt0111161',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.movie_filter_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _posterUrlController,
                decoration: const InputDecoration(
                  labelText: 'Poster URL',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image_outlined),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sourceUrlController,
                decoration: const InputDecoration(
                  labelText: 'Source link',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                  helperText: 'Anything — a streaming page, a file location…',
                  helperMaxLines: 2,
                ),
                keyboardType: TextInputType.url,
              ),
              if (_type == WatchItemType.series) ...[
                const SizedBox(height: 24),
                Text('Seasons', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SeasonsEditor(
                  seasons: _seasons,
                  onChanged: (seasons) => setState(() => _seasons = seasons),
                ),
              ],
              const SizedBox(height: 24),

              Text(
                'Streaming platforms',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              PlatformSelector(
                selectedIds: _platformIds,
                onChanged: (ids) => setState(() => _platformIds = ids),
              ),
              const SizedBox(height: 16),

              CheckboxListTile(
                value: _watched,
                onChanged: (v) => setState(() => _watched = v ?? false),
                title: const Text('Watched'),
                subtitle: _type == WatchItemType.series
                    ? const Text('Series with seasons track this per season')
                    : null,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),

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
              const SizedBox(height: 16),
              TextFormField(
                controller: _reviewController,
                decoration: const InputDecoration(
                  labelText: 'Review',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
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
}
