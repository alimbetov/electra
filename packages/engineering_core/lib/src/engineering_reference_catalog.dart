import 'engineering_reference_constraints.dart';
import 'engineering_reference_vocabulary.dart';
import 'engineering_system.dart';
import 'engineering_topology.dart';

String normalizeEngineeringReferenceCode(String value) =>
    value.trim().toUpperCase();

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
  loopModule,
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
  isolation,
}

enum ProfileConstraintsState { defined, legacyUnspecified }

enum VideoCodec { h264, h265, mjpeg }

enum CopperCategory { cat5e, cat6, cat6a, cat7, cat8 }

enum LockBehavior { failSafe, failSecure }

sealed class DisciplineCharacteristics {
  const DisciplineCharacteristics();

  ReferenceDiscipline get discipline;
  List<String> validate();
  Map<String, Object?> toMap();

  factory DisciplineCharacteristics.fromMap(Map<String, dynamic> map) =>
      switch (ReferenceDiscipline.values.byName(map['discipline'] as String)) {
        ReferenceDiscipline.cctv => CctvCharacteristics(
            codec: map['codec'] == null
                ? null
                : VideoCodec.values.byName(map['codec'] as String),
            bitrateMbps: (map['bitrateMbps'] as num?)?.toDouble(),
            powerDemandW: (map['powerDemandW'] as num?)?.toDouble(),
          ),
        ReferenceDiscipline.lan => LanCharacteristics(
            category: map['category'] == null
                ? null
                : CopperCategory.values.byName(map['category'] as String),
            speedMbps: (map['speedMbps'] as num?)?.toDouble(),
            poeBudgetW: (map['poeBudgetW'] as num?)?.toDouble(),
          ),
        ReferenceDiscipline.acs => AcsCharacteristics(
            lockBehavior: map['lockBehavior'] == null
                ? null
                : LockBehavior.values.byName(map['lockBehavior'] as String),
            operatingCurrentA: (map['operatingCurrentA'] as num?)?.toDouble(),
            controllerChannels: map['controllerChannels'] as int?,
          ),
        ReferenceDiscipline.fire => FireCharacteristics(
            addressConsumption: map['addressConsumption'] as int?,
            standbyCurrentA: (map['standbyCurrentA'] as num?)?.toDouble(),
            alarmCurrentA: (map['alarmCurrentA'] as num?)?.toDouble(),
          ),
      };
}

List<String> _quantities(Iterable<double?> values) => [
      for (final value in values)
        if (value != null && (!value.isFinite || value < 0))
          'Quantities must be finite and nonnegative.',
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
        ..._quantities([bitrateMbps, powerDemandW])
      ];

  @override
  Map<String, Object?> toMap() => {
        'discipline': discipline.name,
        'codec': codec?.name,
        'bitrateMbps': bitrateMbps,
        'powerDemandW': powerDemandW,
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
        ..._quantities([speedMbps, poeBudgetW])
      ];

  @override
  Map<String, Object?> toMap() => {
        'discipline': discipline.name,
        'category': category?.name,
        'speedMbps': speedMbps,
        'poeBudgetW': poeBudgetW,
      };
}

class AcsCharacteristics extends DisciplineCharacteristics {
  const AcsCharacteristics({
    this.lockBehavior,
    this.operatingCurrentA,
    this.controllerChannels,
  });

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
        'controllerChannels': controllerChannels,
      };
}

class FireCharacteristics extends DisciplineCharacteristics {
  const FireCharacteristics({
    this.addressConsumption,
    this.standbyCurrentA,
    this.alarmCurrentA,
  });

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
        'alarmCurrentA': alarmCurrentA,
      };
}

class ComponentEngineeringProfile {
  ComponentEngineeringProfile({
    required this.code,
    required this.label,
    required this.engineeringClass,
    required this.characteristics,
    required Iterable<CanonicalCapability> capabilities,
    required Iterable<EngineeringPort> portTemplates,
    this.deprecated = false,
    Map<String, String> portInterfaceCodes = const {},
    this.constraints,
    ProfileConstraintsState? constraintsState,
  })  : capabilities = List.unmodifiable(capabilities),
        portTemplates = List.unmodifiable(portTemplates),
        portInterfaceCodes = Map.unmodifiable(portInterfaceCodes),
        constraintsState = constraintsState ??
            (constraints == null
                ? ProfileConstraintsState.legacyUnspecified
                : ProfileConstraintsState.defined);

  final String code;
  final String label;
  final CanonicalComponentClass engineeringClass;
  final DisciplineCharacteristics characteristics;
  final List<CanonicalCapability> capabilities;
  final List<EngineeringPort> portTemplates;
  final bool deprecated;
  final Map<String, String> portInterfaceCodes;
  final ProfileConstraintsState constraintsState;
  final EngineeringProfileConstraints? constraints;

  ReferenceDiscipline get discipline => characteristics.discipline;
  bool get hasDefinedConstraints =>
      constraintsState == ProfileConstraintsState.defined &&
      constraints != null;

