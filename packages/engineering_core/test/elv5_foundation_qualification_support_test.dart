import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

import 'support/elv5_foundation_qualification_support.dart';

void main() {
  test('boundary triplet preserves below exact above order', () {
    const triplet = Elv5BoundaryTriplet<int>(below: 9, exact: 10, above: 11);
    expect(triplet.values, orderedEquals(const <int>[9, 10, 11]));
  });

  test('independent oracle and metamorphic helpers fail closed', () {
    expect(
      () => requireIndependentOracle<int>(production: 23, oracle: 24),
      throwsStateError,
    );
    expect(
      () => requireMetamorphicInvariant<int>(
        relation: 'NONDECREASING_CAPACITY_MARGIN',
        baseline: 10,
        transformed: 9,
        invariant: (left, right) => right >= left,
      ),
      throwsStateError,
    );
  });

  test('pilot qualification matrix requires every mandatory gate', () {
    final descriptor = Elv5ProcessCatalog.require(Elv5ProcessCode.fa03);
    final pin = Elv5QualificationEvidencePin(
      sourceSha: List<String>.filled(64, 'a').join(),
      authorityFingerprint:
          Elv5FoundationAuthorityManifest.instance.fingerprint(),
      processVersion: descriptor.versions.processVersion,
      rulesetVersion: Elv5FoundationAuthorityManifest.rulesetVersion,
      testId: 'FA03-Q1-REFERENCE',
    );
    final q1 = Elv5QualificationGateEvidence(
      gate: Elv5QualificationGate.q1MathematicalReferenceVectors,
      pin: pin,
      evidenceRefs: const <String>['fa03_reference_vector_test.dart'],
      assertions: const <String>['dU=I*Rloop', 'Uload=Usource-sum(dU)'],
    );
    final matrix = Elv5PilotQualificationMatrix(
      pilotId: 'FA-03',
      mandatoryGates: const <Elv5QualificationGate>{
        Elv5QualificationGate.q0ContractSchemaInventory,
        Elv5QualificationGate.q1MathematicalReferenceVectors,
        Elv5QualificationGate.q2IndependentOracle,
      },
      evidence: <Elv5QualificationGateEvidence>[q1],
    );

    expect(matrix.allMandatoryGatesSatisfied, isFalse);
    expect(
      matrix.missingMandatoryGates,
      equals(<Elv5QualificationGate>{
        Elv5QualificationGate.q0ContractSchemaInventory,
        Elv5QualificationGate.q2IndependentOracle,
      }),
    );
    expect(matrix.sha256(), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('qualification evidence pin is exact-SHA bound and deterministic', () {
    final descriptor = Elv5ProcessCatalog.require(Elv5ProcessCode.lan05);
    final pin = Elv5QualificationEvidencePin(
      sourceSha: List<String>.filled(64, 'b').join(),
      authorityFingerprint:
          Elv5FoundationAuthorityManifest.instance.fingerprint(),
      processVersion: descriptor.versions.processVersion,
      rulesetVersion: Elv5FoundationAuthorityManifest.rulesetVersion,
      testId: 'LAN05-Q2-ORACLE',
    );

    expect(pin.sha256(), pin.sha256());
    expect(
      () => Elv5QualificationEvidencePin(
        sourceSha: 'HEAD',
        authorityFingerprint:
            Elv5FoundationAuthorityManifest.instance.fingerprint(),
        processVersion: descriptor.versions.processVersion,
        rulesetVersion: Elv5FoundationAuthorityManifest.rulesetVersion,
        testId: 'LAN05-Q2-ORACLE',
      ),
      throwsArgumentError,
    );
  });

  test('determinism helper rejects divergent hashes', () {
    final a = List<String>.filled(64, 'c').join();
    final b = List<String>.filled(64, 'd').join();
    expect(() => requireDeterministicHashes(<String>[a, b]), throwsStateError);
    expect(() => requireDeterministicHashes(<String>[a, a]), returnsNormally);
  });
}
