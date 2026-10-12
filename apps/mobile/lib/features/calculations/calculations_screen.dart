import 'package:flutter/material.dart';

class CalculationsScreen extends StatelessWidget {
  const CalculationsScreen({super.key, required this.roomName});

  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(roomName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.calculate_outlined),
              title: Text('Calculation engine deferred'),
              subtitle: Text(
                'This screen reserves the product workflow. Route lengths, cable sizing, protection, hydraulic and HVAC calculations will be implemented after geometry/routing contracts are validated.',
              ),
            ),
          ),
          const ListTile(
            title: Text('Route lengths'),
            subtitle: Text('Not calculated yet'),
          ),
          const ListTile(
            title: Text('Electrical sizing'),
            subtitle: Text('Not calculated yet'),
          ),
          const ListTile(
            title: Text('Validation / clashes'),
            subtitle: Text('Not calculated yet'),
          ),
        ],
      ),
    );
  }
}
