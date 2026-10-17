import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv5_lan_persistence.dart';
import 'lan04_compatibility_contract.dart';

final class Lan04PersistedInputResolver
    implements Elv5ProcessInputResolver<Lan04Input> {
  Lan04PersistedInputResolver({
    required this.lanStore,
    required this.contractSource,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5LanFactStore lanStore;
  final Lan04CompatibilityContractSource contractSource;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.lan04;

  @override
  Future<Elv5CapturedInput<Lan04Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('LAN04_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'LINK') {
      throw StateError('LAN04_SUBJECT_KIND_MUST_BE_LINK');
    }
    final linkId = request.subject.id;
    final composition = await lanStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_LINK_COMPOSITION',
      subjectId: linkId,
    );
    final basis = _encoder.sha256(<String,Object?>{
      'schema':'electra.elv5-lan04-basis.v1','linkId':linkId,
    });
    if (composition == null) {
      _blocked(request,'LAN04_LINK_COMPOSITION_REQUIRED',basis,basis,
          const <Elv5DependencyMarker>[],<String,Object?>{'linkId':linkId});
    }
    if (_text(composition!.payload,'linkId') != linkId) {
      throw StateError('LAN04_LINK_IDENTITY_MISMATCH:$linkId');
    }
    final compositionFingerprint = _encoder.sha256(composition.payload);
    final dependencies=<Elv5DependencyMarker>[
      _dependency(request,'SET','LAN_LINK_COMPOSITION',linkId),
    ];

    final snapshot=await contractSource.loadActiveForLink(
      projectId:request.projectId,designRevisionId:request.designRevisionId,linkId:linkId,
    );
    if(snapshot==null){
      _blocked(request,'LAN04_COMPATIBILITY_CONTRACT_REQUIRED',compositionFingerprint,
          compositionFingerprint,dependencies,<String,Object?>{'linkId':linkId});
    }
    final contract=snapshot!.contract;
    dependencies.add(_dependency(request,'POLICY','LAN04_COMPATIBILITY_CONTRACT',
        snapshot.evidenceRef,memberId:'${snapshot.bindingId}:${snapshot.bindingRevision}:${snapshot.contentHash}'));
    if(contract.linkId!=linkId||contract.expectedCompositionFingerprint!=compositionFingerprint){
      _blocked(request,'LAN04_LINK_COMPOSITION_FINGERPRINT_MISMATCH',compositionFingerprint,
          snapshot.contentHash,dependencies,<String,Object?>{
            'expected':contract.expectedCompositionFingerprint,'actual':compositionFingerprint,
          });
    }

    final rows=_objects(composition.payload['orderedSections'],'orderedSections')
      ..sort((a,b)=>_ordinal(a).compareTo(_ordinal(b)));
    for(var i=0;i<rows.length;i++){
      if(_ordinal(rows[i])!=i){
        _blocked(request,'LAN04_SECTION_ORDINAL_CLOSURE_INVALID',compositionFingerprint,
            snapshot.contentHash,dependencies,<String,Object?>{'expectedOrdinal':i,'actualOrdinal':_ordinal(rows[i])});
      }
    }
    final pathIds=<String>[for(final row in rows)_text(row,'realizedSectionId')];
    final contractIds=<String>[for(final section in contract.sections)section.sectionId];
    if(pathIds.length!=contractIds.length||
        List.generate(pathIds.length,(i)=>pathIds[i]==contractIds[i]).contains(false)){
      _blocked(request,'LAN04_SECTION_MEMBERSHIP_ORDER_MISMATCH',compositionFingerprint,
          snapshot.contentHash,dependencies,<String,Object?>{'pathSections':pathIds,'contractSections':contractIds});
    }

    final input=Lan04Input(
      linkId:linkId,
      orderedSections:<Lan04PathSection>[
        for(final section in contract.sections)
          Lan04PathSection(
            sectionId:section.sectionId,
            medium:_medium(section.mediumCode),
            supportedInterfaceKinds:section.supportedInterfaceKinds,
            supportedSpeedModes:section.supportedSpeedModes,
            supportedConnectorKinds:section.supportedConnectorKinds,
            shieldContinuityKnown:section.shieldContinuityKnown,
            shieldContinuity:section.shieldContinuity,
          ),
      ],
      requiredMode:Lan04RequiredMode(
        medium:_medium(contract.requiredMediumCode),
        interfaceKind:contract.requiredInterfaceKind,
        speedMode:contract.requiredSpeedMode,
        connectorKind:contract.requiredConnectorKind,
        shieldingRequired:contract.shieldingRequired,
      ),
    );
    for(final section in contract.sections){
      dependencies.add(_dependency(request,'FACT','LAN04_SECTION_CAPABILITY',section.sectionId,
          memberId:'${section.evidenceRef}:${section.evidenceContentHash}'));
    }
    final inputFingerprint=_encoder.sha256(<String,Object?>{
      'schema':'electra.elv5-lan04-captured-input.v1',
      'compositionFingerprint':compositionFingerprint,
      'contractEvidenceRef':snapshot.evidenceRef,
      'contractContentHash':snapshot.contentHash,
    });
    return Elv5CapturedInput<Lan04Input>(
      request:request,value:input,inputFingerprint:inputFingerprint,
      policyFingerprint:snapshot.contentHash,dependencies:dependencies,
      upstreamPointerGenerations:const <String,int>{},captureRevision:composition.revision,
    );
  }

  Never _blocked(Elv5CalculationRequest request,String reason,String input,String policy,
      List<Elv5DependencyMarker> deps,Map<String,Object?> evidence)=>
    throw Elv5CaptureBlockedException(request:request,reasonCode:reason,inputFingerprint:input,
      policyFingerprint:policy,dependencies:deps,evidence:evidence);
  Elv5DependencyMarker _dependency(Elv5CalculationRequest request,String relation,String domain,String subjectId,{String? memberId}){
    final value=<String,Object?>{'schema':'electra.elv5-dependency-key.v1','relationKind':relation,'domain':domain,'subjectId':subjectId,if(memberId!=null)'memberId':memberId};
    return Elv5DependencyMarker(projectId:request.projectId,designRevisionId:request.designRevisionId,
      dependencyKey:utf8.decode(_encoder.encode(value)),dependencyKeySha256:_encoder.sha256(value),
      logicalNodeKeySha256:_encoder.sha256(request.nodeKey.toCanonicalValue()),relationKind:relation,updatedAtUtc:_nowUtc().toUtc());
  }
}

