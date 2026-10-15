import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../application/engineering_reference_repository.dart';

class EngineeringReferenceScreen extends ConsumerWidget {
  const EngineeringReferenceScreen({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Engineering reference catalogs')),
    body: ref
        .watch(projectEngineeringReferencesProvider(projectId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Unable to load references: $e')),
          data: (s) => EngineeringReferenceWorkspace(
            snapshot: s,
            onImport: (c) => ref
                .read(engineeringReferenceRepositoryProvider)
                .importCatalog(projectId, c),
            onBind: (c, r, p) => ref
                .read(engineeringReferenceRepositoryProvider)
                .bind(projectId, c, r, p),
            onUnbind: (c) => ref
                .read(engineeringReferenceRepositoryProvider)
                .unbind(projectId, c),
          ),
        ),
  );
}

class EngineeringReferenceWorkspace extends StatefulWidget {
  const EngineeringReferenceWorkspace({
    super.key,
    required this.snapshot,
    required this.onImport,
    required this.onBind,
    required this.onUnbind,
  });
  final ProjectEngineeringReferences snapshot;
  final Future<void> Function(EngineeringReferenceCatalog) onImport;
  final Future<void> Function(String, String, String) onBind;
  final Future<void> Function(String) onUnbind;
  @override
  State<EngineeringReferenceWorkspace> createState() =>
      _EngineeringReferenceWorkspaceState();
}

class _EngineeringReferenceWorkspaceState
    extends State<EngineeringReferenceWorkspace> {
  ReferenceDiscipline? discipline;
  String? error;
  bool busy = false;
  Future<void> work(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Product-neutral definitions. Choose an exact edition, then instantiate ports on an existing placed device.',
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      ReferenceCatalogImportDialog(onImport: widget.onImport),
                ),
          child: const Text('Import catalog JSON'),
        ),
        DropdownButtonFormField<ReferenceDiscipline>(
          key: ValueKey(discipline),
          initialValue: discipline,
          decoration: const InputDecoration(labelText: 'Discipline'),
          isExpanded: true,
          items: [
            for (final d in ReferenceDiscipline.values)
              DropdownMenuItem(value: d, child: Text(d.name.toUpperCase())),
          ],
          onChanged: (d) => setState(() => discipline = d),
        ),
        TextButton(
          onPressed: () => setState(() => discipline = null),
          child: const Text('Show all disciplines'),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final c in s.catalogs)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.code} / ${c.version}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Source: ${c.source}'),
                  if (!c.vocabulary.isEmpty)
                    ReferenceVocabularyView(catalog: c),

                  for (final p in c.profiles.where(
                    (p) => discipline == null || p.discipline == discipline,
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.label),
                      subtitle: Text(
                        '${p.discipline.name.toUpperCase()} · ${p.engineeringClass.name}\n${p.portTemplates.length} ports · ${p.capabilities.map((v) => v.name).join(', ')}${p.deprecated ? '\nDeprecated — preserved for existing bindings' : ''}',
                      ),
                      onTap: busy || p.deprecated
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (_) => ReferenceProfileBindDialog(
                                snapshot: s,
                                catalog: c,
                                profile: p,
                                onBind: widget.onBind,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        const Text('Project profile bindings'),
        for (final b in s.bindings)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.systems.components.where((c) => c.id == b.componentId).firstOrNull?.name ?? b.componentId} · ${b.profile.label}',
                  ),
                  Text(
                    '${b.catalogId} / ${b.catalogVersion} · ${b.portIds.length} instantiated ports',
                  ),
                  const Text(
                    'A newer catalog does not replace this binding. Resolve links and retire its ports before adopting another edition.',
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => work(() => widget.onUnbind(b.componentId)),
                    child: const Text('Release binding'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ReferenceCatalogImportDialog extends StatefulWidget {
  const ReferenceCatalogImportDialog({super.key, required this.onImport});
  final Future<void> Function(EngineeringReferenceCatalog) onImport;
  @override
  State<ReferenceCatalogImportDialog> createState() =>
      _ReferenceCatalogImportDialogState();
}

class _ReferenceCatalogImportDialogState
    extends State<ReferenceCatalogImportDialog> {
  final input = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final catalog = EngineeringReferenceCatalog.fromMap(
        jsonDecode(input.text) as Map<String, dynamic>,
      );
      if (catalog.validate().isNotEmpty)
        throw ArgumentError(catalog.validate().join(' '));
      await widget.onImport(catalog);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Import reference edition'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: input,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(labelText: 'Catalog JSON'),
            ),
            if (error != null) Text(error!),
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
        child: Text(busy ? 'Importing…' : 'Import edition'),
      ),
    ],
  );
}

