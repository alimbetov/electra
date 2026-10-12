import 'package:engineering_core/engineering_core.dart';

abstract class RevisionedRecord {
  const RevisionedRecord({
    required this.id,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.originDeviceId,
    this.deletedAt,
  });

  final String id;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String originDeviceId;
}

class ProjectRecord extends RevisionedRecord {
  const ProjectRecord({
    required super.id,
    required this.name,
    required this.reference,
    required this.measurementSystem,
    required this.defaultStructuralHeightMm,
    required this.defaultFinishedCeilingHeightMm,
    required super.revision,
    required super.createdAt,
    required super.updatedAt,
    required super.originDeviceId,
    super.deletedAt,
  });

  final String name;
  final String reference;
  final MeasurementSystem measurementSystem;
  final int defaultStructuralHeightMm;
  final int defaultFinishedCeilingHeightMm;
}

class FloorRecord extends RevisionedRecord {
  const FloorRecord({
    required super.id,
    required this.projectId,
    required this.name,
    required this.code,
    required this.sortOrder,
    required super.revision,
    required super.createdAt,
    required super.updatedAt,
    required super.originDeviceId,
    this.defaultStructuralHeightMm,
    this.defaultFinishedCeilingHeightMm,
    super.deletedAt,
  });

  final String projectId;
  final String name;
  final String code;
  final int sortOrder;
  final int? defaultStructuralHeightMm;
  final int? defaultFinishedCeilingHeightMm;
}

class RoomRecord extends RevisionedRecord {
  const RoomRecord({
    required super.id,
    required this.floorId,
    required this.name,
    required this.type,
    required this.category,
    required this.widthMm,
    required this.depthMm,
    required super.revision,
    required super.createdAt,
    required super.updatedAt,
    required super.originDeviceId,
    this.structuralHeightMmOverride,
    this.finishedCeilingHeightMmOverride,
    super.deletedAt,
  });

  final String floorId;
  final String name;
  final RoomType type;
  final RoomCategory category;
  final int widthMm;
  final int depthMm;
  final int? structuralHeightMmOverride;
  final int? finishedCeilingHeightMmOverride;
}

class ProjectFormDraft {
  const ProjectFormDraft({
    required this.name,
    required this.reference,
    required this.measurementSystem,
    required this.defaultStructuralHeightMm,
    required this.defaultFinishedCeilingHeightMm,
  });

  final String name;
  final String reference;
  final MeasurementSystem measurementSystem;
  final int defaultStructuralHeightMm;
  final int defaultFinishedCeilingHeightMm;
}

class FloorFormDraft {
  const FloorFormDraft({
    required this.name,
    required this.code,
    required this.sortOrder,
    this.defaultStructuralHeightMm,
    this.defaultFinishedCeilingHeightMm,
  });

  final String name;
  final String code;
  final int sortOrder;
  final int? defaultStructuralHeightMm;
  final int? defaultFinishedCeilingHeightMm;
}

class RoomFormDraft {
  const RoomFormDraft({
    required this.name,
    required this.type,
    required this.category,
    required this.widthMm,
    required this.depthMm,
    this.structuralHeightMmOverride,
    this.finishedCeilingHeightMmOverride,
  });

  final String name;
  final RoomType type;
  final RoomCategory category;
  final int widthMm;
  final int depthMm;
  final int? structuralHeightMmOverride;
  final int? finishedCeilingHeightMmOverride;
}
