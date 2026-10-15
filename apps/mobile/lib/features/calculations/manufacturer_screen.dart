import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../application/manufacturer_repository.dart';
import 'protection_screen.dart';

class ManufacturerScreen extends ConsumerWidget {
  const ManufacturerScreen({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Manufacturer catalogs')),
    body: ref
        .watch(projectManufacturerProvider(projectId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) =>
                  Center(child: Text('Unable to load catalogs: $error')),
          data: (snapshot) {
            if (snapshot.protection.recalculation.project == null)
              return const Center(child: Text('Project is unavailable.'));
            final repo = ref.read(manufacturerRepositoryProvider);
            return ManufacturerWorkspace(
              snapshot: snapshot,
              nextId: ref.read(idGeneratorProvider).next,
              onImport: repo.importCatalog,
              onArchive: repo.archiveCatalog,
              onPolicy: (policy) => repo.savePolicy(projectId, policy),
              onSelect:
                  (circuit, product, fingerprint) => repo.selectProduct(
                    projectId: projectId,
                    circuitId: circuit,
                    productId: product,
                    expectedRequirementFingerprint: fingerprint,
                  ),
              onClear: (id) => repo.clearSelection(projectId, id),
              onRequirements:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProtectionScreen(projectId: projectId),
                    ),
                  ),
            );
          },
        ),
  );
}

class ManufacturerWorkspace extends StatefulWidget {
  const ManufacturerWorkspace({
    super.key,
    required this.snapshot,
    required this.nextId,
    required this.onImport,
    required this.onArchive,
    required this.onPolicy,
    required this.onSelect,
    required this.onClear,
    required this.onRequirements,
  });
  final ProjectManufacturerSnapshot snapshot;
  final String Function() nextId;
  final Future<void> Function(ManufacturerCatalog) onImport;
  final Future<void> Function(String) onArchive, onClear;
  final Future<void> Function(ProjectManufacturerPolicy) onPolicy;
  final Future<void> Function(String, String, String) onSelect;
  final VoidCallback onRequirements;
  @override
  State<ManufacturerWorkspace> createState() => _ManufacturerWorkspaceState();
}

