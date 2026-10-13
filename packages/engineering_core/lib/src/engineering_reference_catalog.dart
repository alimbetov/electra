import 'engineering_system.dart';
import 'engineering_topology.dart';

enum ReferenceDiscipline { cctv, lan, acs, fire }

enum CanonicalComponentClass {
  camera,
  recorder,
  switchDevice,
  outlet,
  patchPanel,
  reader,
  lock,
  controller,
  detector,
  manualCallPoint,
  isolator,
  loopModule
}

enum CanonicalCapability {
  videoSource,
  videoRecorder,
  ethernet,
  poeSource,
  poeConsumer,
  passivePatching,
  accessReader,
  accessActuator,
  addressable,
  isolation
}

enum VideoCodec { h264, h265, mjpeg }

enum CopperCategory { cat5e, cat6, cat6a, cat7, cat8 }

enum LockBehavior { failSafe, failSecure }

sealed class DisciplineCharacteristics {
  const DisciplineCharacteristics();
  ReferenceDiscipline get discipline;
  List<String> validate();
  Map<String, Object?> toMap();
  factory DisciplineCharacteristics.fromMap(Map<String, dynamic> m) =>
      switch (ReferenceDiscipline.values.byName(m['discipline'] as String)) {
        ReferenceDiscipline.cctv => CctvCharacteristics(
            codec: m['codec'] == null
                ? null
                : VideoCodec.values.byName(m['codec'] as String),
            bitrateMbps: (m['bitrateMbps'] as num?)?.toDouble(),
            powerDemandW: (m['powerDemandW'] as num?)?.toDouble()),
        ReferenceDiscipline.lan => LanCharacteristics(
            category: m['category'] == null
                ? null
                : CopperCategory.values.byName(m['category'] as String),
            speedMbps: (m['speedMbps'] as num?)?.toDouble(),
            poeBudgetW: (m['poeBudgetW'] as num?)?.toDouble()),
        ReferenceDiscipline.acs => AcsCharacteristics(
            lockBehavior: m['lockBehavior'] == null
                ? null
                : LockBehavior.values.byName(m['lockBehavior'] as String),
            operatingCurrentA: (m['operatingCurrentA'] as num?)?.toDouble(),
            controllerChannels: m['controllerChannels'] as int?),
        ReferenceDiscipline.fire => FireCharacteristics(
            addressConsumption: m['addressConsumption'] as int?,
            standbyCurrentA: (m['standbyCurrentA'] as num?)?.toDouble(),
            alarmCurrentA: (m['alarmCurrentA'] as num?)?.toDouble()),
      };
}

List<String> _quantities(Iterable<double?> values) => [
      for (final v in values)
        if (v != null && (!v.isFinite || v < 0))
          'Quantities must be finite and nonnegative.'
    ];

class CctvCharacteristics extends DisciplineCharacteristics {
  const CctvCharacteristics({this.codec, this.bitrateMbps, this.powerDemandW});
  final VideoCodec? codec;
  final double? bitrateMbps;
  final double? powerDemandW;
  @override
  ReferenceDiscipline get discipline => ReferenceDiscipline.cctv;
  @override
  List<String> validate() => [
        ..._quantities([bitrateMbps, powerDemandW]),
      ];
  @override
  Map<String, Object?> toMap() => {
        'discipline': discipline.name,
        'codec': codec?.name,
        'bitrateMbps': bitrateMbps,
        'powerDemandW': powerDemandW
      };
}

class LanCharacteristics extends DisciplineCharacteristics {
  const LanCharacteristics({this.category, this.speedMbps, this.poeBudgetW});
  final CopperCategory? category;
  final double? speedMbps;
  final double? poeBudgetW;
  @override
  ReferenceDiscipline get discipline => ReferenceDiscipline.lan;
  @override
  List<String> validate() => [
        ..._quantities([speedMbps, poeBudgetW]),
      ];
  @override
  Map<String, Object?> toMap() => {
        'discipline': discipline.name,
        'category': category?.name,
        'speedMbps': speedMbps,
        'poeBudgetW': poeBudgetW
      };
}

class AcsCharacteristics extends DisciplineCharacteristics {
  const AcsCharacteristics(
      {this.lockBehavior, this.operatingCurrentA, this.controllerChannels});
  final LockBehavior? lockBehavior;
  final double? operatingCurrentA;
  final int? controllerChannels;
  @override
  ReferenceDiscipline get discipline => ReferenceDiscipline.acs;
  @override
  List<String> validate() => [
        ..._quantities([operatingCurrentA]),
        if (controllerChannels != null && controllerChannels! < 0)
          'Capacity cannot be negative.',
      ];
  @override
  Map<String, Object?> toMap() => {
        'discipline': discipline.name,
        'lockBehavior': lockBehavior?.name,
        'operatingCurrentA': operatingCurrentA,
        'controllerChannels': controllerChannels
      };
}

class FireCharacteristics extends DisciplineCharacteristics {
  const FireCharacteristics(
      {this.addressConsumption, this.standbyCurrentA, this.alarmCurrentA});
  final int? addressConsumption;
  final double? standbyCurrentA;
  final double? alarmCurrentA;
  @override
  ReferenceDiscipline get discipline => ReferenceDiscipline.fire;
  @override
  List<String> validate() => [
        ..._quantities([standbyCurrentA, alarmCurrentA]),
        if (addressConsumption != null && addressConsumption! < 0)
          'Capacity cannot be negative.',
      ];
  @override
  Map<String, Object?> toMap() => {
        'discipline': discipline.name,
        'addressConsumption': addressConsumption,
        'standbyCurrentA': standbyCurrentA,
        'alarmCurrentA': alarmCurrentA
      };
}

