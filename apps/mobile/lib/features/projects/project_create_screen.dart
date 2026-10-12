import 'package:flutter/material.dart';

import '../../domain/models.dart';

class ProjectCreateScreen extends StatefulWidget {
  const ProjectCreateScreen({super.key});

  @override
  State<ProjectCreateScreen> createState() => _ProjectCreateScreenState();
}

class _ProjectCreateScreenState extends State<ProjectCreateScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final referenceController = TextEditingController();
  final structuralController = TextEditingController(text: '2800');
  final ceilingController = TextEditingController(text: '2700');
  MeasurementSystem measurementSystem = MeasurementSystem.metric;

  @override
  void dispose() {
    nameController.dispose();
    referenceController.dispose();
    structuralController.dispose();
    ceilingController.dispose();
    super.dispose();
  }

  int? parsePositiveMm(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create project')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Project name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Project name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: referenceController,
              decoration: const InputDecoration(labelText: 'Reference / code'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MeasurementSystem>(
              initialValue: measurementSystem,
              decoration: const InputDecoration(labelText: 'Measurement system'),
              items: MeasurementSystem.values
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                measurementSystem = value ?? MeasurementSystem.metric;
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: structuralController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default structural height',
                suffixText: 'mm canonical',
              ),
              validator: (value) => parsePositiveMm(value ?? '') == null
                  ? 'Enter a positive millimetre value'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ceilingController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default finished ceiling height',
                suffixText: 'mm canonical',
              ),
              validator: (value) => parsePositiveMm(value ?? '') == null
                  ? 'Enter a positive millimetre value'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(context).pop(
                  ProjectDraft(
                    id: newLocalId('project'),
                    name: nameController.text.trim(),
                    reference: referenceController.text.trim(),
                    measurementSystem: measurementSystem,
                    defaultStructuralHeightMm:
                        parsePositiveMm(structuralController.text)!,
                    defaultFinishedCeilingHeightMm:
                        parsePositiveMm(ceilingController.text)!,
                  ),
                );
              },
              child: const Text('Create project'),
            ),
          ],
        ),
      ),
    );
  }
}
