import 'dart:convert';
import 'dart:typed_data';

import 'package:engineering_core/engineering_core.dart';

const engineeringPlacementFingerprintVersion = 1;
const canonicalElvMembershipRole = 'DEVICE';
const canonicalElvComponentDefinitionId = 'system-elv-canonical-device';
const canonicalElvComponentDefinitionCode = 'ELV_CANONICAL_DEVICE';
const canonicalElvComponentDefinitionVersion = 1;

final class PlaceEngineeringProfileCommand {
  const PlaceEngineeringProfileCommand({
    required this.operationId,
    required this.projectId,
    required this.roomId,
    required this.systemId,
    required this.membershipRole,
    required this.catalogId,
    required this.catalogVersion,
    required this.profileCode,
    required this.hostSurfacePatchId,
    required this.localPosition,
    required this.rotationRadians,
    required this.placementContext,
    this.displayNameOverride,
  });

  final String operationId;
  final String projectId;
  final String roomId;
  final String systemId;
  final String membershipRole;
  final String catalogId;
  final String catalogVersion;
  final String profileCode;
  final String hostSurfacePatchId;
  final Point2Mm localPosition;
  final double rotationRadians;
  final PlacementCandidateContext placementContext;
  final String? displayNameOverride;

  List<EngineeringPlacementFailure> validate() {
    final failures = <EngineeringPlacementFailure>[];
    void requireNonEmpty(String value, String field) {
      if (value.trim().isEmpty) {
        failures.add(
          EngineeringPlacementFailure.invalidCommand(
            '$field must not be empty.',
            details: {'field': field},
          ),
        );
      }
    }

    requireNonEmpty(operationId, 'operationId');
    requireNonEmpty(projectId, 'projectId');
    requireNonEmpty(roomId, 'roomId');
    requireNonEmpty(systemId, 'systemId');
    requireNonEmpty(catalogId, 'catalogId');
    requireNonEmpty(catalogVersion, 'catalogVersion');
    requireNonEmpty(profileCode, 'profileCode');
    requireNonEmpty(hostSurfacePatchId, 'hostSurfacePatchId');

    if (membershipRole.trim().toUpperCase() != canonicalElvMembershipRole) {
      failures.add(
        EngineeringPlacementFailure.invalidCommand(
          'membershipRole must be $canonicalElvMembershipRole for P4 canonical placement.',
          details: {'field': 'membershipRole', 'actual': membershipRole},
        ),
      );
    }
    if (!rotationRadians.isFinite) {
      failures.add(
        EngineeringPlacementFailure.invalidCommand(
          'rotationRadians must be finite.',
          details: {'field': 'rotationRadians'},
        ),
      );
    }
    if (placementContext.projectId != projectId) {
      failures.add(
        EngineeringPlacementFailure.invalidCommand(
          'placementContext.projectId must equal command.projectId.',
          details: {
            'expected': projectId,
            'actual': placementContext.projectId,
          },
        ),
      );
    }
    if (placementContext.roomId != roomId) {
      failures.add(
        EngineeringPlacementFailure.invalidCommand(
          'placementContext.roomId must equal command.roomId.',
          details: {'expected': roomId, 'actual': placementContext.roomId},
        ),
      );
    }
    if (placementContext.surfaceId != hostSurfacePatchId) {
      failures.add(
        EngineeringPlacementFailure.invalidCommand(
          'placementContext.surfaceId must equal hostSurfacePatchId.',
          details: {
            'expected': hostSurfacePatchId,
            'actual': placementContext.surfaceId,
          },
        ),
      );
    }

    for (final entry
        in <String, double?>{
          'ambientTemperatureC': placementContext.ambientTemperatureC,
          'availableClearanceMm': placementContext.availableClearanceMm,
        }.entries) {
      final value = entry.value;
      if (value != null && !value.isFinite) {
        failures.add(
          EngineeringPlacementFailure.invalidCommand(
            '${entry.key} must be finite when supplied.',
            details: {'field': entry.key},
          ),
        );
      }
    }

    return List.unmodifiable(failures);
  }

  String get normalizedMembershipRole => membershipRole.trim().toUpperCase();

