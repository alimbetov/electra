final class Lan04SectionCapabilityContract {
  Lan04SectionCapabilityContract({
    required String sectionId,
    required String mediumCode,
    required Iterable<String> supportedInterfaceKinds,
    required Iterable<String> supportedSpeedModes,
    required Iterable<String> supportedConnectorKinds,
    required this.shieldContinuityKnown,
    required this.shieldContinuity,
    required String evidenceRef,
    required String evidenceContentHash,
  })  : sectionId = _text(sectionId, 'sectionId'),
        mediumCode = _medium(mediumCode),
        supportedInterfaceKinds = Set.unmodifiable(
          supportedInterfaceKinds.map((e) => _token(e, 'interfaceKind')),
        ),
        supportedSpeedModes = Set.unmodifiable(
          supportedSpeedModes.map((e) => _token(e, 'speedMode')),
        ),
        supportedConnectorKinds = Set.unmodifiable(
          supportedConnectorKinds.map((e) => _token(e, 'connectorKind')),
        ),
        evidenceRef = _text(evidenceRef, 'evidenceRef'),
        evidenceContentHash = _sha(evidenceContentHash, 'evidenceContentHash') {
    if (this.supportedInterfaceKinds.isEmpty ||
        this.supportedSpeedModes.isEmpty ||
        this.supportedConnectorKinds.isEmpty) {
      throw ArgumentError(
        'LAN04 section capability edition requires explicit non-empty interface/speed/connector evidence.',
      );
    }
    if (!shieldContinuityKnown && shieldContinuity) {
      throw ArgumentError('LAN04 unknown shield continuity cannot assert true.');
    }
  }
  final String sectionId;
  final String mediumCode;
  final Set<String> supportedInterfaceKinds;
  final Set<String> supportedSpeedModes;
  final Set<String> supportedConnectorKinds;
  final bool shieldContinuityKnown;
  final bool shieldContinuity;
  final String evidenceRef;
  final String evidenceContentHash;
  Map<String,Object?> toCanonicalValue()=>{
    'sectionId':sectionId,'mediumCode':mediumCode,
    'supportedInterfaceKinds':supportedInterfaceKinds.toList()..sort(),
    'supportedSpeedModes':supportedSpeedModes.toList()..sort(),
    'supportedConnectorKinds':supportedConnectorKinds.toList()..sort(),
    'shieldContinuityKnown':shieldContinuityKnown,'shieldContinuity':shieldContinuity,
    'evidenceRef':evidenceRef,'evidenceContentHash':evidenceContentHash,
  };
  factory Lan04SectionCapabilityContract.fromMap(Map<String,Object?> map){
    _exact(map,const {'sectionId','mediumCode','supportedInterfaceKinds','supportedSpeedModes','supportedConnectorKinds','shieldContinuityKnown','shieldContinuity','evidenceRef','evidenceContentHash'},'sectionCapability');
    if(map['shieldContinuityKnown'] is! bool||map['shieldContinuity'] is! bool)throw const FormatException('LAN04 shield fields must be boolean.');
    return Lan04SectionCapabilityContract(
      sectionId:_mapText(map,'sectionId'),mediumCode:_mapText(map,'mediumCode'),
      supportedInterfaceKinds:_strings(map['supportedInterfaceKinds'],'supportedInterfaceKinds'),
      supportedSpeedModes:_strings(map['supportedSpeedModes'],'supportedSpeedModes'),
      supportedConnectorKinds:_strings(map['supportedConnectorKinds'],'supportedConnectorKinds'),
      shieldContinuityKnown:map['shieldContinuityKnown']! as bool,
      shieldContinuity:map['shieldContinuity']! as bool,
      evidenceRef:_mapText(map,'evidenceRef'),evidenceContentHash:_mapText(map,'evidenceContentHash'),
    );
  }
}

