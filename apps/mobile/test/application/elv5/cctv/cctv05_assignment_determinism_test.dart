import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_current_evaluation_source.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv05_capability_contract.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv05_runtime.dart';
import 'package:electra_mobile/application/elv5/cctv/elv5_cctv_persistence.dart';
import 'package:electra_mobile/application/elv5/cctv/elv5_cctv_recorder_persistence.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recorder row order does not change CCTV-05 captured identity or result', () async {
    Future<Elv5CapturedInput<Cctv05Input>> capture(bool reversed) =>
        Cctv05PersistedInputResolver(
          recorderStore: _Recorder(reversed),
          cctvStore: const _Cctv(),
          contractSource: _Contract(_contract()),
          currentEvaluations: const _Current(),
          nowUtc: () => DateTime.utc(2026, 10, 17),
        ).capture(_request());

    final left = await capture(false);
    final right = await capture(true);
    final executor = buildCctv05Executor(
      nowUtc: () => DateTime.utc(2026, 10, 17),
    );
    final leftResult = await executor.execute(left);
    final rightResult = await executor.execute(right);

    expect(left.inputFingerprint, right.inputFingerprint);
    expect(leftResult.outputSha256, rightResult.outputSha256);
    expect(leftResult.evidenceSha256, rightResult.evidenceSha256);
    expect(leftResult.assessment, Elv5Assessment.pass);
    expect(leftResult.output['consumedChannels'], 2);
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'p',
  designRevisionId: 'd',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'd',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.cctv05,
  subject: Elv5SubjectRef(kind: 'RECORDER', id: 'rec-1'),
  expectedPointerGeneration: 0,
);

Cctv05CapabilityContract _contract() => Cctv05CapabilityContract(
  recorderId: 'rec-1',
  expectedDefinitionId: 'rec-def',
  expectedDefinitionVersion: 2,
  channelLimit: 3,
  peakIngressCapacityBps: Elv5Rational.integer(20000000),
  usableStorageCapacityBytes: Elv5Rational.integer(1000),
  supportedCodecProfiles: const ['H264'],
  requireGuaranteedStorage: true,
  expectedCctv02InputFingerprintByCamera: <String,String>{'cam-1': _h('a')},
  expectedCctv03InputFingerprintByPool: <String,String>{'pool-1': _h('b')},
);

final class _Recorder implements Elv5CctvRecorderFactStore {
  const _Recorder(this.reversed);
  final bool reversed;

  @override
  Future<Elv5CctvRecorderSnapshot?> loadRecorder({
    required String projectId,
    required String designRevisionId,
    required String recorderId,
  }) async {
    final rows = <Map<String,Object?>>[
      <String,Object?>{
        'assignmentId':'a1','cameraId':'cam-1','encodedStreamId':'main',
        'licenseChannelId':'ch-1','storagePoolId':'pool-1',
      },
      <String,Object?>{
        'assignmentId':'a2','cameraId':'cam-1','encodedStreamId':'sub',
        'licenseChannelId':'ch-2','storagePoolId':'pool-1',
      },
    ];
    if (reversed) rows.reverse();
    return Elv5CctvRecorderSnapshot(
      aggregateId: 'rec-bind',
      recorderId: 'rec-1',
      revision: 4,
      payload: <String,Object?>{
        'recorderId':'rec-1',
        'accountingBasis':'ENCODED_STREAM',
        'recorderDefinitionRef':<String,Object?>{
          'componentId':'rec-1','definitionId':'rec-def','definitionVersion':2,
        },
        'recorderDefinitionSha256':_h('d'),
        'assignments': rows,
      },
    );
  }
}

final class _Cctv implements Elv5CctvFactStore {
  const _Cctv();
  @override
  Future<Elv5CctvAggregateSnapshot?> loadCameraStreams({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
  }) async => Elv5CctvAggregateSnapshot(
    aggregateKind:'CCTV_CAMERA_STREAMS',aggregateId:'cam-bind',subjectId:'cam-1',revision:3,
    payload:<String,Object?>{
      'cameraId':'cam-1',
      'streams':<Object?>[
        <String,Object?>{'encodedStreamId':'main','codecProfileRef':'H264'},
        <String,Object?>{'encodedStreamId':'sub','codecProfileRef':'H264'},
      ],
    },
  );
  @override
  Future<Elv5CctvAggregateSnapshot?> loadRecordingPool({
    required String projectId,
    required String designRevisionId,
    required String poolId,
  }) async => null;
}

final class _Contract implements Cctv05CapabilityContractSource {
  const _Contract(this.value);
  final Cctv05CapabilityContract value;
  @override
  Future<Cctv05CapabilityContractSnapshot?> loadActiveForRecorder({
    required String projectId,
    required String designRevisionId,
    required String recorderId,
  }) async => Cctv05CapabilityContractSnapshot(
    bindingId:'cap',bindingRevision:2,
    evidenceRef:'CCTV05:rec-1:${_h('c')}',contentHash:_h('c'),contract:value,
  );
}

final class _Current implements Elv5CurrentEvaluationSource {
  const _Current();
  @override
  Future<List<Elv5CurrentEvaluationSnapshot>> loadCurrent({
    required String projectId,
    required String designRevisionId,
    required Elv5ProcessCode processCode,
    String? scopeKind,String? scopeId,String? scenarioKey,String? subjectKind,String? subjectId,
  }) async {
    if (processCode == Elv5ProcessCode.cctv02) {
      return <Elv5CurrentEvaluationSnapshot>[
        Elv5CurrentEvaluationSnapshot(
          logicalNodeKeySha256:_h('1'),processCode:processCode,scopeKind:'DESIGN',scopeId:'d',scenarioKey:'NONE',
          subjectKind:'CAMERA',subjectId:'cam-1',evaluationId:'eval-c02',inputFingerprint:_h('a'),
          outputSha256:_h('2'),evidenceSha256:_h('3'),pointerGeneration:5,
          execution:'SUCCEEDED',completion:'COMPLETE',assessment:'NOT_ASSESSED',
          output:<String,Object?>{
            'recorderIngress':<String,Object?>{
              'rec-1':<String,Object?>{
                'peak':<String,Object?>{'loadBps':_r(12000000),'complete':true},
              },
            },
          },evidence:const <String,Object?>{},
        ),
      ];
    }
    if (processCode == Elv5ProcessCode.cctv03) {
      return <Elv5CurrentEvaluationSnapshot>[
        Elv5CurrentEvaluationSnapshot(
          logicalNodeKeySha256:_h('4'),processCode:processCode,scopeKind:'DESIGN',scopeId:'d',scenarioKey:'NONE',
          subjectKind:'RECORDING_POOL',subjectId:'pool-1',evaluationId:'eval-c03',inputFingerprint:_h('b'),
          outputSha256:_h('5'),evidenceSha256:_h('6'),pointerGeneration:7,
          execution:'SUCCEEDED',completion:'COMPLETE',assessment:'PASS',
          output:<String,Object?>{
            'sizingBasis':'guaranteedUpperBound','usable':<String,Object?>{'requiredBytes':_r(800)},
          },evidence:const <String,Object?>{},
        ),
      ];
    }
    return const <Elv5CurrentEvaluationSnapshot>[];
  }
}

Map<String,Object?> _r(int n) => <String,Object?>{'numerator':'$n','denominator':'1'};
String _h(String char) => List<String>.filled(64,char).join();
