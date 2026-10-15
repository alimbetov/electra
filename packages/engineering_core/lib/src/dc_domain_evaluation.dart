import 'power_dc_backup.dart';
import 'power_evaluation.dart';
import 'power_numeric.dart';

enum DcDomainModelKind {
  constantCurrentTree,
  singleConstantPowerFeeder,
  unsupported,
}

sealed class DcDomainEvaluationInput {
  DcDomainEvaluationInput({
    required String domainId,
    required this.modelKind,
  }) : domainId = _text(domainId, 'domainId');

  final String domainId;
  final DcDomainModelKind modelKind;
}

final class DcConstantCurrentDomainInput extends DcDomainEvaluationInput {
  DcConstantCurrentDomainInput({
    required String domainId,
    required this.tree,
  }) : super(
          domainId: domainId,
          modelKind: DcDomainModelKind.constantCurrentTree,
        );

  final DcTreeInput tree;
}

final class DcSingleConstantPowerDomainInput extends DcDomainEvaluationInput {
  DcSingleConstantPowerDomainInput({
    required String domainId,
    required String loadId,
    required this.sourceVoltageV,
    required this.loadPowerW,
    required this.loopResistanceOhm,
    required String evidenceRef,
    this.maxIterations = 128,
    PowerRational? toleranceV,
  })  : loadId = _text(loadId, 'loadId'),
        evidenceRef = _text(evidenceRef, 'evidenceRef'),
        toleranceV =
            toleranceV ?? PowerRational(BigInt.one, BigInt.from(1000000000)),
        super(
          domainId: domainId,
          modelKind: DcDomainModelKind.singleConstantPowerFeeder,
        ) {
    if (sourceVoltageV <= PowerRational.zero) {
      throw ArgumentError('Constant-power source voltage must be positive.');
    }
    if (loadPowerW.isNegative) {
      throw ArgumentError('Constant-power load cannot be negative.');
    }
    if (loopResistanceOhm <= PowerRational.zero) {
      throw ArgumentError('Constant-power loop resistance must be positive.');
    }
    if (maxIterations < 1 || maxIterations > 1024) {
      throw ArgumentError('Invalid constant-power iteration bound.');
    }
    if (this.toleranceV <= PowerRational.zero) {
      throw ArgumentError('Constant-power voltage tolerance must be positive.');
    }
  }

  final String loadId;
  final PowerRational sourceVoltageV;
  final PowerRational loadPowerW;
  final PowerRational loopResistanceOhm;
  final String evidenceRef;
  final int maxIterations;
  final PowerRational toleranceV;
}

final class DcUnsupportedDomainInput extends DcDomainEvaluationInput {
  DcUnsupportedDomainInput({
    required String domainId,
    required String modelCode,
    Iterable<String> evidenceRefs = const [],
  })  : modelCode = _code(modelCode, 'modelCode'),
        evidenceRefs = List.unmodifiable(_sortedTexts(evidenceRefs)),
        super(
          domainId: domainId,
          modelKind: DcDomainModelKind.unsupported,
        );

  final String modelCode;
  final List<String> evidenceRefs;
}

final class DcDomainEvaluationResult {
  const DcDomainEvaluationResult({
    required this.status,
    required this.modelKind,
    required this.findings,
    this.treeResult,
    this.constantPowerResult,
    this.sourceDemandW,
    this.sourceDemandIntervalW,
  });

  final PowerEvaluationStatus status;
  final DcDomainModelKind modelKind;
  final List<PowerEvaluationFinding> findings;
  final DcTreeResult? treeResult;
  final ConstantPowerFeederResult? constantPowerResult;

  /// Exact source demand when the supported model proves one exact value.
  final PowerRational? sourceDemandW;

  /// Preserved conservative interval for bounded nonlinear models.
  final PowerInterval? sourceDemandIntervalW;

  PowerRational? get sourceDemandUpperBoundW =>
      sourceDemandW ?? sourceDemandIntervalW?.upper;
}

DcDomainEvaluationResult evaluateDcDomain(DcDomainEvaluationInput input) =>
    switch (input) {
      DcConstantCurrentDomainInput() => _evaluateConstantCurrent(input),
      DcSingleConstantPowerDomainInput() => _evaluateConstantPower(input),
      DcUnsupportedDomainInput() => _unsupported(input),
    };

