import 'dart:math' as math;
import 'component_catalog.dart';
import 'engineering_decision.dart';
import 'manufacturer_catalog.dart';
import 'normative_catalog.dart';

enum ResidualProtectionPolicy { undetermined, required, notRequired }

enum ProtectionProposalState { needsInput, invalid, proposed }

/// Project-authored, immutable version. There is no built-in regulatory rating table.
class ProtectionRuleset {
  ProtectionRuleset(
      {required this.id,
      required this.projectId,
      required this.reference,
      required this.normativeDocumentId,
      required Iterable<double> nominalCurrentsA,
      required Iterable<String> tripCurves,
      required Iterable<String> residualTypes,
      this.minimumBreakingCapacityKa})
      : nominalCurrentsA = List.unmodifiable(nominalCurrentsA.toList()..sort()),
        tripCurves = List.unmodifiable(tripCurves.toList()..sort()),
        residualTypes = List.unmodifiable(residualTypes.toList()..sort());
  final String id, projectId, normativeDocumentId;
  final ElectricalRulesetRef reference;
  final List<double> nominalCurrentsA;
  final List<String> tripCurves, residualTypes;
  final double? minimumBreakingCapacityKa;
  List<String> validate() {
    final errors = <String>[];
    if ([
      id,
      projectId,
      reference.id,
      normativeDocumentId,
      reference.jurisdiction,
      reference.standardCode,
      reference.version,
      reference.sourceReference ?? ''
    ].any((v) => v.trim().isEmpty))
      errors.add(
          'Ruleset identity, jurisdiction, standard, version and source are required.');
    if (nominalCurrentsA.isEmpty ||
        nominalCurrentsA.any((v) => !v.isFinite || v <= 0) ||
        nominalCurrentsA.toSet().length != nominalCurrentsA.length)
      errors.add('Provide unique positive finite nominal currents.');
    for (final list in [tripCurves, residualTypes]) {
      if (list.any((v) => v.trim().isEmpty) ||
          list.toSet().length != list.length)
        errors.add('Rule options must be nonempty and unique.');
    }
    if (tripCurves.isEmpty)
      errors.add('Provide at least one trip characteristic.');
    if (minimumBreakingCapacityKa != null &&
        (!minimumBreakingCapacityKa!.isFinite ||
            minimumBreakingCapacityKa! <= 0))
      errors.add('Invalid minimum breaking capacity.');
    return errors;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'projectId': projectId,
        'normativeDocumentId': normativeDocumentId,
        'ruleId': reference.id,
        'jurisdiction': reference.jurisdiction,
        'standardCode': reference.standardCode,
        'version': reference.version,
        'source': reference.sourceReference,
        'nominalCurrentsA': nominalCurrentsA,
        'tripCurves': tripCurves,
        'residualTypes': residualTypes,
        'minimumBreakingCapacityKa': minimumBreakingCapacityKa,
      };
  factory ProtectionRuleset.fromMap(Map<String, dynamic> map) =>
      ProtectionRuleset(
          id: map['id'] as String,
          projectId: map['projectId'] as String,
          normativeDocumentId: map['normativeDocumentId'] as String,
          reference: ElectricalRulesetRef(
              id: map['ruleId'] as String,
              jurisdiction: map['jurisdiction'] as String,
              standardCode: map['standardCode'] as String,
              version: map['version'] as String,
              sourceReference: map['source'] as String),
          nominalCurrentsA: (map['nominalCurrentsA'] as List)
              .map((v) => (v as num).toDouble()),
          tripCurves: (map['tripCurves'] as List).cast<String>(),
          residualTypes: (map['residualTypes'] as List).cast<String>(),
          minimumBreakingCapacityKa:
              (map['minimumBreakingCapacityKa'] as num?)?.toDouble());
}