  List<String> validate() => [
        if (code.trim().isEmpty || label.trim().isEmpty)
          'Profile code and label are required.',
        ...characteristics.validate(),
        if (constraintsState == ProfileConstraintsState.defined &&
            constraints == null)
          'Defined constraint state requires a constraints payload.',
        if (constraintsState == ProfileConstraintsState.legacyUnspecified &&
            constraints != null)
          'Legacy unspecified constraint state cannot carry constraints.',
        if (constraints != null) ...constraints!.validate(),
        if (capabilities.toSet().length != capabilities.length)
          'Duplicate capability.',
        if (portTemplates
                .map((port) => normalizeEngineeringReferenceCode(port.code))
                .toSet()
                .length !=
            portTemplates.length)
          'Duplicate port template code.',
        if (portTemplates.any(
          (port) => port.code != normalizeEngineeringReferenceCode(port.code),
        ))
          'Port template codes must use canonical engineering identity.',
        for (final port in portTemplates) ...port.validate(),
        if (portInterfaceCodes.keys.any(
          (code) => code != normalizeEngineeringReferenceCode(code),
        ))
          'Interface binding keys must use canonical port identity.',
        if (portInterfaceCodes.keys.any(
          (code) => !portTemplates.any(
            (port) =>
                normalizeEngineeringReferenceCode(port.code) ==
                normalizeEngineeringReferenceCode(code),
          ),
        ))
          'Interface binding references an unknown port template.',
        if (!switch (discipline) {
          ReferenceDiscipline.cctv => [
              CanonicalComponentClass.camera,
              CanonicalComponentClass.recorder,
              CanonicalComponentClass.switchDevice,
            ].contains(engineeringClass),
          ReferenceDiscipline.lan => [
              CanonicalComponentClass.switchDevice,
              CanonicalComponentClass.outlet,
              CanonicalComponentClass.patchPanel,
            ].contains(engineeringClass),
          ReferenceDiscipline.acs => [
              CanonicalComponentClass.reader,
              CanonicalComponentClass.lock,
              CanonicalComponentClass.controller,
            ].contains(engineeringClass),
          ReferenceDiscipline.fire => [
              CanonicalComponentClass.detector,
              CanonicalComponentClass.manualCallPoint,
              CanonicalComponentClass.isolator,
              CanonicalComponentClass.loopModule,
              CanonicalComponentClass.controller,
            ].contains(engineeringClass),
        })
          'Component class does not belong to the declared discipline.',
      ];

  List<String> validateForPublication() => [
        ...validate(),
        if (!hasDefinedConstraints)
          'New canonical profiles must define mounting, environment and topology constraints.',
      ];

  List<EngineeringPort> instantiate({
    required String componentId,
    required String catalogId,
    required String version,
    required String Function() nextId,
    String Function(String templateCode)? idForTemplate,
    EngineeringReferenceVocabulary? vocabulary,
  }) {
    if (deprecated ||
        !hasDefinedConstraints ||
        validate().isNotEmpty ||
        componentId.trim().isEmpty ||
        catalogId.trim().isEmpty ||
        version.trim().isEmpty) {
      throw StateError(
        'Resolve an active valid profile with defined constraints and exact provenance before instantiation.',
      );
    }
    if (portInterfaceCodes.isNotEmpty && vocabulary == null) {
      throw StateError('Resolve the catalog vocabulary before instantiation.');
    }
    final resolved = portTemplates.map(
      (port) => portInterfaceCodes.containsKey(port.code)
          ? vocabulary!.resolve(
              port,
              portInterfaceCodes[port.code]!,
              catalogId: catalogId,
              version: version,
            )
          : port,
    );
    final ports = resolved
        .map(
          (port) => EngineeringPort.fromMap({
            ...port.toMap(),
            'id':
                idForTemplate?.call(port.code.trim().toUpperCase()) ?? nextId(),
            'componentId': componentId,
            'templateProvenance': EngineeringProfileReference(
              id: '$catalogId/$code/${port.code}',
              version: version,
            ).toMap(),
          }),
        )
        .toList();
    if (ports.any((port) => port.validate().isNotEmpty) ||
        ports.map((port) => port.id).toSet().length != ports.length) {
      throw StateError('Port identities must be valid and unique.');
    }
    return ports;
  }

  Map<String, Object?> toMap() => {
        'code': code,
        'label': label,
        'engineeringClass': engineeringClass.name,
        'characteristics': characteristics.toMap(),
        'capabilities':
            capabilities.map((capability) => capability.name).toList(),
        'portTemplates': portTemplates.map((port) => port.toMap()).toList(),
        if (portInterfaceCodes.isNotEmpty)
          'portInterfaceCodes': portInterfaceCodes,
        if (constraintsState == ProfileConstraintsState.defined)
          'constraintsState': constraintsState.name,
        if (constraints != null) 'constraints': constraints!.toMap(),
        'deprecated': deprecated,
      };

