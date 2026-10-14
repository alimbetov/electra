import 'package:electra_mobile/application/engineering_reference_adoption_repository.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringReferenceAdoptionCommand _command({
  Map<String, String> mappings = const {},
}) => EngineeringReferenceAdoptionCommand(
  operationId: 'adopt-op',
  projectId: 'project-1',
  componentId: 'component-1',
  expectedCatalogId: 'catalog-v1',
  expectedCatalogVersion: '1',
  candidateCatalogId: 'catalog-v2',
  candidateCatalogVersion: '2',
  profileCode: 'CAMERA',
  reviewedBindingFingerprint: 'binding-fingerprint',
  reviewedGraphFingerprint: 'graph-fingerprint',
  explicitPortMappings: mappings,
);

void main() {
  test('duplicate normalized mapping source is rejected before collapse', () {
    final command = _command(
      mappings: const {
        'eth': 'DATA',
        ' ETH ': 'DATA2',
      },
    );

    expect(
      command.validate(),
      contains('Duplicate normalized explicit mapping source code: ETH.'),
    );
  });

  test('duplicate normalized mapping target is rejected', () {
    final command = _command(
      mappings: const {
        'eth': ' data ',
        'aux': 'DATA',
      },
    );

    expect(
      command.validate(),
      contains('Duplicate normalized explicit mapping target code: DATA.'),
    );
  });

  test('ambiguous source order cannot become valid migration semantics', () {
    final first = _command(
      mappings: const {
        'eth': 'DATA',
        ' ETH ': 'DATA2',
      },
    );
    final reversed = _command(
      mappings: const {
        ' ETH ': 'DATA2',
        'eth': 'DATA',
      },
    );

    expect(first.validate(), isNotEmpty);
    expect(reversed.validate(), isNotEmpty);
  });
}
