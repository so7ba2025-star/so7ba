import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
      ),
      body: Center(
        child: Text('Dashboard Page - Coming Soon'),
      ),
    );
  }
}

// Combined dashboard and profile page
class DashboardProfilePage extends StatelessWidget {
  const DashboardProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard & Profile'),
      ),
      body: Center(
        child: Text('Dashboard & Profile - Coming Soon'),
      ),
    );
  }
}
