import 'package:engineering_core/engineering_core_elv5.dart';

final class Cctv06SectionEvidenceContract {
  Cctv06SectionEvidenceContract({
    required String sectionId,
    required String mediumCode,
    required String interfaceKind,
    required String categoryToken,
    required this.shieldContinuityKnown,
    required this.shieldContinuity,
    required String evidenceRef,
    required String evidenceContentHash,
  })  : sectionId=_text(sectionId,'sectionId'),
        mediumCode=_medium(mediumCode),
        interfaceKind=_token(interfaceKind,'interfaceKind'),
        categoryToken=_token(categoryToken,'categoryToken'),
        evidenceRef=_text(evidenceRef,'evidenceRef'),
        evidenceContentHash=_sha(evidenceContentHash,'evidenceContentHash') {
    if(!shieldContinuityKnown&&shieldContinuity)throw ArgumentError('CCTV06 unknown shield continuity cannot assert true.');
  }
  final String sectionId;final String mediumCode;final String interfaceKind;final String categoryToken;
  final bool shieldContinuityKnown;final bool shieldContinuity;final String evidenceRef;final String evidenceContentHash;
  Map<String,Object?> toCanonicalValue()=>{'sectionId':sectionId,'mediumCode':mediumCode,'interfaceKind':interfaceKind,'categoryToken':categoryToken,'shieldContinuityKnown':shieldContinuityKnown,'shieldContinuity':shieldContinuity,'evidenceRef':evidenceRef,'evidenceContentHash':evidenceContentHash};
  factory Cctv06SectionEvidenceContract.fromMap(Map<String,Object?> m)=>Cctv06SectionEvidenceContract(
    sectionId:_mapText(m,'sectionId'),mediumCode:_mapText(m,'mediumCode'),interfaceKind:_mapText(m,'interfaceKind'),categoryToken:_mapText(m,'categoryToken'),
    shieldContinuityKnown:_bool(m,'shieldContinuityKnown'),shieldContinuity:_bool(m,'shieldContinuity'),evidenceRef:_mapText(m,'evidenceRef'),evidenceContentHash:_mapText(m,'evidenceContentHash'));
}

