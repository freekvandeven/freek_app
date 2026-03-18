import 'package:flutter/foundation.dart'
    show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/recipe.dart';
import '../providers/recipe_providers.dart';
import '../utils/video_link_parser.dart';

class RecipeDetailPage extends ConsumerWidget {
  final String recipeId;
  const RecipeDetailPage({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipeListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return recipesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (recipes) {
        final recipe = recipes.where((r) => r.id == recipeId).firstOrNull;
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Recipe not found')),
          );
        }
        return _buildDetail(context, ref, recipe, colorScheme);
      },
    );
  }

  Widget _buildDetail(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
    ColorScheme colorScheme,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(child: Text(recipe.title)),
        actions: [
          IconButton(
            icon: Icon(
              recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: recipe.isFavorite ? Colors.red : null,
            ),
            onPressed: () =>
                ref.read(recipeListProvider.notifier).toggleFavorite(recipe),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/recipes/${recipe.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Recipe'),
                  content: Text('Delete "${recipe.title}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref
                    .read(recipeListProvider.notifier)
                    .deleteRecipe(recipe.id);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Images
          if (recipe.images.isNotEmpty) ...[
            SizedBox(
              height: 200,
              child: recipe.images.length == 1
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        recipe.images.first,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, size: 48),
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recipe.images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isPrimary = index == recipe.primaryImageIndex;
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                recipe.images[index],
                                width: 280,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 280,
                                  child: Center(
                                    child: Icon(Icons.broken_image, size: 48),
                                  ),
                                ),
                              ),
                            ),
                            if (isPrimary)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Primary',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
          ],

          if (recipe.description != null) ...[
            Text(
              recipe.description!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Metadata row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (recipe.servings != null)
                _infoChip(Icons.people, '${recipe.servings} servings'),
              if (recipe.prepTimeMinutes != null)
                _infoChip(
                  Icons.timer_outlined,
                  '${recipe.prepTimeMinutes} min prep',
                ),
              if (recipe.cookTimeMinutes != null)
                _infoChip(
                  Icons.local_fire_department,
                  '${recipe.cookTimeMinutes} min cook',
                ),
            ],
          ),

          if (recipe.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: recipe.tags
                  .map(
                    (t) => Chip(
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],

          // Ingredients
          if (recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...recipe.ingredients.map(
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, size: 8),
                    const SizedBox(width: 8),
                    Text(
                      [
                        if (i.quantity != null) _formatQuantity(i.quantity!),
                        if (i.unit != null) i.unit,
                        i.name,
                      ].join(' '),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Instructions
          if (recipe.instructions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Instructions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            ...recipe.instructions.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.value.text)),
                      ],
                    ),
                    if (entry.value.imageUrl != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          entry.value.imageUrl!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Videos
          if (recipe.videoLinks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Videos', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...recipe.videoLinks.map(
              (url) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _VideoLinkCard(url: url),
              ),
            ),
          ],

          // Notes
          if (recipe.notes != null) ...[
            const SizedBox(height: 24),
            Text('Notes', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Text(recipe.notes!),
          ],

          // Source
          if (recipe.source != null) ...[
            const SizedBox(height: 24),
            Text(
              'Source: ${recipe.source}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)],
    );
  }

  String _formatQuantity(double q) {
    return q == q.roundToDouble() ? q.toInt().toString() : q.toString();
  }
}

/// Displays a video link: embedded YouTube player for YouTube URLs,
/// or a tappable card that opens in browser for other platforms.
class _VideoLinkCard extends StatefulWidget {
  final String url;
  const _VideoLinkCard({required this.url});

  @override
  State<_VideoLinkCard> createState() => _VideoLinkCardState();
}

class _VideoLinkCardState extends State<_VideoLinkCard> {
  YoutubePlayerController? _ytController;
  late final VideoLinkInfo _info;

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    _info = VideoLinkParser.parse(widget.url);
    // Skip embedding on desktop — WebView YouTube embeds are unreliable there
    if (_info.platform == VideoPlatform.youtube &&
        _info.videoId != null &&
        !_isDesktop) {
      _ytController = YoutubePlayerController.fromVideoId(
        videoId: _info.videoId!,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          strictRelatedVideos: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ytController?.close();
    super.dispose();
  }

  void _openInBrowser() {
    launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Show embedded player with a fallback "Watch on YouTube" button
    if (_ytController != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: YoutubePlayer(
              controller: _ytController!,
              aspectRatio: 16 / 9,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Watch on YouTube'),
            ),
          ),
        ],
      );
    }

    // Fallback card for desktop, non-YouTube, or failed embeds
    final isYouTube = _info.platform == VideoPlatform.youtube;
    final label = VideoLinkParser.platformLabel(_info.platform);
    final thumbnailUrl = _info.thumbnailUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openInBrowser,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (thumbnailUrl != null)
              Image.network(
                thumbnailUrl,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.ondemand_video,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (!isYouTube || thumbnailUrl == null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.ondemand_video,
                        size: 32,
                        color: colorScheme.primary,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Watch on $label',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
