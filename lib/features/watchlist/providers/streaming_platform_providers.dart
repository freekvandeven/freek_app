import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/log_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/streaming_platform.dart';
import '../services/firestore_streaming_platform_service.dart';
import '../services/streaming_platform_service.dart';

final streamingPlatformServiceProvider = Provider<StreamingPlatformService>((
  ref,
) {
  if (AppConfig.useFirebase) {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return FirestoreStreamingPlatformService(userId);
  }
  final service = MockStreamingPlatformService();
  ref.onDispose(service.dispose);
  return service;
});

class StreamingPlatformsNotifier
    extends StreamNotifier<List<StreamingPlatform>> {
  @override
  Stream<List<StreamingPlatform>> build() {
    return ref.watch(streamingPlatformServiceProvider).watchPlatforms();
  }

  Future<void> addPlatform(StreamingPlatform platform) async {
    await ref.read(streamingPlatformServiceProvider).addPlatform(platform);
    LogService.instance.info('Streaming platform added: ${platform.name}');
  }

  Future<void> updatePlatform(StreamingPlatform platform) async {
    await ref.read(streamingPlatformServiceProvider).updatePlatform(platform);
    LogService.instance.info('Streaming platform updated: ${platform.id}');
  }

  Future<void> deletePlatform(String id) async {
    final service = ref.read(streamingPlatformServiceProvider);
    final platform = await service.getPlatform(id);
    final iconUrl = platform?.iconUrl;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      await ref.read(imageUploadServiceProvider).deleteImage(iconUrl);
    }
    await service.deletePlatform(id);
    LogService.instance.info('Streaming platform deleted: $id');
  }
}

final streamingPlatformsProvider =
    StreamNotifierProvider<StreamingPlatformsNotifier, List<StreamingPlatform>>(
      StreamingPlatformsNotifier.new,
    );

/// Platforms keyed by id, so entry tiles can resolve their `platformIds`
/// without scanning the list per row.
final streamingPlatformsByIdProvider = Provider<Map<String, StreamingPlatform>>(
  (ref) {
    final platforms =
        ref.watch(streamingPlatformsProvider).valueOrNull ??
        const <StreamingPlatform>[];
    return {for (final p in platforms) p.id: p};
  },
);
