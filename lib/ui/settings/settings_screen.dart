import 'package:flutter/material.dart';
import 'settings_section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Theme(
      data: t.copyWith(useMaterial3: true),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            const SliverAppBar.large(
              title: Text('Профил и настройки'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    SettingsSectionCard(
                      title: 'Профил',
                      children: const [
                        ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text('Потребител'),
                          subtitle: Text(''),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SettingsSectionCard(
                      title: 'Предпочитания',
                      children: const [
                        ListTile(
                          leading: Icon(Icons.tune),
                          title: Text('Настройка'),
                          subtitle: Text(''),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SettingsSectionCard(
                      title: 'Данни',
                      children: const [
                        ListTile(
                          leading: Icon(Icons.storage_outlined),
                          title: Text('Действие'),
                          subtitle: Text(''),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SettingsSectionCard(
                      title: 'За приложението',
                      children: const [
                        ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('Версия'),
                          subtitle: Text(''),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
