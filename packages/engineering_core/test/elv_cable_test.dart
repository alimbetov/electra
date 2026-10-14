import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  const ref = CableDefinitionRef(
    catalogId: 'catalog-1',
    catalogVersion: '2026.1',
    definitionCode: 'CAT6',
    definitionContentHash:
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  );

  test('cable identity is project scoped and label normalization is stable', () {
    const cable = Cable(
      id: 'cable-1',
      projectId: 'project-1',
      label: '  c-01  ',
      name: 'Horizontal link',
      definitionRef: ref,
      lifecycleState: CableLifecycleState.active,
      revision: 1,
    );
    expect(cable.validate(), isEmpty);
    expect(cable.normalizedLabel, 'C-01');
    expect(Cable.fromMap(cable.toMap()).definitionRef.definitionCode, 'CAT6');
  });

  test('cable rejects empty identity and invalid revision', () {
    const cable = Cable(
      id: '',
      projectId: '',
      label: '',
      name: '',
      definitionRef: ref,
      lifecycleState: CableLifecycleState.active,
      revision: 0,
    );
    expect(cable.validate().length, greaterThanOrEqualTo(5));
  });

  test('definition ref normalizes code and hash casing', () {
    const raw = CableDefinitionRef(
      catalogId: ' catalog-1 ',
      catalogVersion: ' 1 ',
      definitionCode: ' cat6 ',
      definitionContentHash:
          'ABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCD',
    );
    final normalized = raw.normalized();
    expect(normalized.catalogId, 'catalog-1');
    expect(normalized.catalogVersion, '1');
    expect(normalized.definitionCode, 'CAT6');
    expect(normalized.definitionContentHash, normalized.definitionContentHash.toLowerCase());
    expect(normalized.validate(), isEmpty);
  });
}
