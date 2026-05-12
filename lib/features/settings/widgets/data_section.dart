import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'section_header.dart';

class DataSection extends StatelessWidget {
  const DataSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('Data'),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Export Data'),
          subtitle: const Text('Export your data to CSV'),
          onTap: () => context.push('/settings/export'),
        ),
      ],
    );
  }
}
