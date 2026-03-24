import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/conversation_topic.dart';
import '../services/conversation_service.dart';
import '../services/firestore_conversation_service.dart';

final conversationServiceProvider = Provider<ConversationService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreConversationService(userId);
  }
  return MockConversationService();
});

final conversationListProvider =
    AsyncNotifierProvider<ConversationListNotifier, List<ConversationTopic>>(
      ConversationListNotifier.new,
    );

class ConversationListNotifier extends AsyncNotifier<List<ConversationTopic>> {
  @override
  FutureOr<List<ConversationTopic>> build() {
    return ref.watch(conversationServiceProvider).getTopics();
  }

  Future<void> addTopic(ConversationTopic topic) async {
    await ref.read(conversationServiceProvider).addTopic(topic);
    ref.invalidateSelf();
  }

  Future<void> updateTopic(ConversationTopic topic) async {
    await ref.read(conversationServiceProvider).updateTopic(topic);
    ref.invalidateSelf();
  }

  Future<void> deleteTopic(String id) async {
    await ref.read(conversationServiceProvider).deleteTopic(id);
    ref.invalidateSelf();
  }
}

final conversationPersonFilterProvider = StateProvider<String?>((_) => null);
final conversationStatusFilterProvider = StateProvider<TopicStatus?>(
  (_) => null,
);
final conversationSortProvider = StateProvider<ConversationSort>(
  (_) => ConversationSort.priorityDesc,
);

enum ConversationSort { priorityDesc, priorityAsc, newest, oldest }

final filteredConversationsProvider =
    Provider<AsyncValue<List<ConversationTopic>>>((ref) {
      final listAsync = ref.watch(conversationListProvider);
      final personFilter = ref.watch(conversationPersonFilterProvider);
      final statusFilter = ref.watch(conversationStatusFilterProvider);
      final sort = ref.watch(conversationSortProvider);

      return listAsync.whenData((topics) {
        var filtered = topics.toList();
        if (personFilter != null) {
          filtered = filtered
              .where(
                (t) =>
                    t.personOrGroup.toLowerCase() == personFilter.toLowerCase(),
              )
              .toList();
        }
        if (statusFilter != null) {
          filtered = filtered.where((t) => t.status == statusFilter).toList();
        }
        switch (sort) {
          case ConversationSort.priorityDesc:
            filtered.sort(
              (a, b) => b.priority.index.compareTo(a.priority.index),
            );
          case ConversationSort.priorityAsc:
            filtered.sort(
              (a, b) => a.priority.index.compareTo(b.priority.index),
            );
          case ConversationSort.newest:
            filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          case ConversationSort.oldest:
            filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }
        return filtered;
      });
    });

/// Distinct person/group values for filter dropdown.
final conversationPersonsProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(conversationListProvider).whenData((topics) {
    final persons = topics.map((t) => t.personOrGroup).toSet().toList()..sort();
    return persons;
  });
});
