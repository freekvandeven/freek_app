import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/presentation/shell/nav_destinations.dart';

List<String> _keys(List<NavDestination> destinations) =>
    destinations.map((d) => d.key).toList();

void main() {
  group('kNavDestinations (WISH-0106)', () {
    test('branch indexes are unique and match the router positions', () {
      final indexes = kNavDestinations.map((d) => d.branchIndex).toList();

      expect(indexes.toSet().length, indexes.length);
      // The router declares one branch per destination, numbered from 0.
      expect(indexes..sort(), List.generate(kNavDestinations.length, (i) => i));
    });

    test('keys are unique, and every default-order key exists', () {
      final keys = kNavDestinations.map((d) => d.key).toList();
      expect(keys.toSet().length, keys.length);

      for (final key in defaultNavOrder) {
        expect(keys, contains(key), reason: '$key has no destination');
      }
      expect(defaultNavOrder.length, kNavDestinations.length);
    });

    test('watchlist is a real destination, not a pushed route', () {
      expect(kNavDestinations.any((d) => d.key == 'watchlist'), isTrue);
    });
  });

  group('resolveNavOrder (WISH-0106)', () {
    test('falls back to the default order when nothing is saved', () {
      expect(_keys(resolveNavOrder(const [])), defaultNavOrder);
    });

    test('honours a saved order', () {
      final resolved = _keys(resolveNavOrder(['watchlist', 'tasks']));

      expect(resolved.first, 'watchlist');
      expect(resolved[1], 'tasks');
    });

    test('appends destinations the saved order does not mention', () {
      final resolved = _keys(resolveNavOrder(['watchlist']));

      // A feature added in a later release turns up rather than vanishing.
      expect(resolved.toSet(), defaultNavOrder.toSet());
      expect(resolved.first, 'watchlist');
    });

    test('drops keys that no longer exist', () {
      final resolved = _keys(resolveNavOrder(['gone', 'tasks']));

      expect(resolved, isNot(contains('gone')));
      expect(resolved.first, 'tasks');
      expect(resolved.length, kNavDestinations.length);
    });

    test('ignores duplicates', () {
      final resolved = _keys(resolveNavOrder(['tasks', 'tasks', 'home']));

      expect(resolved.where((k) => k == 'tasks').length, 1);
      expect(resolved.take(2), ['tasks', 'home']);
    });

    test('always puts More last, wherever it was saved', () {
      final resolved = _keys(
        resolveNavOrder([kMoreDestinationKey, 'tasks', 'home']),
      );

      expect(resolved.last, kMoreDestinationKey);
      expect(resolved.take(2), ['tasks', 'home']);
    });
  });

  group('visibleNavDestinations (WISH-0106)', () {
    test('a phone shows the first few of the order, plus More', () {
      final visible = _keys(
        visibleNavDestinations(resolveNavOrder(const []), 400),
      );

      expect(visible.length, 5);
      expect(visible.last, kMoreDestinationKey);
      expect(visible.take(4), defaultNavOrder.take(4));
    });

    test('a wide window shows everything', () {
      final visible = visibleNavDestinations(resolveNavOrder(const []), 1400);

      expect(visible.length, kNavDestinations.length);
      expect(visible.last.key, kMoreDestinationKey);
    });

    test('the order decides what survives a narrow screen', () {
      // The point of ordering: promoting something makes it visible on a
      // phone, and what it displaced is not.
      final visible = _keys(
        visibleNavDestinations(resolveNavOrder(['watchlist']), 400),
      );

      expect(visible.first, 'watchlist');
      expect(visible, isNot(contains('finance')));
    });

    test('More survives at every width', () {
      for (final width in [320.0, 700.0, 1000.0, 1600.0]) {
        final visible = visibleNavDestinations(
          resolveNavOrder(const []),
          width,
        );
        expect(visible.last.key, kMoreDestinationKey, reason: 'at $width');
      }
    });
  });
}
