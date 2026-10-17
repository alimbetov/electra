import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../database/app_database.dart';

final class DriftElv5DependencyInvalidator {
  const DriftElv5DependencyInvalidator(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? _defaultNow;

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();
  static DateTime _defaultNow() => DateTime.now().toUtc();

  Future<int> invalidate({
    required String projectId,
    required String designRevisionId,
    required Iterable<Elv5InvalidationDependency> dependencies,
  }) async {
    final hashes = <String>{
      for (final dependency in dependencies) dependency.sha256,
    };
    if (hashes.isEmpty) return 0;
    final ordered = hashes.toList()..sort();
    final placeholders = List.filled(ordered.length, '?').join(',');
    final rows = await database
        .customSelect(
          'SELECT DISTINCT logical_node_key_sha256 FROM discipline_dependency_index '
          'WHERE project_id = ? AND design_revision_id = ? '
          'AND dependency_key_sha256 IN ($placeholders)',
          variables: <Variable>[
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            ...ordered.map(Variable.withString),
          ],
        )
        .get();
    final nodeHashes = <String>{
      for (final row in rows) row.read<String>('logical_node_key_sha256'),
    };
    if (nodeHashes.isEmpty) return 0;
    final nodes = nodeHashes.toList()..sort();
    final nodePlaceholders = List.filled(nodes.length, '?').join(',');
    return database.customUpdate(
      'UPDATE discipline_evaluation_pointers '
      "SET freshness = 'STALE', generation = generation + 1, updated_at = ?, "
      'origin_device_id = ? WHERE project_id = ? AND design_revision_id = ? '
      'AND logical_node_key_sha256 IN ($nodePlaceholders) '
      "AND freshness <> 'STALE'",
      variables: <Variable>[
        Variable<DateTime>(_nowUtc().toUtc()),
        Variable.withString(originDeviceId),
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        ...nodes.map(Variable.withString),
      ],
    );
  }
}

final class Elv5InvalidationDependency {
  Elv5InvalidationDependency({
    required String relationKind,
    required String domain,
    required String subjectId,
    String? memberId,
  }) : relationKind = relationKind.trim().toUpperCase(),
       domain = domain.trim(),
       subjectId = subjectId.trim(),
       memberId = memberId?.trim() {
    if (this.relationKind.isEmpty ||
        this.domain.isEmpty ||
        this.subjectId.isEmpty) {
      throw ArgumentError('Invalid ELV5 invalidation dependency identity.');
    }
  }

  final String relationKind;
  final String domain;
  final String subjectId;
  final String? memberId;

  static const _encoder = Elv5CanonicalJsonV1();

  Map<String, Object?> get canonicalValue => <String, Object?>{
    'schema': 'electra.elv5-dependency-key.v1',
    'relationKind': relationKind,
    'domain': domain,
    'subjectId': subjectId,
    if (memberId != null && memberId!.isNotEmpty) 'memberId': memberId,
  };

  String get json => utf8.decode(_encoder.encode(canonicalValue));
  String get sha256 => _encoder.sha256(canonicalValue);
}
