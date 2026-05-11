import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/log_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/feedback_entry.dart';
import '../services/feedback_service.dart';
import '../services/firestore_feedback_service.dart';

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreFeedbackService(userId);
  }
  return MockFeedbackService();
});

final feedbackListProvider =
    AsyncNotifierProvider<FeedbackListNotifier, List<FeedbackEntry>>(
      FeedbackListNotifier.new,
    );

class FeedbackListNotifier extends AsyncNotifier<List<FeedbackEntry>> {
  @override
  FutureOr<List<FeedbackEntry>> build() {
    return ref.watch(feedbackServiceProvider).getEntries();
  }

  Future<void> addEntry(FeedbackEntry entry) async {
    // Auto-generate reference ID if not set.
    if (entry.referenceId == null) {
      final entries = await ref.read(feedbackServiceProvider).getEntries();
      final prefix = entry.type.referencePrefix;
      final sameType = entries.where((e) => e.type == entry.type).toList();
      int maxNum = 0;
      for (final e in sameType) {
        if (e.referenceId != null) {
          final parts = e.referenceId!.split('-');
          if (parts.length == 2) {
            final num = int.tryParse(parts[1]) ?? 0;
            if (num > maxNum) maxNum = num;
          }
        }
      }
      entry = entry.copyWith(
        referenceId: '$prefix-${(maxNum + 1).toString().padLeft(4, '0')}',
      );
    }
    await ref.read(feedbackServiceProvider).addEntry(entry);
    LogService.instance.info(
      'Feedback entry created: ${entry.referenceId} (${entry.type.name})',
    );
    ref.invalidateSelf();
  }

  Future<void> updateEntry(FeedbackEntry entry) async {
    await ref.read(feedbackServiceProvider).updateEntry(entry);
    LogService.instance.info('Feedback entry updated: ${entry.id}');
    ref.invalidateSelf();
  }

  Future<void> deleteEntry(String id) async {
    // Delete associated images from Storage
    final entry = await ref.read(feedbackServiceProvider).getEntry(id);
    if (entry != null && entry.imageUrls.isNotEmpty) {
      final uploader = ref.read(imageUploadServiceProvider);
      for (final url in entry.imageUrls) {
        await uploader.deleteImage(url);
      }
    }
    await ref.read(feedbackServiceProvider).deleteEntry(id);
    LogService.instance.info('Feedback entry deleted: $id');
    ref.invalidateSelf();
  }
}

final feedbackTypeFilterProvider = StateProvider<FeedbackType?>((_) => null);
final feedbackStatusFilterProvider = StateProvider<FeedbackStatus?>(
  (_) => null,
);
final feedbackManualFilterProvider = StateProvider<bool?>((_) => null);
final feedbackWipOnlyProvider = StateProvider<bool>((_) => false);

final filteredFeedbackProvider = Provider<AsyncValue<List<FeedbackEntry>>>((
  ref,
) {
  final listAsync = ref.watch(feedbackListProvider);
  final typeFilter = ref.watch(feedbackTypeFilterProvider);
  final statusFilter = ref.watch(feedbackStatusFilterProvider);
  final manualFilter = ref.watch(feedbackManualFilterProvider);
  final wipOnly = ref.watch(feedbackWipOnlyProvider);

  return listAsync.whenData((entries) {
    var filtered = entries;
    if (typeFilter != null) {
      filtered = filtered.where((e) => e.type == typeFilter).toList();
    }
    if (statusFilter != null) {
      filtered = filtered.where((e) => e.status == statusFilter).toList();
    }
    if (manualFilter != null) {
      filtered = filtered.where((e) => e.isManual == manualFilter).toList();
    }
    if (wipOnly) {
      filtered = filtered.where((e) => e.isWip).toList();
    }
    return filtered;
  });
});
