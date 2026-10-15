import 'dart:convert';
import 'dart:io';

import 'package:electra_mobile/application/engineering_reference_adoption.dart';
import 'package:electra_mobile/application/engineering_reference_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringReferenceCatalog fixture() => EngineeringReferenceCatalog.fromMap(
  jsonDecode(
    File('../../docs/examples/elv2-reference-catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>,
);

ComponentReferenceBinding bindingFor(
  EngineeringReferenceCatalog catalog,
  List<EngineeringPort> ports,
) => ComponentReferenceBinding(
  componentId: 'camera-1',
  catalogId: catalog.id,
  profileCode: 'CAMERA',
  catalogVersion: catalog.version,
  profile: catalog.profile('CAMERA'),
  portIds: ports.map((port) => port.id).toList(),
);

List<EngineeringPort> currentPorts(EngineeringReferenceCatalog catalog) {
  var index = 0;
  return catalog
      .profile('CAMERA')
      .instantiate(
        componentId: 'camera-1',
        catalogId: catalog.id,
        version: catalog.version,
        vocabulary: catalog.vocabulary,
        nextId: () => 'port-${++index}',
      );
}

EngineeringReferenceCatalog candidate(
  EngineeringReferenceCatalog previous,
  List<EngineeringPort> templates,
) => EngineeringReferenceCatalog.fromMap({
  ...previous.toMap(),
  'id': '${previous.id}-v2',
  'version': '2',
  'profiles': [
    for (final profile in previous.profiles)
      if (profile.code == 'CAMERA')
        {
          ...profile.toMap(),
          'portTemplates': templates.map((port) => port.toMap()).toList(),
        }
      else
        profile.toMap(),
  ],
});

void main() {
  test('template reorder preserves exact existing port identity by code', () {
    final previous = fixture();
    final ports = currentPorts(previous);
    final templates = previous
        .profile('CAMERA')
        .portTemplates
        .reversed
        .toList();
    final plan = planEngineeringReferenceAdoption(
      binding: bindingFor(previous, ports),
      currentPorts: ports,
      candidateCatalog: candidate(previous, templates),
    );

    expect(plan.canApply, isTrue);
    expect(
      plan.steps.where(
        (step) => step.action == EngineeringPortMigrationAction.preserve,
      ),
      hasLength(ports.length),
    );
    expect(
      plan.steps.where(
        (step) => step.action != EngineeringPortMigrationAction.preserve,
      ),
      isEmpty,
    );
    for (final step in plan.steps) {
      final old = ports.singleWhere(
        (port) => port.code.toUpperCase() == step.currentCode,
      );
      expect(step.currentPortId, old.id);
      expect(step.candidateCode, step.currentCode);
    }
  });

  test('additive candidate preserves old identity and plans only new port', () {
    final previous = fixture();
    final ports = currentPorts(previous);
    final template = previous.profile('CAMERA').portTemplates.first;
    final added = EngineeringPort.fromMap({
      ...template.toMap(),
      'id': 'template-aux',
      'componentId': 'template',
      'code': 'AUX',
    });

    final plan = planEngineeringReferenceAdoption(
      binding: bindingFor(previous, ports),
      currentPorts: ports,
      candidateCatalog: candidate(previous, [
        ...previous.profile('CAMERA').portTemplates,
        added,
      ]),
    );

    expect(plan.canApply, isTrue);
    expect(
      plan.steps
          .where((step) => step.action == EngineeringPortMigrationAction.add)
          .single
          .candidateCode,
      'AUX',
    );
    expect(
      plan.steps.where(
        (step) => step.action == EngineeringPortMigrationAction.preserve,
      ),
      hasLength(ports.length),
    );
  });

  test('removed connected port blocks retirement', () {
    final previous = fixture();
    final ports = currentPorts(previous);
    final removed = ports.first;
    final keepCodes = ports
        .skip(1)
        .map((port) => port.code.toUpperCase())
        .toSet();
    final templates = previous
        .profile('CAMERA')
        .portTemplates
        .where((template) => keepCodes.contains(template.code.toUpperCase()))
        .toList();

    final plan = planEngineeringReferenceAdoption(
      binding: bindingFor(previous, ports),
      currentPorts: ports,
      candidateCatalog: candidate(previous, templates),
      dependentPortIds: {removed.id},
    );

    expect(plan.canApply, isFalse);
    expect(plan.blockers.join(' '), contains('cannot be retired'));
    expect(
      plan.steps.singleWhere((step) => step.currentPortId == removed.id).action,
      EngineeringPortMigrationAction.retire,
    );
  });

  test('rename is never inferred and requires explicit one-to-one mapping', () {
    final previous = fixture();
    final ports = currentPorts(previous);
    final old = previous.profile('CAMERA').portTemplates.first;
    final renamed = EngineeringPort.fromMap({
      ...old.toMap(),
      'id': 'template-renamed',
      'componentId': 'template',
      'code': 'RENAMED',
    });
    final templates = [
      renamed,
      ...previous.profile('CAMERA').portTemplates.skip(1),
    ];
    final withoutMapping = planEngineeringReferenceAdoption(
      binding: bindingFor(previous, ports),
      currentPorts: ports,
      candidateCatalog: candidate(previous, templates),
      dependentPortIds: {ports.first.id},
    );
    expect(withoutMapping.canApply, isFalse);

    final withMapping = planEngineeringReferenceAdoption(
      binding: bindingFor(previous, ports),
      currentPorts: ports,
      candidateCatalog: candidate(previous, templates),
      explicitPortMappings: {old.code: 'RENAMED'},
      dependentPortIds: {ports.first.id},
    );
    expect(withMapping.canApply, isTrue);
    final step = withMapping.steps.singleWhere(
      (item) => item.currentPortId == ports.first.id,
    );
    expect(step.action, EngineeringPortMigrationAction.explicitRemap);
    expect(step.candidateCode, 'RENAMED');
  });

  test(
    'connected same-code technical change requires commit-time revalidation',
    () {
      final previous = fixture();
      final ports = currentPorts(previous);
      final template = previous.profile('CAMERA').portTemplates.first;
      final changed = EngineeringPort.fromMap({
        ...template.toMap(),
        'capacity': template.capacity + 1,
      });
      final templates = [
        changed,
        ...previous.profile('CAMERA').portTemplates.skip(1),
      ];

      final plan = planEngineeringReferenceAdoption(
        binding: bindingFor(previous, ports),
        currentPorts: ports,
        candidateCatalog: candidate(previous, templates),
        dependentPortIds: {ports.first.id},
      );

      expect(plan.canApply, isTrue);
      expect(plan.requiresConnectionRevalidation, isTrue);
      expect(
        plan.steps
            .singleWhere((step) => step.currentPortId == ports.first.id)
            .requiresConnectionRevalidation,
        isTrue,
      );
    },
  );

  test('invalid mapping and missing candidate profile fail closed', () {
    final previous = fixture();
    final ports = currentPorts(previous);
    final missingProfile = EngineeringReferenceCatalog.fromMap({
      ...previous.toMap(),
      'id': '${previous.id}-v2',
      'version': '2',
      'profiles': previous.profiles
          .where((profile) => profile.code != 'CAMERA')
          .map((profile) => profile.toMap())
          .toList(),
    });

    final plan = planEngineeringReferenceAdoption(
      binding: bindingFor(previous, ports),
      currentPorts: ports,
      candidateCatalog: missingProfile,
      explicitPortMappings: const {'UNKNOWN': 'MISSING'},
    );

    expect(plan.canApply, isFalse);
    expect(plan.blockers.join(' '), contains('does not contain bound profile'));
    expect(plan.blockers.join(' '), contains('unknown old port'));
  });
}
