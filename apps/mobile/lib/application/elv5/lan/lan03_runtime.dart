import 'dart:convert';

import 'package:engineering_core/engineering_core.dart'
    show PowerEvaluationScopeKind, PowerProcessCode;
import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import '../power/elv4_current_evidence_source.dart';
import 'lan03_poe_contract.dart';

final class Lan03PersistedInputResolver
    implements Elv5ProcessInputResolver<Lan03Input> {
  Lan03PersistedInputResolver({
    required this.contractSource,
    required this.powerEvidence,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Lan03PoeProjectionContractSource contractSource;
  final Elv4CurrentEvidenceSource powerEvidence;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.lan03;

  @override
  Future<Elv5CapturedInput<Lan03Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('LAN03_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'PSE') {
      throw StateError('LAN03_SUBJECT_KIND_MUST_BE_PSE');
    }
    final pseId = request.subject.id;
    final basis = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan03-basis.v1',
      'pseId': pseId,
    });
    final dependencies = <Elv5DependencyMarker>[];
    final contractSnapshot = await contractSource.loadActiveForPse(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      pseId: pseId,
    );
    if (contractSnapshot == null) {
      _blocked(request, 'LAN03_POE_CONTRACT_REQUIRED', basis, basis,
          dependencies, <String, Object?>{'pseId': pseId});
    }
    final contract = contractSnapshot!.contract;
    if (contract.pseId != pseId) {
      throw StateError('LAN03_CONTRACT_PSE_IDENTITY_MISMATCH:$pseId');
    }
    dependencies.add(_dependency(
      request,
      'POLICY',
      'LAN03_POE_PROJECTION_CONTRACT',
      contractSnapshot.evidenceRef,
      memberId:
          '${contractSnapshot.bindingId}:${contractSnapshot.bindingRevision}:${contractSnapshot.contentHash}',
    ));

    final current = await powerEvidence.loadCurrent(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      processCode: PowerProcessCode.pwr06,
      scenarioId: contract.scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: contract.segmentId,
    );
    final group = <Elv4CurrentEvaluationSnapshot>[];
    for (final snapshot in current) {
      final output = snapshot.output;
      if (output['groupId'] == pseId) group.add(snapshot);
    }
    group.sort((a, b) => a.nodeKey.subjectId.compareTo(b.nodeKey.subjectId));
    final actualDeliveries = <String>{for (final value in group) value.nodeKey.subjectId};
    final expectedDeliveries = contract.expectedInputFingerprintByDeliveryId.keys.toSet();
    if (actualDeliveries.length != expectedDeliveries.length ||
        !actualDeliveries.containsAll(expectedDeliveries)) {
      _blocked(
        request,
        'LAN03_PWR06_DELIVERY_SET_MISMATCH',
        basis,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'expected': expectedDeliveries.toList()..sort(),
          'actual': actualDeliveries.toList()..sort(),
        },
      );
    }

    List<Map<String, Object?>>? canonicalMembers;
    Elv5Rational? globalDemand;
    Elv5Rational? globalMargin;
    String? closureFingerprint;
    final generations = <String, int>{};
    final upstream = <Map<String, Object?>>[];

    for (final snapshot in group) {
      final deliveryId = snapshot.nodeKey.subjectId;
      if (snapshot.nodeKey.subjectKind != 'POE_DELIVERY') {
        _blocked(request, 'LAN03_PWR06_SUBJECT_KIND_MISMATCH', basis,
            contractSnapshot.contentHash, dependencies,
            <String, Object?>{'deliveryId': deliveryId, 'subjectKind': snapshot.nodeKey.subjectKind});
      }
      if (snapshot.inputFingerprint !=
          contract.expectedInputFingerprintByDeliveryId[deliveryId]) {
        _blocked(request, 'LAN03_PWR06_INPUT_FINGERPRINT_MISMATCH', basis,
            contractSnapshot.contentHash, dependencies, <String, Object?>{
              'deliveryId': deliveryId,
              'expected': contract.expectedInputFingerprintByDeliveryId[deliveryId],
              'actual': snapshot.inputFingerprint,
            });
      }
      final members = _membership(snapshot);
      final fingerprint = lan03Pwr06ClosureFingerprint(pseId: pseId, members: members);
      if (closureFingerprint != null && closureFingerprint != fingerprint) {
        _blocked(request, 'LAN03_PWR06_GROUP_MEMBERSHIP_DIVERGED', basis,
            contractSnapshot.contentHash, dependencies,
            <String, Object?>{'deliveryId': deliveryId});
      }
      closureFingerprint = fingerprint;
      canonicalMembers ??= members;

      final output = snapshot.output;
      final demand = _rational(output['groupReservedW'], 'groupReservedW');
      final margin = _rational(output['groupMarginW'], 'groupMarginW');
      if (globalDemand != null && globalDemand != demand ||
          globalMargin != null && globalMargin != margin) {
        _blocked(request, 'LAN03_PWR06_GROUP_TOTALS_DIVERGED', basis,
            contractSnapshot.contentHash, dependencies,
            <String, Object?>{'deliveryId': deliveryId});
      }
      globalDemand = demand;
      globalMargin = margin;

      generations[snapshot.nodeKey.sha256] = snapshot.pointerGeneration;
      dependencies.add(_dependency(
        request,
        'EVAL',
        'ELV4_PWR06_CURRENT',
        snapshot.evaluationId,
        memberId:
            '${snapshot.nodeKey.sha256}:${snapshot.pointerGeneration}:${snapshot.evidenceSha256}',
      ));
      upstream.add(<String, Object?>{
        'evaluationId': snapshot.evaluationId,
        'nodeKeySha256': snapshot.nodeKey.sha256,
        'generation': snapshot.pointerGeneration,
        'evidenceSha256': snapshot.evidenceSha256,
      });
    }

    if (closureFingerprint != contract.expectedClosureFingerprint) {
      _blocked(request, 'LAN03_PWR06_CLOSURE_MISMATCH', basis,
          contractSnapshot.contentHash, dependencies, <String, Object?>{
            'expected': contract.expectedClosureFingerprint,
            'actual': closureFingerprint,
          });
    }
    if (globalDemand == null || globalMargin == null || canonicalMembers == null) {
      _blocked(request, 'LAN03_PWR06_GROUP_EVIDENCE_MISSING', basis,
          contractSnapshot.contentHash, dependencies,
          <String, Object?>{'pseId': pseId});
    }

    final contributors = <Lan03Pwr06Contributor>[
      for (final member in canonicalMembers!)
        Lan03Pwr06Contributor(
          loadId: member['originId']! as String,
          power: Power(Elv5Rational.fromMap(
            Map<String, Object?>.from(member['reservedW']! as Map),
          )),
        ),
    ];
    final demand = globalDemand!;
    final margin = globalMargin!;
    final input = Lan03Input(
      pseId: pseId,
      expectedClosureFingerprint: contract.expectedClosureFingerprint,
      lanLoadIds: contract.lanLoadIds,
      evidence: Lan03Pwr06Evidence(
        pseId: pseId,
        closureFingerprint: closureFingerprint!,
        globalDemand: Power(demand),
        availableCapability: Power(demand + margin),
        globalMargin: Power(margin),
        governingCaseId: contract.segmentId,
        contributors: contributors,
      ),
    );
    upstream.sort((a, b) => (a['evaluationId']! as String)
        .compareTo(b['evaluationId']! as String));
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan03-captured-input.v1',
      'contractEvidenceRef': contractSnapshot.evidenceRef,
      'contractContentHash': contractSnapshot.contentHash,
      'closureFingerprint': closureFingerprint,
      'upstream': upstream,
    });
    return Elv5CapturedInput<Lan03Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: contractSnapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: generations,
      captureRevision: contractSnapshot.bindingRevision,
    );
  }

  List<Map<String, Object?>> _membership(Elv4CurrentEvaluationSnapshot snapshot) {
    final raw = snapshot.evidence['consumedFacts'];
    if (raw is! List) {
      throw StateError('LAN03_PWR06_CONSUMED_FACTS_MISSING:${snapshot.evaluationId}');
    }
    final matches = <Map<String, Object?>>[];
    for (final value in raw) {
      if (value is! Map) continue;
      final fact = Map<String, Object?>.from(value);
      if (fact['valueSchema'] == 'electra.elv4.poe-membership.v1' &&
          fact['presence'] == 'PRESENT') {
        matches.add(fact);
      }
    }
    if (matches.length != 1) {
      throw StateError('LAN03_PWR06_MEMBERSHIP_FACT_AMBIGUOUS:${snapshot.evaluationId}');
    }
    final canonical = matches.single['canonicalValueJson'];
    if (canonical is! String) {
      throw StateError('LAN03_PWR06_MEMBERSHIP_VALUE_MISSING:${snapshot.evaluationId}');
    }
    final decoded = jsonDecode(canonical);
    if (decoded is! List) {
      throw StateError('LAN03_PWR06_MEMBERSHIP_VALUE_INVALID:${snapshot.evaluationId}');
    }
    final members = <Map<String, Object?>>[];
    for (final rawMember in decoded) {
      if (rawMember is! Map) {
        throw StateError('LAN03_PWR06_MEMBERSHIP_MEMBER_INVALID:${snapshot.evaluationId}');
      }
      final member = Map<String, Object?>.from(rawMember);
      members.add(<String, Object?>{
        'originId': _text(member, 'originId'),
        'portId': _text(member, 'portId'),
        'reservedW': _map(member['reservedW'], 'reservedW'),
      });
    }
    members.sort((a, b) => (a['originId']! as String).compareTo(b['originId']! as String));
    return members;
  }

  Never _blocked(Elv5CalculationRequest request,String reason,String input,String policy,
      List<Elv5DependencyMarker> dependencies,Map<String,Object?> evidence)=>
    throw Elv5CaptureBlockedException(request:request,reasonCode:reason,
      inputFingerprint:input,policyFingerprint:policy,dependencies:dependencies,evidence:evidence);

  Elv5DependencyMarker _dependency(Elv5CalculationRequest request,String relation,String domain,String subjectId,{String? memberId}){
    final value=<String,Object?>{'schema':'electra.elv5-dependency-key.v1','relationKind':relation,'domain':domain,'subjectId':subjectId,if(memberId!=null)'memberId':memberId};
    return Elv5DependencyMarker(projectId:request.projectId,designRevisionId:request.designRevisionId,
      dependencyKey:utf8.decode(_encoder.encode(value)),dependencyKeySha256:_encoder.sha256(value),
      logicalNodeKeySha256:_encoder.sha256(request.nodeKey.toCanonicalValue()),relationKind:relation,updatedAtUtc:_nowUtc().toUtc());
  }
}

