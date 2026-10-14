import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';

const engineeringReferenceAdoptionFingerprintVersion = 1;
const engineeringReferenceAdoptionLedgerPrefix = 'adopt:';
const engineeringReferenceAdoptionCompletedStatus = 'ADOPTION_COMPLETED';

final class EngineeringReferenceAdoptionCommand {
  EngineeringReferenceAdoptionCommand({
    required this.operationId,
    required this.projectId,
    required this.componentId,
    required this.expectedCatalogId,
    required this.expectedCatalogVersion,
    required this.candidateCatalogId,
    required this.candidateCatalogVersion,
    required this.profileCode,
    required this.reviewedBindingFingerprint,
    required this.reviewedGraphFingerprint,
    Iterable<String> reviewedConnectionIds = const [],
    Iterable<String> reviewedTopologyGroupIds = const [],
    Map<String, String> explicitPortMappings = const {},
  }) : reviewedConnectionIds = List.unmodifiable(
         reviewedConnectionIds.toSet().toList()..sort(),
       ),
       reviewedTopologyGroupIds = List.unmodifiable(
         reviewedTopologyGroupIds.toSet().toList()..sort(),
       ),
       explicitPortMappings = Map.unmodifiable({
         for (final entry in explicitPortMappings.entries)
           entry.key.trim().toUpperCase(): entry.value.trim().toUpperCase(),
       });

  final String operationId;
  final String projectId;
  final String componentId;
  final String expectedCatalogId;
  final String expectedCatalogVersion;
  final String candidateCatalogId;
  final String candidateCatalogVersion;
  final String profileCode;
  final String reviewedBindingFingerprint;
  final String reviewedGraphFingerprint;
  final List<String> reviewedConnectionIds;
  final List<String> reviewedTopologyGroupIds;
  final Map<String, String> explicitPortMappings;

  List<String> validate() => [
    if (operationId.trim().isEmpty) 'operationId is required.',
    if (projectId.trim().isEmpty) 'projectId is required.',
    if (componentId.trim().isEmpty) 'componentId is required.',
    if (expectedCatalogId.trim().isEmpty) 'expectedCatalogId is required.',
    if (expectedCatalogVersion.trim().isEmpty)
      'expectedCatalogVersion is required.',
    if (candidateCatalogId.trim().isEmpty) 'candidateCatalogId is required.',
    if (candidateCatalogVersion.trim().isEmpty)
      'candidateCatalogVersion is required.',
    if (profileCode.trim().isEmpty) 'profileCode is required.',
    if (reviewedBindingFingerprint.trim().isEmpty)
      'reviewedBindingFingerprint is required.',
    if (reviewedGraphFingerprint.trim().isEmpty)
      'reviewedGraphFingerprint is required.',
    if (explicitPortMappings.keys.any((value) => value.isEmpty) ||
        explicitPortMappings.values.any((value) => value.isEmpty))
      'Explicit port mappings require non-empty codes.',
    if (explicitPortMappings.values.toSet().length !=
        explicitPortMappings.length)
      'Explicit port mappings must be one-to-one.',
  ];

  Map<String, Object?> toMap() => {
    'operationId': operationId,
    'projectId': projectId,
    'componentId': componentId,
    'expectedCatalogId': expectedCatalogId,
    'expectedCatalogVersion': expectedCatalogVersion,
    'candidateCatalogId': candidateCatalogId,
    'candidateCatalogVersion': candidateCatalogVersion,
    'profileCode': profileCode.trim().toUpperCase(),
    'reviewedBindingFingerprint': reviewedBindingFingerprint,
    'reviewedGraphFingerprint': reviewedGraphFingerprint,
    'reviewedConnectionIds': reviewedConnectionIds,
    'reviewedTopologyGroupIds': reviewedTopologyGroupIds,
    'explicitPortMappings': {
      for (final key in explicitPortMappings.keys.toList()..sort())
        key: explicitPortMappings[key],
    },
  };

  String get fingerprint => canonicalEngineeringJson(toMap());
  String get ledgerOperationId =>
      '$engineeringReferenceAdoptionLedgerPrefix${operationId.trim()}';
}

final class EngineeringReferenceAdoptionResult {
  EngineeringReferenceAdoptionResult({
    required this.operationId,
    required this.projectId,
    required this.componentId,
    required this.catalogId,
    required this.catalogVersion,
    required this.profileCode,
    required Iterable<String> portIds,
    required this.committedAt,
  }) : portIds = List.unmodifiable(portIds);

  final String operationId;
  final String projectId;
  final String componentId;
  final String catalogId;
  final String catalogVersion;
  final String profileCode;
  final List<String> portIds;
  final DateTime committedAt;

  Map<String, Object?> toMap() => {
    'operationId': operationId,
    'projectId': projectId,
    'componentId': componentId,
    'catalogId': catalogId,
    'catalogVersion': catalogVersion,
    'profileCode': profileCode,
    'portIds': portIds,
    'committedAt': committedAt.toUtc().toIso8601String(),
  };

  factory EngineeringReferenceAdoptionResult.fromMap(
    Map<String, dynamic> map,
  ) => EngineeringReferenceAdoptionResult(
    operationId: map['operationId'] as String,
    projectId: map['projectId'] as String,
    componentId: map['componentId'] as String,
    catalogId: map['catalogId'] as String,
    catalogVersion: map['catalogVersion'] as String,
    profileCode: map['profileCode'] as String,
    portIds: (map['portIds'] as List).cast<String>(),
    committedAt: DateTime.parse(map['committedAt'] as String).toUtc(),
  );
}

String engineeringReferenceAdoptionResultJson(
  EngineeringReferenceAdoptionResult result,
) => canonicalEngineeringJson(result.toMap());

EngineeringReferenceAdoptionResult engineeringReferenceAdoptionResultFromJson(
  String value,
) => EngineeringReferenceAdoptionResult.fromMap(
  jsonDecode(value) as Map<String, dynamic>,
);

enum EngineeringReferenceAdoptionFailureCode {
  invalidCommand,
  idempotencyConflict,
  staleReview,
  currentBindingUnavailable,
  candidateUnavailable,
  candidateInvalid,
  placementBlocked,
  dependencyConflict,
  graphIncompatible,
  transactionFailed,
}

final class EngineeringReferenceAdoptionFailure implements Exception {
  const EngineeringReferenceAdoptionFailure(this.code, this.message);

  final EngineeringReferenceAdoptionFailureCode code;
  final String message;

  @override
  String toString() =>
      'EngineeringReferenceAdoptionFailure(${code.name}): $message';
}

abstract interface class EngineeringReferenceAdoptionRepository {
  Future<EngineeringReferenceAdoptionResult> adopt(
    EngineeringReferenceAdoptionCommand command,
  );
}
