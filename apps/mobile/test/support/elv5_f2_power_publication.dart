import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/application/power_mutation_command.dart';
import 'package:electra_mobile/data/repositories/drift_power_command_service.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:engineering_core/engineering_core.dart';

/// Explicit deterministic ELV4 fixture facts published through the guarded
/// production boundary; no evaluation/pointer/index rows are inserted by tests.
Future<String> publishF2PowerEvidence(
  AppDatabase db, {
  required PowerNodeKeyV2 node,
  required String edition,
  required Map<String, Object?> inputs,
  required Map<String, Object?> output,
  required PowerEvaluationStatus status,
  List<PowerConsumedFact> additionalFacts = const [],
  List<PowerConsumedEvaluationRef> evaluations = const [],
}) async {
  final input = PowerConsumedInput(
    algorithmVersion: 'f2-power-source-v1',
    inputSchemaVersion: 'electra.f2-power-source.v1',
    numericPolicyVersion: powerNumericPolicyVersion,
    evaluations: evaluations,
    facts: [
      ...additionalFacts,
      PowerConsumedFact.present(
        key: PowerDependencyKey(
          projectId: 'p',
          revisionId: 'd',
          kind: PowerDependencyKind.definition,
          entityId: node.subjectId,
          purpose:
              'F2_EXPLICIT_${node.processCode.name.toUpperCase()}_POWER_FIXTURE',
        ),
        valueSchema: 'electra.f2-power-source-fact.v1',
        value: {'edition': edition, 'inputs': inputs, 'output': output},
      ),
    ],
  );
  final runtime = DriftPowerPublicationRuntime(
    db,
    originDeviceId: 'f2-fire',
    now: () => DateTime.utc(2026, 10, 17, 15),
  );
  final capture = await runtime.captureForCalculation(
    projectId: 'p',
    designRevisionId: 'd',
    targetNodeKey: node,
    captureInput: () async => input,
  );
  final operation = 'power-${node.sha256}-$edition';
  await runtime.publishGuarded(
    capture: capture,
    evidence: PowerEvaluationEvidence(
      evaluationId: operation,
      nodeKey: node,
      algorithmVersion: input.algorithmVersion,
      inputSchemaVersion: input.inputSchemaVersion,
      outputSchemaVersion: 'electra.f2-power-output.v1',
      numericPolicyVersion: input.numericPolicyVersion,
      inputFingerprint: input.inputFingerprint,
      status: status,
      applicability: PowerEvaluationApplicability.applicable,
      inputs: inputs,
      output: output,
      dependencies: evaluations.map(
        (v) => PowerNodeKeyV2.decode(v.logicalNodeKey),
      ),
    ),
    operationId: operation,
    commandFingerprint: sha256HexUtf8(operation),
    recaptureInput: () async => input,
  );
  return input.inputFingerprint;
}

Future<void> replaceF2PowerDefinition(
  AppDatabase db, {
  required String componentId,
  required String edition,
  required Map<String, Object?> definition,
  required PowerComponentCapability capability,
  required PowerProcessCode processCode,
}) async {
  final revision = (await db
          .customSelect(
            "SELECT revision FROM project_design_revisions WHERE id = 'd'",
          )
          .getSingle())
      .read<int>('revision');
  await DriftPowerCommandService(
    db,
    originDeviceId: 'f2-fire',
    now: () => DateTime.utc(2026, 10, 17, 15),
  ).execute(
    BindPowerComponentCommand(
      operationId: 'definition-$componentId-$edition',
      projectId: 'p',
      designRevisionId: 'd',
      expectedRevision: revision,
      changedDependencies: [
        PowerDependencyKey(
          projectId: 'p',
          revisionId: 'd',
          kind: PowerDependencyKind.definition,
          entityId: componentId,
          purpose:
              'F2_EXPLICIT_${processCode.name.toUpperCase()}_POWER_FIXTURE',
        ),
      ],
      bindingId: 'source-$componentId',
      binding: PowerComponentBinding(
        componentId: componentId,
        capabilities: [capability],
        definitionRefs: [
          PowerDefinitionRef(
            catalogId: 'f2-power',
            catalogVersion: '1',
            definitionKind: PowerDefinitionKind.component,
            definitionCode: componentId,
            definitionVersion: edition,
            definitionSchema: 'electra.f2-power-source-fact.v1',
            contentSha256: sha256HexUtf8(
              canonicalEngineeringJsonV1(definition),
            ),
            sourceRef: 'Fictional exact qualification vector',
          ),
        ],
      ),
    ),
  );
}
