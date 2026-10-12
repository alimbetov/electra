import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.roomName});

  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(roomName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('Report generation deferred'),
              subtitle: Text(
                'Report forms are reserved now; authoritative calculations and final PDF generation will be connected later.',
              ),
            ),
          ),
          const ListTile(
            title: Text('Project / room summary'),
            subtitle: Text('Planned'),
          ),
          const ListTile(
            title: Text('Routes and materials'),
            subtitle: Text('Planned'),
          ),
          const ListTile(title: Text('Labels / QR'), subtitle: Text('Planned')),
          const ListTile(
            title: Text('Published package'),
            subtitle: Text('Planned'),
          ),
        ],
      ),
    );
  }
}