  String? get normalizedDisplayNameOverride {
    final value = displayNameOverride?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

final class EngineeringPlacementResult {
  EngineeringPlacementResult({
    required this.operationId,
    required this.componentId,
    required this.systemId,
    required this.membershipRole,
    required this.catalogId,
    required this.catalogVersion,
    required this.profileCode,
    required this.bindingComponentId,
    required Iterable<String> portIds,
    required this.placementStatus,
    required this.committedAt,
  }) : portIds = List.unmodifiable(portIds);

  final String operationId;
  final String componentId;
  final String systemId;
  final String membershipRole;
  final String catalogId;
  final String catalogVersion;
  final String profileCode;
  final String bindingComponentId;
  final List<String> portIds;
  final PlacementCompatibilityStatus placementStatus;
  final DateTime committedAt;
}

enum EngineeringPlacementFailureCode {
  invalidCommand,
  projectNotFound,
  roomNotFound,
  surfacePatchNotFound,
  systemNotFound,
  systemProjectMismatch,
  systemDisciplineMismatch,
  componentDefinitionNotFound,
  catalogEditionNotFound,
  profileNotFound,
  profileDeprecated,
  placementForbidden,
  placementUnresolved,
  componentConflict,
  membershipConflict,
  bindingConflict,
  portConflict,
  idempotencyConflict,
  operationInProgress,
  operationUndone,
  historyConflict,
  transactionFailed,
}

final class EngineeringPlacementFailure implements Exception {
  EngineeringPlacementFailure({
    required this.code,
    required this.message,
    Map<String, Object?> details = const {},
    Iterable<PlacementFinding> findings = const [],
  }) : details = Map.unmodifiable(details),
       findings = List.unmodifiable(findings);

  factory EngineeringPlacementFailure.invalidCommand(
    String message, {
    Map<String, Object?> details = const {},
  }) => EngineeringPlacementFailure(
    code: EngineeringPlacementFailureCode.invalidCommand,
    message: message,
    details: details,
  );

  final EngineeringPlacementFailureCode code;
  final String message;
  final Map<String, Object?> details;
  final List<PlacementFinding> findings;

  @override
  String toString() => 'EngineeringPlacementFailure(${code.name}): $message';
}

String engineeringPlacementFingerprintV1(
  PlaceEngineeringProfileCommand command,
) {
  final validation = command.validate();
  if (validation.isNotEmpty) throw validation.first;
  final context = command.placementContext;
  final canonical = <String>[
    'fingerprintVersion=$engineeringPlacementFingerprintVersion',
    _field('projectId', command.projectId),
    _field('roomId', command.roomId),
    _field('systemId', command.systemId),
    _field('membershipRole', command.normalizedMembershipRole),
    _field('catalogId', command.catalogId),
    _field('catalogVersion', command.catalogVersion),
    _field('profileCode', command.profileCode),
    _field('hostSurfacePatchId', command.hostSurfacePatchId),
    'localPosition.xMm=${command.localPosition.xMm}',
    'localPosition.yMm=${command.localPosition.yMm}',
    'rotationRadians=${_canonicalDouble(command.rotationRadians)}',
    _field('context.projectId', context.projectId),
    _field('context.roomId', context.roomId),
    _field('context.surfaceId', context.surfaceId),
    _nullableName('context.installationSurface', context.installationSurface),
    _nullableName('context.mountingMethod', context.mountingMethod),
    _nullableName('context.environmentExposure', context.environmentExposure),
    _nullableName('context.environmentMoisture', context.environmentMoisture),
    _nullableName(
      'context.environmentContamination',
      context.environmentContamination,
    ),
    _nullableName('context.environmentClimate', context.environmentClimate),
    _nullableDouble('context.ambientTemperatureC', context.ambientTemperatureC),
    _field('context.actualIpRating', context.actualIpRating?.value),
    _field('context.hasEnclosure', context.hasEnclosure?.toString()),
    _nullableDouble(
      'context.availableClearanceMm',
      context.availableClearanceMm,
    ),
    _nullableName('context.topologyShape', context.topologyShape),
    _nullableName('context.topologyRole', context.topologyRole),
    _field('displayNameOverride', command.normalizedDisplayNameOverride),
  ].join('\n');
  return _sha256Hex(utf8.encode(canonical));
}

String _field(String name, String? value) {
  if (value == null) return '$name=null';
  return '$name=${utf8.encode(value).length}:$value';
}

String _nullableName(String name, Enum? value) => _field(name, value?.name);

String _nullableDouble(String name, double? value) =>
    value == null ? '$name=null' : '$name=${_canonicalDouble(value)}';

String _canonicalDouble(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'Must be finite.');
  }
  final normalized = value == 0.0 ? 0.0 : value;
  final bytes = ByteData(8)..setFloat64(0, normalized, Endian.big);
  return bytes.getUint64(0, Endian.big).toRadixString(16).padLeft(16, '0');
}

String _sha256Hex(List<int> input) {
  const initial = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  const constants = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  final message = List<int>.from(input)..add(0x80);
  while (message.length % 64 != 56) {
    message.add(0);
  }
  final bitLength = input.length * 8;
  for (var shift = 56; shift >= 0; shift -= 8) {
    message.add((bitLength >> shift) & 0xff);
  }

  final hash = List<int>.from(initial);
  for (var offset = 0; offset < message.length; offset += 64) {
    final w = List<int>.filled(64, 0);
    for (var i = 0; i < 16; i++) {
      final j = offset + i * 4;
      w[i] =
          (message[j] << 24) |
          (message[j + 1] << 16) |
          (message[j + 2] << 8) |
          message[j + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }

    var a = hash[0];
    var b = hash[1];
    var c = hash[2];
    var d = hash[3];
    var e = hash[4];
    var f = hash[5];
    var g = hash[6];
    var h = hash[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = (h + s1 + ch + constants[i] + w[i]) & 0xffffffff;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }
    hash[0] = (hash[0] + a) & 0xffffffff;
    hash[1] = (hash[1] + b) & 0xffffffff;
    hash[2] = (hash[2] + c) & 0xffffffff;
    hash[3] = (hash[3] + d) & 0xffffffff;
    hash[4] = (hash[4] + e) & 0xffffffff;
    hash[5] = (hash[5] + f) & 0xffffffff;
    hash[6] = (hash[6] + g) & 0xffffffff;
    hash[7] = (hash[7] + h) & 0xffffffff;
  }
  return hash.map((value) => value.toRadixString(16).padLeft(8, '0')).join();
}

int _rotr(int value, int count) =>
    ((value >> count) | (value << (32 - count))) & 0xffffffff;
