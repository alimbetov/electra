import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/lan/elv3_realized_link_facts.dart';
import '../../database/app_database.dart';

/// Builds conservative ELV5 length intervals directly from persisted integer-mm
/// ELV3 route geometry. Legacy derived double lengths are never consumed.
final class DriftElv3RealizedLinkFactSource
    implements Elv3RealizedLinkFactSource {
  const DriftElv3RealizedLinkFactSource(this.database);

  final AppDatabase database;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Future<Elv3RealizedSectionLengthFact> requireSectionLength({
    required String projectId,
    required String designRevisionId,
    required String realizedSectionId,
  }) async {
    final rows = await database.customSelect(
      'SELECT t.id AS traversal_id, t.route_segment_id, t.cable_run_id, '
      'r.revision AS run_revision, r.reserve_percent, '
      'r.termination_allowance_mm, '
      'n1.world_xmm AS x1, n1.world_ymm AS y1, n1.world_zmm AS z1, '
      'n2.world_xmm AS x2, n2.world_ymm AS y2, n2.world_zmm AS z2, '
      '(SELECT COUNT(*) FROM cable_run_traversals tx '
      ' WHERE tx.cable_run_id = r.id AND tx.deleted_at IS NULL) AS run_member_count '
      'FROM cable_run_traversals t '
      'JOIN canonical_cable_runs r ON r.id = t.cable_run_id '
      'JOIN cable_route_segments s ON s.id = t.route_segment_id '
      'JOIN cable_route_nodes n1 ON n1.id = s.from_node_id '
      'JOIN cable_route_nodes n2 ON n2.id = s.to_node_id '
      'WHERE r.project_id = ? AND r.design_revision_id = ? '
      'AND t.id = ? AND r.deleted_at IS NULL AND t.deleted_at IS NULL '
      'AND s.deleted_at IS NULL AND n1.deleted_at IS NULL AND n2.deleted_at IS NULL',
      variables: <Variable>[
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(realizedSectionId),
      ],
    ).get();
    if (rows.isEmpty) {
      throw StateError('ELV3_REALIZED_SECTION_NOT_FOUND:$realizedSectionId');
    }
    if (rows.length != 1) {
      throw StateError('ELV3_REALIZED_SECTION_AMBIGUOUS:$realizedSectionId');
    }
    final row = rows.single;

    // ELV3 reservePercent is legacy REAL. Using a non-zero binary floating
    // value as an exact ELV5 engineering factor would violate the numeric
    // contract. Until reserve is persisted as exact decimal/rational evidence,
    // affected realized sections fail closed.
    final reservePercent = row.read<double>('reserve_percent');
    if (!reservePercent.isFinite || reservePercent != 0) {
      throw StateError(
        'ELV3_REALIZED_SECTION_EXACT_RESERVE_REQUIRED:$realizedSectionId',
      );
    }

    final memberCount = row.read<int>('run_member_count');
    final terminationMm = row.read<int>('termination_allowance_mm');
    if (terminationMm != 0 && memberCount != 1) {
      throw StateError(
        'ELV3_REALIZED_SECTION_ALLOWANCE_PROVENANCE_REQUIRED:$realizedSectionId',
      );
    }

    final dx = BigInt.from(row.read<int>('x2') - row.read<int>('x1'));
    final dy = BigInt.from(row.read<int>('y2') - row.read<int>('y1'));
    final dz = BigInt.from(row.read<int>('z2') - row.read<int>('z1'));
    final squareMm = dx * dx + dy * dy + dz * dz;
    final floorMm = _integerSqrt(squareMm);
    final ceilMm = floorMm * floorMm == squareMm ? floorMm : floorMm + BigInt.one;
    final allowance = memberCount == 1 ? BigInt.from(terminationMm) : BigInt.zero;

    final lower = Length(Elv5Rational(floorMm + allowance, BigInt.from(1000)));
    final upper = Length(Elv5Rational(ceilMm + allowance, BigInt.from(1000)));
    final routeSegmentId = row.read<String>('route_segment_id');
    final cableRunId = row.read<String>('cable_run_id');
    final runRevision = row.read<int>('run_revision');
    final fingerprintValue = <String, Object?>{
      'schema': 'electra.elv3-realized-section-length.v1',
      'realizedSectionId': realizedSectionId,
      'routeSegmentId': routeSegmentId,
      'cableRunId': cableRunId,
      'cableRunRevision': runRevision,
      'worldEndpointsMm': <Object?>[
        <Object?>[row.read<int>('x1'), row.read<int>('y1'), row.read<int>('z1')],
        <Object?>[row.read<int>('x2'), row.read<int>('y2'), row.read<int>('z2')],
      ],
      'terminationAllowanceMm': terminationMm,
      'runMemberCount': memberCount,
      'reservePercentExactZero': true,
      'lengthLowerM': lower.value.toMap(),
      'lengthUpperM': upper.value.toMap(),
    };

    return Elv3RealizedSectionLengthFact(
      realizedSectionId: realizedSectionId,
      routeSegmentId: routeSegmentId,
      cableRunId: cableRunId,
      cableRunRevision: runRevision,
      installedLength: Lan01LengthInterval(lower: lower, upper: upper),
      includesRunReserve: true,
      includesTerminationAllowance: terminationMm == 0 || memberCount == 1,
      sourceFingerprint: _encoder.sha256(fingerprintValue),
    );
  }
}

BigInt _integerSqrt(BigInt value) {
  if (value < BigInt.zero) throw ArgumentError('sqrt input must be nonnegative.');
  if (value < BigInt.two) return value;
  var x = BigInt.one << ((value.bitLength + 1) >> 1);
  while (true) {
    final next = (x + value ~/ x) >> 1;
    if (next >= x) return x;
    x = next;
  }
}
