import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../presentation/hooks/use_synced_search_controller.dart';
import '../../../presentation/widgets/pullable_center.dart';
import '../../../presentation/widgets/quick_actions_title.dart';
import '../../../presentation/widgets/responsive_center.dart';
import '../models/contact.dart';
import '../providers/contact_providers.dart';

class ContactListPage extends HookConsumerWidget {
  const ContactListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(contactSearchProvider);
    final contacts = ref.watch(filteredContactsProvider);
    final searchController = useSyncedSearchController(search);

    // Not part of the bottom-nav shell, so leaving disposes this page —
    // reset the search then, but not on the way back from a detail/edit
    // push within Contacts itself, since that doesn't dispose this page
    // (BUG-0047).
    useEffect(() {
      if (ref.read(contactSearchProvider).isNotEmpty) {
        ref.read(contactSearchProvider.notifier).state = '';
      }
      return null;
    }, const []);

    return Scaffold(
      appBar: AppBar(title: const QuickActionsTitle(child: Text('Contacts'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/contacts/new'),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, phone…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                ref.read(contactSearchProvider.notifier).state =
                                    '',
                          )
                        : null,
                  ),
                  onChanged: (v) =>
                      ref.read(contactSearchProvider.notifier).state = v,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(contactListProvider.future),
                  child: contacts.when(
                    loading: () => const PullableCenter(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => PullableCenter(child: Text('Error: $e')),
                    data: (list) {
                      if (list.isEmpty) {
                        return PullableCenter(
                          child: Text(
                            search.isEmpty
                                ? 'No contacts yet.\nTap + to add one.'
                                : 'No contacts match "$search".',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _ContactTile(contact: list[i]),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (contact.email != null && contact.email!.isNotEmpty) contact.email!,
      if (contact.phone != null && contact.phone!.isNotEmpty) contact.phone!,
      if (contact.dateOfBirth != null)
        DateFormat.yMMMd().format(contact.dateOfBirth!),
    ];
    return ListTile(
      leading: Icon(
        contact.isGroup ? Icons.groups_rounded : Icons.person_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(contact.name),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(subtitleParts.join(' · '), maxLines: 1),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/contacts/${contact.id}'),
    );
  }
}