Elv5PureKernelExecutor<Lan04Input,Lan04Result> buildLan04Executor({DateTime Function()? nowUtc})=>
  Elv5PureKernelExecutor<Lan04Input,Lan04Result>(
    processCode:Elv5ProcessCode.lan04,calculate:const Lan04PathCompatibilityKernel().evaluate,
    encodeOutput:(r)=><String,Object?>{
      'schema':'electra.elv5-lan04-output.v1','status':r.status.name,
      'limitingSectionId':r.limitingSectionId,'limitingProperty':r.limitingProperty?.name,
      'sections':<Object?>[
        for(final section in r.sections)<String,Object?>{
          'sectionId':section.sectionId,'status':section.status.name,
          'statusByProperty':<String,Object?>{
            for(final entry in section.statusByProperty.entries)entry.key.name:entry.value.name,
          },
        },
      ],
    },
    encodeEvidence:(c,_)=><String,Object?>{
      'schema':'electra.elv5-lan04-evidence.v1',
      'source':'PERSISTED_LINK_COMPOSITION_PLUS_IMMUTABLE_SECTION_CAPABILITIES',
      'captureRevision':c.captureRevision,
    },
    executionOf:(_)=>Elv5Execution.succeeded,
    completionOf:(r)=>(r.status==Lan04AssessmentStatus.unresolved||r.status==Lan04AssessmentStatus.unsupported)
        ?Elv5Completion.incomplete:Elv5Completion.complete,
    assessmentOf:(r)=>switch(r.status){
      Lan04AssessmentStatus.pass=>Elv5Assessment.pass,
      Lan04AssessmentStatus.fail=>Elv5Assessment.fail,
      Lan04AssessmentStatus.unresolved=>Elv5Assessment.unresolved,
      Lan04AssessmentStatus.unsupported=>Elv5Assessment.unresolved,
    },
    nowUtc:nowUtc,
  );

Lan04Medium _medium(String code)=>switch(code.trim().toUpperCase()){
  'COPPER'=>Lan04Medium.copper,'FIBER'=>Lan04Medium.fiber,'OTHER'=>Lan04Medium.other,
  _=>throw StateError('LAN04_UNSUPPORTED_MEDIUM:$code'),
};
int _ordinal(Map<String,Object?> value){final raw=value['ordinal'];if(raw is! int||raw<0)throw FormatException('ordinal must be nonnegative integer.');return raw;}
List<Map<String,Object?>> _objects(Object? value,String field){if(value is! List)throw FormatException('$field must be array.');return [for(final raw in value)if(raw is Map)Map<String,Object?>.from(raw)else throw FormatException('$field entry must be object.')];}
String _text(Map<String,Object?> map,String key){final value=map[key];if(value is! String||value.trim().isEmpty)throw FormatException('$key must be text.');return value.trim();}
