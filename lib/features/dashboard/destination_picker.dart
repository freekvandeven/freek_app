import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../catalog/models/catalog_item.dart';
import '../catalog/providers/catalog_providers.dart';
import '../contacts/models/contact.dart';
import '../contacts/providers/contact_providers.dart';
import '../conversations/models/conversation_topic.dart';
import '../conversations/providers/conversation_providers.dart';
import '../inventory/models/inventory_item.dart';
import '../inventory/providers/inventory_providers.dart';
import '../knowledge/models/knowledge_page.dart';
import '../knowledge/providers/knowledge_providers.dart';
import '../recipes/models/recipe.dart';
import '../recipes/providers/recipe_providers.dart';
import '../tasks/models/task.dart';
import '../tasks/providers/task_providers.dart';
import '../watchlist/models/watch_item.dart';
import '../watchlist/providers/watchlist_providers.dart';

/// A destination a shortcut can point at.
class PickedDestination {
  final String label;
  final String route;
  const PickedDestination({required this.label, required this.route});
}

/// One thing inside a feature that has its own page.
class PickableItem {
  final String title;
  final String? subtitle;
  final String route;
  const PickableItem({required this.title, this.subtitle, required this.route});
}

/// A feature that can be linked to, and optionally browsed into.
///
/// [items] is null for features whose pages are not addressed by id (or
/// whose contents should not be enumerated, like the locked vault) —
/// those can still be linked to as a whole (WISH-0108).
class PickableFeature {
  final String label;
  final IconData icon;
  final String rootRoute;
  final List<PickableItem> Function(WidgetRef ref)? items;

  const PickableFeature({
    required this.label,
    required this.icon,
    required this.rootRoute,
    this.items,
  });

  bool get isBrowsable => items != null;
}

final List<PickableFeature> kPickableFeatures = [
  PickableFeature(
    label: 'Tasks',
    icon: Icons.check_circle_rounded,
    rootRoute: '/tasks',
    items: (ref) => [
      for (final task
          in ref.watch(taskListProvider).valueOrNull ?? const <Task>[])
        PickableItem(title: task.title, route: '/tasks/${task.id}'),
    ],
  ),
  PickableFeature(
    label: 'Recipes',
    icon: Icons.restaurant_menu_rounded,
    rootRoute: '/recipes',
    items: (ref) => [
      for (final recipe
          in ref.watch(recipeListProvider).valueOrNull ?? const <Recipe>[])
        PickableItem(title: recipe.title, route: '/recipes/${recipe.id}'),
    ],
  ),
  PickableFeature(
    label: 'Knowledge',
    icon: Icons.menu_book_rounded,
    rootRoute: '/knowledge',
    items: (ref) => [
      for (final page
          in ref.watch(knowledgeListProvider).valueOrNull ??
              const <KnowledgePage>[])
        PickableItem(title: page.title, route: '/knowledge/${page.id}'),
    ],
  ),
  PickableFeature(
    label: 'Watchlist',
    icon: Icons.movie_rounded,
    rootRoute: '/watchlist',
    items: (ref) => [
      for (final item
          in ref.watch(watchlistProvider).valueOrNull ?? const <WatchItem>[])
        PickableItem(title: item.title, route: '/watchlist/${item.id}'),
    ],
  ),
  PickableFeature(
    label: 'Inventory',
    icon: Icons.inventory_2_rounded,
    rootRoute: '/inventory',
    items: (ref) => [
      for (final item
          in ref.watch(inventoryListProvider).valueOrNull ??
              const <InventoryItem>[])
        PickableItem(title: item.name, route: '/inventory/${item.id}'),
    ],
  ),
  PickableFeature(
    label: 'Catalog',
    icon: Icons.auto_stories_rounded,
    rootRoute: '/catalog',
    items: (ref) => [
      for (final item
          in ref.watch(catalogListProvider).valueOrNull ??
              const <CatalogItem>[])
        PickableItem(title: item.title, route: '/catalog/${item.id}'),
    ],
  ),
  PickableFeature(
    label: 'Contacts',
    icon: Icons.contacts_rounded,
    rootRoute: '/contacts',
    items: (ref) => [
      for (final contact
          in ref.watch(contactListProvider).valueOrNull ?? const <Contact>[])
        PickableItem(title: contact.name, route: '/contacts/${contact.id}'),
    ],
  ),
  PickableFeature(
    label: 'Conversations',
    icon: Icons.forum_rounded,
    rootRoute: '/conversations',
    items: (ref) => [
      for (final topic
          in ref.watch(conversationListProvider).valueOrNull ??
              const <ConversationTopic>[])
        PickableItem(title: topic.title, route: '/conversations/${topic.id}'),
    ],
  ),
  const PickableFeature(
    label: 'Calendar',
    icon: Icons.calendar_month_rounded,
    rootRoute: '/calendar',
  ),
  const PickableFeature(
    label: 'Finance',
    icon: Icons.account_balance_wallet_rounded,
    rootRoute: '/finance',
  ),
  const PickableFeature(
    label: 'Shopping List',
    icon: Icons.shopping_cart_rounded,
    rootRoute: '/shopping',
  ),
  const PickableFeature(
    label: 'Files',
    icon: Icons.folder_rounded,
    rootRoute: '/files',
  ),
  const PickableFeature(
    label: 'Password Vault',
    icon: Icons.lock_rounded,
    rootRoute: '/passwords',
  ),
  const PickableFeature(
    label: 'People',
    icon: Icons.people_rounded,
    rootRoute: '/people',
  ),
  const PickableFeature(
    label: 'Gemini AI',
    icon: Icons.auto_awesome_rounded,
    rootRoute: '/gemini',
  ),
  const PickableFeature(
    label: 'Feedback',
    icon: Icons.feedback_rounded,
    rootRoute: '/feedback',
  ),
  const PickableFeature(
    label: 'Connections',
    icon: Icons.link_rounded,
    rootRoute: '/connections',
  ),
  const PickableFeature(
    label: 'Settings',
    icon: Icons.settings_rounded,
    rootRoute: '/settings',
  ),
];

