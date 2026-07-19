import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/calendar/models/calendar_event.dart';
import 'package:personal_app/features/calendar/services/calendar_service.dart';
import 'package:personal_app/features/contacts/models/contact.dart';
import 'package:personal_app/features/contacts/services/contact_service.dart';
import 'package:personal_app/features/conversations/models/conversation_topic.dart';
import 'package:personal_app/features/conversations/services/conversation_service.dart';
import 'package:personal_app/features/feedback/models/feedback_entry.dart';
import 'package:personal_app/features/feedback/services/feedback_service.dart';
import 'package:personal_app/features/files/models/file_entry.dart';
import 'package:personal_app/features/files/services/file_service.dart';
import 'package:personal_app/features/finances/models/finance_models.dart';
import 'package:personal_app/features/finances/services/finance_service.dart';
import 'package:personal_app/features/knowledge/models/knowledge_page.dart';
import 'package:personal_app/features/knowledge/services/knowledge_service.dart';
import 'package:personal_app/features/passwords/models/password_entry.dart';
import 'package:personal_app/features/passwords/services/vault_service.dart';
import 'package:personal_app/features/recipes/models/recipe.dart';
import 'package:personal_app/features/recipes/services/recipe_service.dart';
import 'package:personal_app/features/shopping/models/shopping_item.dart';
import 'package:personal_app/features/shopping/services/shopping_service.dart';
import 'package:personal_app/features/tasks/models/task.dart';
import 'package:personal_app/features/tasks/services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('MockTaskService.watchTasks (IMPR-0018)', () {
    test('emits on listen and after add/delete', () async {
      final service = MockTaskService(SharedPreferencesAsync());
      final emissions = <List<Task>>[];
      final sub = service.watchTasks().listen(emissions.add);
      await pumpEventQueue();

      final task = await service.createTask(Task(title: 'Water plants'));
      await service.deleteTask(task.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Water plants');
      expect(emissions[2], isEmpty);
    });
  });

  group('MockShoppingService.watchItems (IMPR-0018)', () {
    test('emits on listen and after add/delete', () async {
      final service = MockShoppingService();
      final emissions = <List<ShoppingItem>>[];
      final sub = service.watchItems().listen(emissions.add);
      await pumpEventQueue();

      final item = ShoppingItem(title: 'Milk');
      await service.addItem(item);
      await service.deleteItem(item.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Milk');
      expect(emissions[2], isEmpty);
    });
  });

  group('MockRecipeService.watchRecipes (IMPR-0018)', () {
    test('emits on listen and after create/delete', () async {
      final service = MockRecipeService(SharedPreferencesAsync());
      final emissions = <List<Recipe>>[];
      final sub = service.watchRecipes().listen(emissions.add);
      await pumpEventQueue();

      final recipe = await service.createRecipe(Recipe(title: 'Soup'));
      await service.deleteRecipe(recipe.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Soup');
      expect(emissions[2], isEmpty);
    });
  });

  group('MockKnowledgeService.watchPages (IMPR-0018)', () {
    test('emits on listen and after add/delete', () async {
      final service = MockKnowledgeService();
      final emissions = <List<KnowledgePage>>[];
      final sub = service.watchPages().listen(emissions.add);
      await pumpEventQueue();

      final page = KnowledgePage(title: 'Router setup', content: 'Notes');
      await service.addPage(page);
      await service.deletePage(page.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Router setup');
      expect(emissions[2], isEmpty);
    });
  });

  group('MockCalendarService.watchEvents (IMPR-0018)', () {
    test('emits on listen and after add/delete', () async {
      final service = MockCalendarService();
      final emissions = <List<CalendarEvent>>[];
      final sub = service.watchEvents().listen(emissions.add);
      await pumpEventQueue();

      final event = CalendarEvent(title: 'Dentist', date: DateTime(2026, 8, 1));
      await service.addEvent(event);
      await service.deleteEvent(event.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Dentist');
      expect(emissions[2], isEmpty);
    });
  });

  group('MockContactService.watchContacts (IMPR-0018)', () {
    test('emits on listen and after add/delete', () async {
      final service = MockContactService();
      final emissions = <List<Contact>>[];
      final sub = service.watchContacts().listen(emissions.add);
      await pumpEventQueue();

      final contact = Contact(name: 'Ada');
      await service.addContact(contact);
      await service.deleteContact(contact.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.name, 'Ada');
      expect(emissions[2], isEmpty);
    });
  });

  group('MockConversationService.watchTopics (IMPR-0018)', () {
    test('emits on listen and after add/delete', () async {
      final service = MockConversationService();
      final emissions = <List<ConversationTopic>>[];
      final sub = service.watchTopics().listen(emissions.add);
      await pumpEventQueue();

      final topic = ConversationTopic(
        title: 'Vacation plans',
        description: 'Where to go',
        personOrGroup: 'Family',
      );
      await service.addTopic(topic);
      await service.deleteTopic(topic.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Vacation plans');
      expect(emissions[2], isEmpty);
    });
  });

  group('MockFeedbackService.watchEntries (IMPR-0018)', () {
    test('emits on listen and after add/delete', () async {
      final service = MockFeedbackService();
      final emissions = <List<FeedbackEntry>>[];
      final sub = service.watchEntries().listen(emissions.add);
      await pumpEventQueue();

      final entry = FeedbackEntry(
        type: FeedbackType.bug,
        title: 'Button misaligned',
        description: 'On the settings page',
      );
      await service.addEntry(entry);
      await service.deleteEntry(entry.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Button misaligned');
      expect(emissions[2], isEmpty);
    });
  });

  group('MockFileService.watchEntries (IMPR-0018)', () {
    test('emits on listen and after add/delete', () async {
      final service = MockFileService();
      final emissions = <List<FileEntry>>[];
      final sub = service.watchEntries().listen(emissions.add);
      await pumpEventQueue();

      final entry = FileEntry(name: 'invoice.pdf', isDirectory: false);
      await service.addEntry(entry);
      await service.deleteEntry(entry.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.name, 'invoice.pdf');
      expect(emissions[2], isEmpty);
    });
  });

  group('MockFinanceService watch streams (IMPR-0018)', () {
    test('watchTransactions emits on listen and after add/delete', () async {
      final service = MockFinanceService();
      final emissions = <List<FinancialTransaction>>[];
      final sub = service.watchTransactions().listen(emissions.add);
      await pumpEventQueue();

      final tx = FinancialTransaction(
        title: 'Groceries',
        amount: 42.50,
        type: TransactionType.expense,
        date: DateTime(2026, 7, 1),
      );
      await service.addTransaction(tx);
      await service.deleteTransaction(tx.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Groceries');
      expect(emissions[2], isEmpty);
    });

    test('watchCategories seeds defaults and emits after add', () async {
      final service = MockFinanceService();
      final emissions = <List<FinancialCategory>>[];
      final sub = service.watchCategories().listen(emissions.add);
      await pumpEventQueue();

      expect(emissions.first, isNotEmpty);

      await service.addCategory(
        FinancialCategory(name: 'Hobby', type: TransactionType.expense),
      );
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.last.map((c) => c.name), contains('Hobby'));
      expect(emissions.last.length, emissions.first.length + 1);
    });

    test('watchAssets emits on listen and after add/delete', () async {
      final service = MockFinanceService();
      final emissions = <List<FinancialAsset>>[];
      final sub = service.watchAssets().listen(emissions.add);
      await pumpEventQueue();

      final asset = FinancialAsset(
        name: 'Savings',
        type: AssetType.bankAccount,
        currentValue: 1000,
      );
      await service.addAsset(asset);
      await service.deleteAsset(asset.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.name, 'Savings');
      expect(emissions[2], isEmpty);
    });
  });

  group('MockVaultService.watchEntries (IMPR-0018)', () {
    test('emits encrypted entries on listen and after add/delete', () async {
      final service = MockVaultService();
      final emissions = <List<PasswordEntry>>[];
      final sub = service.watchEntries().listen(emissions.add);
      await pumpEventQueue();

      final entry = PasswordEntry(
        title: 'Email',
        encryptedPassword: 'ciphertext-blob',
      );
      await service.addEntry(entry);
      await service.deleteEntry(entry.id);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].single.title, 'Email');
      expect(emissions[1].single.encryptedPassword, 'ciphertext-blob');
      expect(emissions[2], isEmpty);
    });

    test('emissions stay sorted by title', () async {
      final service = MockVaultService();
      final emissions = <List<PasswordEntry>>[];
      final sub = service.watchEntries().listen(emissions.add);
      await pumpEventQueue();

      await service.addEntry(
        PasswordEntry(title: 'Zoo pass', encryptedPassword: 'z'),
      );
      await service.addEntry(
        PasswordEntry(title: 'Bank', encryptedPassword: 'b'),
      );
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.last.map((e) => e.title), ['Bank', 'Zoo pass']);
    });
  });
}
