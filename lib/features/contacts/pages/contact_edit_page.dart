import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../presentation/widgets/quick_actions_title.dart';
import '../../../presentation/widgets/responsive_center.dart';
import '../models/contact.dart';
import '../providers/contact_providers.dart';

class ContactEditPage extends HookConsumerWidget {
  final String? contactId;
  const ContactEditPage({super.key, this.contactId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = contactId != null;
    final formKey = useMemoized(() => GlobalKey<FormState>(), const []);
    final nameController = useTextEditingController();
    final emailController = useTextEditingController();
    final phoneController = useTextEditingController();
    final notesController = useTextEditingController();
    final dateOfBirth = useState<DateTime?>(null);
    final isGroup = useState(false);
    final isLoading = useState(isEditing);
    final existing = useState<Contact?>(null);

    useEffect(() {
      if (isEditing) {
        () async {
          final c = await ref
              .read(contactServiceProvider)
              .getContact(contactId!);
          if (c == null || !context.mounted) {
            isLoading.value = false;
            return;
          }
          existing.value = c;
          nameController.text = c.name;
          emailController.text = c.email ?? '';
          phoneController.text = c.phone ?? '';
          notesController.text = c.notes;
          dateOfBirth.value = c.dateOfBirth;
          isGroup.value = c.isGroup;
          isLoading.value = false;
        }();
      }
      return null;
    }, const []);

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      final phone = phoneController.text.trim();
      final notes = notesController.text.trim();
      final notifier = ref.read(contactListProvider.notifier);
      if (existing.value != null) {
        await notifier.updateContact(
          existing.value!.copyWith(
            name: name,
            email: () => email.isEmpty ? null : email,
            phone: () => phone.isEmpty ? null : phone,
            dateOfBirth: () => dateOfBirth.value,
            notes: notes,
            isGroup: isGroup.value,
          ),
        );
      } else {
        await notifier.addContact(
          Contact(
            name: name,
            email: email.isEmpty ? null : email,
            phone: phone.isEmpty ? null : phone,
            dateOfBirth: dateOfBirth.value,
            notes: notes,
            isGroup: isGroup.value,
          ),
        );
      }
      if (context.mounted) context.pop();
    }

    Future<void> confirmDelete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isGroup.value ? 'Delete group?' : 'Delete contact?'),
          content: Text('"${nameController.text}" will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await ref.read(contactListProvider.notifier).deleteContact(contactId!);
      if (context.mounted) context.pop();
    }

    if (isLoading.value) {
      return Scaffold(
        appBar: AppBar(
          title: QuickActionsTitle(
            child: Text(isEditing ? 'Edit Contact' : 'New Contact'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: QuickActionsTitle(
          child: Text(isEditing ? 'Edit Contact' : 'New Contact'),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: confirmDelete,
            ),
          TextButton(onPressed: save, child: const Text('Save')),
        ],
      ),
      body: ResponsiveCenter(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                value: isGroup.value,
                onChanged: (v) => isGroup.value = v,
                title: const Text('Group'),
                subtitle: const Text(
                  'Toggle when this represents a family, team, or other '
                  'collection rather than a single person.',
                ),
                secondary: Icon(
                  isGroup.value ? Icons.groups_rounded : Icons.person_rounded,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Date of birth'),
                subtitle: Text(
                  dateOfBirth.value != null
                      ? DateFormat.yMMMd().format(dateOfBirth.value!)
                      : 'Not set',
                ),
                trailing: dateOfBirth.value != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                        onPressed: () => dateOfBirth.value = null,
                      )
                    : const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        dateOfBirth.value ?? DateTime(now.year - 30, 1, 1),
                    firstDate: DateTime(1900),
                    lastDate: now,
                  );
                  if (picked != null) dateOfBirth.value = picked;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
