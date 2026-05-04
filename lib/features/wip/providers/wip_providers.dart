import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feedback/models/feedback_entry.dart';
import '../../feedback/providers/feedback_providers.dart';
import '../../knowledge/models/knowledge_page.dart';
import '../../knowledge/providers/knowledge_providers.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/providers/recipe_providers.dart';
import '../../shopping/models/shopping_item.dart';
import '../../shopping/providers/shopping_providers.dart';

enum WipSource { recipe, knowledge, shopping, feedback }

extension WipSourceLabel on WipSource {
  String get label => switch (this) {
    WipSource.recipe => 'Recipe',
    WipSource.knowledge => 'Knowledge',
    WipSource.shopping => 'Shopping',
    WipSource.feedback => 'Feedback',
  };

  IconData get icon => switch (this) {
    WipSource.recipe => Icons.restaurant_menu,
    WipSource.knowledge => Icons.menu_book,
    WipSource.shopping => Icons.shopping_cart,
    WipSource.feedback => Icons.feedback,
  };
}

class WipItem {
  final String id;
  final String title;
  final WipSource source;

  const WipItem({required this.id, required this.title, required this.source});
}

final wipItemsProvider = Provider<List<WipItem>>((ref) {
  final recipes = ref.watch(recipeListProvider).valueOrNull ?? const <Recipe>[];
  final pages =
      ref.watch(knowledgeListProvider).valueOrNull ?? const <KnowledgePage>[];
  final shopping =
      ref.watch(shoppingListProvider).valueOrNull ?? const <ShoppingItem>[];
  final feedback =
      ref.watch(feedbackListProvider).valueOrNull ?? const <FeedbackEntry>[];

  final items = <WipItem>[
    for (final r in recipes.where((r) => r.isWip))
      WipItem(id: r.id, title: r.title, source: WipSource.recipe),
    for (final p in pages.where((p) => p.isWip))
      WipItem(id: p.id, title: p.title, source: WipSource.knowledge),
    for (final s in shopping.where((s) => s.isWip))
      WipItem(id: s.id, title: s.title, source: WipSource.shopping),
    for (final f in feedback.where((f) => f.isWip))
      WipItem(id: f.id, title: f.title, source: WipSource.feedback),
  ];
  return items;
});
