import 'package:flutter/material.dart';

class WipBadge extends StatelessWidget {
  const WipBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'WIP',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: cs.onTertiaryContainer,
        ),
      ),
    );
  }
}