final class Cctv06LinkContract {
  Cctv06LinkContract({
    required String linkId,
    required String expectedCompositionFingerprint,
    required Iterable<String> allowedMediaCodes,
    required Iterable<String> allowedInterfaceKinds,
    required Iterable<String> allowedCategoryTokens,
    required this.shieldingRequired,
    this.maximumLengthM,
    required Iterable<Cctv06SectionEvidenceContract> sections,
    required this.powered,
    this.pseId,
    this.scenarioId,
    this.segmentId,
    Map<String,String> expectedPwr06InputFingerprintByDeliveryId=const {},
    Map<String,String> poweredSectionToDeliveryId=const {},
  }) : linkId=_text(linkId,'linkId'),
       expectedCompositionFingerprint=_sha(expectedCompositionFingerprint,'expectedCompositionFingerprint'),
       allowedMediaCodes=Set.unmodifiable(allowedMediaCodes.map(_medium)),
       allowedInterfaceKinds=Set.unmodifiable(allowedInterfaceKinds.map((e)=>_token(e,'allowedInterfaceKind'))),
       allowedCategoryTokens=Set.unmodifiable(allowedCategoryTokens.map((e)=>_token(e,'allowedCategoryToken'))),
       sections=List.unmodifiable(sections),
       expectedPwr06InputFingerprintByDeliveryId=Map.unmodifiable(_fingerprints(expectedPwr06InputFingerprintByDeliveryId)),
       poweredSectionToDeliveryId=Map.unmodifiable({for(final e in poweredSectionToDeliveryId.entries)_text(e.key,'poweredSectionId'):_text(e.value,'deliveryId')}) {
    if(this.sections.isEmpty)throw ArgumentError('CCTV06 sections must not be empty.');
    final ids=<String>{};for(final s in this.sections){if(!ids.add(s.sectionId))throw ArgumentError('CCTV06 duplicate sectionId: ${s.sectionId}');}
    if(maximumLengthM!=null&&maximumLengthM!<Elv5Rational.zero)throw ArgumentError('CCTV06 maximum length must be nonnegative.');
    if(this.allowedMediaCodes.isEmpty||this.allowedInterfaceKinds.isEmpty||this.allowedCategoryTokens.isEmpty)throw ArgumentError('CCTV06 policy sets must not be empty.');
    if(powered){
      _text(pseId??'','pseId');_text(scenarioId??'','scenarioId');_text(segmentId??'','segmentId');
      if(this.expectedPwr06InputFingerprintByDeliveryId.isEmpty||this.poweredSectionToDeliveryId.isEmpty)throw ArgumentError('Powered CCTV06 contract requires PWR06 delivery and section mapping.');
      for(final e in this.poweredSectionToDeliveryId.entries){if(!ids.contains(e.key)||!this.expectedPwr06InputFingerprintByDeliveryId.containsKey(e.value))throw ArgumentError('CCTV06 powered section mapping is outside section/delivery closure.');}
    } else if(pseId!=null||scenarioId!=null||segmentId!=null||this.expectedPwr06InputFingerprintByDeliveryId.isNotEmpty||this.poweredSectionToDeliveryId.isNotEmpty){
      throw ArgumentError('Unpowered CCTV06 contract cannot carry PWR06 binding.');
    }
  }
  static const schema='electra.elv5-cctv06-link-contract.v1';
  final String linkId;final String expectedCompositionFingerprint;final Set<String> allowedMediaCodes;final Set<String> allowedInterfaceKinds;final Set<String> allowedCategoryTokens;final bool shieldingRequired;final Elv5Rational? maximumLengthM;final List<Cctv06SectionEvidenceContract> sections;final bool powered;final String? pseId;final String? scenarioId;final String? segmentId;final Map<String,String> expectedPwr06InputFingerprintByDeliveryId;final Map<String,String> poweredSectionToDeliveryId;
  Map<String,Object?> toCanonicalValue()=>{'schema':schema,'linkId':linkId,'expectedCompositionFingerprint':expectedCompositionFingerprint,'allowedMediaCodes':allowedMediaCodes.toList()..sort(),'allowedInterfaceKinds':allowedInterfaceKinds.toList()..sort(),'allowedCategoryTokens':allowedCategoryTokens.toList()..sort(),'shieldingRequired':shieldingRequired,'maximumLengthM':maximumLengthM?.toMap(),'sections':[for(final s in sections)s.toCanonicalValue()],'powered':powered,'pseId':pseId,'scenarioId':scenarioId,'segmentId':segmentId,'expectedPwr06InputFingerprintByDeliveryId':{for(final k in expectedPwr06InputFingerprintByDeliveryId.keys.toList()..sort())k:expectedPwr06InputFingerprintByDeliveryId[k]},'poweredSectionToDeliveryId':{for(final k in poweredSectionToDeliveryId.keys.toList()..sort())k:poweredSectionToDeliveryId[k]}};
  factory Cctv06LinkContract.fromMap(Map<String,Object?> m){
    final sections=m['sections'];if(sections is! List)throw const FormatException('CCTV06 sections must be list.');
    return Cctv06LinkContract(linkId:_mapText(m,'linkId'),expectedCompositionFingerprint:_mapText(m,'expectedCompositionFingerprint'),allowedMediaCodes:_strings(m['allowedMediaCodes']),allowedInterfaceKinds:_strings(m['allowedInterfaceKinds']),allowedCategoryTokens:_strings(m['allowedCategoryTokens']),shieldingRequired:_bool(m,'shieldingRequired'),maximumLengthM:m['maximumLengthM']==null?null:Elv5Rational.fromMap(_map(m['maximumLengthM'],'maximumLengthM')),sections:[for(final x in sections)Cctv06SectionEvidenceContract.fromMap(_map(x,'section'))],powered:_bool(m,'powered'),pseId:_nullableText(m['pseId']),scenarioId:_nullableText(m['scenarioId']),segmentId:_nullableText(m['segmentId']),expectedPwr06InputFingerprintByDeliveryId:_stringMap(m['expectedPwr06InputFingerprintByDeliveryId'],'expectedPwr06InputFingerprintByDeliveryId'),poweredSectionToDeliveryId:_stringMap(m['poweredSectionToDeliveryId'],'poweredSectionToDeliveryId'));
  }
}
final class Cctv06LinkContractSnapshot{const Cctv06LinkContractSnapshot({required this.bindingId,required this.bindingRevision,required this.evidenceRef,required this.contentHash,required this.contract});final String bindingId;final int bindingRevision;final String evidenceRef;final String contentHash;final Cctv06LinkContract contract;}
abstract interface class Cctv06LinkContractSource{Future<Cctv06LinkContractSnapshot?> loadActiveForLink({required String projectId,required String designRevisionId,required String linkId});}
final class ReplaceCctv06LinkContractCommand{ReplaceCctv06LinkContractCommand({required this.projectId,required this.designRevisionId,required this.expectedDesignRevision,required this.bindingId,required this.expectedBindingRevision,required this.contract});final String projectId;final String designRevisionId;final int expectedDesignRevision;final String bindingId;final int? expectedBindingRevision;final Cctv06LinkContract contract;}
abstract interface class Cctv06LinkContractWriter{Future<void> replace(ReplaceCctv06LinkContractCommand command);}
Map<String,String> _fingerprints(Map<String,String> m)=>{for(final e in m.entries)_text(e.key,'deliveryId'):_sha(e.value,'inputFingerprint')};
String _medium(String v){final x=_token(v,'mediumCode');if(!const {'COPPER','FIBER','OTHER'}.contains(x))throw ArgumentError('Unsupported CCTV06 medium $x');return x;}
String _token(String v,String f)=>_text(v,f).toUpperCase();String _text(String v,String f){final x=v.trim();if(x.isEmpty)throw ArgumentError.value(v,f,'Must not be empty.');return x;}String _sha(String v,String f){final x=_text(v,f).toLowerCase();if(!RegExp(r'^[0-9a-f]{64}$').hasMatch(x))throw ArgumentError.value(v,f,'Expected SHA-256.');return x;}Map<String,Object?> _map(Object? v,String f){if(v is! Map)throw FormatException('$f must be object.');return Map<String,Object?>.from(v);}String _mapText(Map<String,Object?> m,String k){final v=m[k];if(v is! String)throw FormatException('$k must be text.');return _text(v,k);}bool _bool(Map<String,Object?> m,String k){final v=m[k];if(v is! bool)throw FormatException('$k must be bool.');return v;}List<String> _strings(Object? v){if(v is! List||v.any((x)=>x is! String))throw const FormatException('Expected string list.');return v.cast<String>();}String? _nullableText(Object? v)=>v==null?null:(v is String?_text(v,'nullableText'):throw const FormatException('Expected nullable text.'));Map<String,String> _stringMap(Object? v,String f){final m=_map(v,f);return {for(final e in m.entries)_text(e.key,f):e.value is String?_text(e.value as String,f):throw FormatException('$f value must be text.')};}
