import 'package:engineering_core/engineering_core.dart';
export 'package:engineering_core/engineering_core.dart';

enum EditorTool { select, point, route, measure, architecturalFeature }

class ProjectDraft {
  ProjectDraft({
    required this.id,
    required this.name,
    required this.reference,
    required this.measurementSystem,
    required this.defaultStructuralHeightMm,
    required this.defaultFinishedCeilingHeightMm,
  });

  final String id;
  final String name;
  final String reference;
  final MeasurementSystem measurementSystem;
  final int defaultStructuralHeightMm;
  final int defaultFinishedCeilingHeightMm;
  final List<RoomDraft> rooms = [];
}

class RoomDraft {
  RoomDraft({
    required this.id,
    required this.name,
    required this.type,
    required this.widthMm,
    required this.depthMm,
    this.structuralHeightMmOverride,
    this.finishedCeilingHeightMmOverride,
  });

  final String id;
  final String name;
  final RoomType type;
  final int widthMm;
  final int depthMm;
  final int? structuralHeightMmOverride;
  final int? finishedCeilingHeightMmOverride;
}

String newLocalId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
