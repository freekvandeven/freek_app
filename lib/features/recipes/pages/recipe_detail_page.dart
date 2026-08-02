import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_app/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';
import 'package:personal_app/presentation/widgets/star_rating.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../utils/decimal_input.dart';
import '../models/recipe.dart';
import '../providers/recipe_providers.dart';
import '../utils/video_link_parser.dart';
import '../widgets/recipe_ask_ai_sheet.dart';

class RecipeDetailPage extends ConsumerStatefulWidget {
  final String recipeId;
  const RecipeDetailPage({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  int? _currentServings;

  @override
  Widget build(BuildContext context) {
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
        final recipe = recipes
            .where((r) => r.id == widget.recipeId)
            .firstOrNull;
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Recipe not found')),
          );
        }
        _currentServings ??= recipe.servings;
        return _buildDetail(context, recipe, colorScheme, recipes);
      },
    );
  }

  Widget _buildDetail(
    BuildContext context,
    Recipe recipe,
    ColorScheme colorScheme,
    List<Recipe> allRecipes,
  ) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
              tooltip: recipe.hasBeenMade
                  ? 'Made before'
                  : 'Mark as made before',
              icon: Icon(
                recipe.hasBeenMade
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: recipe.hasBeenMade ? Colors.green : null,
              ),
              onPressed: () => ref
                  .read(recipeListProvider.notifier)
                  .toggleHasBeenMade(recipe),
            ),
            IconButton(
              tooltip: 'Ask AI about this recipe',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => RecipeAskAiSheet(recipe: recipe),
              ),
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'General'),
              Tab(text: 'Ingredients'),
              Tab(text: 'Instructions'),
            ],
          ),
        ),
        body: Column(
          children: [
            ResponsiveCenter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (recipe.servings != null) _servingsAdjuster(recipe),
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
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _generalTab(context, recipe, colorScheme, allRecipes),
                  _ingredientsTab(context, recipe),
                  _instructionsTab(context, recipe),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _generalTab(
    BuildContext context,
    Recipe recipe,
    ColorScheme colorScheme,
    List<Recipe> allRecipes,
  ) {
    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (recipe.images.isNotEmpty) ...[
            SizedBox(
              height: 200,
              child: recipe.images.length == 1
                  ? GestureDetector(
                      onTap: () => showFullscreenNetworkImage(
                        context,
                        recipe.images.first,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: recipe.images.first,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
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
                            GestureDetector(
                              onTap: () => showFullscreenNetworkImage(
                                context,
                                recipe.images[index],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: recipe.images[index],
                                  width: 280,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const SizedBox(
                                    width: 280,
                                    child: Center(
                                      child: Icon(Icons.broken_image, size: 48),
                                    ),
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

          if (recipe.rating != null) ...[
            StarRating(value: recipe.rating, size: 22),
            const SizedBox(height: 12),
          ],

          if (recipe.tags.isNotEmpty) ...[
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

          if (recipe.subRecipeIds.isNotEmpty) ...[
            Text('Components', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...recipe.subRecipeIds.map((subId) {
              final sub = allRecipes.where((r) => r.id == subId).firstOrNull;
              if (sub == null) return const SizedBox.shrink();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text(sub.title),
                subtitle: sub.description != null
                    ? Text(
                        sub.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/recipes/${sub.id}'),
              );
            }),
            const SizedBox(height: 16),
          ],

          if (recipe.videoLinks.isNotEmpty) ...[
            Text('Videos', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...recipe.videoLinks.map(
              (url) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _VideoLinkCard(url: url),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (recipe.notes != null) ...[
            Text('Notes', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Text(recipe.notes!),
            const SizedBox(height: 16),
          ],

          if (recipe.source != null)
            Text(
              'Source: ${recipe.source}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _ingredientsTab(BuildContext context, Recipe recipe) {
    if (recipe.ingredients.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No ingredients listed'),
        ),
      );
    }
    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: recipe.ingredients.map((i) {
          final scaledQty =
              (i.quantity != null &&
                  recipe.servings != null &&
                  recipe.servings! > 0 &&
                  _currentServings != null)
              ? i.quantity! * _currentServings! / recipe.servings!
              : i.quantity;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.fiber_manual_record, size: 8),
                const SizedBox(width: 8),
                Text(
                  [
                    if (scaledQty != null) formatDecimal(scaledQty),
                    if (i.unit != null) i.unit,
                    i.name,
                  ].join(' '),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _instructionsTab(BuildContext context, Recipe recipe) {
    if (recipe.instructions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No instructions listed'),
        ),
      );
    }
    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: recipe.instructions.asMap().entries.map((entry) {
          return Padding(
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
                  GestureDetector(
                    onTap: () => showFullscreenNetworkImage(
                      context,
                      entry.value.imageUrl!,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: entry.value.imageUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _servingsAdjuster(Recipe recipe) {
    final current = _currentServings ?? recipe.servings!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.people, size: 16),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.remove, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: current > 1
              ? () => setState(() => _currentServings = current - 1)
              : null,
        ),
        Text('$current'),
        IconButton(
          icon: const Icon(Icons.add, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () => setState(() => _currentServings = current + 1),
        ),
        const Text('servings'),
        if (current != recipe.servings)
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 28),
            ),
            onPressed: () => setState(() => _currentServings = recipe.servings),
            child: const Text('reset'),
          ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)],
    );
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
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                height: 180,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
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