  factory ComponentEngineeringProfile.fromMap(Map<String, dynamic> map) {
    final rawConstraints = map['constraints'] as Map<String, dynamic>?;
    final stateName = map['constraintsState'] as String?;
    final state = stateName == null
        ? (rawConstraints == null
            ? ProfileConstraintsState.legacyUnspecified
            : ProfileConstraintsState.defined)
        : ProfileConstraintsState.values.byName(stateName);
    return ComponentEngineeringProfile(
      code: map['code'] as String,
      label: map['label'] as String,
      engineeringClass: CanonicalComponentClass.values.byName(
        map['engineeringClass'] as String,
      ),
      characteristics: DisciplineCharacteristics.fromMap(
        map['characteristics'] as Map<String, dynamic>,
      ),
      capabilities: (map['capabilities'] as List)
          .map((value) => CanonicalCapability.values.byName(value as String)),
      portTemplates: (map['portTemplates'] as List).map(
        (value) => EngineeringPort.fromMap(value as Map<String, dynamic>),
      ),
      deprecated: map['deprecated'] as bool? ?? false,
      portInterfaceCodes: (map['portInterfaceCodes'] as Map<String, dynamic>?)
              ?.cast<String, String>() ??
          {},
      constraintsState: state,
      constraints: rawConstraints == null
          ? null
          : EngineeringProfileConstraints.fromMap(rawConstraints),
    );
  }
}

class EngineeringReferenceCatalog {
  EngineeringReferenceCatalog({
    required this.id,
    required this.code,
    required this.version,
    required this.source,
    required Iterable<ComponentEngineeringProfile> profiles,
    this.jurisdiction,
    EngineeringReferenceVocabulary? vocabulary,
  })  : profiles = List.unmodifiable(profiles),
        vocabulary = vocabulary ?? EngineeringReferenceVocabulary();

  final String id;
  final String code;
  final String version;
  final String source;
  final String? jurisdiction;
  final List<ComponentEngineeringProfile> profiles;
  final EngineeringReferenceVocabulary vocabulary;

  List<String> validate() => [
        if ([id, code, version, source].any((value) => value.trim().isEmpty))
          'Catalog identity, code, version and provenance are required.',
        if (code != normalizeEngineeringReferenceCode(code))
          'Catalog code must use canonical engineering identity.',
        if (profiles.isEmpty) 'Provide at least one engineering profile.',
        if (profiles.any(
              (profile) =>
                  profile.code !=
                  normalizeEngineeringReferenceCode(profile.code),
            ) ||
            profiles
                    .map(
                      (profile) =>
                          normalizeEngineeringReferenceCode(profile.code),
                    )
                    .toSet()
                    .length !=
                profiles.length)
          'Profile codes must be canonical and unique after normalization.',
        ...vocabulary.validate(),
        for (final profile in profiles) ...profile.validate(),
        ..._referenceErrors(),
      ];

  List<String> validateForPublication() => [
        ...validate(),
        for (final profile in profiles) ...profile.validateForPublication(),
      ];

  List<String> _referenceErrors() {
    final errors = <String>[];
    if (vocabulary.validate().isNotEmpty) return errors;
    for (final profile in profiles) {
      for (final template in profile.portTemplates) {
        final code = profile.portInterfaceCodes[template.code];
        if (code == null) continue;
        try {
          vocabulary.resolve(
            template,
            code,
            catalogId: id,
            version: version,
            newInstantiation: false,
          );
        } catch (error) {
          errors.add('Profile ${profile.code} port ${template.code}: $error');
        }
      }
    }
    return errors;
  }

  List<ConnectionCompatibilityProfile> connectionProfiles(String projectId) =>
      vocabulary.connectionProfiles(
        projectId: projectId,
        catalogId: id,
        catalogCode: code,
        version: version,
        source: source,
      );

  ComponentEngineeringProfile profile(String code) {
    final normalized = normalizeEngineeringReferenceCode(code);
    return profiles.singleWhere(
      (profile) =>
          normalizeEngineeringReferenceCode(profile.code) == normalized,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'version': version,
        'source': source,
        'jurisdiction': jurisdiction,
        if (!vocabulary.isEmpty) 'vocabulary': vocabulary.toMap(),
        'profiles': profiles.map((profile) => profile.toMap()).toList(),
      };

  factory EngineeringReferenceCatalog.fromMap(Map<String, dynamic> map) =>
      EngineeringReferenceCatalog(
        id: map['id'] as String,
        code: map['code'] as String,
        version: map['version'] as String,
        source: map['source'] as String,
        jurisdiction: map['jurisdiction'] as String?,
        vocabulary: map['vocabulary'] == null
            ? null
            : EngineeringReferenceVocabulary.fromMap(
                map['vocabulary'] as Map<String, dynamic>,
              ),
        profiles: (map['profiles'] as List).map(
          (value) => ComponentEngineeringProfile.fromMap(
            value as Map<String, dynamic>,
          ),
        ),
      );
}
