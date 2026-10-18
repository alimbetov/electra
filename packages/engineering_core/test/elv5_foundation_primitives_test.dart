import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  group('F1 shared quantity inventory', () {
    test('new foundation dimensions retain exact rational values', () {
      final crossSection = CrossSectionArea(Elv5Rational.parseDecimal('2.5'));
      final temperature = Temperature(Elv5Rational.integer(45));
      final apparentPower = ApparentPower(Elv5Rational.integer(500));
      final heatPower = HeatPower(Elv5Rational.integer(120));
      final frequency = Frequency(Elv5Rational.integer(50));

      expect(crossSection.value, Elv5Rational.parseDecimal('2.5'));
      expect(temperature.value, Elv5Rational.integer(45));
      expect(apparentPower.value, Elv5Rational.integer(500));
      expect(heatPower.value, Elv5Rational.integer(120));
      expect(frequency.value, Elv5Rational.integer(50));
    });
  });

  group('F1 typed evidence states', () {
    final applicability = Elv5EvidenceApplicability(
      scope: 'ROUTE_SECTION',
      scenarioIds: const <String>['NORMAL'],
      environmentCodes: const <String>['INDOOR'],
    );

    test('ASSUMED evidence requires explicit assumption provenance', () {
      expect(
        () => Elv5EvidenceDescriptor(
          evidenceId: 'e-assumed-invalid',
          state: Elv5EvidenceState.assumed,
          sourceType: Elv5EvidenceSourceType.engineeringAssumption,
          sourceId: 'assumption-1',
          sourceEdition: 'v1',
          contentHash: _hash('a'),
          applicability: applicability,
        ),
        throwsArgumentError,
      );

      final evidence = Elv5EvidenceDescriptor(
        evidenceId: 'e-assumed',
        state: Elv5EvidenceState.assumed,
        sourceType: Elv5EvidenceSourceType.engineeringAssumption,
        sourceId: 'assumption-1',
        sourceEdition: 'v1',
        contentHash: _hash('b'),
        applicability: applicability,
        assumption: Elv5AssumptionDescriptor(
          reason: 'temporary design exploration',
          scope: 'ROUTE_SECTION',
          authorOrSource: 'engineer-approval-ref',
          applicability: applicability,
        ),
      );

      expect(evidence.maySatisfyVerifiedOnly, isFalse);
      expect(evidence.toCanonicalValue()['state'], 'ASSUMED');
    });

    test('only VERIFIED evidence satisfies verified-only requirement', () {
      final verified = Elv5EvidenceDescriptor(
        evidenceId: 'e-verified',
        state: Elv5EvidenceState.verified,
        sourceType: Elv5EvidenceSourceType.catalog,
        sourceId: 'catalog-row-1',
        sourceEdition: '2026.1',
        contentHash: _hash('c'),
        applicability: applicability,
      );
      final declared = Elv5EvidenceDescriptor(
        evidenceId: 'e-declared',
        state: Elv5EvidenceState.declared,
        sourceType: Elv5EvidenceSourceType.projectFact,
        sourceId: 'project-fact-1',
        sourceEdition: 'rev-7',
        contentHash: _hash('d'),
        applicability: applicability,
      );

      expect(verified.maySatisfyVerifiedOnly, isTrue);
      expect(declared.maySatisfyVerifiedOnly, isFalse);
    });
  });
}

String _hash(String char) => List<String>.filled(64, char).join();
