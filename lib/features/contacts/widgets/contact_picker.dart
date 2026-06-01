import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/contact.dart';
import '../providers/contact_providers.dart';

/// Result of [showContactPicker]: either a linked [contact] (preferred)
/// or a [freeText] label when the user wants to type a name without
/// creating a Contact entity (legacy fallback for WISH-0076).
class ContactPickerResult {
  final Contact? contact;
  final String? freeText;
  const ContactPickerResult({this.contact, this.freeText});

  String get displayName => contact?.name ?? freeText ?? '';
  String? get contactId => contact?.id;
}

/// Bottom sheet listing existing contacts with options to create a new
/// one or fall back to a free-text label. Returns null on cancel.
Future<ContactPickerResult?> showContactPicker(BuildContext context) {
  return showModalBottomSheet<ContactPickerResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _ContactPickerSheet(),
  );
}

class _ContactPickerSheet extends ConsumerWidget {
  const _ContactPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(filteredContactsProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose a contact',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: const Text('New contact…'),
              subtitle: const Text('Opens the contacts editor'),
              onTap: () {
                Navigator.pop(context);
                context.push('/contacts/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields_rounded),
              title: const Text('Use a name without linking'),
              subtitle: const Text(
                'Type a label only — no contact entity is created.',
              ),
              onTap: () async {
                final text = await _promptFreeText(context);
                if (text != null && context.mounted) {
                  Navigator.pop(context, ContactPickerResult(freeText: text));
                }
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: contactsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (contacts) {
                  if (contacts.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No contacts yet. Tap "New contact…" above to '
                          'create one.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (_, i) {
                      final c = contacts[i];
                      return ListTile(
                        leading: Icon(
                          c.isGroup
                              ? Icons.groups_rounded
                              : Icons.person_rounded,
                        ),
                        title: Text(c.name),
                        subtitle: _subtitle(c),
                        onTap: () => Navigator.pop(
                          context,
                          ContactPickerResult(contact: c),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _subtitle(Contact c) {
    final bits = <String>[
      if (c.email != null && c.email!.isNotEmpty) c.email!,
      if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
    ];
    if (bits.isEmpty) return null;
    return Text(bits.join(' · '), maxLines: 1);
  }

  Future<String?> _promptFreeText(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Person or group label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Mum, Work team'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Use'),
          ),
        ],
      ),
    );
  }
}
