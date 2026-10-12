import 'package:flutter/material.dart';

import '../../domain/models.dart';

class RoomCreateScreen extends StatefulWidget {
  const RoomCreateScreen({super.key, required this.project});

  final ProjectDraft project;

  @override
  State<RoomCreateScreen> createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends State<RoomCreateScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final widthController = TextEditingController(text: '4000');
  final depthController = TextEditingController(text: '3000');
  final structuralController = TextEditingController();
  final ceilingController = TextEditingController();
  RoomType roomType = RoomType.livingRoom;

  int? positiveMm(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? optionalMm(String value) =>
      value.trim().isEmpty ? null : positiveMm(value);

  @override
  void dispose() {
    nameController.dispose();
    widthController.dispose();
    depthController.dispose();
    structuralController.dispose();
    ceilingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create room')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Room name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Room name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RoomType>(
              initialValue: roomType,
              decoration: const InputDecoration(labelText: 'Room type'),
              items: RoomType.values
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                roomType = value ?? RoomType.custom;
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Width', suffixText: 'mm'),
                    validator: (value) => positiveMm(value ?? '') == null
                        ? 'Invalid width'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: depthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Depth', suffixText: 'mm'),
                    validator: (value) => positiveMm(value ?? '') == null
                        ? 'Invalid depth'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: structuralController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Structural height override',
                hintText: '${widget.project.defaultStructuralHeightMm}',
                suffixText: 'mm',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ceilingController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Finished ceiling override',
                hintText: '${widget.project.defaultFinishedCeilingHeightMm}',
                suffixText: 'mm',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final structural = optionalMm(structuralController.text);
                final ceiling = optionalMm(ceilingController.text);
                if (structuralController.text.trim().isNotEmpty && structural == null) return;
                if (ceilingController.text.trim().isNotEmpty && ceiling == null) return;
                Navigator.of(context).pop(
                  RoomDraft(
                    id: newLocalId('room'),
                    name: nameController.text.trim(),
                    type: roomType,
                    widthMm: positiveMm(widthController.text)!,
                    depthMm: positiveMm(depthController.text)!,
                    structuralHeightMmOverride: structural,
                    finishedCeilingHeightMmOverride: ceiling,
                  ),
                );
              },
              child: const Text('Create room'),
            ),
          ],
        ),
      ),
    );
  }
}
