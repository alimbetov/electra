import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/project_models.dart';

class FloorCreateScreen extends ConsumerStatefulWidget {
  const FloorCreateScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<FloorCreateScreen> createState() => _FloorCreateScreenState();
}

class _FloorCreateScreenState extends ConsumerState<FloorCreateScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: 'Floor 01');
  final codeController = TextEditingController(text: 'F01');
  final orderController = TextEditingController(text: '1');
  final structuralController = TextEditingController();
  final ceilingController = TextEditingController();
  bool saving = false;

  int? positiveInt(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? optionalPositiveInt(String value) {
    if (value.trim().isEmpty) return null;
    return positiveInt(value);
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || saving) return;
    setState(() => saving = true);
    try {
      final floor = await ref
          .read(projectHierarchyServiceProvider)
          .createFloor(
            projectId: widget.projectId,
            draft: FloorFormDraft(
              name: nameController.text,
              code: codeController.text,
              sortOrder: positiveInt(orderController.text)!,
              defaultStructuralHeightMm: optionalPositiveInt(
                structuralController.text,
              ),
              defaultFinishedCeilingHeightMm: optionalPositiveInt(
                ceilingController.text,
              ),
            ),
          );
      if (!mounted) return;
      context.go('/projects/${widget.projectId}/floors/${floor.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create floor: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    orderController.dispose();
    structuralController.dispose();
    ceilingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create floor')),
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
                  decoration: const InputDecoration(labelText: 'Floor name'),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Floor name is required'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Floor code'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort order'),
                  validator:
                      (value) =>
                          positiveInt(value ?? '') == null
                              ? 'Enter a positive order'
                              : null,
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
                  label: Text(saving ? 'Saving…' : 'Create floor'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
