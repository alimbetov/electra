import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../environment/ampacity_route_resolver.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'fa08_policy_contract.dart';
import 'fa08_route_facts.dart';

final class Fa08PersistedInputResolver
    implements Elv5ProcessInputResolver<Fa08Input> {
  Fa08PersistedInputResolver({
    required this.policySource,
    required this.ampacityResolver,
    required this.routeCableFacts,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Fa08CablePolicyContractSource policySource;
  final Elv5AmpacityRouteResolver ampacityResolver;
  final Fa08RouteCableFactSource routeCableFacts;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa08;

  @override
  Future<Elv5CapturedInput<Fa08Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('FA08_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'CABLE_RUN') {
      throw StateError('FA08_SUBJECT_KIND_MUST_BE_CABLE_RUN');
    }

    final cableRunId = request.subject.id;
    final basisFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-fa08-route-basis.v1',
      'cableRunId': cableRunId,
    });
    final dependencies = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'CABLE_RUN_ROUTE', cableRunId),
    ];

    final policySnapshot = await policySource.loadActiveForCableRun(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      cableRunId: cableRunId,
    );
    if (policySnapshot == null) {
      _blocked(
        request,
        'FA08_CABLE_POLICY_CONTRACT_REQUIRED',
        basisFingerprint,
        basisFingerprint,
        dependencies,
        <String, Object?>{'cableRunId': cableRunId},
      );
    }
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'FA08_CABLE_POLICY_CONTRACT',
        policySnapshot!.evidenceRef,
        memberId:
            '${policySnapshot.bindingId}:${policySnapshot.bindingRevision}:${policySnapshot.contentHash}',
      ),
    );

    late final Elv5RouteAmpacityInput ampacity;
    try {
      ampacity = await ampacityResolver.resolve(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
        cableRunId: cableRunId,
      );
    } on Elv5AmpacityRouteResolutionException catch (error) {
      _blocked(
        request,
        error.code,
        basisFingerprint,
        policySnapshot.contentHash,
        dependencies,
        error.details,
      );
    }

    final cableFacts = await routeCableFacts.loadForCableRun(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      cableRunId: cableRunId,
    );
    if (cableFacts.isEmpty) {
      _blocked(
        request,
        'FA08_ROUTE_CABLE_FACTS_REQUIRED',
        basisFingerprint,
        policySnapshot.contentHash,
        dependencies,
        <String, Object?>{'cableRunId': cableRunId},
      );
    }

    final factBySection = <String, Fa08RouteCableFact>{};
    for (final fact in cableFacts) {
      if (factBySection.putIfAbsent(fact.sectionId, () => fact) != fact) {
        _blocked(
          request,
          'FA08_ROUTE_CABLE_FACT_SECTION_DUPLICATE',
          basisFingerprint,
          policySnapshot.contentHash,
          dependencies,
          <String, Object?>{'sectionId': fact.sectionId},
        );
      }
    }
    final ampacityIds = ampacity.orderedSections.map((e) => e.sectionId).toSet();
    final factIds = factBySection.keys.toSet();
    if (ampacityIds.length != factIds.length ||
        !ampacityIds.containsAll(factIds)) {
      _blocked(
        request,
        'FA08_ROUTE_SECTION_SET_MISMATCH',
        basisFingerprint,
        policySnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'ampacitySections': ampacityIds.toList()..sort(),
          'cableFactSections': factIds.toList()..sort(),
        },
      );
    }

    final sections = <Fa08RouteSection>[];
    final evidenceBasis = <Map<String, Object?>>[];
    for (final section in ampacity.orderedSections) {
      final fact = factBySection[section.sectionId]!;
      final environment = section.environmentBinding.profile;
      final tags = <String>{
        'EXPOSURE:${environment.exposure.name.toUpperCase()}',
        'CONDENSATION:${environment.condensationRisk.name.toUpperCase()}',
        if (environment.moistureClassCode != null)
          'MOISTURE:${environment.moistureClassCode}',
        if (environment.contaminationClassCode != null)
          'CONTAMINATION:${environment.contaminationClassCode}',
        if (environment.climateClassCode != null)
          'CLIMATE:${environment.climateClassCode}',
      };

      sections.add(
        Fa08RouteSection(
          sectionId: section.sectionId,
          cableEditionId: fact.cableEditionId,
          cableClass: fact.cableClass,
          environmentEvidenceComplete: true,
          environmentTags: tags,
          numericFacts: fact.numericFacts,
          ampacityInput: section.ampacityInput,
        ),
      );

      dependencies.add(
        _dependency(
          request,
          'POLICY',
          'ELV5_ENVIRONMENT_PROFILE',
          environment.evidenceRef,
          memberId:
              '${section.environmentBinding.bindingId}:${environment.editionId}:${environment.evidenceContentHash}',
        ),
      );
      for (final evidence in <Map<String, String>>[
        <String, String>{
          'domain': 'AMPACITY_REFERENCE_ROW',
          'ref': section.ampacityInput.referenceRow.evidenceRef,
          'hash': section.ampacityInput.referenceRow.evidenceContentHash,
        },
        <String, String>{
          'domain': 'AMPACITY_TEMPERATURE_CORRECTION',
          'ref': section.ampacityInput.temperatureCorrection.evidenceRef,
          'hash': section.ampacityInput.temperatureCorrection.evidenceContentHash,
        },
        <String, String>{
          'domain': 'AMPACITY_GROUPING_CORRECTION',
          'ref': section.ampacityInput.groupingCorrection.evidenceRef,
          'hash': section.ampacityInput.groupingCorrection.evidenceContentHash,
        },
      ]) {
        dependencies.add(
          _dependency(
            request,
            'POLICY',
            evidence['domain']!,
            evidence['ref']!,
            memberId: evidence['hash'],
          ),
        );
      }
      for (final correction in section.ampacityInput.additionalCorrections) {
        dependencies.add(
          _dependency(
            request,
            'POLICY',
            'AMPACITY_ADDITIONAL_CORRECTION',
            correction.evidenceRef,
            memberId: '${correction.code}:${correction.evidenceContentHash}',
          ),
        );
      }
      evidenceBasis.add(<String, Object?>{
        'sectionId': section.sectionId,
        'cableEditionId': fact.cableEditionId,
        'environment': section.environmentBinding.toCanonicalValue(),
        'ampacity': section.ampacityInput.toCanonicalValue(),
      });
    }

    final input = Fa08Input(
      orderedSections: sections,
      policy: policySnapshot.contract.policy,
      // ELV7 alone owns verified jurisdictional compliance. Until an exact
      // ELV7 evidence source is wired, this axis must remain NOT_ASSESSED.
      complianceEvidence: null,
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-fa08-captured-input.v1',
      'cableRunId': cableRunId,
      'policyEvidenceRef': policySnapshot.evidenceRef,
      'policyContentHash': policySnapshot.contentHash,
      'sections': evidenceBasis,
    });

    return Elv5CapturedInput<Fa08Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: policySnapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: policySnapshot.bindingRevision,
    );
  }

  Never _blocked(
    Elv5CalculationRequest request,
    String reasonCode,
    String inputFingerprint,
    String policyFingerprint,
    List<Elv5DependencyMarker> dependencies,
    Map<String, Object?> evidence,
  ) {
    throw Elv5CaptureBlockedException(
      request: request,
      reasonCode: reasonCode,
      inputFingerprint: inputFingerprint,
      policyFingerprint: policyFingerprint,
      dependencies: dependencies,
      evidence: evidence,
    );
  }

  Elv5DependencyMarker _dependency(
    Elv5CalculationRequest request,
    String relationKind,
    String domain,
    String subjectId, {
    String? memberId,
  }) {
    final value = <String, Object?>{
      'schema': 'electra.elv5-dependency-key.v1',
      'relationKind': relationKind,
      'domain': domain,
      'subjectId': subjectId,
      if (memberId != null) 'memberId': memberId,
    };
    return Elv5DependencyMarker(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      dependencyKey: utf8.decode(_encoder.encode(value)),
      dependencyKeySha256: _encoder.sha256(value),
      logicalNodeKeySha256: _encoder.sha256(request.nodeKey.toCanonicalValue()),
      relationKind: relationKind,
      updatedAtUtc: _nowUtc().toUtc(),
    );
  }
}

