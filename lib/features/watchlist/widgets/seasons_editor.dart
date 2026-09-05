import 'package:flutter/material.dart';

import '../models/watch_item.dart';

/// Add / edit / remove the seasons of a series (WISH-0098). Watched state
/// is not edited here — it is a quick toggle on the detail page, the same
/// way the whole-entry watched flag works.
class SeasonsEditor extends StatelessWidget {
  final List<Season> seasons;
  final ValueChanged<List<Season>> onChanged;

  const SeasonsEditor({
    super.key,
    required this.seasons,
    required this.onChanged,
  });

  Future<void> _edit(BuildContext context, {Season? existing}) async {
    final nextNumber = seasons.isEmpty
        ? 1
        : seasons.map((s) => s.number).reduce((a, b) => a > b ? a : b) + 1;

    final result = await showDialog<Season>(
      context: context,
      builder: (ctx) =>
          _SeasonDialog(season: existing, defaultNumber: nextNumber),
    );
    if (result == null) return;

    final updated = [
      for (final season in seasons)
        if (season.number == existing?.number) result else season,
      if (existing == null) result,
    ]..sort((a, b) => a.number.compareTo(b.number));
    onChanged(updated);
  }

  void _remove(Season season) =>
      onChanged(seasons.where((s) => s.number != season.number).toList());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (seasons.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No seasons yet — add them to track watching season by season',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          for (final season in seasons)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                child: Text(
                  '${season.number}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              title: Text(season.title ?? 'Season ${season.number}'),
              subtitle: season.episodeCount == null
                  ? null
                  : Text('${season.episodeCount} episodes'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove season',
                onPressed: () => _remove(season),
              ),
              onTap: () => _edit(context, existing: season),
            ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Season'),
        ),
      ],
    );
  }
}

class _SeasonDialog extends StatefulWidget {
  final Season? season;
  final int defaultNumber;

  const _SeasonDialog({this.season, required this.defaultNumber});

  @override
  State<_SeasonDialog> createState() => _SeasonDialogState();
}

class _SeasonDialogState extends State<_SeasonDialog> {
  late final TextEditingController _numberController;
  late final TextEditingController _titleController;
  late final TextEditingController _episodesController;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(
      text: '${widget.season?.number ?? widget.defaultNumber}',
    );
    _titleController = TextEditingController(text: widget.season?.title ?? '');
    _episodesController = TextEditingController(
      text: widget.season?.episodeCount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    _titleController.dispose();
    _episodesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.season != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Season' : 'Add Season'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _numberController,
            decoration: const InputDecoration(
              labelText: 'Season number',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            autofocus: !isEditing,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _episodesController,
            decoration: const InputDecoration(
              labelText: 'Episodes',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final number = int.tryParse(_numberController.text.trim());
            if (number == null) return;
            final title = _titleController.text.trim();
            Navigator.pop(
              context,
              Season(
                number: number,
                title: title.isEmpty ? null : title,
                episodeCount: int.tryParse(_episodesController.text.trim()),
                // Editing a season's details never changes whether it has
                // been watched — that is toggled on the detail page.
                watched: widget.season?.watched ?? false,
                watchedAt: widget.season?.watchedAt,
              ),
            );
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
