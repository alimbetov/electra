import 'package:electra_mobile/application/elv5/acs/acs04_source_requirement_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa04_source_requirement_contract.dart';
import 'package:flutter_test/flutter_test.dart';

String _hash(String ch) => List<String>.filled(64, ch).join();

void main() {
  test('ACS-04 and FA-04 hash the same complete source requirement set identically', () {
    final acs = Acs04SourceRequirementContract(
      sourceId: 'psu-1',
      sourceDefinitionContentHash: _hash('a'),
      contributors: <Acs04RequirementContributorRef>[
        Acs04RequirementContributorRef(
          contributorId: 'acs',
          disciplineCode: 'ACS',
          policyCode: 'ACS-PSU',
          editionId: 'acs-v1',
          contentHash: _hash('b'),
        ),
        Acs04RequirementContributorRef(
          contributorId: 'fire',
          disciplineCode: 'FIRE',
          policyCode: 'FIRE-PSU',
          editionId: 'fire-v1',
          contentHash: _hash('c'),
        ),
      ],
      cases: <Acs04SourceCaseContract>[
        Acs04SourceCaseContract(
          caseId: 'alarm-w',
          scenarioId: 'ALARM',
          segmentId: 'S1',
          dimension: Acs04SourceDimension.watt,
          pwr01SubjectKind: 'SOURCE_AGGREGATE',
          pwr01SubjectId: 'psu-1',
          pwr02SubjectKind: 'CAPACITY_GROUP',
          pwr02SubjectId: 'psu-1',
          expectedPwr02InputFingerprint: _hash('d'),
        ),
      ],
    );
    final fire = Fa04SourceRequirementContract(
      sourceId: 'psu-1',
      sourceDefinitionContentHash: _hash('a'),
      contributors: <Fa04RequirementContributorRef>[
        Fa04RequirementContributorRef(
          contributorId: 'acs',
          disciplineCode: 'ACS',
          policyCode: 'ACS-PSU',
          editionId: 'acs-v1',
          contentHash: _hash('b'),
        ),
        Fa04RequirementContributorRef(
          contributorId: 'fire',
          disciplineCode: 'FIRE',
          policyCode: 'FIRE-PSU',
          editionId: 'fire-v1',
          contentHash: _hash('c'),
        ),
      ],
      cases: <Fa04SourceCaseContract>[
        Fa04SourceCaseContract(
          caseId: 'alarm-w',
          scenarioId: 'ALARM',
          segmentId: 'S1',
          dimension: Fa04SourceDimension.watt,
          pwr01SubjectKind: 'SOURCE_AGGREGATE',
          pwr01SubjectId: 'psu-1',
          pwr02SubjectKind: 'CAPACITY_GROUP',
          pwr02SubjectId: 'psu-1',
          expectedPwr02InputFingerprint: _hash('d'),
        ),
      ],
    );

    expect(fire.requirementSetFingerprint, acs.requirementSetFingerprint);
  });
}
