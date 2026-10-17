import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qualification identity upgrades evaluation content address to v2', () {
    final descriptor = Elv5ProcessCatalog.require(Elv5ProcessCode.cctv01);
    final nodeKey = Elv5EngineeringNodeKeyV3(
      designRevisionId: 'design-1',
      scope: Elv5ScopeRef(
        kind: Elv5ScopeKind.design,
        scopeId: 'design-1',
        scenarioKey: 'NONE',
      ),
      processCode: Elv5ProcessCode.cctv01,
      subject: Elv5SubjectRef(kind: 'CAMERA', id: 'cam-1'),
    );
    final fingerprint = List<String>.filled(64, 'a').join();
    final base = Elv5ProcessEvaluationCandidate(
      nodeKey: nodeKey,
      algorithmVersion: descriptor.versions.algorithmVersion,
      inputSchemaVersion: descriptor.versions.inputSchemaVersion,
      outputSchemaVersion: descriptor.versions.outputSchemaVersion,
      numericBackendVersion: descriptor.versions.numericBackendVersion,
      canonicalEncoderVersion: Elv5RuntimeContract.canonicalEncoderVersion,
      inputFingerprint: fingerprint,
      policyFingerprint: fingerprint,
      execution: Elv5Execution.succeeded,
      completion: Elv5Completion.complete,
      assessment: Elv5Assessment.pass,
      output: const <String, Object?>{'value': 'PASS'},
      evidence: const <String, Object?>{'source': 'fixture'},
      dependencies: const <Never>[],
      completedAtUtc: DateTime.utc(2026, 10, 17),
    );
    final identity = Elv5QualificationIdentity(
      processVersion: descriptor.versions.processVersion,
      rulesetVersion: Elv5FoundationAuthorityManifest.rulesetVersion,
      sourceSha: List<String>.filled(64, 'b').join(),
      authorityFingerprint: Elv5FoundationAuthorityManifest.instance.fingerprint(),
    );
    final qualified = base.withQualificationIdentity(identity);

    expect(base.evaluationIdentitySchema, 'electra.elv5-evaluation-identity.v1');
    expect(qualified.evaluationIdentitySchema, 'electra.elv5-evaluation-identity.v2');
    expect(qualified.isQualificationAddressed, isTrue);
    expect(qualified.evaluationId, isNot(base.evaluationId));
    expect(
      qualified.withQualificationIdentity(identity).evaluationId,
      qualified.evaluationId,
    );
  });

  test('qualification identity cannot bind another process version', () {
    final cctv = Elv5ProcessCatalog.require(Elv5ProcessCode.cctv01);
    final lan = Elv5ProcessCatalog.require(Elv5ProcessCode.lan01);
    final fingerprint = List<String>.filled(64, 'c').join();

    expect(
      () => Elv5ProcessEvaluationCandidate(
        nodeKey: Elv5EngineeringNodeKeyV3(
          designRevisionId: 'design-1',
          scope: Elv5ScopeRef(
            kind: Elv5ScopeKind.design,
            scopeId: 'design-1',
            scenarioKey: 'NONE',
          ),
          processCode: Elv5ProcessCode.cctv01,
          subject: Elv5SubjectRef(kind: 'CAMERA', id: 'cam-1'),
        ),
        algorithmVersion: cctv.versions.algorithmVersion,
        inputSchemaVersion: cctv.versions.inputSchemaVersion,
        outputSchemaVersion: cctv.versions.outputSchemaVersion,
        numericBackendVersion: cctv.versions.numericBackendVersion,
        canonicalEncoderVersion: Elv5RuntimeContract.canonicalEncoderVersion,
        inputFingerprint: fingerprint,
        policyFingerprint: fingerprint,
        execution: Elv5Execution.succeeded,
        completion: Elv5Completion.complete,
        assessment: Elv5Assessment.pass,
        output: const <String, Object?>{},
        evidence: const <String, Object?>{},
        dependencies: const <Never>[],
        completedAtUtc: DateTime.utc(2026, 10, 17),
        qualificationIdentity: Elv5QualificationIdentity(
          processVersion: lan.versions.processVersion,
          rulesetVersion: Elv5FoundationAuthorityManifest.rulesetVersion,
          sourceSha: List<String>.filled(64, 'd').join(),
          authorityFingerprint: Elv5FoundationAuthorityManifest.instance.fingerprint(),
        ),
      ),
      throwsStateError,
    );
  });
}
