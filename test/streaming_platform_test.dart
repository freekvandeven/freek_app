import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/watchlist/models/streaming_platform.dart';
import 'package:personal_app/features/watchlist/pages/streaming_platform_list_page.dart';
import 'package:personal_app/features/watchlist/providers/streaming_platform_providers.dart';
import 'package:personal_app/features/watchlist/services/streaming_platform_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakePlatformsNotifier extends StreamingPlatformsNotifier {
  final List<StreamingPlatform> platforms;
  _FakePlatformsNotifier(this.platforms);

  @override
  Stream<List<StreamingPlatform>> build() => Stream.value(platforms);
}

void main() {
  group('StreamingPlatform model (WISH-0099)', () {
    test('toMap/fromMap round-trips every field', () {
      final platform = StreamingPlatform(
        name: 'Netflix',
        url: 'https://netflix.com',
        vaultEntryId: 'vault-entry-1',
        quality: '4K HDR',
        iconUrl: 'https://example.com/netflix.png',
        subscriptionStartedAt: DateTime(2025, 6, 1),
        subscriptionEndedAt: DateTime(2026, 6, 1),
      );

      final restored = StreamingPlatform.fromMap(platform.toMap());

      expect(restored.id, platform.id);
      expect(restored.name, 'Netflix');
      expect(restored.url, 'https://netflix.com');
      expect(restored.vaultEntryId, 'vault-entry-1');
      expect(restored.quality, '4K HDR');
      expect(restored.iconUrl, platform.iconUrl);
      expect(restored.subscriptionStartedAt, DateTime(2025, 6, 1));
      expect(restored.subscriptionEndedAt, DateTime(2026, 6, 1));
    });

    test('fromMap tolerates a document with only the required fields', () {
      final restored = StreamingPlatform.fromMap({
        'id': 'p1',
        'name': 'Videoland',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(restored.name, 'Videoland');
      expect(restored.url, isNull);
      expect(restored.vaultEntryId, isNull);
      expect(restored.isSubscribed, isFalse);
    });

    test('stores only a vault reference, never a credential', () {
      final map = StreamingPlatform(
        name: 'HBO Max',
        vaultEntryId: 'vault-entry-1',
      ).toMap();

      expect(map['vaultEntryId'], 'vault-entry-1');
      expect(map.keys, isNot(contains('password')));
      expect(map.keys, isNot(contains('username')));
    });

    group('isSubscribed', () {
      test('is false without a start date', () {
        expect(StreamingPlatform(name: 'Netflix').isSubscribed, isFalse);
      });

      test('is true once started and not ended', () {
        final platform = StreamingPlatform(
          name: 'Netflix',
          subscriptionStartedAt: DateTime(2025, 6, 1),
        );
        expect(platform.isSubscribed, isTrue);
      });

      test('is false again once ended', () {
        final platform = StreamingPlatform(
          name: 'Netflix',
          subscriptionStartedAt: DateTime(2025, 6, 1),
          subscriptionEndedAt: DateTime(2026, 1, 1),
        );
        expect(platform.isSubscribed, isFalse);
      });
    });

    test('copyWith clears the subscription end to resubscribe', () {
      final ended = StreamingPlatform(
        name: 'Netflix',
        subscriptionStartedAt: DateTime(2025, 6, 1),
        subscriptionEndedAt: DateTime(2026, 1, 1),
      );

      final resumed = ended.copyWith(clearSubscriptionEndedAt: true);
      expect(resumed.isSubscribed, isTrue);
      expect(resumed.subscriptionStartedAt, DateTime(2025, 6, 1));
    });
  });

  group('MockStreamingPlatformService (WISH-0099)', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('emits on listen and again after every mutation', () async {
      final service = MockStreamingPlatformService();
      addTearDown(service.dispose);

      final emissions = <List<StreamingPlatform>>[];
      final sub = service.watchPlatforms().listen(emissions.add);
      await pumpEventQueue();

      final platform = StreamingPlatform(name: 'Netflix');
      await service.addPlatform(platform);
      await service.deletePlatform(platform.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.name, 'Netflix');
      expect(emissions[2], isEmpty);
    });

    test('sorts case-insensitively by name', () async {
      final service = MockStreamingPlatformService();
      addTearDown(service.dispose);

      await service.addPlatform(StreamingPlatform(name: 'videoland'));
      await service.addPlatform(StreamingPlatform(name: 'Apple TV+'));
      await service.addPlatform(StreamingPlatform(name: 'netflix'));

      final platforms = await service.getPlatforms();
      expect(platforms.map((p) => p.name), [
        'Apple TV+',
        'netflix',
        'videoland',
      ]);
    });
  });

  group('StreamingPlatformListPage (WISH-0099)', () {
    Future<void> pump(
      WidgetTester tester,
      List<StreamingPlatform> platforms,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamingPlatformsProvider.overrideWith(
              () => _FakePlatformsNotifier(platforms),
            ),
          ],
          child: const MaterialApp(home: StreamingPlatformListPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows an empty state', (tester) async {
      await pump(tester, []);
      expect(find.text('No streaming platforms yet'), findsOneWidget);
    });

    testWidgets('shows quality and subscription state', (tester) async {
      await pump(tester, [
        StreamingPlatform(
          name: 'Netflix',
          quality: '4K HDR',
          subscriptionStartedAt: DateTime(2025, 6, 1),
        ),
      ]);

      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('4K HDR • Subscribed'), findsOneWidget);
    });

    testWidgets('marks an ended subscription', (tester) async {
      await pump(tester, [
        StreamingPlatform(
          name: 'Videoland',
          subscriptionStartedAt: DateTime(2025, 1, 1),
          subscriptionEndedAt: DateTime(2026, 1, 1),
        ),
      ]);

      expect(find.text('Subscription ended'), findsOneWidget);
    });

    testWidgets('flags a platform whose account lives in the vault', (
      tester,
    ) async {
      await pump(tester, [
        StreamingPlatform(name: 'HBO Max', vaultEntryId: 'vault-1'),
        StreamingPlatform(name: 'Prime Video'),
      ]);

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });
}