class ReferenceProfileBindDialog extends StatefulWidget {
  const ReferenceProfileBindDialog({
    super.key,
    required this.snapshot,
    required this.catalog,
    required this.profile,
    required this.onBind,
  });
  final ProjectEngineeringReferences snapshot;
  final EngineeringReferenceCatalog catalog;
  final ComponentEngineeringProfile profile;
  final Future<void> Function(String, String, String) onBind;
  @override
  State<ReferenceProfileBindDialog> createState() =>
      _ReferenceProfileBindDialogState();
}

class _ReferenceProfileBindDialogState
    extends State<ReferenceProfileBindDialog> {
  String? component, error;
  bool busy = false;
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onBind(component!, widget.catalog.id, widget.profile.code);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.profile.label),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.catalog.code} / ${widget.catalog.version}\n${widget.catalog.source}',
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Placed device'),
              items: [
                for (final c in widget.snapshot.systems.components)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.roomName} · ${c.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: busy ? null : (v) => setState(() => component = v),
            ),
            const Text(
              'Assign the device to a matching discipline system first. Existing authored ports require explicit resolution.',
            ),
            if (error != null) Text(error!),
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
        onPressed: busy || component == null ? null : save,
        child: const Text('Bind and create ports'),
      ),
    ],
  );
}

class ReferenceVocabularyView extends StatelessWidget {
  const ReferenceVocabularyView({super.key, required this.catalog});
  final EngineeringReferenceCatalog catalog;
  @override
  Widget build(BuildContext context) {
    final v = catalog.vocabulary;
    Widget entry(
      String label,
      String details, {
      bool deprecated = false,
    }) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        '$details${deprecated ? '\nDeprecated; retained for existing projects' : ''}',
      ),
    );
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Interfaces and compatibility'),
      subtitle: Text(
        '${v.interfaces.length} interfaces · ${v.compatibility.length} connection definitions',
      ),
      children: [
        for (final i in v.interfaces)
          entry(
            i.identity.label,
            '${i.kind.name} · ${i.direction.name} · capacity ${i.capacity}\nConnector: ${v.connectors.singleWhere((c) => c.code == i.connectorCode).identity.label}\nProtocol: ${v.protocols.singleWhere((p) => p.code == i.protocolCode).identity.label}\nMedium: ${v.media.singleWhere((m) => m.code == i.mediaCode).identity.label}${i.voltageCode == null ? '\nVoltage: needs input' : '\nVoltage: ${v.voltages.singleWhere((p) => p.code == i.voltageCode).domain.minimumV}–${v.voltages.singleWhere((p) => p.code == i.voltageCode).domain.maximumV} V'}',
            deprecated: i.identity.deprecated,
          ),
        for (final rule in v.compatibility)
          entry(
            rule.identity.label,
            '${v.interface(rule.fromInterfaceCode).identity.label} → ${v.interface(rule.toInterfaceCode).identity.label}\n${rule.familyCodes.join(', ')} · ${rule.layer.name} · ${rule.flow.name}',
            deprecated: rule.identity.deprecated,
          ),
        ExpansionTile(
          title: const Text('Reference definitions'),
          children: [
            for (final c in v.connectors)
              entry(
                c.identity.label,
                'Connector · ${c.connectorClass.name}${c.contactCount == null ? '' : ' · ${c.contactCount} contacts'}',
                deprecated: c.identity.deprecated,
              ),
            for (final p in v.protocols)
              entry(
                p.identity.label,
                'Protocol · ${p.portKinds.map((k) => k.name).join(', ')}${p.dataRateMbps == null ? '' : ' · ${p.dataRateMbps} Mbps'}',
                deprecated: p.identity.deprecated,
              ),
            for (final m in v.media)
              entry(
                m.identity.label,
                'Medium · ${m.kind.name} · ${m.connectionMedium.name}',
                deprecated: m.identity.deprecated,
              ),
            for (final d in v.voltages)
              entry(
                d.identity.label,
                'Voltage · ${d.domain.currentKind.name.toUpperCase()} · ${d.domain.minimumV}–${d.domain.maximumV} V',
                deprecated: d.identity.deprecated,
              ),
          ],
        ),
      ],
    );
  }
}
