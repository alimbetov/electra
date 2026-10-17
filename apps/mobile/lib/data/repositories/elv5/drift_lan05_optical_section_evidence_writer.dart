import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/lan/lan05_optical_section_evidence_write.dart';
import '../../database/app_database.dart';

final class DriftLan05OpticalSectionEvidenceWriter
    implements Lan05OpticalSectionEvidenceWriter {
  const DriftLan05OpticalSectionEvidenceWriter(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? _defaultNow;

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  static DateTime _defaultNow() => DateTime.now().toUtc();

  @override
  Future<void> replace(
    ReplaceLan05SectionEvidenceCommand command,
  ) => database.transaction(() async {
    final root = await database
        .customSelect(
          'SELECT id, revision FROM link_composition_bindings '
          'WHERE project_id = ? AND design_revision_id = ? AND link_id = ? '
          'AND deleted_at IS NULL',
          variables: <Variable>[
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable.withString(command.linkId),
          ],
        )
        .getSingleOrNull();
    if (root == null) {
      throw StateError('LAN05_LINK_COMPOSITION_NOT_FOUND:${command.linkId}');
    }
    final bindingId = root.read<String>('id');
    final rootRevision = root.read<int>('revision');
    if (rootRevision != command.expectedLinkRevision) {
      throw StateError(
        'LAN05_LINK_REVISION_CONFLICT:${command.expectedLinkRevision}:$rootRevision',
      );
    }

    final sections = await database
        .customSelect(
          'SELECT ordinal FROM link_section_assignments '
          'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? '
          'AND realized_section_id = ?',
          variables: <Variable>[
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable.withString(bindingId),
            Variable.withString(command.realizedSectionId),
          ],
        )
        .get();
    if (sections.length != 1) {
      throw StateError(
        'LAN05_REALIZED_SECTION_MEMBERSHIP_INVALID:'
        '${command.realizedSectionId}:${sections.length}',
      );
    }

    final now = _nowUtc().toUtc();
    final evidenceJson = utf8.decode(
      _encoder.encode(command.evidencePayload),
      allowMalformed: false,
    );
    final changedEvidence = await database.customUpdate(
      'UPDATE link_section_assignments SET evidence_json = ? '
      'WHERE project_id = ? AND design_revision_id = ? AND binding_id = ? '
      'AND realized_section_id = ?',
      variables: <Variable>[
        Variable.withString(evidenceJson),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(bindingId),
        Variable.withString(command.realizedSectionId),
      ],
    );
    if (changedEvidence != 1) {
      throw StateError('LAN05_SECTION_EVIDENCE_WRITE_FAILED');
    }

    final changedRoot = await database.customUpdate(
      'UPDATE link_composition_bindings '
      'SET revision = revision + 1, updated_at = ?, origin_device_id = ? '
      'WHERE project_id = ? AND design_revision_id = ? AND id = ? '
      'AND revision = ? AND deleted_at IS NULL',
      variables: <Variable>[
        Variable<DateTime>(now),
        Variable.withString(originDeviceId),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(bindingId),
        Variable<int>(command.expectedLinkRevision),
      ],
    );
    if (changedRoot != 1) {
      throw StateError('LAN05_LINK_REVISION_CAS_FAILED');
    }

    final changedDesign = await database.customUpdate(
      'UPDATE project_design_revisions '
      'SET revision = revision + 1, updated_at = ?, origin_device_id = ? '
      'WHERE project_id = ? AND id = ? AND revision = ? '
      "AND state = 'WORKING' AND deleted_at IS NULL",
      variables: <Variable>[
        Variable<DateTime>(now),
        Variable.withString(originDeviceId),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable<int>(command.expectedDesignRevision),
      ],
    );
    if (changedDesign != 1) {
      throw StateError('LAN05_DESIGN_REVISION_CAS_FAILED');
    }
  });
}
