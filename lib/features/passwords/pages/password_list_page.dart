import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:personal_app/presentation/widgets/app_snackbar.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:personal_app/presentation/widgets/responsive_center.dart';

import '../../../presentation/hooks/use_synced_search_controller.dart';
import '../../../presentation/widgets/pullable_center.dart';
import '../providers/vault_providers.dart';

class PasswordListPage extends HookConsumerWidget {
  const PasswordListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(filteredVaultEntriesProvider);
    final search = ref.watch(vaultSearchProvider);
    final searchController = useSyncedSearchController(search);

    // Not part of the bottom-nav shell, so leaving (locking the vault, or
    // navigating elsewhere) disposes this page — reset the search then,
    // but not on the way back from a detail/edit push within Passwords
    // itself, since that doesn't dispose this page (BUG-0047).
    useEffect(() {
      if (ref.read(vaultSearchProvider).isNotEmpty) {
        ref.read(vaultSearchProvider.notifier).state = '';
      }
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(
        title: const QuickActionsTitle(child: Text('Passwords')),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock),
            tooltip: 'Lock vault',
            onPressed: () {
              ref.read(vaultKeyProvider.notifier).state = null;
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search passwords...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                ref.read(vaultSearchProvider.notifier).state =
                                    '',
                          )
                        : null,
                  ),
                  onChanged: (v) =>
                      ref.read(vaultSearchProvider.notifier).state = v,
                ),
              ),

              // Category chips
              _CategoryChips(),

              // Entry list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(vaultEntriesProvider.future),
                  child: entries.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return const PullableCenter(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.key, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No passwords yet'),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final entry = list[index];
                          return Dismissible(
                            key: Key(entry.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (_) => showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Entry'),
                                content: Text('Delete "${entry.title}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                            onDismissed: (_) => ref
                                .read(vaultEntriesProvider.notifier)
                                .deleteEntry(entry.id),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  entry.title.isNotEmpty
                                      ? entry.title[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(entry.title),
                              subtitle: Text(
                                [
                                  entry.username,
                                  entry.category,
                                ].whereType<String>().join(' \u2022 '),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy),
                                tooltip: 'Copy password',
                                onPressed: () =>
                                    _copyPassword(context, entry.password),
                              ),
                              onTap: () =>
                                  context.push('/passwords/list/${entry.id}'),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const PullableCenter(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => PullableCenter(child: Text('Error: $e')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/passwords/list/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _copyPassword(BuildContext context, String password) {
    Clipboard.setData(ClipboardData(text: password));
    context.showSuccessSnackbar(
      'Password copied (auto-clears in 30s)',
      duration: const Duration(seconds: 2),
    );
    // Auto-clear clipboard after 30 seconds
    Timer(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }
}

class _CategoryChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(vaultCategoriesProvider);
    final selected = ref.watch(vaultCategoryFilterProvider);

    return categories.when(
      data: (cats) {
        if (cats.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: selected == null,
                  onSelected: (_) =>
                      ref.read(vaultCategoryFilterProvider.notifier).state =
                          null,
                ),
              ),
              ...cats.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selected == cat,
                    onSelected: (_) =>
                        ref.read(vaultCategoryFilterProvider.notifier).state =
                            selected == cat ? null : cat,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
