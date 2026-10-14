import 'package:engineering_core/engineering_core.dart';

final class PersistRouteSeparationEvidenceCommand {
  const PersistRouteSeparationEvidenceCommand({
    required this.commandId,
    required this.projectId,
    required this.designRevisionId,
    required this.evidenceId,
    required this.subjectAId,
    required this.subjectBId,
    required this.distanceMm,
    required this.kind,
    required this.provenance,
    this.expectedRevision,
  });

  final String commandId;
  final String projectId;
  final String designRevisionId;
  final String evidenceId;
  final String subjectAId;
  final String subjectBId;
  final double distanceMm;
  final RouteSeparationEvidenceKind kind;
  final String provenance;
  final int? expectedRevision;
}
