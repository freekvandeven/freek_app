import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/log_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/conversation_topic.dart';
import '../services/conversation_service.dart';
import '../services/firestore_conversation_service.dart';

final conversationServiceProvider = Provider<ConversationService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreConversationService(userId);
  }
  final service = MockConversationService();
  ref.onDispose(service.dispose);
  return service;
});

final conversationListProvider =
    StreamNotifierProvider<ConversationListNotifier, List<ConversationTopic>>(
      ConversationListNotifier.new,
    );

class ConversationListNotifier extends StreamNotifier<List<ConversationTopic>> {
  @override
  Stream<List<ConversationTopic>> build() {
    return ref.watch(conversationServiceProvider).watchTopics();
  }

  Future<void> addTopic(ConversationTopic topic) async {
    await ref.read(conversationServiceProvider).addTopic(topic);
    LogService.instance.info('Conversation topic added: ${topic.title}');
  }

  Future<void> updateTopic(ConversationTopic topic) async {
    await ref.read(conversationServiceProvider).updateTopic(topic);
    LogService.instance.info('Conversation topic updated: ${topic.id}');
  }

  Future<void> deleteTopic(String id) async {
    // Delete associated images from Storage
    final topic = await ref.read(conversationServiceProvider).getTopic(id);
    if (topic != null && topic.imageUrls.isNotEmpty) {
      final uploader = ref.read(imageUploadServiceProvider);
      for (final url in topic.imageUrls) {
        await uploader.deleteImage(url);
      }
    }
    await ref.read(conversationServiceProvider).deleteTopic(id);
    LogService.instance.info('Conversation topic deleted: $id');
  }
}

final conversationPersonFilterProvider = StateProvider<String?>((_) => null);
// Default to Open so the page lands on actionable topics, not the
// noise of every resolved conversation ever (WISH-0071).
final conversationStatusFilterProvider = StateProvider<TopicStatus?>(
  (_) => TopicStatus.open,
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
          // "Newest/oldest" follow the same logic as the subtitle date —
          // last-updated rather than created (WISH-0073) so recently
          // active topics float to the top.
          case ConversationSort.newest:
            filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          case ConversationSort.oldest:
            filtered.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
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