/// Case-insensitive "contains" match, used for both levels of the picker.
bool matchesQuery(String haystack, String query) =>
    haystack.toLowerCase().contains(query.trim().toLowerCase());

/// Browse to a destination instead of typing its route (WISH-0108):
/// pick a feature, then optionally an item inside it.
Future<PickedDestination?> showDestinationPicker(BuildContext context) {
  return showModalBottomSheet<PickedDestination>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DestinationPicker(),
  );
}

class _DestinationPicker extends ConsumerStatefulWidget {
  const _DestinationPicker();

  @override
  ConsumerState<_DestinationPicker> createState() => _DestinationPickerState();
}

class _DestinationPickerState extends ConsumerState<_DestinationPicker> {
  final _search = TextEditingController();
  PickableFeature? _feature;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openFeature(PickableFeature feature) {
    setState(() {
      _feature = feature;
      _search.clear();
    });
  }

  void _back() {
    setState(() {
      _feature = null;
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text;
    final feature = _feature;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Row(
              children: [
                if (feature != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'All features',
                    onPressed: _back,
                  )
                else
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature?.label ?? 'Choose a destination',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: feature == null
                    ? 'Search features...'
                    : 'Search in ${feature.label}...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: feature == null
                ? _buildFeatureList(scrollController, query)
                : _buildItemList(feature, scrollController, query),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList(ScrollController controller, String query) {
    final features = kPickableFeatures
        .where((f) => matchesQuery(f.label, query))
        .toList();

    if (features.isEmpty) return const _Empty('No features match');

    return ListView.builder(
      controller: controller,
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return ListTile(
          leading: Icon(feature.icon),
          title: Text(feature.label),
          subtitle: Text(feature.rootRoute),
          trailing: feature.isBrowsable
              ? const Icon(Icons.chevron_right)
              : null,
          onTap: () => feature.isBrowsable
              ? _openFeature(feature)
              : Navigator.of(context).pop(
                  PickedDestination(
                    label: feature.label,
                    route: feature.rootRoute,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildItemList(
    PickableFeature feature,
    ScrollController controller,
    String query,
  ) {
    final items = feature.items!(ref)
        .where((i) => matchesQuery(i.title, query))
        .toList();

    return ListView.builder(
      controller: controller,
      // The first row links to the feature itself, so "everything in
      // Knowledge" is as reachable as one page in it.
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListTile(
            leading: Icon(feature.icon),
            title: Text('Open ${feature.label}'),
            subtitle: Text(feature.rootRoute),
            onTap: () => Navigator.of(context).pop(
              PickedDestination(label: feature.label, route: feature.rootRoute),
            ),
          );
        }

        final item = items[index - 1];
        return ListTile(
          leading: const Icon(Icons.arrow_forward_rounded),
          title: Text(item.title),
          subtitle: item.subtitle == null ? null : Text(item.subtitle!),
          onTap: () => Navigator.of(
            context,
          ).pop(PickedDestination(label: item.title, route: item.route)),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty(this.message);

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
