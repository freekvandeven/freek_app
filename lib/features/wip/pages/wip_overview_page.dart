import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../presentation/widgets/responsive_center.dart';
import '../providers/wip_providers.dart';

class WipOverviewPage extends ConsumerWidget {
  const WipOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(wipItemsProvider);
    final grouped = <WipSource, List<WipItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.source, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Work in Progress')),
      body: ResponsiveCenter(
        child: items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Nothing in progress.\nMark recipes, knowledge pages, '
                    'shopping items, or feedback entries as WIP to see them here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                children: [
                  for (final source in WipSource.values)
                    if (grouped[source]?.isNotEmpty ?? false) ...[
                      _SectionHeader(
                        source: source,
                        count: grouped[source]!.length,
                      ),
                      ...grouped[source]!.map((item) => _WipTile(item: item)),
                    ],
                ],
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final WipSource source;
  final int count;
  const _SectionHeader({required this.source, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(source.icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            '${source.label}  ·  $count',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

class _WipTile extends StatelessWidget {
  final WipItem item;
  const _WipTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.construction),
      title: Text(item.title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _navigate(context, item),
    );
  }

  void _navigate(BuildContext context, WipItem item) {
    switch (item.source) {
      case WipSource.recipe:
        context.push('/recipes/${item.id}');
      case WipSource.knowledge:
        context.push('/knowledge/${item.id}');
      case WipSource.shopping:
        context.go('/shopping');
      case WipSource.feedback:
        context.push('/feedback/${item.id}');
    }
  }
}