Elv5PureKernelExecutor<Lan03Input,Lan03Result> buildLan03Executor({DateTime Function()? nowUtc})=>
  Elv5PureKernelExecutor<Lan03Input,Lan03Result>(
    processCode:Elv5ProcessCode.lan03,calculate:const Lan03PoeProjectionKernel().evaluate,
    encodeOutput:(r)=><String,Object?>{
      'schema':'electra.elv5-lan03-output.v1','status':r.status.name,
      'globalDemandW':r.globalDemand.value.toMap(),'availableCapabilityW':r.availableCapability.value.toMap(),
      'globalMarginW':r.globalMargin.value.toMap(),'lanContributionW':r.lanContribution.value.toMap(),
      'governingCaseId':r.governingCaseId,'blockingReason':r.blockingReason,
    },
    encodeEvidence:(c,_)=><String,Object?>{
      'schema':'electra.elv5-lan03-evidence.v1','source':'VERIFIED_CURRENT_PWR06_GROUP_CLOSURE',
      'upstreamPointerGenerations':c.upstreamPointerGenerations,
    },
    executionOf:(r)=>r.status==Lan03AssessmentStatus.blocked?Elv5Execution.blocked:Elv5Execution.succeeded,
    completionOf:(r)=>r.status==Lan03AssessmentStatus.blocked?Elv5Completion.incomplete:Elv5Completion.complete,
    assessmentOf:(r)=>switch(r.status){Lan03AssessmentStatus.pass=>Elv5Assessment.pass,Lan03AssessmentStatus.fail=>Elv5Assessment.fail,Lan03AssessmentStatus.blocked=>Elv5Assessment.unresolved},
    nowUtc:nowUtc,
  );

Elv5Rational _rational(Object? value,String field)=>Elv5Rational.fromMap(_map(value,field));
Map<String,Object?> _map(Object? value,String field){if(value is! Map)throw FormatException('$field must be object.');return Map<String,Object?>.from(value);}
String _text(Map<String,Object?> map,String key){final value=map[key];if(value is! String||value.trim().isEmpty)throw FormatException('$key must be text.');return value.trim();}
