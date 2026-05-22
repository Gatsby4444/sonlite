import 'package:flutter/material.dart';

import 'logs_screen.dart';
import 'themes_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Thèmes',
            subtitle: 'Couleur de l\'interface',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThemesScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.terminal_outlined,
            title: 'Logs',
            subtitle: 'Journal des actions de l\'application',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LogsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
