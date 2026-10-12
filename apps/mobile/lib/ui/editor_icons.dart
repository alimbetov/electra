import 'package:flutter/material.dart';

import '../domain/models.dart';

abstract final class ElectraIcons {
  static IconData tool(EditorTool tool) => switch (tool) {
        EditorTool.select => Icons.near_me_outlined,
        EditorTool.point => Icons.add_location_alt_outlined,
        EditorTool.equipment => Icons.precision_manufacturing_outlined,
        EditorTool.route => Icons.route_outlined,
        EditorTool.measure => Icons.straighten_outlined,
        EditorTool.architecturalFeature => Icons.architecture_outlined,
      };

  static IconData feature(ArchitecturalFeatureType type) => switch (type) {
        ArchitecturalFeatureType.door => Icons.door_front_door_outlined,
        ArchitecturalFeatureType.window => Icons.window_outlined,
        ArchitecturalFeatureType.passage => Icons.sensor_door_outlined,
        ArchitecturalFeatureType.technicalOpening => Icons.crop_square_outlined,
        ArchitecturalFeatureType.beam => Icons.horizontal_rule,
        ArchitecturalFeatureType.column => Icons.view_column_outlined,
        ArchitecturalFeatureType.soffit => Icons.view_stream_outlined,
        ArchitecturalFeatureType.niche => Icons.insert_chart_outlined,
        ArchitecturalFeatureType.shaft => Icons.unfold_more_outlined,
        ArchitecturalFeatureType.step => Icons.stairs_outlined,
        ArchitecturalFeatureType.platform => Icons.layers_outlined,
        ArchitecturalFeatureType.recess => Icons.indeterminate_check_box_outlined,
        ArchitecturalFeatureType.protrusion => Icons.add_box_outlined,
        ArchitecturalFeatureType.custom => Icons.category_outlined,
      };

  static IconData equipment(EquipmentCategory category) => switch (category) {
        EquipmentCategory.electricalPoint => Icons.power_outlined,
        EquipmentCategory.lighting => Icons.lightbulb_outline,
        EquipmentCategory.distribution => Icons.account_tree_outlined,
        EquipmentCategory.motor => Icons.settings_outlined,
        EquipmentCategory.pump => Icons.water_outlined,
        EquipmentCategory.fan => Icons.air_outlined,
        EquipmentCategory.compressor => Icons.compress_outlined,
        EquipmentCategory.machineTool => Icons.precision_manufacturing_outlined,
        EquipmentCategory.cncMachine => Icons.memory_outlined,
        EquipmentCategory.conveyor => Icons.linear_scale_outlined,
        EquipmentCategory.weldingEquipment => Icons.flash_on_outlined,
        EquipmentCategory.heater => Icons.local_fire_department_outlined,
        EquipmentCategory.boiler => Icons.hot_tub_outlined,
        EquipmentCategory.refrigeration => Icons.ac_unit_outlined,
        EquipmentCategory.hvacEquipment => Icons.air_outlined,
        EquipmentCategory.processEquipment => Icons.factory_outlined,
        EquipmentCategory.variableFrequencyDrive => Icons.speed_outlined,
        EquipmentCategory.softStarter => Icons.electric_bolt_outlined,
        EquipmentCategory.controlPanel => Icons.developer_board_outlined,
        EquipmentCategory.plcPanel => Icons.memory_outlined,
        EquipmentCategory.sensor => Icons.sensors_outlined,
        EquipmentCategory.actuator => Icons.open_with_outlined,
        EquipmentCategory.instrumentation => Icons.speed_outlined,
        EquipmentCategory.networkEquipment => Icons.router_outlined,
        EquipmentCategory.safetyEquipment => Icons.health_and_safety_outlined,
        EquipmentCategory.custom => Icons.category_outlined,
      };

  static IconData discipline(Discipline discipline) => switch (discipline) {
        Discipline.architecture => Icons.architecture_outlined,
        Discipline.electrical => Icons.electrical_services_outlined,
        Discipline.lowVoltage => Icons.cable_outlined,
        Discipline.cctv => Icons.videocam_outlined,
        Discipline.fireAlarm => Icons.local_fire_department_outlined,
        Discipline.security => Icons.shield_outlined,
        Discipline.accessControl => Icons.meeting_room_outlined,
        Discipline.plumbing => Icons.plumbing_outlined,
        Discipline.heating => Icons.thermostat_outlined,
        Discipline.hvac => Icons.air_outlined,
        Discipline.gas => Icons.propane_tank_outlined,
        Discipline.drainage => Icons.water_drop_outlined,
        Discipline.solar => Icons.solar_power_outlined,
        Discipline.evCharging => Icons.ev_station_outlined,
        Discipline.industrialAutomation => Icons.precision_manufacturing_outlined,
      };
}

abstract final class ElectraUi {
  static const double minimumTouchTarget = 48;
  static const double toolRailWidth = 80;
  static const double inspectorWidth = 304;
  static const double compactBreakpoint = 900;
  static const double radius = 12;
}
