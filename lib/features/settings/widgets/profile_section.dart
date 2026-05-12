import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_providers.dart';
import 'section_header.dart';

class ProfileSection extends ConsumerWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('Profile'),
        ListTile(
          leading: user.photoUrl != null
              ? CircleAvatar(
                  backgroundImage: CachedNetworkImageProvider(user.photoUrl!),
                )
              : const Icon(Icons.person),
          title: const Text('Edit Profile'),
          subtitle: Text(user.displayName ?? user.email),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/profile'),
        ),
      ],
    );
  }
}