class _ManufacturerWorkspaceState extends State<ManufacturerWorkspace> {
  bool busy = false, rejected = false;
  String? error;
  Future<void> work(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
      if (mounted) setState(() => error = null);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    return DefaultTabController(
      length: 3,
      initialIndex: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Catalogs'),
              Tab(text: 'Policy'),
              Tab(text: 'Selection'),
            ],
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  key: const ValueKey('manufacturer-catalogs'),
                  padding: const EdgeInsets.all(12),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => ManufacturerCatalogEditor(
                                        id: widget.nextId(),
                                        nextId: widget.nextId,
                                        onSave: widget.onImport,
                                      ),
                                ),
                              ),
                          child: const Text('New catalog version'),
                        ),
                        OutlinedButton(
                          onPressed:
                              () => showDialog<void>(
                                context: context,
                                builder:
                                    (_) => ManufacturerDataDialog(
                                      policy: false,
                                      onCatalog: widget.onImport,
                                      onPolicy: widget.onPolicy,
                                    ),
                              ),
                          child: const Text('Import catalog JSON'),
                        ),
                      ],
                    ),
                    if (snapshot.catalogs.isEmpty)
                      const Text(
                        'Add variants from their datasheets or import a sourced catalog. No vendor specifications are invented.',
                      ),
                    for (final catalog in snapshot.catalogs)
                      Card(
                        child: ExpansionTile(
                          title: Text(
                            '${catalog.manufacturer} · ${catalog.catalogVersion}',
                          ),
                          subtitle: Text(
                            '${catalog.region ?? "Region not declared"} · ${catalog.products.length} variants',
                          ),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          childrenPadding: const EdgeInsets.all(12),
                          children: [
                            SelectableText(catalog.sourceReference ?? ''),
                            for (final p in catalog.products)
                              ListTile(
                                title: Text('${p.sku} · ${p.displayName}'),
                                subtitle: Text(
                                  '${p.series} · ${p.functionalRole.name} · ${p.lifecycleStatus.name}\n${p.ratedCurrentA ?? "?"} A · ${p.ratedVoltageV ?? "?"} V · ${p.breakingCapacityKa ?? "?"} kA',
                                ),
                              ),
                            TextButton(
                              onPressed:
                                  busy
                                      ? null
                                      : () => work(
                                        () => widget.onArchive(catalog.id!),
                                      ),
                              child: const Text('Archive catalog version'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                ListView(
                  key: const ValueKey('manufacturer-policy'),
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text(
                      'Manufacturer and series preferences rank compatible products. The allowlist and required region restrict selection.',
                    ),
                    Text(
                      'Preferred: ${snapshot.policy.preferredManufacturers.join(", ")}',
                    ),
                    Text(
                      'Allowed: ${snapshot.policy.allowedManufacturers.isEmpty ? "Any manufacturer" : snapshot.policy.allowedManufacturers.join(", ")}',
                    ),
                    Text(
                      'Required region: ${snapshot.policy.requiredRegion ?? "Not restricted"}',
                    ),
                    Text(
                      'Preferred series: ${snapshot.policy.preferredSeriesByRole.entries.map((e) => "${e.key.name}: ${e.value}").join(", ")}',
                    ),
                    FilledButton(
                      onPressed:
                          () => showDialog<void>(
                            context: context,
                            builder:
                                (_) => ManufacturerPolicyDialog(
                                  initial: snapshot.policy,
                                  onSave: widget.onPolicy,
                                ),
                          ),
                      child: const Text('Edit manufacturer policy'),
                    ),
                  ],
                ),
                ListView(
                  key: const ValueKey('manufacturer-selection'),
                  padding: const EdgeInsets.all(12),
                  children: [
                    TextButton(
                      onPressed: widget.onRequirements,
                      child: const Text('Protection requirements'),
                    ),
                    SwitchListTile(
                      title: const Text('Show rejected products'),
                      value: rejected,
                      onChanged: (value) => setState(() => rejected = value),
                    ),
                    if (snapshot.protection.circuits.isEmpty)
                      const Text(
                        'Create a circuit and protection requirement first.',
                      ),
                    for (final c in snapshot.protection.circuits)
                      Card(
                        child: ExpansionTile(
                          key: ValueKey(c.circuitId),
                          title: Text(c.label),
                          subtitle: Text(snapshot.selectionStatus(c)),
                          childrenPadding: const EdgeInsets.all(12),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (snapshot.selections[c.circuitId]
                                case final ManufacturerSelection selected) ...[
                              const Text(
                                'Design-time selection snapshot',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${(selected.snapshot["product"] as Map)["manufacturer"]} · ${(selected.snapshot["product"] as Map)["sku"]}',
                              ),
                              Text(
                                'Catalog version: ${selected.snapshot["catalogVersion"]} · ${selected.snapshot["region"] ?? "Region not declared"}',
                              ),
                              SelectableText(
                                selected.snapshot['sourceReference'] as String,
                              ),
                              TextButton(
                                onPressed:
                                    busy
                                        ? null
                                        : () => work(
                                          () => widget.onClear(c.circuitId),
                                        ),
                                child: const Text('Clear selection'),
                              ),
                            ],
                            if (c.stale)
                              const Text(
                                'Protection inputs changed. Recalculate protection before selecting a product.',
                              ),
                            for (final candidate in snapshot.candidates(
                              c,
                              includeRejected: rejected,
                            ))
                              ListTile(
                                title: Text(
                                  '${candidate.product.manufacturer} · ${candidate.product.sku}',
                                ),
                                subtitle: Text(
                                  '${candidate.product.series} · version ${candidate.catalog.catalogVersion}\n${candidate.match.compatible ? "Compatible with declared requirement" : candidate.match.issues.join(" ")}',
                                ),
                                trailing:
                                    candidate.match.compatible
                                        ? TextButton(
                                          onPressed:
                                              busy
                                                  ? null
                                                  : () => work(
                                                    () => widget.onSelect(
                                                      c.circuitId,
                                                      candidate.product.id,
                                                      c.fingerprint,
                                                    ),
                                                  ),
                                          child: const Text('Select'),
                                        )
                                        : const Icon(Icons.block),
                              ),
                            if (snapshot.candidates(c).isEmpty)
                              const Text(
                                'No compatible products with complete required technical data.',
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManufacturerCatalogEditor extends StatefulWidget {
  const ManufacturerCatalogEditor({
    super.key,
    required this.id,
    required this.nextId,
    required this.onSave,
  });
  final String id;
  final String Function() nextId;
  final Future<void> Function(ManufacturerCatalog) onSave;
  @override
  State<ManufacturerCatalogEditor> createState() =>
      _ManufacturerCatalogEditorState();
}

class _ManufacturerCatalogEditorState extends State<ManufacturerCatalogEditor> {
  final brand = TextEditingController(),
      version = TextEditingController(),
      region = TextEditingController(),
      source = TextEditingController();
  final products = <ManufacturerProductVariant>[];
  String? error;
  bool busy = false;
  @override
  void dispose() {
    brand.dispose();
    version.dispose();
    region.dispose();
    source.dispose();
    super.dispose();
  }

  Future<void> add() async {
    if (brand.text.trim().isEmpty) {
      setState(() => error = 'Enter manufacturer first.');
      return;
    }
    final product = await showDialog<ManufacturerProductVariant>(
      context: context,
      builder:
          (_) => ManufacturerProductDialog(
            id: widget.nextId(),
            manufacturer: brand.text.trim(),
          ),
    );
    if (product != null && mounted) setState(() => products.add(product));
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      if ([
            brand.text,
            version.text,
            source.text,
          ].any((v) => v.trim().isEmpty) ||
          products.isEmpty)
        throw ArgumentError(
          'Manufacturer, version, source and at least one product are required.',
        );
      final catalog = ManufacturerCatalog(
        id: widget.id,
        manufacturer: brand.text.trim(),
        catalogVersion: version.text.trim(),
        region: region.text.trim().isEmpty ? null : region.text.trim(),
        sourceReference: source.text.trim(),
        products: [
          for (final p in products)
            ManufacturerCatalogCodec.decodeProduct({
              ...ManufacturerCatalogCodec.product(p),
              'manufacturer': brand.text.trim(),
            }),
        ],
      );
      await widget.onSave(catalog);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New catalog version')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: brand,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'Manufacturer'),
        ),
        TextField(
          controller: version,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'Catalog version'),
        ),
        TextField(
          controller: region,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'Region'),
        ),
        TextField(
          controller: source,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Datasheet / catalog source',
          ),
        ),
        for (final p in products)
          ListTile(
            title: Text('${p.sku} · ${p.series}'),
            trailing: IconButton(
              tooltip: 'Remove draft product',
              onPressed: busy ? null : () => setState(() => products.remove(p)),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        OutlinedButton(
          onPressed: busy ? null : add,
          child: const Text('Add product variant'),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(
          onPressed: busy ? null : save,
          child: const Text('Save catalog version'),
        ),
      ],
    ),
  );
}

class ManufacturerProductDialog extends StatefulWidget {
  const ManufacturerProductDialog({
    super.key,
    required this.id,
    required this.manufacturer,
  });
  final String id, manufacturer;
  @override
  State<ManufacturerProductDialog> createState() =>
      _ManufacturerProductDialogState();
}

class _ManufacturerProductDialogState extends State<ManufacturerProductDialog> {
  final fields = <String, TextEditingController>{};
  FunctionalDeviceRole role = FunctionalDeviceRole.mcb;
  ProductCurrentKind? kind;
  ProductLifecycleStatus lifecycle = ProductLifecycleStatus.active;
  String? error;
  @override
  void dispose() {
    for (final f in fields.values) f.dispose();
    super.dispose();
  }

  String text(String field) => fields[field]?.text.trim() ?? '';
  double? number(String field) {
    if (text(field).isEmpty) return null;
    final n = double.tryParse(text(field));
    if (n == null || !n.isFinite || n <= 0)
      throw ArgumentError('Invalid $field.');
    return n;
  }

  int? integer(String field) {
    if (text(field).isEmpty) return null;
    final n = int.tryParse(text(field));
    if (n == null || n <= 0) throw ArgumentError('Invalid $field.');
    return n;
  }

  void save() {
    try {
      final product = ManufacturerProductVariant(
        id: widget.id,
        manufacturer: widget.manufacturer,
        series: text('Series'),
        sku: text('SKU'),
        displayName: text('Display name'),
        functionalRole: role,
        currentKind: kind,
        lifecycleStatus: lifecycle,
        ratedCurrentA: number('Rated current A'),
        ratedVoltageV: number('Rated voltage V'),
        breakingCapacityKa: number('Breaking capacity kA'),
        poles: integer('Poles'),
        tripCurve:
            text('Trip characteristic').isEmpty
                ? null
                : text('Trip characteristic'),
        residualCurrentMa: number('Residual trip mA'),
        residualCurrentType:
            text('Residual type').isEmpty ? null : text('Residual type'),
        moduleWidthUnits: integer('Module width'),
        widthMm: number('Width mm'),
        heightMm: number('Height mm'),
        depthMm: number('Depth mm'),
        mountingType:
            text('Mounting type').isEmpty ? null : text('Mounting type'),
        metadata:
            text('Product datasheet source').isEmpty
                ? {}
                : {'sourceReference': text('Product datasheet source')},
      );
      final issues = ManufacturerProductMatcher.validateProduct(product);
      if (issues.isNotEmpty) throw ArgumentError(issues.join(' '));
      Navigator.pop(context, product);
    } catch (failure) {
      setState(() => error = '$failure');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Product variant'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<FunctionalDeviceRole>(
              initialValue: role,
              isExpanded: true,
              items:
                  FunctionalDeviceRole.values
                      .map(
                        (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                      )
                      .toList(),
              onChanged: (v) => setState(() => role = v!),
            ),
            DropdownButtonFormField<ProductCurrentKind>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'AC/DC declaration'),
              items:
                  ProductCurrentKind.values
                      .map(
                        (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                      )
                      .toList(),
              onChanged: (v) => setState(() => kind = v),
            ),
            DropdownButtonFormField<ProductLifecycleStatus>(
              initialValue: lifecycle,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Lifecycle'),
              items:
                  ProductLifecycleStatus.values
                      .map(
                        (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                      )
                      .toList(),
              onChanged: (v) => setState(() => lifecycle = v!),
            ),
            for (final field in [
              'Series',
              'SKU',
              'Display name',
              'Rated current A',
              'Rated voltage V',
              'Breaking capacity kA',
              'Poles',
              'Trip characteristic',
              'Residual trip mA',
              'Residual type',
              'Module width',
              'Width mm',
              'Height mm',
              'Depth mm',
              'Mounting type',
              'Product datasheet source',
            ])
              TextField(
                controller: fields.putIfAbsent(
                  field,
                  () => TextEditingController(),
                ),
                decoration: InputDecoration(labelText: field),
              ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Add variant')),
    ],
  );
}

class ManufacturerPolicyDialog extends StatefulWidget {
  const ManufacturerPolicyDialog({
    super.key,
    required this.initial,
    required this.onSave,
  });
  final ProjectManufacturerPolicy initial;
  final Future<void> Function(ProjectManufacturerPolicy) onSave;
  @override
  State<ManufacturerPolicyDialog> createState() =>
      _ManufacturerPolicyDialogState();
}

class _ManufacturerPolicyDialogState extends State<ManufacturerPolicyDialog> {
  late final TextEditingController preferred, allowed, region;
  late final Map<FunctionalDeviceRole, TextEditingController> series;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    preferred = TextEditingController(
      text: widget.initial.preferredManufacturers.join(', '),
    );
    allowed = TextEditingController(
      text: widget.initial.allowedManufacturers.join(', '),
    );
    region = TextEditingController(text: widget.initial.requiredRegion ?? '');
    series = {
      for (final role in [FunctionalDeviceRole.mcb, FunctionalDeviceRole.rcbo])
        role: TextEditingController(
          text: widget.initial.preferredSeriesByRole[role] ?? '',
        ),
    };
  }

  @override
  void dispose() {
    preferred.dispose();
    allowed.dispose();
    region.dispose();
    for (final c in series.values) c.dispose();
    super.dispose();
  }

  List<String> list(TextEditingController c) =>
      c.text
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
  Future<void> save() async {
    setState(() => busy = true);
    try {
      final policy = ProjectManufacturerPolicy(
        preferredManufacturers: list(preferred),
        allowedManufacturers: list(allowed),
        requiredRegion: region.text.trim().isEmpty ? null : region.text.trim(),
        preferredSeriesByRole: {
          ...widget.initial.preferredSeriesByRole,
          for (final e in series.entries) e.key: e.value.text.trim(),
        }..removeWhere((_, v) => v.isEmpty),
      );
      await widget.onSave(policy);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Project manufacturer policy'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: preferred,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Preferred manufacturers, ranked',
            ),
          ),
          TextField(
            controller: allowed,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Allowed manufacturers',
            ),
          ),
          TextField(
            controller: region,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Required region'),
          ),
          for (final e in series.entries)
            TextField(
              controller: e.value,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: 'Preferred ${e.key.name} series',
              ),
            ),
          const Text(
            'Manufacturer lists are comma-separated; empty allowlist permits any compatible brand.',
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Save policy'),
      ),
    ],
  );
}

class ManufacturerDataDialog extends StatefulWidget {
  const ManufacturerDataDialog({
    super.key,
    required this.policy,
    required this.onCatalog,
    required this.onPolicy,
  });
  final bool policy;
  final Future<void> Function(ManufacturerCatalog) onCatalog;
  final Future<void> Function(ProjectManufacturerPolicy) onPolicy;
  @override
  State<ManufacturerDataDialog> createState() => _ManufacturerDataDialogState();
}

class _ManufacturerDataDialogState extends State<ManufacturerDataDialog> {
  final data = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final map = jsonDecode(data.text) as Map<String, dynamic>;
      if (widget.policy)
        await widget.onPolicy(ManufacturerCatalogCodec.decodePolicy(map));
      else
        await widget.onCatalog(ManufacturerCatalogCodec.decodeCatalog(map));
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Import catalog JSON'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Catalog fields: id, manufacturer, catalogVersion, region, sourceReference, products. Each product declares its identity, role, lifecycle and technical characteristics.',
            ),
            TextField(
              controller: data,
              enabled: !busy,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(labelText: 'Catalog JSON'),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Import catalog'),
      ),
    ],
  );
}
