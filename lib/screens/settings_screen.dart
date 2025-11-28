import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            title: Text('الثيم: فاتح'),
            subtitle: Text('حسب المتطلبات الحالية'),
            leading: Icon(Icons.light_mode),
          ),
          ListTile(
            title: Text('اللغة: العربية'),
            subtitle: Text('اتجاه RTL وأرقام لاتينية'),
            leading: Icon(Icons.language),
          ),
          ListTile(
            title: Text('الدوران'),
            subtitle: Text('عمودي وأفقي'),
            leading: Icon(Icons.screen_rotation),
          ),
        ],
      ),
    );
  }
}
