import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../database/app_database.dart';
import 'drift_elv5_lifecycle_invalidation.dart';

final class DriftElv5DependencyInvalidator {
  const DriftElv5DependencyInvalidator(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? _defaultNow;

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() _nowUtc;
  static DateTime _defaultNow() => DateTime.now().toUtc();

  /// Expands a semantic subject selector into exact persisted dependencies.
  /// Capture markers may include member identity (edition/binding generation);
  /// hashing a member-less selector cannot match those exact index entries.
  Future<int> invalidateSubject({
    required String projectId,
    required String designRevisionId,
    required String relationKind,
    required String domain,
    required String subjectId,
  }) => database.transaction(() async {
    await DriftElv5LifecycleInvalidation(
      database,
      originDeviceId: originDeviceId,
    ).requireWorking(projectId, designRevisionId);
    final rows =
        await database
            .customSelect(
              'SELECT DISTINCT dependency_key, dependency_key_sha256 '
              'FROM discipline_dependency_index WHERE project_id = ? '
              'AND design_revision_id = ? AND relation_kind = ? '
              r"AND json_extract(dependency_key, '$.domain') = ? "
              r"AND json_extract(dependency_key, '$.subjectId') = ?",
              variables: <Variable>[
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
                Variable.withString(relationKind.trim().toUpperCase()),
                Variable.withString(domain),
                Variable.withString(subjectId),
              ],
            )
            .get();
    final dependencies = <Elv5InvalidationDependency>[];
    for (final row in rows) {
      final value = jsonDecode(row.read<String>('dependency_key')) as Map;
      final dependency = Elv5InvalidationDependency(
        relationKind: value['relationKind'] as String,
        domain: value['domain'] as String,
        subjectId: value['subjectId'] as String,
        memberId: value['memberId'] as String?,
      );
      if (value['schema'] != 'electra.elv5-dependency-key.v1' ||
          dependency.sha256 != row.read<String>('dependency_key_sha256')) {
        throw StateError('ELV5_DEPENDENCY_INDEX_HASH_MISMATCH');
      }
      dependencies.add(dependency);
    }
    return invalidate(
      projectId: projectId,
      designRevisionId: designRevisionId,
      dependencies: dependencies,
    );
  });

  Future<int> invalidate({
    required String projectId,
    required String designRevisionId,
    required Iterable<Elv5InvalidationDependency> dependencies,
  }) => database.transaction(() async {
    final lifecycle = DriftElv5LifecycleInvalidation(
      database,
      originDeviceId: originDeviceId,
    );
    await lifecycle.requireWorking(projectId, designRevisionId);
    final hashes = <String>{
      for (final dependency in dependencies) dependency.sha256,
    };
    if (hashes.isEmpty) return 0;
    final ordered = hashes.toList()..sort();
    final placeholders = List.filled(ordered.length, '?').join(',');
    final rows =
        await database
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
    return lifecycle.invalidateNodes(
      projectId: projectId,
      designRevisionId: designRevisionId,
      nodeHashes: nodeHashes,
      updatedAtUtc: _nowUtc(),
    );
  });
}

final class Elv5InvalidationDependency {
  static const _encoder = Elv5CanonicalJsonV1();
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
