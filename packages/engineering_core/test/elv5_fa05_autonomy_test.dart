import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

Energy _wh(String v)=>Energy(Elv5Rational.parseDecimal(v));
Current _a(String v)=>Current(Elv5Rational.parseDecimal(v));

void main(){
  test('FA05 preserves shared-bank global energy and fire contribution',(){
    final result=const Fa05AutonomyProjectionKernel().evaluate(Fa05Input(
      bankId:'bank-1',
      expectedSequenceFingerprint:'seq-v1',
      expectedProtectedLoadSetFingerprint:'loads-v1',
      sequence:[
        Fa05SequenceSegment(segmentId:'standby',durationMicroseconds:BigInt.from(7200000000)),
        Fa05SequenceSegment(segmentId:'alarm',durationMicroseconds:BigInt.from(1800000000)),
      ],
      fireProtectedLoadIds:{'fire-1'},
      evidence:Fa05Pwr04Evidence(
        sequenceFingerprint:'seq-v1',protectedLoadSetFingerprint:'loads-v1',
        coveredSegmentIds:{'standby','alarm'},globalRequiredEnergy:_wh('36'),availableEnergy:_wh('134.4'),
        contributors:[Fa05ContributorEnergy(loadId:'fire-1',energy:_wh('24')),Fa05ContributorEnergy(loadId:'shared-1',energy:_wh('12'))],
        governingDimension:Fa05GoverningDimension.energy,governingSegmentId:'alarm',peakCurrentMargin:_a('0.2')),
    ));
    expect(result.status,Fa05AssessmentStatus.pass);
    expect(result.energyMargin,_wh('98.4'));
    expect(result.fireContributionEnergy,_wh('24'));
  });

  test('FA05 peak-current failure governs even when energy fits',(){
    final result=const Fa05AutonomyProjectionKernel().evaluate(Fa05Input(
      bankId:'bank-1',expectedSequenceFingerprint:'seq-v1',expectedProtectedLoadSetFingerprint:'loads-v1',
      sequence:[Fa05SequenceSegment(segmentId:'alarm',durationMicroseconds:BigInt.from(1))],fireProtectedLoadIds:{'fire-1'},
      evidence:Fa05Pwr04Evidence(sequenceFingerprint:'seq-v1',protectedLoadSetFingerprint:'loads-v1',coveredSegmentIds:{'alarm'},globalRequiredEnergy:_wh('10'),availableEnergy:_wh('100'),contributors:[Fa05ContributorEnergy(loadId:'fire-1',energy:_wh('10'))],governingDimension:Fa05GoverningDimension.energy,governingSegmentId:'alarm',peakCurrentMargin:_a('-0.4')),
    ));
    expect(result.status,Fa05AssessmentStatus.fail);
    expect(result.governingDimension,Fa05GoverningDimension.peakCurrent);
  });
}
