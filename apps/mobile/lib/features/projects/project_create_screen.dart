import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';

class ProjectCreateScreen extends ConsumerStatefulWidget {
  const ProjectCreateScreen({super.key});

  @override
  ConsumerState<ProjectCreateScreen> createState() =>
      _ProjectCreateScreenState();
}

class _ProjectCreateScreenState extends ConsumerState<ProjectCreateScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final referenceController = TextEditingController();
  final structuralController = TextEditingController(text: '2800');
  final ceilingController = TextEditingController(text: '2700');
  MeasurementSystem measurementSystem = MeasurementSystem.metric;
  bool saving = false;

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

  Future<void> save() async {
    if (!formKey.currentState!.validate() || saving) return;
    setState(() => saving = true);
    try {
      final project = await ref
          .read(projectHierarchyServiceProvider)
          .createProject(
            ProjectFormDraft(
              name: nameController.text,
              reference: referenceController.text,
              measurementSystem: measurementSystem,
              defaultStructuralHeightMm:
                  parsePositiveMm(structuralController.text)!,
              defaultFinishedCeilingHeightMm:
                  parsePositiveMm(ceilingController.text)!,
            ),
          );
      if (!mounted) return;
      context.go('/projects/${project.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create project: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create project')),
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
                  decoration: const InputDecoration(labelText: 'Project name'),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Project name is required'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference / code',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MeasurementSystem>(
                  initialValue: measurementSystem,
                  decoration: const InputDecoration(
                    labelText: 'Measurement system',
                  ),
                  items:
                      MeasurementSystem.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                  onChanged:
                      saving
                          ? null
                          : (value) => setState(() {
                            measurementSystem =
                                value ?? MeasurementSystem.metric;
                          }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: structuralController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Default structural height',
                    suffixText: 'mm',
                  ),
                  validator:
                      (value) =>
                          parsePositiveMm(value ?? '') == null
                              ? 'Enter a positive millimetre value'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ceilingController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Default finished ceiling height',
                    suffixText: 'mm',
                  ),
                  validator:
                      (value) =>
                          parsePositiveMm(value ?? '') == null
                              ? 'Enter a positive millimetre value'
                              : null,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon:
                      saving
                          ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Saving…' : 'Create project'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
