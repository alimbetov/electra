import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

TerminationPolicy _bothEnds() => TerminationPolicy(
      mode: TerminationPolicyMode.bothEnds,
      terminalRequired: true,
    );

CableDefinition cat6Definition({String label = 'Cat6 U/UTP'}) =>
    CableDefinition(
      code: 'CAT6-UUTP',
      label: label,
      mediaCode: 'COPPER_BALANCED',
      categoryCode: 'CAT6',
      technicalClassCodes: const ['DATA'],
      pairCount: 1,
      conductorCount: 2,
      outerDiameterMm: 6.2,
      minimumBendRadiusMm: 25,
      resourceDefinitions: [
        CableResourceDefinition(
          identity: '__WHOLE_CABLE__',
          kind: CableResourceKind.wholeCable,
          allocatable: true,
          atomic: false,
          childResourceIds: const ['PAIR-1'],
          terminationPolicy: _bothEnds(),
        ),
        CableResourceDefinition(
          identity: 'PAIR-1',
          kind: CableResourceKind.pair,
          allocatable: true,
          atomic: false,
          parentResourceId: '__WHOLE_CABLE__',
          childResourceIds: const ['COND-1', 'COND-2'],
          terminationPolicy: _bothEnds(),
        ),
        CableResourceDefinition(
          identity: 'COND-1',
          kind: CableResourceKind.conductor,
          allocatable: true,
          atomic: true,
          parentResourceId: 'PAIR-1',
          terminationPolicy: _bothEnds(),
        ),
        CableResourceDefinition(
          identity: 'COND-2',
          kind: CableResourceKind.conductor,
          allocatable: true,
          atomic: true,
          parentResourceId: 'PAIR-1',
          terminationPolicy: _bothEnds(),
        ),
      ],
    );

void main() {
  test('shared SHA-256 helper matches the standard abc vector', () {
    expect(
      sha256HexUtf8('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('valid cable definition produces stable exact reference hash', () {
    final definition = cat6Definition();
    expect(definition.validate(), isEmpty);

    final catalog = EngineeringReferenceCatalog(
      id: 'catalog-cable-1',
      code: 'ELV-CABLES',
      version: '2026.1',
      source: 'test',
      cableDefinitions: [definition],
    );
    expect(catalog.validateForPublication(), isEmpty);

    final ref = catalog.cableDefinitionRef('cat6-uutp');
    expect(ref.catalogId, 'catalog-cable-1');
    expect(ref.catalogVersion, '2026.1');
    expect(ref.definitionCode, 'CAT6-UUTP');
    expect(ref.definitionContentHash, hasLength(64));
    expect(ref.validate(), isEmpty);
    expect(
      ref.definitionContentHash,
      cableDefinitionContentHashV1(
        CableDefinition.fromMap(
          jsonDecode(jsonEncode(definition.toMap())) as Map<String, dynamic>,
        ),
      ),
    );
  });

  test('definition hash changes when semantic content changes', () {
    final before = cableDefinitionContentHashV1(cat6Definition());
    final after = cableDefinitionContentHashV1(
      cat6Definition(label: 'Cat6 revised label'),
    );
    expect(after, isNot(before));
  });

  test('resource graph rejects cycles and broken reciprocal links', () {
    final broken = CableDefinition(
      code: 'BROKEN',
      label: 'Broken',
      mediaCode: 'COPPER',
      resourceDefinitions: [
        CableResourceDefinition(
          identity: '__WHOLE_CABLE__',
          kind: CableResourceKind.wholeCable,
          allocatable: true,
          atomic: false,
          childResourceIds: const ['PAIR-1'],
          terminationPolicy: _bothEnds(),
        ),
        CableResourceDefinition(
          identity: 'PAIR-1',
          kind: CableResourceKind.pair,
          allocatable: true,
          atomic: false,
          parentResourceId: '__WHOLE_CABLE__',
          childResourceIds: const ['__WHOLE_CABLE__'],
          terminationPolicy: _bothEnds(),
        ),
      ],
    );
    expect(broken.validate(), isNotEmpty);
  });

  test('component-only ELV2 catalog remains readable without cableDefinitions',
      () {
    final old = EngineeringReferenceCatalog.fromMap({
      'id': 'legacy',
      'code': 'LEGACY',
      'version': '1',
      'source': 'test',
      'profiles': <Object?>[],
    });
    expect(old.cableDefinitions, isEmpty);
    expect(old.toMap().containsKey('cableDefinitions'), isFalse);
  });
}
