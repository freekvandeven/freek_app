import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/catalog/models/catalog_item.dart';
import 'package:personal_app/features/catalog/services/catalog_service.dart';
import 'package:personal_app/features/inventory/models/inventory_item.dart';
import 'package:personal_app/features/inventory/services/inventory_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('MockInventoryService.watchItems (IMPR-0016)', () {
    test('emits the current list immediately on listen', () async {
      final service = MockInventoryService();
      await service.addItem(InventoryItem(name: 'Beans'));

      final first = await service.watchItems().first;
      expect(first.map((i) => i.name), ['Beans']);
    });

    test('emits again after add, update, and delete', () async {
      final service = MockInventoryService();
      final emissions = <List<InventoryItem>>[];
      final sub = service.watchItems().listen(emissions.add);
      await pumpEventQueue();

      final item = InventoryItem(name: 'Rice');
      await service.addItem(item);
      await service.updateItem(item.copyWith(quantity: 5));
      await service.deleteItem(item.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 4);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.name, 'Rice');
      expect(emissions[2].single.quantity, 5);
      expect(emissions[3], isEmpty);
    });

    test('emissions are sorted by name', () async {
      final service = MockInventoryService();
      final emissions = <List<InventoryItem>>[];
      final sub = service.watchItems().listen(emissions.add);
      await pumpEventQueue();

      await service.addItem(InventoryItem(name: 'Zucchini'));
      await service.addItem(InventoryItem(name: 'Apple'));
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.last.map((i) => i.name), ['Apple', 'Zucchini']);
    });
  });

  group('MockCatalogService.watchItems (IMPR-0016)', () {
    test('emits the current list immediately on listen', () async {
      final service = MockCatalogService();
      await service.addItem(CatalogItem(title: 'Blender'));

      final first = await service.watchItems().first;
      expect(first.map((i) => i.title), ['Blender']);
    });

    test('emits again after add, update, and delete', () async {
      final service = MockCatalogService();
      final emissions = <List<CatalogItem>>[];
      final sub = service.watchItems().listen(emissions.add);
      await pumpEventQueue();

      final item = CatalogItem(title: 'Kettle');
      await service.addItem(item);
      await service.updateItem(item.copyWith(description: 'Electric'));
      await service.deleteItem(item.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 4);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Kettle');
      expect(emissions[2].single.description, 'Electric');
      expect(emissions[3], isEmpty);
    });

    test('emissions are sorted by title', () async {
      final service = MockCatalogService();
      final emissions = <List<CatalogItem>>[];
      final sub = service.watchItems().listen(emissions.add);
      await pumpEventQueue();

      await service.addItem(CatalogItem(title: 'Whisk'));
      await service.addItem(CatalogItem(title: 'Apron'));
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.last.map((i) => i.title), ['Apron', 'Whisk']);
    });
  });
}