class ComponentEngineeringProfile {
  ComponentEngineeringProfile(
      {required this.code,
      required this.label,
      required this.engineeringClass,
      required this.characteristics,
      required Iterable<CanonicalCapability> capabilities,
      required Iterable<EngineeringPort> portTemplates,
      this.deprecated = false})
      : capabilities = List.unmodifiable(capabilities),
        portTemplates = List.unmodifiable(portTemplates);
  final String code, label;
  final CanonicalComponentClass engineeringClass;
  final DisciplineCharacteristics characteristics;
  final List<CanonicalCapability> capabilities;

  /// Template placeholder identities are replaced by persisted instance identities.
  final List<EngineeringPort> portTemplates;
  final bool deprecated;
  ReferenceDiscipline get discipline => characteristics.discipline;
  List<String> validate() => [
        if (code.trim().isEmpty || label.trim().isEmpty)
          'Profile code and label are required.',
        ...characteristics.validate(),
        if (capabilities.toSet().length != capabilities.length)
          'Duplicate capability.',
        if (portTemplates
                .map((p) => p.code.trim().toUpperCase())
                .toSet()
                .length !=
            portTemplates.length)
          'Duplicate port template code.',
        for (final p in portTemplates) ...p.validate(),
        if (!switch (discipline) {
          ReferenceDiscipline.cctv => [
              CanonicalComponentClass.camera,
              CanonicalComponentClass.recorder,
              CanonicalComponentClass.switchDevice
            ].contains(engineeringClass),
          ReferenceDiscipline.lan => [
              CanonicalComponentClass.switchDevice,
              CanonicalComponentClass.outlet,
              CanonicalComponentClass.patchPanel
            ].contains(engineeringClass),
          ReferenceDiscipline.acs => [
              CanonicalComponentClass.reader,
              CanonicalComponentClass.lock,
              CanonicalComponentClass.controller
            ].contains(engineeringClass),
          ReferenceDiscipline.fire => [
              CanonicalComponentClass.detector,
              CanonicalComponentClass.manualCallPoint,
              CanonicalComponentClass.isolator,
              CanonicalComponentClass.loopModule,
              CanonicalComponentClass.controller
            ].contains(engineeringClass),
        })
          'Component class does not belong to the declared discipline.',
      ];
  List<EngineeringPort> instantiate(
      {required String componentId,
      required String catalogId,
      required String version,
      required String Function() nextId}) {
    if (deprecated ||
        validate().isNotEmpty ||
        componentId.trim().isEmpty ||
        catalogId.trim().isEmpty ||
        version.trim().isEmpty)
      throw StateError(
          'Resolve an active valid profile and exact provenance before instantiation.');
    final ports = portTemplates
        .map((p) => EngineeringPort.fromMap({
              ...p.toMap(),
              'id': nextId(),
              'componentId': componentId,
              'templateProvenance': EngineeringProfileReference(
                      id: '$catalogId/$code/${p.code}', version: version)
                  .toMap()
            }))
        .toList();
    if (ports.any((p) => p.validate().isNotEmpty) ||
        ports.map((p) => p.id).toSet().length != ports.length)
      throw StateError('Port identities must be valid and unique.');
    return ports;
  }

  Map<String, Object?> toMap() => {
        'code': code,
        'label': label,
        'engineeringClass': engineeringClass.name,
        'characteristics': characteristics.toMap(),
        'capabilities': capabilities.map((c) => c.name).toList(),
        'portTemplates': portTemplates.map((p) => p.toMap()).toList(),
        'deprecated': deprecated
      };
  factory ComponentEngineeringProfile.fromMap(Map<String, dynamic> m) =>
      ComponentEngineeringProfile(
          code: m['code'] as String,
          label: m['label'] as String,
          engineeringClass: CanonicalComponentClass.values
              .byName(m['engineeringClass'] as String),
          characteristics: DisciplineCharacteristics.fromMap(
              m['characteristics'] as Map<String, dynamic>),
          capabilities: (m['capabilities'] as List)
              .map((c) => CanonicalCapability.values.byName(c as String)),
          portTemplates: (m['portTemplates'] as List)
              .map((p) => EngineeringPort.fromMap(p as Map<String, dynamic>)),
          deprecated: m['deprecated'] as bool? ?? false);
}

class EngineeringReferenceCatalog {
  EngineeringReferenceCatalog(
      {required this.id,
      required this.code,
      required this.version,
      required this.source,
      required Iterable<ComponentEngineeringProfile> profiles,
      this.jurisdiction})
      : profiles = List.unmodifiable(profiles);
  final String id, code, version, source;
  final String? jurisdiction;
  final List<ComponentEngineeringProfile> profiles;
  List<String> validate() => [
        if ([id, code, version, source].any((v) => v.trim().isEmpty))
          'Catalog identity, code, version and provenance are required.',
        if (profiles.isEmpty) 'Provide at least one engineering profile.',
        if (profiles.map((p) => p.code).toSet().length != profiles.length)
          'Profile codes must be unique.',
        for (final p in profiles) ...p.validate()
      ];
  ComponentEngineeringProfile profile(String code) =>
      profiles.singleWhere((p) => p.code == code);
  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'version': version,
        'source': source,
        'jurisdiction': jurisdiction,
        'profiles': profiles.map((p) => p.toMap()).toList()
      };
  factory EngineeringReferenceCatalog.fromMap(Map<String, dynamic> m) =>
      EngineeringReferenceCatalog(
          id: m['id'] as String,
          code: m['code'] as String,
          version: m['version'] as String,
          source: m['source'] as String,
          jurisdiction: m['jurisdiction'] as String?,
          profiles: (m['profiles'] as List).map((p) =>
              ComponentEngineeringProfile.fromMap(p as Map<String, dynamic>)));
}
