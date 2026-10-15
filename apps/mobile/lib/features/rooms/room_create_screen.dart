import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/project_models.dart';

import 'package:engineering_core/engineering_core.dart';

class RoomCreateScreen extends ConsumerStatefulWidget {
  const RoomCreateScreen({
    super.key,
    required this.projectId,
    required this.floorId,
  });

  final String projectId;
  final String floorId;

  @override
  ConsumerState<RoomCreateScreen> createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends ConsumerState<RoomCreateScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final widthController = TextEditingController(text: '4000');
  final depthController = TextEditingController(text: '3000');
  final structuralController = TextEditingController();
  final ceilingController = TextEditingController();
  RoomType roomType = RoomType.livingRoom;
  RoomCategory roomCategory = RoomCategory.residential;
  bool saving = false;

  int? positiveMm(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? optionalMm(String value) =>
      value.trim().isEmpty ? null : positiveMm(value);

  Future<void> save() async {
    if (!formKey.currentState!.validate() || saving) return;
    final structural = optionalMm(structuralController.text);
    final ceiling = optionalMm(ceilingController.text);
    if (structuralController.text.trim().isNotEmpty && structural == null)
      return;
    if (ceilingController.text.trim().isNotEmpty && ceiling == null) return;

    setState(() => saving = true);
    try {
      await ref
          .read(projectHierarchyServiceProvider)
          .createRoom(
            floorId: widget.floorId,
            draft: RoomFormDraft(
              name: nameController.text,
              type: roomType,
              category: roomCategory,
              widthMm: positiveMm(widthController.text)!,
              depthMm: positiveMm(depthController.text)!,
              structuralHeightMmOverride: structural,
              finishedCeilingHeightMmOverride: ceiling,
            ),
          );
      if (!mounted) return;
      context.go('/projects/${widget.projectId}/floors/${widget.floorId}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create room: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Room name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Room name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoomCategory>(
                  initialValue: roomCategory,
                  decoration: const InputDecoration(labelText: 'Room category'),
                  items: RoomCategory.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    roomCategory = value ?? RoomCategory.other;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoomType>(
                  initialValue: roomType,
                  decoration: const InputDecoration(labelText: 'Room type'),
                  items: RoomType.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
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
                        decoration: const InputDecoration(
                          labelText: 'Width',
                          suffixText: 'mm',
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Depth',
                          suffixText: 'mm',
                        ),
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
                  decoration: const InputDecoration(
                    labelText: 'Structural height override',
                    suffixText: 'mm',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ceilingController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Finished ceiling override',
                    suffixText: 'mm',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Saving…' : 'Create room'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
