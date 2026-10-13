import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import '../../application/engineering_profile_palette.dart';
import '../../application/engineering_reference_repository.dart';

class EngineeringProfilePalette extends StatefulWidget {
  const EngineeringProfilePalette({
    super.key,
    required this.snapshot,
    required this.projectId,
    this.initialSystemId,
  });
  final ProjectEngineeringReferences snapshot;
  final String projectId;
  final String? initialSystemId;
  static Future<CanonicalProfileChoice?> show(
    BuildContext context, {
    required ProjectEngineeringReferences snapshot,
    required String projectId,
    String? initialSystemId,
  }) => showModalBottomSheet<CanonicalProfileChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (_) => FractionallySizedBox(
          heightFactor: .86,
          child: EngineeringProfilePalette(
            snapshot: snapshot,
            projectId: projectId,
            initialSystemId: initialSystemId,
          ),
        ),
  );
  @override
  State<EngineeringProfilePalette> createState() =>
      _EngineeringProfilePaletteState();
}

class _EngineeringProfilePaletteState extends State<EngineeringProfilePalette> {
  String? systemId;
  CanonicalComponentClass? category;
  String query = '';
  @override
  void initState() {
    super.initState();
    systemId = widget.initialSystemId;
  }

  @override
  Widget build(BuildContext context) {
    final systems =
        widget.snapshot.systems.project?.id == widget.projectId
            ? widget.snapshot.systems.systems
                .where((s) => s.projectId == widget.projectId)
                .toList()
            : <EngineeringSystem>[];
    final system = systems.where((s) => s.id == systemId).firstOrNull;
    final all =
        system == null
            ? <CanonicalProfileChoice>[]
            : canonicalPaletteChoices(
              widget.snapshot,
              widget.projectId,
              system.id,
            );
    final classes =
        all.map((c) => c.profile.engineeringClass).toSet().toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final values =
        all
            .where(
              (c) =>
                  (category == null ||
                      c.profile.engineeringClass == category) &&
                  '${c.profile.label} ${c.profile.code} ${c.catalog.code} ${c.catalog.version}'
                      .toLowerCase()
                      .contains(query.trim().toLowerCase()),
            )
            .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Canonical profile palette',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Choose an engineering system to inspect its profile editions.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('palette-system-${system?.id}'),
              initialValue: system?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Active engineering system',
              ),
              items: [
                for (final s in systems)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.code} · ${s.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged:
                  (v) => setState(() {
                    systemId = v;
                    category = null;
                  }),
            ),
            if (system != null)
              Text(
                'Discipline: ${paletteDiscipline(system, widget.snapshot.systems.families)?.name.toUpperCase() ?? 'unresolved family edition'}',
              ),
            if (all.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search canonical profiles',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => query = v),
              ),
              DropdownButtonFormField<CanonicalComponentClass>(
                key: ValueKey('palette-class-$systemId-$category'),
                initialValue: category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Engineering class',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All classes'),
                  ),
                  for (final c in classes)
                    DropdownMenuItem(value: c, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => category = v),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child:
                  values.isEmpty
                      ? Center(
                        child: Text(
                          systems.isEmpty
                              ? 'No active engineering systems in this project.'
                              : system == null
                              ? 'Select a system first.'
                              : all.isEmpty
                              ? 'No canonical profiles for this exact system family. Import a matching catalog in Engineering reference catalogs.'
                              : 'No matching profiles.',
                        ),
                      )
                      : ListView.builder(
                        itemCount: values.length,
                        itemBuilder: (context, index) {
                          final choice = values[index];
                          final p = choice.profile;
                          return Card(
                            child: ListTile(
                              key: ValueKey(
                                'palette-profile-${choice.catalog.id}-${p.code}',
                              ),
                              leading: Icon(switch (p.discipline) {
                                ReferenceDiscipline.cctv =>
                                  Icons.videocam_outlined,
                                ReferenceDiscipline.lan => Icons.lan_outlined,
                                ReferenceDiscipline.acs =>
                                  Icons.sensor_door_outlined,
                                ReferenceDiscipline.fire =>
                                  Icons.local_fire_department_outlined,
                              }),
                              title: Text(p.label),
                              subtitle: Text(
                                '${p.engineeringClass.name} · ${p.code}\n${choice.catalog.code} / ${choice.catalog.version}${p.deprecated
                                    ? '\nDeprecated'
                                    : p.constraintsState == ProfileConstraintsState.legacyUnspecified
                                    ? '\nLegacy constraints unspecified'
                                    : ''}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final use = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (_) => AlertDialog(
                                        title: Text(p.label),
                                        content: SizedBox(
                                          width: 600,
                                          child: SingleChildScrollView(
                                            child: CanonicalProfileDetails(
                                              choice: choice,
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('Back'),
                                          ),
                                          FilledButton(
                                            onPressed:
                                                p.deprecated
                                                    ? null
                                                    : () => Navigator.pop(
                                                      context,
                                                      true,
                                                    ),
                                            child: const Text(
                                              'Preview on surface',
                                            ),
                                          ),
                                        ],
                                      ),
                                );
                                if (use == true && context.mounted)
                                  Navigator.pop(context, choice);
                              },
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class CanonicalProfileDetails extends StatelessWidget {
  const CanonicalProfileDetails({super.key, required this.choice});
  final CanonicalProfileChoice choice;
  @override
  Widget build(BuildContext context) {
    final p = choice.profile, c = choice.catalog, constraints = p.constraints;
    Widget section(String title, List<Widget> children) => ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      children: children,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile: ${p.code} · ${p.engineeringClass.name}'),
        Text(
          'Catalog: ${c.code} / ${c.version}\nIdentity: ${c.id}\nSource: ${c.source}',
        ),
        Text('System: ${choice.system.code} · ${choice.system.name}'),
        Text('Lifecycle: ${p.deprecated ? 'deprecated' : 'active'}'),
        Text(
          'Capabilities: ${p.capabilities.isEmpty ? 'none declared' : p.capabilities.map((v) => v.name).join(', ')}',
        ),
        section('Ports and interfaces', [
          for (final port in p.portTemplates) _port(port, p, c),
        ]),
        if (constraints == null)
          Text(
            p.constraintsState == ProfileConstraintsState.legacyUnspecified
                ? 'Placement constraints: unspecified in this legacy edition. Preview remains UNRESOLVED.'
                : 'Placement constraints: missing from this edition. Compatibility cannot be confirmed.',
          )
        else ...[
          section('Mounting', [
            for (final option in constraints.mounting.options)
              ListTile(
                dense: true,
                title: Text('${option.surface.name} + ${option.method.name}'),
              ),
            Text(
              'Enclosure required: ${constraints.mounting.enclosureRequired ? 'yes' : 'no'}',
            ),
            Text(
              'Minimum clearance: ${constraints.mounting.minimumClearanceMm == null ? 'not declared' : '${constraints.mounting.minimumClearanceMm} mm'}',
            ),
          ]),
          section('Environment', [
            Text(
              'Exposure: ${constraints.environment.allowedExposure.map((v) => v.name).join(', ')}',
            ),
            Text(
              'Moisture: ${_names(constraints.environment.allowedMoisture)}',
            ),
            Text(
              'Contamination: ${_names(constraints.environment.allowedContamination)}',
            ),
            Text('Climate: ${_names(constraints.environment.allowedClimate)}'),
            Text(
              'Minimum protection: ${constraints.environment.minimumIpRating?.value ?? 'not declared'}',
            ),
            Text(
              'Temperature: ${constraints.environment.minimumTemperatureC == null ? 'not declared' : '${constraints.environment.minimumTemperatureC}…${constraints.environment.maximumTemperatureC} °C'}',
            ),
          ]),
          section('Topology', [
            Text('Shapes: ${_names(constraints.topology.allowedShapes)}'),
            Text('Roles: ${_names(constraints.topology.allowedRoles)}'),
            Text('Branching allowed: ${constraints.topology.branchingAllowed}'),
            Text(
              'Closed loop required: ${constraints.topology.closedLoopRequired}',
            ),
            Text(
              'Node order matters: ${constraints.topology.nodeOrderMatters}',
            ),
            Text(
              'Maximum degree: ${constraints.topology.maximumDegree ?? 'not declared'}',
            ),
            const Text(
              'Preview checks shape and role intent. Loop closure, branching and node order require graph validation.',
            ),
          ]),
        ],
      ],
    );
  }

  String _names(Iterable<Enum> values) =>
      values.isEmpty ? 'not constrained' : values.map((v) => v.name).join(', ');
  Widget _port(
    EngineeringPort template,
    ComponentEngineeringProfile profile,
    EngineeringReferenceCatalog catalog,
  ) {
    final code = profile.portInterfaceCodes[template.code];
    try {
      final port =
          code == null
              ? template
              : catalog.vocabulary.resolve(
                template,
                code,
                catalogId: catalog.id,
                version: catalog.version,
                newInstantiation: false,
              );
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          '${port.code} · ${port.kind.name} · ${port.direction.name}',
        ),
        subtitle: Text(
          'Capacity: ${port.capacity}\nInterface: ${code ?? 'inline template'} / ${catalog.version}\nConnector: ${port.connector ?? 'unresolved'}\nProtocol: ${port.protocol?.id ?? 'unresolved'} / ${port.protocol?.version ?? '?'}${port.voltage == null ? '' : '\nVoltage: ${port.voltage!.currentKind.name} ${port.voltage!.minimumV}–${port.voltage!.maximumV} V'}',
        ),
      );
    } catch (_) {
      return Text(
        '${template.code}: interface reference is unresolved in this edition.',
      );
    }
  }
}