class CircuitProtectionInputs {
  const CircuitProtectionInputs(
      {required this.circuitId,
      this.rulesetId,
      this.allowableCurrentA,
      this.prospectiveFaultKa,
      this.poles,
      this.tripCurve,
      this.residualPolicy = ResidualProtectionPolicy.undetermined,
      this.residualCurrentMa,
      this.residualType,
      this.evidence = ''});
  final String circuitId;
  final String? rulesetId, tripCurve, residualType;
  final double? allowableCurrentA, prospectiveFaultKa, residualCurrentMa;
  final int? poles;
  final ResidualProtectionPolicy residualPolicy;
  final String evidence;
  List<String> validate() => [
        if (circuitId.trim().isEmpty) 'Circuit is required.',
        for (final v in [
          allowableCurrentA,
          prospectiveFaultKa,
          residualCurrentMa
        ])
          if (v != null && (!v.isFinite || v <= 0))
            'Protection quantities must be positive and finite.',
        if (poles != null && (poles! < 1 || poles! > 4))
          'Poles must be between one and four.',
        if (residualPolicy != ResidualProtectionPolicy.required &&
            (residualCurrentMa != null || residualType != null))
          'Residual parameters require an explicit required residual-protection policy.',
      ];
  Map<String, Object?> toMap() => {
        'circuitId': circuitId,
        'rulesetId': rulesetId,
        'allowableCurrentA': allowableCurrentA,
        'prospectiveFaultKa': prospectiveFaultKa,
        'poles': poles,
        'tripCurve': tripCurve,
        'residualPolicy': residualPolicy.name,
        'residualCurrentMa': residualCurrentMa,
        'residualType': residualType,
        'evidence': evidence,
      };
  factory CircuitProtectionInputs.fromMap(Map<String, dynamic> m) =>
      CircuitProtectionInputs(
          circuitId: m['circuitId'] as String,
          rulesetId: m['rulesetId'] as String?,
          allowableCurrentA: (m['allowableCurrentA'] as num?)?.toDouble(),
          prospectiveFaultKa: (m['prospectiveFaultKa'] as num?)?.toDouble(),
          poles: m['poles'] as int?,
          tripCurve: m['tripCurve'] as String?,
          residualPolicy: ResidualProtectionPolicy.values
              .byName(m['residualPolicy'] as String),
          residualCurrentMa: (m['residualCurrentMa'] as num?)?.toDouble(),
          residualType: m['residualType'] as String?,
          evidence: m['evidence'] as String);
}

class ProtectionRequirementProposal {
  ProtectionRequirementProposal(
      {required this.state,
      required this.requirement,
      required this.ruleset,
      required Map<String, Object?> inputs,
      required Iterable<String> reasons,
      required Iterable<String> warnings,
      required Iterable<String> issues})
      : inputs = Map.unmodifiable(inputs),
        reasons = List.unmodifiable(reasons),
        warnings = List.unmodifiable(warnings),
        issues = List.unmodifiable(issues);
  final ProtectionProposalState state;
  final FunctionalDeviceRequirement? requirement;
  final ProtectionRuleset? ruleset;
  final Map<String, Object?> inputs;
  final List<String> reasons, warnings, issues;
  bool get ready => state == ProtectionProposalState.proposed;
  Map<String, Object?> toMap() => {
        'proposalState': state.name,
        'inputs': inputs,
        'ruleset': ruleset?.toMap(),
        'role': requirement?.role.name,
        'ratedCurrentA': requirement?.ratedCurrentA,
        'ratedVoltageV': requirement?.ratedVoltageV,
        'poles': requirement?.poles,
        'breakingCapacityKa': requirement?.breakingCapacityKa,
        'tripCurve': requirement?.tripCurve,
        'residualCurrentMa': requirement?.residualCurrentMa,
        'residualType': requirement?.residualCurrentType,
        'reasons': reasons,
        'warnings': warnings,
        'inputIssues': issues,
      };
}

