import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../component_instance_repository.dart';
import '../../geometry_repository.dart';
import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'cctv01_geometry_contract.dart';

final class Cctv01PersistedInputResolver
    implements Elv5ProcessInputResolver<Cctv01Input> {
  Cctv01PersistedInputResolver({
    required this.contractSource,
    required this.components,
    required this.geometry,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Cctv01GeometryContractSource contractSource;
  final ComponentInstanceRepository components;
  final GeometryRepository geometry;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.cctv01;

  @override
  Future<Elv5CapturedInput<Cctv01Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('CCTV01_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'CAMERA') {
      throw StateError('CCTV01_SUBJECT_KIND_MUST_BE_CAMERA');
    }
    final cameraId = request.subject.id;
    final basis = _encoder.sha256(<String,Object?>{
      'schema':'electra.elv5-cctv01-basis.v1',
      'cameraId':cameraId,
    });
    final dependencies = <Elv5DependencyMarker>[];
    final snapshot = await contractSource.loadActiveForCamera(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      cameraId: cameraId,
    );
    if (snapshot == null) {
      _blocked(request,'CCTV01_GEOMETRY_CONTRACT_REQUIRED',basis,basis,dependencies,<String,Object?>{'cameraId':cameraId});
    }
    final contract = snapshot!.contract;
    dependencies.add(_dependency(
      request,'POLICY','CCTV01_GEOMETRY_CONTRACT',snapshot.evidenceRef,
      memberId:'${snapshot.bindingId}:${snapshot.bindingRevision}:${snapshot.contentHash}',
    ));

    if (!contract.hasExactSurfaceFrames) {
      _blocked(
        request,
        'CCTV01_EXACT_SURFACE_FRAME_CONTRACT_REQUIRED',
        basis,
        snapshot.contentHash,
        dependencies,
        <String,Object?>{
          'cameraId':cameraId,
          'contractSchema':contract.effectiveSchema,
          'requiredSchema':Cctv01GeometryContract.schema,
        },
      );
    }

    final roomComponents = await components.loadRoomComponents(contract.roomId);
    final matching = roomComponents.where((item) => item.id == cameraId).toList(growable:false);
    if (matching.length != 1) {
      _blocked(request,'CCTV01_CAMERA_PLACEMENT_REQUIRED',basis,snapshot.contentHash,dependencies,
        <String,Object?>{'cameraId':cameraId,'roomId':contract.roomId,'matches':matching.length});
    }
    final camera = matching.single;
    if (camera.definitionId != contract.expectedDefinitionId ||
        camera.definitionVersion != contract.expectedDefinitionVersion) {
      _blocked(request,'CCTV01_CAMERA_DEFINITION_MISMATCH',basis,snapshot.contentHash,dependencies,<String,Object?>{
        'expectedDefinitionId':contract.expectedDefinitionId,
        'expectedDefinitionVersion':contract.expectedDefinitionVersion,
        'actualDefinitionId':camera.definitionId,
        'actualDefinitionVersion':camera.definitionVersion,
      });
    }
    if (camera.hostSurfacePatchId != contract.expectedHostSurfacePatchId) {
      _blocked(request,'CCTV01_HOST_SURFACE_PATCH_MISMATCH',basis,snapshot.contentHash,dependencies,<String,Object?>{
        'expectedHostSurfacePatchId':contract.expectedHostSurfacePatchId,
        'actualHostSurfacePatchId':camera.hostSurfacePatchId,
      });
    }

    final room = await geometry.loadRoomGeometry(contract.roomId);
    final violations = room.validate();
    if (violations.isNotEmpty) {
      _blocked(request,'CCTV01_ELV3_GEOMETRY_INVALID',basis,snapshot.contentHash,dependencies,
        <String,Object?>{'roomId':contract.roomId,'violations':violations.map((v)=>v.code).toList()..sort()});
    }
    final host = _patch(room, camera.hostSurfacePatchId);
    final target = _patch(room, contract.targetSurfacePatchId);
    if (host == null || target == null) {
      _blocked(request,'CCTV01_REQUIRED_SURFACE_PATCH_MISSING',basis,snapshot.contentHash,dependencies,<String,Object?>{
        'hostSurfacePatchId':camera.hostSurfacePatchId,
        'targetSurfacePatchId':contract.targetSurfacePatchId,
      });
    }

    final hostPatch = host!;
    final targetPatch = target!;
    final tolerance = contract.legacyFrameAxisTolerance!;
    if (!_frameCompatible(hostPatch.frame, contract.hostSurfaceFrame!, tolerance)) {
      _blocked(request,'CCTV01_HOST_FRAME_COMPATIBILITY_MISMATCH',basis,snapshot.contentHash,dependencies,<String,Object?>{
        'hostSurfacePatchId':hostPatch.id,
        'legacyAxisTolerance':tolerance.toMap(),
      });
    }
    if (!_frameCompatible(targetPatch.frame, contract.targetSurfaceFrame!, tolerance)) {
      _blocked(request,'CCTV01_TARGET_FRAME_COMPATIBILITY_MISMATCH',basis,snapshot.contentHash,dependencies,<String,Object?>{
        'targetSurfacePatchId':targetPatch.id,
        'legacyAxisTolerance':tolerance.toMap(),
      });
    }

    // Engineering math below uses integer-mm persisted origins/placement plus
    // exact immutable v2 axes only. ELV3 floating axes are compatibility
    // witnesses and cannot affect the verdict once the v2 contract is bound.
    final hostU = contract.hostSurfaceFrame!.uAxis;
    final hostV = contract.hostSurfaceFrame!.vAxis;
    final localX = Elv5Rational.integer(camera.localPosition.xMm);
    final localY = Elv5Rational.integer(camera.localPosition.yMm);
    final opticalCenter = Cctv01Point3(
      Elv5Rational.integer(hostPatch.frame.origin.xMm) + hostU.x * localX + hostV.x * localY,
      Elv5Rational.integer(hostPatch.frame.origin.yMm) + hostU.y * localX + hostV.y * localY,
      Elv5Rational.integer(hostPatch.frame.origin.zMm) + hostU.z * localX + hostV.z * localY,
    );
    final targetU = contract.targetSurfaceFrame!.uAxis;
    final targetV = contract.targetSurfaceFrame!.vAxis;
    final targetZone = Cctv01Polygon2(<Cctv01Point2>[
      for (final point in targetPatch.boundary.vertices)
        Cctv01Point2(Elv5Rational.integer(point.xMm),Elv5Rational.integer(point.yMm)),
    ]);

    final input = Cctv01Input(
      cameraId: cameraId,
      cameraFrameId: 'PROJECT',
      targetFrameId: 'PROJECT',
      frameTransformResolved: true,
      rectilinearPinholeSupported: contract.rectilinearPinholeSupported,
      targetIsPlanar: contract.targetIsPlanar,
      opticalCenter: opticalCenter,
      orientation: Cctv01ResolvedOrientation(
        forward:_kernelVec(contract.forward),
        right:_kernelVec(contract.right),
        up:_kernelVec(contract.up),
      ),
      intrinsics: Cctv01PinholeIntrinsics(
        sensorWidth:Length(contract.sensorWidthMm),
        sensorHeight:Length(contract.sensorHeightMm),
        focalLength:Length(contract.focalLengthMm),
      ),
      targetPlane:Cctv01Plane(
        origin:Cctv01Point3(
          Elv5Rational.integer(targetPatch.frame.origin.xMm),
          Elv5Rational.integer(targetPatch.frame.origin.yMm),
          Elv5Rational.integer(targetPatch.frame.origin.zMm),
        ),
        uAxis:Cctv01Vec3(targetU.x,targetU.y,targetU.z),
        vAxis:Cctv01Vec3(targetV.x,targetV.y,targetV.z),
      ),
      targetZone:targetZone,
      minimumCoverageRatio:contract.minimumCoverageRatio,
    );

    final cameraFact = <String,Object?>{
      'id':camera.id,
      'definitionId':camera.definitionId,
      'definitionVersion':camera.definitionVersion,
      'roomId':camera.roomId,
      'hostSurfacePatchId':camera.hostSurfacePatchId,
      'localXmm':camera.localPosition.xMm,
      'localYmm':camera.localPosition.yMm,
    };
    final hostFact = _patchFact(hostPatch);
    final targetFact = _patchFact(targetPatch);
    final inputFingerprint = _encoder.sha256(<String,Object?>{
      'schema':'electra.elv5-cctv01-captured-input.v2',
      'contractContentHash':snapshot.contentHash,
      'camera':cameraFact,
      'hostPatch':hostFact,
      'targetPatch':targetFact,
      'exactHostFrame':contract.hostSurfaceFrame!.toCanonicalValue(),
      'exactTargetFrame':contract.targetSurfaceFrame!.toCanonicalValue(),
    });
    dependencies.addAll(<Elv5DependencyMarker>[
      _dependency(request,'FACT','ELV3_COMPONENT_PLACEMENT',cameraId,memberId:_encoder.sha256(cameraFact)),
      _dependency(request,'FACT','ELV3_SURFACE_PATCH',hostPatch.id,memberId:_encoder.sha256(hostFact)),
      _dependency(request,'FACT','ELV3_SURFACE_PATCH',targetPatch.id,memberId:_encoder.sha256(targetFact)),
    ]);

    return Elv5CapturedInput<Cctv01Input>(
      request:request,
      value:input,
      inputFingerprint:inputFingerprint,
      policyFingerprint:snapshot.contentHash,
      dependencies:dependencies,
      upstreamPointerGenerations:const <String,int>{},
      captureRevision:snapshot.bindingRevision,
    );
  }

  SurfacePatch? _patch(RoomGeometrySnapshot room,String id){
    for(final patch in room.patches){if(patch.id==id)return patch;}
    return null;
  }

  Map<String,Object?> _patchFact(SurfacePatch patch)=><String,Object?>{
    'id':patch.id,
    'roomId':patch.roomId,
    'surfaceId':patch.surfaceId,
    'originMm':<String,Object?>{'x':patch.frame.origin.xMm,'y':patch.frame.origin.yMm,'z':patch.frame.origin.zMm},
    'legacyUAxis':<String,Object?>{'x':_legacyDecimal(patch.frame.uAxis.x),'y':_legacyDecimal(patch.frame.uAxis.y),'z':_legacyDecimal(patch.frame.uAxis.z)},
    'legacyVAxis':<String,Object?>{'x':_legacyDecimal(patch.frame.vAxis.x),'y':_legacyDecimal(patch.frame.vAxis.y),'z':_legacyDecimal(patch.frame.vAxis.z)},
    'boundary':<Object?>[
      for(final point in patch.boundary.vertices)<String,Object?>{'xMm':point.xMm,'yMm':point.yMm},
    ],
  };

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

Elv5PureKernelExecutor<Cctv01Input,Cctv01Result> buildCctv01Executor({DateTime Function()? nowUtc})=>
  Elv5PureKernelExecutor<Cctv01Input,Cctv01Result>(
    processCode:Elv5ProcessCode.cctv01,
    calculate:const Cctv01GeometryKernel().evaluate,
    encodeOutput:(r)=><String,Object?>{
      'schema':'electra.elv5-cctv01-output.v1',
      'status':r.status.name,
      'footprint':r.footprint==null?null:<Object?>[
        for(final p in r.footprint!.vertices)<String,Object?>{'xMm':p.x.toMap(),'yMm':p.y.toMap()},
      ],
      'coveredAreaMm2':r.coveredArea?.toMap(),
      'targetAreaMm2':r.targetArea?.toMap(),
      'coverageRatio':r.coverageRatio?.toMap(),
      'coverageMargin':r.coverageMargin?.toMap(),
      'horizontalHalfFovTangent':r.horizontalHalfFovTangent?.toMap(),
      'verticalHalfFovTangent':r.verticalHalfFovTangent?.toMap(),
      'governingDimension':r.governingDimension?.name,
      'limitingCornerIndex':r.limitingCornerIndex,
      'reasonCode':r.reasonCode,
    },
    encodeEvidence:(c,_)=><String,Object?>{
      'schema':'electra.elv5-cctv01-evidence.v2',
      'source':'ELV3_COMPONENT_AND_INTEGER_ORIGINS_PLUS_IMMUTABLE_EXACT_CCTV01_SURFACE_FRAMES',
      'surfaceFrameBasis':'IMMUTABLE_EXACT_SURFACE_FRAME_CONTRACT_V2',
      'legacyElv3FrameRole':'COMPATIBILITY_WITNESS_ONLY',
      'cameraOrientationBasis':'IMMUTABLE_EXACT_ORTHONORMAL_CONTRACT',
      'captureRevision':c.captureRevision,
    },
    executionOf:(r)=>r.status==Cctv01AssessmentStatus.blocked?Elv5Execution.blocked:Elv5Execution.succeeded,
    completionOf:(r)=>r.status==Cctv01AssessmentStatus.blocked?Elv5Completion.incomplete:Elv5Completion.complete,
    assessmentOf:(r)=>switch(r.status){
      Cctv01AssessmentStatus.pass=>Elv5Assessment.pass,
      Cctv01AssessmentStatus.fail=>Elv5Assessment.fail,
      Cctv01AssessmentStatus.unresolved=>Elv5Assessment.unresolved,
      Cctv01AssessmentStatus.blocked=>Elv5Assessment.unresolved,
      Cctv01AssessmentStatus.unsupported=>Elv5Assessment.notAssessed,
      Cctv01AssessmentStatus.notAssessed=>Elv5Assessment.notAssessed,
    },
    nowUtc:nowUtc,
  );

Cctv01Vec3 _kernelVec(Cctv01ExactVec3Contract v)=>Cctv01Vec3(v.x,v.y,v.z);

bool _frameCompatible(
  LocalCoordinateFrame legacy,
  Cctv01ExactSurfaceFrameContract exact,
  Elv5Rational tolerance,
) =>
    _axisCompatible(legacy.uAxis, exact.uAxis, tolerance) &&
    _axisCompatible(legacy.vAxis, exact.vAxis, tolerance);

bool _axisCompatible(
  Vector3D legacy,
  Cctv01ExactVec3Contract exact,
  Elv5Rational tolerance,
) =>
    _componentCompatible(legacy.x, exact.x, tolerance) &&
    _componentCompatible(legacy.y, exact.y, tolerance) &&
    _componentCompatible(legacy.z, exact.z, tolerance);

bool _componentCompatible(
  double legacy,
  Elv5Rational exact,
  Elv5Rational tolerance,
) {
  if (!legacy.isFinite) return false;
  final exactDouble = exact.numerator.toDouble() / exact.denominator.toDouble();
  final toleranceDouble =
      tolerance.numerator.toDouble() / tolerance.denominator.toDouble();
  return (legacy - exactDouble).abs() <= toleranceDouble;
}

String _legacyDecimal(double value){
  if(!value.isFinite)throw StateError('CCTV01_ELV3_FRAME_AXIS_NON_FINITE');
  return value.toString();
}
