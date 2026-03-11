import 'package:flutter/material.dart';
import 'package:personal_app/presentation/widgets/quick_actions_title.dart';
import 'package:url_launcher/url_launcher.dart';

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const QuickActionsTitle(child: Text('Connections'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Quick Links',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._quickLinks.map((link) => _LinkTile(link: link)),
          const SizedBox(height: 24),
          Text(
            'Integrations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._integrations.map((item) => _IntegrationTile(item: item)),
        ],
      ),
    );
  }
}

class _QuickLink {
  final String label;
  final String url;
  final IconData icon;
  final Color color;

  const _QuickLink({
    required this.label,
    required this.url,
    required this.icon,
    required this.color,
  });
}

class _Integration {
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _Integration({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const _quickLinks = [
  _QuickLink(
    label: 'Google Calendar',
    url: 'https://calendar.google.com',
    icon: Icons.calendar_month,
    color: Colors.blue,
  ),
  _QuickLink(
    label: 'Gmail',
    url: 'https://mail.google.com',
    icon: Icons.email,
    color: Colors.red,
  ),
  _QuickLink(
    label: 'Google Drive',
    url: 'https://drive.google.com',
    icon: Icons.cloud,
    color: Colors.green,
  ),
  _QuickLink(
    label: 'Google Keep',
    url: 'https://keep.google.com',
    icon: Icons.sticky_note_2,
    color: Colors.amber,
  ),
  _QuickLink(
    label: 'GitHub',
    url: 'https://github.com',
    icon: Icons.code,
    color: Colors.grey,
  ),
  _QuickLink(
    label: 'ChatGPT',
    url: 'https://chat.openai.com',
    icon: Icons.smart_toy,
    color: Colors.teal,
  ),
];

const _integrations = [
  _Integration(
    label: 'Google Calendar',
    description: 'Sync events with your Google Calendar',
    icon: Icons.calendar_month,
    color: Colors.blue,
  ),
  _Integration(
    label: 'Kerio Connect',
    description: 'Connect to your Kerio mail and calendar',
    icon: Icons.mail,
    color: Colors.orange,
  ),
  _Integration(
    label: 'Google Gemini',
    description: 'AI-powered assistance across the app',
    icon: Icons.auto_awesome,
    color: Colors.purple,
  ),
];

class _LinkTile extends StatelessWidget {
  final _QuickLink link;
  const _LinkTile({required this.link});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(link.icon, color: link.color),
        title: Text(link.label),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => launchUrl(
          Uri.parse(link.url),
          mode: LaunchMode.externalApplication,
        ),
      ),
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  final _Integration item;
  const _IntegrationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(item.icon, color: item.color),
        title: Text(item.label),
        subtitle: Text(item.description),
        trailing: OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.label} integration coming soon'),
                    ),
                  );
                },
                child: const Text('Connect'),
              ),
      ),
    );
  }
}