final class Lan04CompatibilityContract {
  Lan04CompatibilityContract({
    required String linkId,
    required String expectedCompositionFingerprint,
    required String requiredMediumCode,
    required String requiredInterfaceKind,
    required String requiredSpeedMode,
    required String requiredConnectorKind,
    required this.shieldingRequired,
    required Iterable<Lan04SectionCapabilityContract> sections,
  }) : linkId=_text(linkId,'linkId'),
       expectedCompositionFingerprint=_sha(expectedCompositionFingerprint,'expectedCompositionFingerprint'),
       requiredMediumCode=_medium(requiredMediumCode),
       requiredInterfaceKind=_token(requiredInterfaceKind,'requiredInterfaceKind'),
       requiredSpeedMode=_token(requiredSpeedMode,'requiredSpeedMode'),
       requiredConnectorKind=_token(requiredConnectorKind,'requiredConnectorKind'),
       sections=List.unmodifiable(_sections(sections));
  static const schema='electra.elv5-lan04-compatibility-contract.v1';
  final String linkId;
  final String expectedCompositionFingerprint;
  final String requiredMediumCode;
  final String requiredInterfaceKind;
  final String requiredSpeedMode;
  final String requiredConnectorKind;
  final bool shieldingRequired;
  final List<Lan04SectionCapabilityContract> sections;
  Map<String,Object?> toCanonicalValue()=>{
    'schema':schema,'linkId':linkId,'expectedCompositionFingerprint':expectedCompositionFingerprint,
    'requiredMediumCode':requiredMediumCode,'requiredInterfaceKind':requiredInterfaceKind,
    'requiredSpeedMode':requiredSpeedMode,'requiredConnectorKind':requiredConnectorKind,
    'shieldingRequired':shieldingRequired,'sections':[for(final s in sections)s.toCanonicalValue()],
  };
  factory Lan04CompatibilityContract.fromMap(Map<String,Object?> map){
    _exact(map,const {'schema','linkId','expectedCompositionFingerprint','requiredMediumCode','requiredInterfaceKind','requiredSpeedMode','requiredConnectorKind','shieldingRequired','sections'},'LAN04 contract');
    if(map['schema']!=schema||map['shieldingRequired'] is! bool)throw const FormatException('Unsupported/invalid LAN04 contract schema.');
    final sections=map['sections'];if(sections is! List)throw const FormatException('LAN04 sections must be array.');
    return Lan04CompatibilityContract(
      linkId:_mapText(map,'linkId'),expectedCompositionFingerprint:_mapText(map,'expectedCompositionFingerprint'),
      requiredMediumCode:_mapText(map,'requiredMediumCode'),requiredInterfaceKind:_mapText(map,'requiredInterfaceKind'),
      requiredSpeedMode:_mapText(map,'requiredSpeedMode'),requiredConnectorKind:_mapText(map,'requiredConnectorKind'),
      shieldingRequired:map['shieldingRequired']! as bool,
      sections:[for(final raw in sections)Lan04SectionCapabilityContract.fromMap(_map(raw,'section'))],
    );
  }
}

final class Lan04CompatibilityContractSnapshot {
  const Lan04CompatibilityContractSnapshot({required this.bindingId,required this.bindingRevision,required this.evidenceRef,required this.contentHash,required this.contract});
  final String bindingId;final int bindingRevision;final String evidenceRef;final String contentHash;final Lan04CompatibilityContract contract;
}
abstract interface class Lan04CompatibilityContractSource {
  Future<Lan04CompatibilityContractSnapshot?> loadActiveForLink({required String projectId,required String designRevisionId,required String linkId});
}
final class ReplaceLan04CompatibilityContractCommand {
  ReplaceLan04CompatibilityContractCommand({required this.projectId,required this.designRevisionId,required this.expectedDesignRevision,required this.bindingId,required this.expectedBindingRevision,required this.contract}){
    if(projectId.trim().isEmpty||designRevisionId.trim().isEmpty||bindingId.trim().isEmpty)throw ArgumentError('LAN04 command identity is required.');
    if(expectedDesignRevision<1||(expectedBindingRevision!=null&&expectedBindingRevision!<1))throw ArgumentError('LAN04 expected revisions must be positive.');
  }
  final String projectId;final String designRevisionId;final int expectedDesignRevision;final String bindingId;final int? expectedBindingRevision;final Lan04CompatibilityContract contract;
}
abstract interface class Lan04CompatibilityContractWriter {Future<void> replace(ReplaceLan04CompatibilityContractCommand command);}

List<Lan04SectionCapabilityContract> _sections(Iterable<Lan04SectionCapabilityContract> input){final out=input.toList();final seen=<String>{};for(final s in out){if(!seen.add(s.sectionId))throw ArgumentError('LAN04 duplicate sectionId: ${s.sectionId}');}if(out.isEmpty)throw ArgumentError('LAN04 sections must not be empty.');return out;}
String _medium(String value){final code=_text(value,'mediumCode').toUpperCase();if(!const {'COPPER','FIBER','OTHER'}.contains(code))throw ArgumentError('LAN04 unsupported medium: $code');return code;}
String _token(String value,String field)=>_text(value,field).toUpperCase();
List<String> _strings(Object? value,String field){if(value is! List||value.any((e)=>e is! String))throw FormatException('$field must be string array.');return value.cast<String>();}
Map<String,Object?> _map(Object? value,String field){if(value is! Map)throw FormatException('$field must be object.');return Map<String,Object?>.from(value);}
String _mapText(Map<String,Object?> map,String key){final value=map[key];if(value is! String)throw FormatException('$key must be text.');return _text(value,key);}
String _text(String value,String field){final v=value.trim();if(v.isEmpty)throw ArgumentError.value(value,field,'Must not be empty.');return v;}
String _sha(String value,String field){final v=_text(value,field).toLowerCase();if(!RegExp(r'^[0-9a-f]{64}$').hasMatch(v))throw ArgumentError.value(value,field,'Expected lowercase SHA-256.');return v;}
void _exact(Map<String,Object?> map,Set<String> expected,String field){final actual=map.keys.toSet();if(actual.length!=expected.length||actual.difference(expected).isNotEmpty||expected.difference(actual).isNotEmpty)throw FormatException('$field has missing or unknown fields.');}