abstract final class ProtectionRequirementPlanner {
  static const algorithmVersion = 'fl13-functional-protection-v1';
  static ProtectionRequirementProposal propose(
      {required CircuitProtectionInputs settings,
      required ProtectionRuleset? ruleset,
      required NormativeDocument? normativeDocument,
      required double? designCurrentA,
      required double nominalVoltageV,
      required int phases,
      required SupplySystem supplySystem}) {
    final issues = [...settings.validate()],
        missing = <String>[],
        reasons = <String>[];
    final warnings = <String>[
      'Functional proposal only. Disconnection time, neutral switching, I2/energy coordination, voltage drop, earthing and selectivity require separate verification.',
      'Declared Iz and prospective fault current are engineer-supplied inputs, not calculated by this planner.',
    ];
    if (normativeDocument == null) {
      missing.add('Choose an active normative catalog document.');
    } else {
      issues.addAll(normativeDocument.validate());
      if (ruleset != null &&
          ruleset.normativeDocumentId != normativeDocument.id)
        issues.add('Normative reference does not match the ruleset.');
      if (!normativeDocument.supportsPlanner)
        missing.add(
            'Reference metadata only; executable protection criteria have not been curated.');
      reasons.add(
          'Catalog source: ${normativeDocument.standardCode} · ${normativeDocument.version} · ${normativeDocument.clauseReference}.');
      if (normativeDocument.kind != NormativeDocumentKind.standard)
        warnings.add(
            'Catalog entry is ${normativeDocument.kind.name}; national applicability needs project verification.');
    }
    if (ruleset == null)
      missing.add('Choose a versioned ruleset.');
    else {
      issues.addAll(ruleset.validate());
      if (settings.rulesetId != ruleset.id)
        issues.add('Ruleset assignment does not match.');
    }
    if (designCurrentA == null)
      missing.add('Resolve circuit design current.');
    else if (!designCurrentA.isFinite || designCurrentA <= 0)
      issues.add('Invalid design current.');
    if (!nominalVoltageV.isFinite || nominalVoltageV <= 0)
      issues.add('Invalid voltage.');
    if ((supplySystem != SupplySystem.singlePhaseAc &&
            supplySystem != SupplySystem.threePhaseAc) ||
        (phases != 1 && phases != 3))
      missing.add(
          'This planner supports single-phase and balanced three-phase AC only.');
    if (settings.allowableCurrentA == null)
      missing.add('Declare conductor allowable current Iz.');
    if (settings.prospectiveFaultKa == null)
      missing.add('Declare prospective fault current at installation point.');
    if (settings.poles == null)
      missing.add('Declare pole count.');
    else if (settings.poles! < phases)
      issues.add('Pole count cannot be less than the phase count.');
    if (settings.tripCurve == null)
      missing.add('Select trip characteristic.');
    else if (ruleset != null &&
        !ruleset.tripCurves.contains(settings.tripCurve))
      issues.add('Trip characteristic is not allowed by this ruleset.');
    if (settings.evidence.trim().isEmpty)
      missing.add('Document input evidence and residual-protection policy.');
    if (settings.residualPolicy == ResidualProtectionPolicy.undetermined)
      missing.add('Declare residual-protection applicability.');
    if (settings.residualPolicy == ResidualProtectionPolicy.required) {
      if (settings.residualCurrentMa == null || settings.residualType == null)
        missing.add('Declare residual trip current and type.');
      if (settings.residualType != null &&
          ruleset != null &&
          !ruleset.residualTypes.contains(settings.residualType))
        issues.add('Residual type is not allowed by this ruleset.');
      reasons.add(
          'Explicit policy requires residual protection: propose a combined RCBO function.');
    } else if (settings.residualPolicy ==
        ResidualProtectionPolicy.notRequired) {
      reasons.add(
          'Engineer explicitly declared residual protection not required for this proposal.');
    }
    double? rating;
    if (ruleset != null &&
        designCurrentA != null &&
        designCurrentA.isFinite &&
        settings.allowableCurrentA != null) {
      final options = ruleset.nominalCurrentsA
          .where((v) => v >= designCurrentA && v <= settings.allowableCurrentA!)
          .toList();
      if (options.isEmpty)
        issues.add(
            'No configured nominal current satisfies Ib ≤ In ≤ declared Iz.');
      else {
        rating = options.first;
        reasons.add(
            'Smallest configured nominal current satisfying Ib ≤ In ≤ declared Iz: $designCurrentA ≤ $rating ≤ ${settings.allowableCurrentA} A.');
      }
    }
    final breaking = settings.prospectiveFaultKa == null
        ? null
        : math.max(settings.prospectiveFaultKa!,
            ruleset?.minimumBreakingCapacityKa ?? 0.0);
    if (breaking != null)
      reasons.add(
          'Required breaking capacity is at least $breaking kA from declared fault current and ruleset floor.');
    if (ruleset != null)
      reasons.add(
          'Ruleset ${ruleset.reference.standardCode} · ${ruleset.reference.version} · ${ruleset.reference.jurisdiction}.');
    final state = issues.isNotEmpty
        ? ProtectionProposalState.invalid
        : missing.isNotEmpty
            ? ProtectionProposalState.needsInput
            : ProtectionProposalState.proposed;
    return ProtectionRequirementProposal(
        state: state,
        requirement: state == ProtectionProposalState.proposed
            ? FunctionalDeviceRequirement(
                role:
                    settings.residualPolicy == ResidualProtectionPolicy.required
                        ? FunctionalDeviceRole.rcbo
                        : FunctionalDeviceRole.mcb,
                ratedCurrentA: rating,
                ratedVoltageV: nominalVoltageV,
                poles: settings.poles,
                tripCurve: settings.tripCurve,
                breakingCapacityKa: breaking,
                residualCurrentMa: settings.residualCurrentMa,
                residualCurrentType: settings.residualType)
            : null,
        ruleset: ruleset,
        inputs: {
          ...settings.toMap(),
          'designCurrentA': designCurrentA,
          'nominalVoltageV': nominalVoltageV,
          'phases': phases,
          'supplySystem': supplySystem.name,
          'normativeDocument': normativeDocument?.toMap(),
        },
        reasons: reasons,
        warnings: [...warnings, ...missing],
        issues: issues);
  }
}
