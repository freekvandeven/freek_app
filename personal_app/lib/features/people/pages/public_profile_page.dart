import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/widgets/quick_actions_title.dart';

class PublicProfilePage extends ConsumerWidget {
  final String userId;

  const PublicProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const QuickActionsTitle(child: Text('Profile'))),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('publicProfiles')
            .doc(userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(child: Text('Profile not found'));
          }

          final displayName = data['displayName'] as String? ?? 'Anonymous';
          final bio = data['bio'] as String?;
          final photoUrl = data['photoUrl'] as String?;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: photoUrl != null
                      ? CachedNetworkImageProvider(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          _initials(displayName),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: colorScheme.onPrimaryContainer),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (bio != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    bio,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(RegExp(r'[\s@]+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
