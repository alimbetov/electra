import 'package:electra_mobile/application/elv5/acs/acs04_source_requirement_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ACS-04 contract round-trips canonically with stable requirement-set hash', () {
    final contract = _contract(_hash('a'));
    final restored = Acs04SourceRequirementContract.fromMap(
      contract.toCanonicalValue(),
    );

    expect(restored.toCanonicalValue(), contract.toCanonicalValue());
    expect(restored.requirementSetFingerprint, contract.requirementSetFingerprint);
    expect(restored.contributors.map((e) => e.contributorId), ['acs', 'fire']);
  });

  test('requires an ACS contributor in the complete shared requirement set', () {
    expect(
      () => Acs04SourceRequirementContract(
        sourceId: 'psu-1',
        sourceDefinitionContentHash: _hash('b'),
        contributors: [
          Acs04RequirementContributorRef(
            contributorId: 'fire',
            disciplineCode: 'FIRE',
            policyCode: 'FIRE-PSU',
            editionId: 'fire-v1',
            contentHash: _hash('c'),
          ),
        ],
        cases: [_case(_hash('d'))],
      ),
      throwsArgumentError,
    );
  });
}

Acs04SourceRequirementContract _contract(String pwr02InputHash) =>
    Acs04SourceRequirementContract(
      sourceId: 'psu-1',
      sourceDefinitionContentHash: _hash('b'),
      contributors: [
        Acs04RequirementContributorRef(
          contributorId: 'fire',
          disciplineCode: 'FIRE',
          policyCode: 'FIRE-PSU',
          editionId: 'fire-v1',
          contentHash: _hash('c'),
        ),
        Acs04RequirementContributorRef(
          contributorId: 'acs',
          disciplineCode: 'ACS',
          policyCode: 'ACS-PSU',
          editionId: 'acs-v1',
          contentHash: _hash('d'),
        ),
      ],
      cases: [_case(pwr02InputHash)],
    );

Acs04SourceCaseContract _case(String pwr02InputHash) => Acs04SourceCaseContract(
      caseId: 'normal-w',
      scenarioId: 'NORMAL',
      segmentId: 'S1',
      dimension: Acs04SourceDimension.watt,
      pwr01SubjectKind: 'SOURCE_AGGREGATE',
      pwr01SubjectId: 'psu-1',
      pwr02SubjectKind: 'CAPACITY_GROUP',
      pwr02SubjectId: 'psu-1',
      expectedPwr02InputFingerprint: pwr02InputHash,
    );

String _hash(String char) => List<String>.filled(64, char).join();
