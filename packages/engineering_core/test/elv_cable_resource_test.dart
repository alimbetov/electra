import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('CableResourceResolver', () {
    test('whole cable resolves to the canonical whole-cable atom', () {
      final resolved = CableResourceResolver.resolve(
        definition: _eightCoreDefinition(),
        selection: const WholeCableSelection(),
      );

      expect(resolved.atomicResourceIdentities, ['__WHOLE_CABLE__']);
      expect(resolved.selectionSha256, hasLength(64));
    });

    test('resource set resolves composites to sorted unique atomic cores', () {
      final resolved = CableResourceResolver.resolve(
        definition: _eightCoreDefinition(),
        selection: ResourceSetSelection(['PAIR-2', 'CORE-1']),
      );

      expect(
        resolved.atomicResourceIdentities,
        ['CORE-1', 'CORE-3', 'CORE-4'],
      );
    });

    test('definition group resolves every allocatable member to atoms', () {
      final resolved = CableResourceResolver.resolve(
        definition: _eightCoreDefinition(),
        selection: DefinitionGroupSelection('ACCESS_CONTROL'),
      );

      expect(
        resolved.atomicResourceIdentities,
        ['CORE-1', 'CORE-2', 'CORE-3', 'CORE-4'],
      );
    });

    test('unknown resource is rejected with stable code', () {
      expect(
        () => CableResourceResolver.resolve(
          definition: _eightCoreDefinition(),
          selection: ResourceSetSelection(['CORE-99']),
        ),
        throwsA(
          isA<CableResourceResolutionException>().having(
            (error) => error.code,
            'code',
            'ELV_ALLOC_RESOURCE_UNKNOWN',
          ),
        ),
      );
    });
  });

  group('CableResourceOverlap', () {
    test('whole cable conflicts with every non-empty physical claim', () {
      expect(
        CableResourceOverlap.conflicts(
          ['__WHOLE_CABLE__'],
          ['CORE-1'],
        ),
        isTrue,
      );
    });

    test('disjoint conductor claims can coexist', () {
      expect(
        CableResourceOverlap.conflicts(
          ['CORE-1', 'CORE-2'],
          ['CORE-3', 'CORE-4'],
        ),
        isFalse,
      );
    });

    test('shared atomic conductor conflicts', () {
      expect(
        CableResourceOverlap.conflicts(
          ['CORE-1', 'CORE-2'],
          ['CORE-2', 'CORE-3'],
        ),
        isTrue,
      );
    });
  });
}

CableDefinition _eightCoreDefinition() => CableDefinition(
      code: 'ACS-8C',
      label: '8-core ACS cable',
      mediaCode: 'COPPER',
      resourceDefinitions: [
        CableResourceDefinition(
          identity: '__WHOLE_CABLE__',
          kind: CableResourceKind.wholeCable,
          allocatable: true,
          atomic: true,
          terminationPolicy: TerminationPolicy(
            mode: TerminationPolicyMode.bothEnds,
            terminalRequired: false,
          ),
        ),
        for (var i = 1; i <= 4; i++)
          CableResourceDefinition(
            identity: 'CORE-$i',
            kind: CableResourceKind.conductor,
            allocatable: true,
            atomic: true,
            parentResourceId: i <= 2 ? 'PAIR-1' : 'PAIR-2',
            groupMembership: const ['ACCESS_CONTROL'],
            terminationPolicy: TerminationPolicy(
              mode: TerminationPolicyMode.bothEnds,
              terminalRequired: true,
            ),
          ),
        CableResourceDefinition(
          identity: 'PAIR-1',
          kind: CableResourceKind.coreGroup,
          allocatable: true,
          atomic: false,
          childResourceIds: const ['CORE-1', 'CORE-2'],
          groupMembership: const ['ACCESS_CONTROL'],
          terminationPolicy: TerminationPolicy(
            mode: TerminationPolicyMode.groupLevel,
            terminalRequired: false,
          ),
        ),
        CableResourceDefinition(
          identity: 'PAIR-2',
          kind: CableResourceKind.coreGroup,
          allocatable: true,
          atomic: false,
          childResourceIds: const ['CORE-3', 'CORE-4'],
          groupMembership: const ['ACCESS_CONTROL'],
          terminationPolicy: TerminationPolicy(
            mode: TerminationPolicyMode.groupLevel,
            terminalRequired: false,
          ),
        ),
      ],
    );