Elv5PureKernelExecutor<Fa08Input, Fa08Result> buildFa08Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Fa08Input, Fa08Result>(
  processCode: Elv5ProcessCode.fa08,
  calculate: const Fa08CablePolicyKernel().evaluate,
  encodeOutput: (result) => <String, Object?>{
    'schema': 'electra.elv5-fa08-output.v1',
    'technicalPolicyMatch': result.technicalPolicyMatch.name,
    'verifiedCompliance': result.verifiedCompliance.name,
    'limitingSectionId': result.limitingSectionId,
    'limitingRequirementCode': result.limitingRequirementCode,
    'policyResults': <Object?>[
      for (final item in result.policyResults)
        <String, Object?>{
          'sectionId': item.sectionId,
          'requirementCode': item.requirementCode,
          'status': item.status.name,
          'numericMargin': item.numericMargin?.toMap(),
        },
    ],
  },
  encodeEvidence: (captured, _) => <String, Object?>{
    'schema': 'electra.elv5-fa08-evidence.v1',
    'source':
        'PINNED_CABLE_EDITION_PLUS_VERSIONED_ENVIRONMENT_PLUS_EXACT_ROUTE_AMPACITY',
    'captureRevision': captured.captureRevision,
    'verifiedComplianceOwner': 'ELV7',
  },
  executionOf: (result) =>
      result.technicalPolicyMatch == Fa08AssessmentStatus.blocked
          ? Elv5Execution.blocked
          : Elv5Execution.succeeded,
  completionOf: (result) =>
      result.technicalPolicyMatch == Fa08AssessmentStatus.blocked
          ? Elv5Completion.incomplete
          : Elv5Completion.complete,
  assessmentOf: (result) => switch (result.technicalPolicyMatch) {
    Fa08AssessmentStatus.pass => Elv5Assessment.pass,
    Fa08AssessmentStatus.fail => Elv5Assessment.fail,
    Fa08AssessmentStatus.blocked => Elv5Assessment.unresolved,
    Fa08AssessmentStatus.notAssessed => Elv5Assessment.unresolved,
  },
  nowUtc: nowUtc,
);
