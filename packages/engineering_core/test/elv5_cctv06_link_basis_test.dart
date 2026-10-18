import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  Elv5Rational q(String value) => Elv5Rational.parseDecimal(value);
  Length m(String value) => Length(q(value));
  Power w(String value) => Power(q(value));

  Cctv06Section section(
    String id,
    String length, {
    Cctv06Medium medium = Cctv06Medium.copper,
    String interfaceKind = 'ethernet',
    String category = 'cat6',
  }) =>
      Cctv06Section(
        sectionId: id,
        length: Elv5Interval<LengthDim>.exact(m(length)),
        medium: medium,
        interfaceKind: interfaceKind,
        categoryToken: category,
        shieldContinuityKnown: true,
        shieldContinuity: true,
      );

  Cctv06LinkPolicy policy(String max) => Cctv06LinkPolicy(
        allowedMedia: {Cctv06Medium.copper},
        allowedInterfaceKinds: {'ethernet'},
        allowedCategoryTokens: {'cat6'},
        shieldingRequired: true,
        maximumLength: m(max),
      );

  test('exact 30 m realized link passes inclusive limit', () {
    final result = const Cctv06LinkBasisKernel().evaluate(Cctv06Input(
      linkId: 'link',
      pathFingerprint: 'path-v1',
      sections: [section('permanent', '28'), section('patch', '2')],
      policy: policy('30'),
      powered: true,
      powerEvidence: Cctv06PowerEvidence(
        pathFingerprint: 'path-v1',
        globalMargin: w('5'),
        requiredSegmentIds: {'permanent'},
        evidencedSegmentIds: {'permanent'},
      ),
    ));
    expect(result.status, Cctv06AssessmentStatus.pass);
    expect(result.realizedLength.upper, m('30'));
    expect(result.lengthMargin, m('0'));
    expect(result.powerStatus, Cctv06AssessmentStatus.pass);
  });

  test(
      'upper length bound above limit fails even when display could round to 30',
      () {
    final result = const Cctv06LinkBasisKernel().evaluate(Cctv06Input(
      linkId: 'link',
      pathFingerprint: 'path-v1',
      sections: [
        Cctv06Section(
          sectionId: 'cable',
          length: Elv5Interval<LengthDim>(m('30'), m('30.000001')),
          medium: Cctv06Medium.copper,
          interfaceKind: 'ethernet',
          categoryToken: 'cat6',
          shieldContinuityKnown: true,
          shieldContinuity: true,
        ),
      ],
      policy: policy('30'),
      powered: false,
      powerEvidence: null,
    ));
    expect(result.status, Cctv06AssessmentStatus.fail);
    expect(result.lengthMargin, m('-0.000001'));
  });

  test('one incompatible patch section governs categorical failure', () {
    final result = const Cctv06LinkBasisKernel().evaluate(Cctv06Input(
      linkId: 'link',
      pathFingerprint: 'path-v1',
      sections: [
        section('main', '20'),
        section('patch', '2', interfaceKind: 'unsupported'),
      ],
      policy: policy('30'),
      powered: false,
      powerEvidence: null,
    ));
    expect(result.status, Cctv06AssessmentStatus.fail);
    expect(result.limitingSectionId, 'patch');
    expect(result.limitingProperty, Cctv06PropertyCode.interfaceKind);
  });

  test('stale PWR-06 path generation blocks powered link', () {
    final result = const Cctv06LinkBasisKernel().evaluate(Cctv06Input(
      linkId: 'link',
      pathFingerprint: 'path-v2',
      sections: [section('main', '20')],
      policy: policy('30'),
      powered: true,
      powerEvidence: Cctv06PowerEvidence(
        pathFingerprint: 'path-v1',
        globalMargin: w('10'),
        requiredSegmentIds: {'main'},
        evidencedSegmentIds: {'main'},
      ),
    ));
    expect(result.status, Cctv06AssessmentStatus.blocked);
    expect(result.blockingReason, 'CCTV06_PWR06_PATH_FINGERPRINT_MISMATCH');
  });
}
