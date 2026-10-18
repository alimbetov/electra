import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  Lan04PathSection section(
    String id, {
    Lan04Medium medium = Lan04Medium.copper,
    Set<String> interfaces = const {'ethernet'},
    Set<String> speeds = const {'1G'},
    Set<String> connectors = const {'RJ45'},
    bool shieldKnown = true,
    bool shield = true,
  }) =>
      Lan04PathSection(
        sectionId: id,
        medium: medium,
        supportedInterfaceKinds: interfaces,
        supportedSpeedModes: speeds,
        supportedConnectorKinds: connectors,
        shieldContinuityKnown: shieldKnown,
        shieldContinuity: shield,
      );

  final mode = Lan04RequiredMode(
    medium: Lan04Medium.copper,
    interfaceKind: 'ethernet',
    speedMode: '1G',
    connectorKind: 'RJ45',
    shieldingRequired: true,
  );

  test('all exact section capabilities pass selected mode', () {
    final result = const Lan04PathCompatibilityKernel().evaluate(Lan04Input(
      linkId: 'link-1',
      orderedSections: [
        section('cable'),
        section('patch-a'),
        section('patch-b')
      ],
      requiredMode: mode,
    ));
    expect(result.status, Lan04AssessmentStatus.pass);
    expect(result.limitingSectionId, isNull);
  });

  test('patch connector mismatch fails on exact path element', () {
    final result = const Lan04PathCompatibilityKernel().evaluate(Lan04Input(
      linkId: 'link-1',
      orderedSections: [
        section('main-cable'),
        section('bad-patch', connectors: {'LC'}),
      ],
      requiredMode: mode,
    ));
    expect(result.status, Lan04AssessmentStatus.fail);
    expect(result.limitingSectionId, 'bad-patch');
    expect(result.limitingProperty, Lan04PropertyCode.connector);
  });

  test('unknown shield continuity remains unresolved', () {
    final result = const Lan04PathCompatibilityKernel().evaluate(Lan04Input(
      linkId: 'link-1',
      orderedSections: [section('cable', shieldKnown: false, shield: false)],
      requiredMode: mode,
    ));
    expect(result.status, Lan04AssessmentStatus.unresolved);
    expect(result.limitingProperty, Lan04PropertyCode.shielding);
  });

  test('medium mismatch is unsupported rather than guessed', () {
    final result = const Lan04PathCompatibilityKernel().evaluate(Lan04Input(
      linkId: 'link-1',
      orderedSections: [section('fiber', medium: Lan04Medium.fiber)],
      requiredMode: mode,
    ));
    expect(result.status, Lan04AssessmentStatus.unsupported);
    expect(result.limitingProperty, Lan04PropertyCode.medium);
  });
}
