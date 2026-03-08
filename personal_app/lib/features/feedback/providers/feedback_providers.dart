import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feedback_entry.dart';
import '../services/feedback_service.dart';

final feedbackServiceProvider = Provider<FeedbackService>(
  (_) => MockFeedbackService(),
);

final feedbackListProvider =
    AsyncNotifierProvider<FeedbackListNotifier, List<FeedbackEntry>>(
      FeedbackListNotifier.new,
    );

class FeedbackListNotifier extends AsyncNotifier<List<FeedbackEntry>> {
  @override
  FutureOr<List<FeedbackEntry>> build() {
    return ref.read(feedbackServiceProvider).getEntries();
  }

  Future<void> addEntry(FeedbackEntry entry) async {
    await ref.read(feedbackServiceProvider).addEntry(entry);
    ref.invalidateSelf();
  }

  Future<void> updateEntry(FeedbackEntry entry) async {
    await ref.read(feedbackServiceProvider).updateEntry(entry);
    ref.invalidateSelf();
  }

  Future<void> deleteEntry(String id) async {
    await ref.read(feedbackServiceProvider).deleteEntry(id);
    ref.invalidateSelf();
  }
}

final feedbackTypeFilterProvider = StateProvider<FeedbackType?>((_) => null);
final feedbackStatusFilterProvider = StateProvider<FeedbackStatus?>(
  (_) => null,
);

final filteredFeedbackProvider = Provider<AsyncValue<List<FeedbackEntry>>>((
  ref,
) {
  final listAsync = ref.watch(feedbackListProvider);
  final typeFilter = ref.watch(feedbackTypeFilterProvider);
  final statusFilter = ref.watch(feedbackStatusFilterProvider);

  return listAsync.whenData((entries) {
    var filtered = entries;
    if (typeFilter != null) {
      filtered = filtered.where((e) => e.type == typeFilter).toList();
    }
    if (statusFilter != null) {
      filtered = filtered.where((e) => e.status == statusFilter).toList();
    }
    return filtered;
  });
});
