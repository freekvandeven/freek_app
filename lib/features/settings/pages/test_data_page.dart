import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../conversations/models/conversation_topic.dart';
import '../../conversations/providers/conversation_providers.dart';
import '../../feedback/models/feedback_entry.dart';
import '../../feedback/providers/feedback_providers.dart';
import '../../finances/models/finance_models.dart';
import '../../finances/providers/finance_providers.dart';
import '../../inventory/models/inventory_item.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../knowledge/models/knowledge_page.dart';
import '../../knowledge/providers/knowledge_providers.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/providers/recipe_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';

class TestDataPage extends ConsumerStatefulWidget {
  const TestDataPage({super.key});

  @override
  ConsumerState<TestDataPage> createState() => _TestDataPageState();
}

class _TestDataPageState extends ConsumerState<TestDataPage> {
  final _selected = <String, bool>{
    'tasks': true,
    'recipes': true,
    'transactions': true,
    'categories': true,
    'assets': true,
    'calendar': true,
    'inventory': true,
    'feedback': true,
    'knowledge': true,
    'conversations': true,
  };
  bool _generating = false;
  int _itemsPerCategory = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Test Data')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select which data categories to generate. '
                    'Each selected category will create $_itemsPerCategory sample items.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('Items per category:'),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _itemsPerCategory,
                        items: const [
                          DropdownMenuItem(value: 3, child: Text('3')),
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 20, child: Text('20')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _itemsPerCategory = v);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                for (final entry in _selected.entries)
                  CheckboxListTile(
                    title: Text(
                      entry.key[0].toUpperCase() + entry.key.substring(1),
                    ),
                    value: entry.value,
                    onChanged: _generating
                        ? null
                        : (v) {
                            setState(() => _selected[entry.key] = v ?? false);
                          },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.science),
                label: Text(
                  _generating ? 'Generating...' : 'Generate Test Data',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    final rng = Random();
    int totalCreated = 0;

    try {
      if (_selected['categories'] == true) {
        final notifier = ref.read(categoryListProvider.notifier);
        for (final cat in _sampleCategories().take(_itemsPerCategory)) {
          await notifier.addCategory(cat);
          totalCreated++;
        }
      }

      if (_selected['tasks'] == true) {
        final notifier = ref.read(taskListProvider.notifier);
        for (final task in _sampleTasks(rng).take(_itemsPerCategory)) {
          await notifier.addTask(task);
          totalCreated++;
        }
      }

      if (_selected['recipes'] == true) {
        final notifier = ref.read(recipeListProvider.notifier);
        for (final recipe in _sampleRecipes(rng).take(_itemsPerCategory)) {
          await notifier.addRecipe(recipe);
          totalCreated++;
        }
      }

      if (_selected['transactions'] == true) {
        final notifier = ref.read(transactionListProvider.notifier);
        for (final tx in _sampleTransactions(rng).take(_itemsPerCategory)) {
          await notifier.addTransaction(tx);
          totalCreated++;
        }
      }

      if (_selected['assets'] == true) {
        final notifier = ref.read(assetListProvider.notifier);
        for (final asset in _sampleAssets(rng).take(_itemsPerCategory)) {
          await notifier.addAsset(asset);
          totalCreated++;
        }
      }

      if (_selected['calendar'] == true) {
        final notifier = ref.read(calendarEventsProvider.notifier);
        for (final event in _sampleCalendarEvents(
          rng,
        ).take(_itemsPerCategory)) {
          await notifier.addEvent(event);
          totalCreated++;
        }
      }

      if (_selected['inventory'] == true) {
        final notifier = ref.read(inventoryListProvider.notifier);
        for (final item in _sampleInventoryItems(rng).take(_itemsPerCategory)) {
          await notifier.addItem(item);
          totalCreated++;
        }
      }

      if (_selected['feedback'] == true) {
        final notifier = ref.read(feedbackListProvider.notifier);
        for (final entry in _sampleFeedbackEntries(
          rng,
        ).take(_itemsPerCategory)) {
          await notifier.addEntry(entry);
          totalCreated++;
        }
      }

      if (_selected['knowledge'] == true) {
        final notifier = ref.read(knowledgeListProvider.notifier);
        for (final page in _sampleKnowledgePages(rng).take(_itemsPerCategory)) {
          await notifier.addPage(page);
          totalCreated++;
        }
      }

      if (_selected['conversations'] == true) {
        final notifier = ref.read(conversationListProvider.notifier);
        for (final topic in _sampleConversationTopics(
          rng,
        ).take(_itemsPerCategory)) {
          await notifier.addTopic(topic);
          totalCreated++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created $totalCreated test items')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ─── Sample data generators ───────────────────────────────────────

  Iterable<Task> _sampleTasks(Random rng) sync* {
    const titles = [
      'Buy groceries',
      'Clean the kitchen',
      'Prepare presentation',
      'Call dentist',
      'Fix leaking faucet',
      'Update resume',
      'Read chapter 5',
      'Organize desk',
      'Plan weekend trip',
      'Renew subscription',
      'Water plants',
      'Walk the dog',
      'File taxes',
      'Reply to emails',
      'Review budget',
      'Backup photos',
      'Wash car',
      'Schedule meeting',
      'Order supplies',
      'Write blog post',
    ];
    const categories = [
      'Home',
      'Work',
      'Personal',
      'Health',
      'Finance',
      'Learning',
    ];
    final priorities = TaskPriority.values;

    for (final title in titles) {
      yield Task(
        title: title,
        description: 'Test data: $title',
        priority: priorities[rng.nextInt(priorities.length)],
        category: categories[rng.nextInt(categories.length)],
        dueDate: DateTime.now().add(Duration(days: rng.nextInt(30) - 5)),
      );
    }
  }

  Iterable<Recipe> _sampleRecipes(Random rng) sync* {
    const recipes = [
      ('Spaghetti Bolognese', ['pasta', 'Italian', 'dinner']),
      ('Chicken Curry', ['curry', 'Asian', 'dinner']),
      ('Caesar Salad', ['salad', 'healthy', 'lunch']),
      ('Pancakes', ['breakfast', 'sweet']),
      ('Mushroom Risotto', ['Italian', 'vegetarian', 'dinner']),
      ('Fish Tacos', ['Mexican', 'seafood', 'lunch']),
      ('Banana Bread', ['baking', 'sweet', 'snack']),
      ('Tomato Soup', ['soup', 'vegetarian', 'lunch']),
      ('Grilled Salmon', ['seafood', 'healthy', 'dinner']),
      ('Chocolate Cake', ['baking', 'dessert', 'sweet']),
      ('Greek Salad', ['salad', 'healthy', 'Mediterranean']),
      ('Beef Stew', ['dinner', 'comfort food']),
      ('Avocado Toast', ['breakfast', 'healthy']),
      ('Pad Thai', ['Asian', 'Thai', 'dinner']),
      ('Apple Pie', ['baking', 'dessert', 'American']),
      ('Vegetable Stir Fry', ['Asian', 'vegetarian', 'dinner']),
      ('French Onion Soup', ['soup', 'French']),
      ('Eggs Benedict', ['breakfast', 'brunch']),
      ('Lasagna', ['Italian', 'pasta', 'dinner']),
      ('Mango Smoothie', ['drinks', 'healthy', 'breakfast']),
    ];
    final units = ['g', 'ml', 'pcs', 'tbsp', 'tsp', 'cup'];

    for (final (title, tags) in recipes) {
      final ingredientCount = 3 + rng.nextInt(5);
      yield Recipe(
        title: title,
        description: 'A delicious $title recipe for testing.',
        servings: 2 + rng.nextInt(4),
        prepTimeMinutes: 10 + rng.nextInt(20),
        cookTimeMinutes: 15 + rng.nextInt(45),
        ingredients: List.generate(
          ingredientCount,
          (i) => Ingredient(
            name: 'Ingredient ${i + 1}',
            quantity: (1 + rng.nextInt(5)).toDouble(),
            unit: units[rng.nextInt(units.length)],
          ),
        ),
        instructions: [
          RecipeInstruction(text: 'Prepare all ingredients.'),
          RecipeInstruction(text: 'Cook according to the recipe.'),
          RecipeInstruction(text: 'Serve and enjoy.'),
        ],
        tags: tags,
        isFavorite: rng.nextBool(),
      );
    }
  }

  Iterable<FinancialCategory> _sampleCategories() sync* {
    const categories = [
      ('Salary', TransactionType.income),
      ('Freelance', TransactionType.income),
      ('Dividends', TransactionType.income),
      ('Groceries', TransactionType.expense),
      ('Rent', TransactionType.expense),
      ('Utilities', TransactionType.expense),
      ('Transport', TransactionType.expense),
      ('Entertainment', TransactionType.expense),
      ('Healthcare', TransactionType.expense),
      ('Dining Out', TransactionType.expense),
      ('Clothing', TransactionType.expense),
      ('Subscriptions', TransactionType.expense),
      ('Gifts', TransactionType.expense),
      ('Travel', TransactionType.expense),
      ('Education', TransactionType.expense),
      ('Insurance', TransactionType.expense),
      ('Investments', TransactionType.income),
      ('Bonus', TransactionType.income),
      ('Side Hustle', TransactionType.income),
      ('Refunds', TransactionType.income),
    ];

    for (final (name, type) in categories) {
      yield FinancialCategory(name: name, type: type);
    }
  }

  Iterable<FinancialTransaction> _sampleTransactions(Random rng) sync* {
    const descriptions = [
      ('Weekly groceries', TransactionType.expense, 85.0),
      ('Monthly salary', TransactionType.income, 3500.0),
      ('Netflix subscription', TransactionType.expense, 12.99),
      ('Coffee shop', TransactionType.expense, 4.50),
      ('Gas station', TransactionType.expense, 55.0),
      ('Freelance payment', TransactionType.income, 800.0),
      ('Restaurant dinner', TransactionType.expense, 45.0),
      ('Phone bill', TransactionType.expense, 25.0),
      ('Gym membership', TransactionType.expense, 35.0),
      ('Book purchase', TransactionType.expense, 19.99),
      ('Electricity bill', TransactionType.expense, 78.0),
      ('Birthday gift', TransactionType.expense, 30.0),
      ('Parking fee', TransactionType.expense, 8.0),
      ('Dividend payment', TransactionType.income, 125.0),
      ('Train ticket', TransactionType.expense, 22.50),
      ('Clothing', TransactionType.expense, 65.0),
      ('Insurance', TransactionType.expense, 120.0),
      ('Bonus', TransactionType.income, 500.0),
      ('Doctor visit', TransactionType.expense, 40.0),
      ('Online course', TransactionType.expense, 49.99),
    ];

    for (final (title, type, baseAmount) in descriptions) {
      final variance = (rng.nextDouble() * 20) - 10;
      yield FinancialTransaction(
        title: title,
        amount: double.parse((baseAmount + variance).toStringAsFixed(2)),
        type: type,
        date: DateTime.now().subtract(Duration(days: rng.nextInt(60))),
      );
    }
  }

  Iterable<FinancialAsset> _sampleAssets(Random rng) sync* {
    const assets = [
      ('Checking Account', AssetType.bankAccount, 5200.0),
      ('Savings Account', AssetType.bankAccount, 15000.0),
      ('Emergency Fund', AssetType.bankAccount, 8000.0),
      ('Stock Portfolio', AssetType.investment, 22000.0),
      ('ETF Portfolio', AssetType.investment, 12000.0),
      ('Bitcoin Wallet', AssetType.crypto, 3500.0),
      ('Ethereum Wallet', AssetType.crypto, 1800.0),
      ('Cash at Home', AssetType.cash, 200.0),
      ('Retirement Fund', AssetType.investment, 45000.0),
      ('Bonds', AssetType.investment, 10000.0),
      ('Gold Investment', AssetType.other, 5000.0),
      ('Real Estate Fund', AssetType.investment, 30000.0),
      ('Foreign Currency', AssetType.other, 1500.0),
      ('Vacation Fund', AssetType.bankAccount, 3000.0),
      ('Joint Account', AssetType.bankAccount, 7500.0),
      ('Crypto Staking', AssetType.crypto, 900.0),
      ('Money Market', AssetType.investment, 6000.0),
      ('Company Shares', AssetType.investment, 18000.0),
      ('Petty Cash', AssetType.cash, 50.0),
      ('Forex Account', AssetType.other, 2500.0),
    ];

    for (final (name, type, baseValue) in assets) {
      final variance = rng.nextDouble() * baseValue * 0.1;
      yield FinancialAsset(
        name: name,
        type: type,
        currentValue: double.parse((baseValue + variance).toStringAsFixed(2)),
      );
    }
  }

  Iterable<CalendarEvent> _sampleCalendarEvents(Random rng) sync* {
    const events = [
      'Team standup',
      'Dentist appointment',
      'Grocery shopping',
      'Yoga class',
      'Project deadline',
      'Birthday party',
      'Car service',
      'Book club meeting',
      'Date night',
      'Weekend hike',
      'Lunch with Alex',
      'Piano lesson',
      'Flight to Berlin',
      'Conference call',
      'Volunteer work',
      'Movie night',
      'House cleaning',
      'Tax filing deadline',
      'Performance review',
      'Family dinner',
    ];

    for (final title in events) {
      yield CalendarEvent(
        title: title,
        description: 'Test event: $title',
        date: DateTime.now().add(Duration(days: rng.nextInt(60) - 10)),
      );
    }
  }

  Iterable<InventoryItem> _sampleInventoryItems(Random rng) sync* {
    const items = [
      ('Laptop', 'Electronics', 'Office', 999.0),
      ('Wireless Mouse', 'Electronics', 'Office', 29.99),
      ('Desk Chair', 'Furniture', 'Office', 349.0),
      ('Coffee Maker', 'Kitchen', 'Kitchen', 89.0),
      ('Bookshelf', 'Furniture', 'Living Room', 179.0),
      ('Headphones', 'Electronics', 'Office', 149.0),
      ('Yoga Mat', 'Sports', 'Garage', 25.0),
      ('Winter Jacket', 'Clothing', 'Bedroom', 120.0),
      ('Drill', 'Tools', 'Garage', 79.0),
      ('Blender', 'Kitchen', 'Kitchen', 45.0),
      ('Monitor', 'Electronics', 'Office', 450.0),
      ('Tent', 'Outdoor', 'Garage', 220.0),
      ('Vacuum Cleaner', 'Home', 'Storage', 199.0),
      ('Guitar', 'Music', 'Living Room', 380.0),
      ('Bicycle', 'Sports', 'Garage', 650.0),
      ('Printer', 'Electronics', 'Office', 199.0),
      ('Standing Desk', 'Furniture', 'Office', 499.0),
      ('Camping Stove', 'Outdoor', 'Garage', 55.0),
      ('Suitcase', 'Travel', 'Storage', 89.0),
      ('Board Game Set', 'Entertainment', 'Living Room', 35.0),
    ];

    for (final (name, category, location, price) in items) {
      yield InventoryItem(
        name: name,
        description: 'Test item: $name',
        category: category,
        location: location,
        quantity: 1 + rng.nextInt(3),
        purchasePrice: price,
        purchaseDate: DateTime.now().subtract(Duration(days: rng.nextInt(365))),
      );
    }
  }

  Iterable<FeedbackEntry> _sampleFeedbackEntries(Random rng) sync* {
    const entries = [
      ('App crashes on startup', FeedbackType.bug),
      ('Dark mode support', FeedbackType.wish),
      ('Search not finding results', FeedbackType.bug),
      ('Export to PDF', FeedbackType.wish),
      ('Slow loading on recipes', FeedbackType.bug),
      ('Add barcode scanner', FeedbackType.wish),
      ('Calendar sync with Google', FeedbackType.wish),
      ('Notification reminders', FeedbackType.wish),
      ('Login fails intermittently', FeedbackType.bug),
      ('Widget for home screen', FeedbackType.wish),
      ('Offline mode support', FeedbackType.wish),
      ('Sorting not working', FeedbackType.bug),
      ('Multi-language support', FeedbackType.wish),
      ('Image upload fails', FeedbackType.bug),
      ('Shared shopping list', FeedbackType.wish),
      ('Tags disappearing', FeedbackType.bug),
      ('Recurring tasks', FeedbackType.wish),
      ('Data import from CSV', FeedbackType.wish),
      ('Button alignment off', FeedbackType.bug),
      ('Meal planning feature', FeedbackType.wish),
    ];

    for (final (title, type) in entries) {
      yield FeedbackEntry(
        type: type,
        title: '[Test] $title',
        description: 'Test feedback entry: $title',
        isManual: true,
      );
    }
  }

  Iterable<KnowledgePage> _sampleKnowledgePages(Random rng) sync* {
    const pages = [
      (
        'Flutter Tips',
        'Tips and tricks for Flutter development.',
        ['flutter', 'dev'],
      ),
      ('Cooking Notes', 'Various cooking techniques and notes.', ['cooking']),
      (
        'Travel Checklist',
        'Things to pack before travel.',
        ['travel', 'planning'],
      ),
      ('Meeting Notes', 'Notes from team meetings.', ['work', 'meetings']),
      ('Book Recommendations', 'Books worth reading.', ['books', 'reading']),
      ('Fitness Plan', 'Weekly workout schedule.', ['health', 'fitness']),
      ('Project Ideas', 'Ideas for side projects.', ['dev', 'ideas']),
      (
        'Shopping Hacks',
        'Ways to save money while shopping.',
        ['finance', 'shopping'],
      ),
      (
        'Language Learning',
        'Resources for learning new languages.',
        ['learning', 'languages'],
      ),
      ('Home Maintenance', 'Regular home maintenance tasks.', ['home']),
      (
        'Investment Strategy',
        'Notes on investment approaches.',
        ['finance', 'investing'],
      ),
      (
        'Recipe Variations',
        'Variations on favorite recipes.',
        ['cooking', 'recipes'],
      ),
      ('Productivity Tips', 'Methods to boost productivity.', ['productivity']),
      ('Garden Planning', 'Plans for the garden.', ['home', 'garden']),
      ('Tech Stack Notes', 'Notes on tech stack choices.', ['dev', 'tech']),
      ('Gift Ideas', 'Gift ideas for friends and family.', ['personal']),
      ('Movie Watchlist', 'Movies to watch.', ['entertainment']),
      ('Health Notes', 'Medical notes and reminders.', ['health']),
      ('Car Maintenance', 'Schedule for car service.', ['car']),
      ('Bucket List', 'Things to do before...', ['personal', 'goals']),
    ];

    for (final (title, content, tags) in pages) {
      yield KnowledgePage(title: title, content: content, tags: tags);
    }
  }

  Iterable<ConversationTopic> _sampleConversationTopics(Random rng) sync* {
    const topics = [
      ('Vacation plans', 'Discuss where to go this summer', 'Family'),
      ('Project deadline', 'Talk about the Q3 deadline', 'Team'),
      ('Birthday surprise', 'Plan surprise party for Alex', 'Friends'),
      ('Rent increase', 'Negotiate new lease terms', 'Landlord'),
      ('Career advice', 'Ask about promotion path', 'Manager'),
      ('Wedding planning', 'Venue and date discussion', 'Partner'),
      ('Diet plan', 'Discuss new nutrition plan', 'Trainer'),
      ('School enrollment', 'Discuss options for next year', 'Family'),
      ('Car repair quote', 'Get estimate for brake pads', 'Mechanic'),
      ('Investment advice', 'Review portfolio allocation', 'Financial Advisor'),
      ('Home renovation', 'Discuss kitchen remodel', 'Contractor'),
      ('Book club pick', 'Vote on next book', 'Book Club'),
      ('Weekend plans', 'Coordinate hiking trip', 'Friends'),
      ('Insurance review', 'Annual policy check', 'Agent'),
      ('Pet sitting', 'Arrange holiday pet care', 'Neighbor'),
      ('Freelance contract', 'Review contract terms', 'Client'),
      ('Moving logistics', 'Plan the big move', 'Family'),
      ('Gym schedule', 'Agree on workout times', 'Gym Buddy'),
      ('Volunteer work', 'Sign up for charity event', 'Community'),
      ('Tech setup', 'Help with new laptop', 'Colleague'),
    ];
    final priorities = TopicPriority.values;

    for (final (title, description, person) in topics) {
      yield ConversationTopic(
        title: title,
        description: description,
        personOrGroup: person,
        priority: priorities[rng.nextInt(priorities.length)],
      );
    }
  }
}
