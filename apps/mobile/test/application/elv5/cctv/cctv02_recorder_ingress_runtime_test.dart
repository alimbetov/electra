import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv02_runtime.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv_recorder_assignment_source.dart';
import 'package:electra_mobile/application/elv5/cctv/elv5_cctv_persistence.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('explicit recorder assignment enables recorder ingress without receiver inference',() async{
    final store=_Store(Elv5CctvAggregateSnapshot(
      aggregateKind:'CCTV_CAMERA_STREAMS',aggregateId:'a',subjectId:'cam-1',revision:2,
      payload:<String,Object?>{
        'cameraId':'cam-1',
        'streams':<Object?>[<String,Object?>{
          'encodedStreamId':'main','codecProfileRef':'H264','expectedBitrateBps':'8000000','peakBitrateBps':'12000000',
          'expectedRateEvidence':<String,Object?>{},'peakRateEvidence':<String,Object?>{},
        }],
        'subscriptions':<Object?>[<String,Object?>{
          'subscriptionId':'rec-feed','encodedStreamId':'main','receiverId':'rec-1','deliveryMode':'UNICAST',
          'orderedNetworkEdgeIds':<String>['edge-1'],'multicastGroupId':null,'multicastTree':null,
        }],
        'transportOverheadModelRef':null,
      },
    ));
    final resolver=Cctv02PersistedInputResolver(
      store:store,
      recorderAssignments:const _Assignments(),
    );
    final captured=await resolver.capture(_request());
    final result=const Cctv02BandwidthKernel().evaluate(captured.value);
    expect(result.recorderIngress.keys,contains('rec-1'));
    expect(result.recorderIngress['rec-1']!.peak.complete,isTrue);
    expect(result.recorderIngress['rec-1']!.peak.load.value,Elv5Rational.integer(12000000));
    expect(captured.dependencies.any((d)=>d.dependencyKey.contains('CCTV_RECORDER_ASSIGNMENT')),isTrue);
  });
}

Elv5CalculationRequest _request()=>Elv5CalculationRequest(
  projectId:'p',designRevisionId:'d',
  scope:Elv5ScopeRef(kind:Elv5ScopeKind.design,scopeId:'d',scenarioKey:'NONE'),
  processCode:Elv5ProcessCode.cctv02,subject:Elv5SubjectRef(kind:'CAMERA',id:'cam-1'),expectedPointerGeneration:0,
);

final class _Assignments implements CctvRecorderAssignmentSource{
  const _Assignments();
  @override
  Future<List<CctvRecorderAssignmentRef>> loadForCamera({required String projectId,required String designRevisionId,required String cameraId}) async=>
    <CctvRecorderAssignmentRef>[CctvRecorderAssignmentRef(bindingId:'r',bindingRevision:3,recorderId:'rec-1',assignmentId:'a1',cameraId:'cam-1',encodedStreamId:'main',licenseChannelId:'ch-1',storagePoolId:'pool-1')];
}
final class _Store implements Elv5CctvMutationStore{
  const _Store(this.camera);final Elv5CctvAggregateSnapshot camera;
  @override Future<Elv5CctvAggregateSnapshot?> loadCameraStreams({required String projectId,required String designRevisionId,required String cameraId})async=>camera;
  @override Future<Elv5CctvAggregateSnapshot?> loadRecordingPool({required String projectId,required String designRevisionId,required String poolId})async=>null;
  @override Future<void> replaceCameraStreams({required String projectId,required String designRevisionId,required String cameraId,required String bindingId,required int? expectedRootRevision,required Map<String,Object?> payload,required DateTime updatedAtUtc})=>throw UnimplementedError();
  @override Future<void> replaceRecordingPool({required String projectId,required String designRevisionId,required String poolId,required String bindingId,required int? expectedRootRevision,required Map<String,Object?> payload,required DateTime updatedAtUtc})=>throw UnimplementedError();
}