DcDomainEvaluationResult _evaluateConstantCurrent(
  DcConstantCurrentDomainInput input,
) {
  final result = solveDcConstantCurrentTree(input.tree);
  final findings = <PowerEvaluationFinding>[];
  for (final section in result.sections) {
    if (section.currentMarginA.isNegative) {
      findings.add(
        _finding(
          'ELV4_DC_SECTION_CURRENT_EXCEEDED',
          'FAIL',
          'DC section current exceeds its declared current rating.',
          [section.sectionId],
        ),
      );
    }
  }
  for (final terminal in result.terminals) {
    if (terminal.status == PowerEvaluationStatus.fail) {
      findings.add(
        _finding(
          'ELV4_DC_TERMINAL_VOLTAGE_OUT_OF_RANGE',
          'FAIL',
          'DC terminal voltage is outside the declared compatible envelope.',
          [terminal.loadId],
        ),
      );
    }
  }
  if (!result.conservationResidualW.isZero) {
    findings.add(
      _finding(
        'ELV4_DC_POWER_CONSERVATION_FAILED',
        'BLOCKED',
        'DC source, delivered and loss power do not conserve at one boundary.',
        [input.domainId],
      ),
    );
  }
  final status = findings.any((item) => item.severity == 'BLOCKED')
      ? PowerEvaluationStatus.blocked
      : result.status;
  return DcDomainEvaluationResult(
    status: status,
    modelKind: input.modelKind,
    findings: List.unmodifiable(findings),
    treeResult: result,
    sourceDemandW: result.sourceNominalW,
  );
}

DcDomainEvaluationResult _evaluateConstantPower(
  DcSingleConstantPowerDomainInput input,
) {
  final result = solveSingleConstantPowerFeeder(
    sourceVoltageV: input.sourceVoltageV,
    loadPowerW: input.loadPowerW,
    loopResistanceOhm: input.loopResistanceOhm,
    maxIterations: input.maxIterations,
    toleranceV: input.toleranceV,
  );
  final sourceDemand = result.current == null
      ? null
      : PowerInterval(
          input.sourceVoltageV * result.current!.lower,
          input.sourceVoltageV * result.current!.upper,
        );

  if (result.status == PowerEvaluationStatus.fail) {
    return DcDomainEvaluationResult(
      status: PowerEvaluationStatus.fail,
      modelKind: input.modelKind,
      findings: [
        _finding(
          'ELV4_NO_FEASIBLE_ELECTRICAL_SOLUTION',
          'FAIL',
          'The bounded constant-power feeder has no feasible high-voltage root.',
          [input.domainId, input.loadId],
        ),
      ],
      constantPowerResult: result,
      sourceDemandIntervalW: sourceDemand,
    );
  }
  if (result.status == PowerEvaluationStatus.unresolved) {
    return DcDomainEvaluationResult(
      status: PowerEvaluationStatus.blocked,
      modelKind: input.modelKind,
      findings: [
        _finding(
          'ELV4_SOLVER_NOT_CONVERGED',
          'BLOCKED',
          'The bounded constant-power solver did not converge within its contract.',
          [input.domainId, input.loadId],
        ),
      ],
      constantPowerResult: result,
      sourceDemandIntervalW: sourceDemand,
    );
  }
  return DcDomainEvaluationResult(
    status: PowerEvaluationStatus.pass,
    modelKind: input.modelKind,
    findings: const [],
    constantPowerResult: result,
    sourceDemandIntervalW: sourceDemand,
  );
}

DcDomainEvaluationResult _unsupported(DcUnsupportedDomainInput input) =>
    DcDomainEvaluationResult(
      status: PowerEvaluationStatus.blocked,
      modelKind: input.modelKind,
      findings: [
        _finding(
          'ELV4_UNSUPPORTED_ELECTRICAL_MODEL',
          'BLOCKED',
          'The declared DC electrical model is outside the supported P6 slice.',
          [input.domainId, input.modelCode, ...input.evidenceRefs],
        ),
      ],
    );

PowerEvaluationFinding _finding(
  String code,
  String severity,
  String message,
  Iterable<String> refs,
) =>
    PowerEvaluationFinding(
      code: code,
      severity: severity,
      message: message,
      sourceRefs: refs,
    );

List<String> _sortedTexts(Iterable<String> values) {
  final result = values.map((value) => _text(value, 'evidenceRefs')).toList()
    ..sort();
  if (result.toSet().length != result.length) {
    throw ArgumentError('evidenceRefs must be unique.');
  }
  return result;
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _code(String value, String field) {
  final normalized = _text(value, field).toUpperCase();
  if (!RegExp(r'^[A-Z][A-Z0-9_-]{0,127}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Invalid canonical code.');
  }
  return normalized;
}
