import 'package:engineering_core/engineering_core_elv5.dart';

enum Fa03ContractModel { radialDc, declaredOneControlPointDc, unsupported }

final class Fa03CaseContract {
  Fa03CaseContract({
    required String caseId,
    required String scenarioId,
    required String segmentId,
    required String pwr03SubjectKind,
    required String pwr03SubjectId,
    required String expectedPwr03InputFingerprint,
    required Map<String, String> terminalLoadIdByTerminalId,
  })  : caseId = _text(caseId, 'caseId'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        segmentId = _text(segmentId, 'segmentId'),
        pwr03SubjectKind = _text(pwr03SubjectKind, 'pwr03SubjectKind'),
        pwr03SubjectId = _text(pwr03SubjectId, 'pwr03SubjectId'),
        expectedPwr03InputFingerprint = _sha(expectedPwr03InputFingerprint, 'expectedPwr03InputFingerprint'),
        terminalLoadIdByTerminalId = Map.unmodifiable(_terminalMap(terminalLoadIdByTerminalId));

  final String caseId;
  final String scenarioId;
  final String segmentId;
  final String pwr03SubjectKind;
  final String pwr03SubjectId;
  final String expectedPwr03InputFingerprint;
  final Map<String, String> terminalLoadIdByTerminalId;

  Map<String, Object?> toCanonicalValue() => {
    'caseId': caseId,
    'scenarioId': scenarioId,
    'segmentId': segmentId,
    'pwr03SubjectKind': pwr03SubjectKind,
    'pwr03SubjectId': pwr03SubjectId,
    'expectedPwr03InputFingerprint': expectedPwr03InputFingerprint,
    'terminalLoadIdByTerminalId': {
      for (final key in (terminalLoadIdByTerminalId.keys.toList()..sort())) key: terminalLoadIdByTerminalId[key],
    },
  };

  factory Fa03CaseContract.fromMap(Map<String,Object?> map) {
    final terminals = _object(map['terminalLoadIdByTerminalId'], 'terminalLoadIdByTerminalId');
    return Fa03CaseContract(
      caseId: _mapText(map, 'caseId'),
      scenarioId: _mapText(map, 'scenarioId'),
      segmentId: _mapText(map, 'segmentId'),
      pwr03SubjectKind: _mapText(map, 'pwr03SubjectKind'),
      pwr03SubjectId: _mapText(map, 'pwr03SubjectId'),
      expectedPwr03InputFingerprint: _mapText(map, 'expectedPwr03InputFingerprint'),
      terminalLoadIdByTerminalId: {for (final e in terminals.entries) e.key: _text(e.value as String, 'terminalLoadId')},
    );
  }
}

final class Fa03TerminalVoltageContract {
  Fa03TerminalVoltageContract({
    required String circuitId,
    required this.model,
    required this.minimumTerminalVoltageV,
    required this.maximumTerminalVoltageV,
    required Iterable<Fa03CaseContract> cases,
  })  : circuitId = _text(circuitId, 'circuitId'),
        cases = List.unmodifiable(_cases(cases)) {
    if (minimumTerminalVoltageV < Elv5Rational.zero || maximumTerminalVoltageV < minimumTerminalVoltageV) {
      throw ArgumentError('FA03 voltage limits are invalid.');
    }
    if (this.cases.isEmpty) throw ArgumentError('FA03 requires at least one operating case.');
  }

  static const schema = 'electra.elv5-fa03-terminal-voltage-contract.v1';
  static const _encoder = Elv5CanonicalJsonV1();
  final String circuitId;
  final Fa03ContractModel model;
  final Elv5Rational minimumTerminalVoltageV;
  final Elv5Rational maximumTerminalVoltageV;
  final List<Fa03CaseContract> cases;

  String get scopeFingerprint => _encoder.sha256({
    'schema': 'electra.elv5-fa03-scope.v1',
    'circuitId': circuitId,
    'model': model.name,
    'cases': [for (final c in cases) {
      'caseId': c.caseId,
      'scenarioId': c.scenarioId,
      'segmentId': c.segmentId,
      'pwr03SubjectKind': c.pwr03SubjectKind,
      'pwr03SubjectId': c.pwr03SubjectId,
      'terminalLoadIdByTerminalId': c.toCanonicalValue()['terminalLoadIdByTerminalId'],
    }],
  });

  Map<String,Object?> toCanonicalValue() => {
    'schema': schema,
    'circuitId': circuitId,
    'model': model.name,
    'minimumTerminalVoltageV': minimumTerminalVoltageV.toMap(),
    'maximumTerminalVoltageV': maximumTerminalVoltageV.toMap(),
    'cases': [for (final c in cases) c.toCanonicalValue()],
  };

  factory Fa03TerminalVoltageContract.fromMap(Map<String,Object?> map) {
    if (map['schema'] != schema) throw const FormatException('Unsupported FA03 contract schema.');
    final rawCases = map['cases'];
    if (rawCases is! List) throw const FormatException('FA03 cases must be an array.');
    final model = switch (_mapText(map, 'model')) {
      'radialDc' => Fa03ContractModel.radialDc,
      'declaredOneControlPointDc' => Fa03ContractModel.declaredOneControlPointDc,
      'unsupported' => Fa03ContractModel.unsupported,
      final v => throw FormatException('Unsupported FA03 model: $v'),
    };
    return Fa03TerminalVoltageContract(
      circuitId: _mapText(map, 'circuitId'),
      model: model,
      minimumTerminalVoltageV: _rational(map['minimumTerminalVoltageV'], 'minimumTerminalVoltageV'),
      maximumTerminalVoltageV: _rational(map['maximumTerminalVoltageV'], 'maximumTerminalVoltageV'),
      cases: [for (final raw in rawCases) Fa03CaseContract.fromMap(_object(raw, 'FA03 case'))],
    );
  }
}

final class Fa03TerminalVoltageContractSnapshot {
  const Fa03TerminalVoltageContractSnapshot({required this.bindingId, required this.bindingRevision, required this.evidenceRef, required this.contentHash, required this.contract});
  final String bindingId; final int bindingRevision; final String evidenceRef; final String contentHash; final Fa03TerminalVoltageContract contract;
}

abstract interface class Fa03TerminalVoltageContractSource {
  Future<Fa03TerminalVoltageContractSnapshot?> loadActiveForCircuit({required String projectId, required String designRevisionId, required String circuitId});
}

List<Fa03CaseContract> _cases(Iterable<Fa03CaseContract> values) {
  final out = values.toList()..sort((a,b)=>a.caseId.compareTo(b.caseId));
  final ids=<String>{}; for(final c in out){if(!ids.add(c.caseId)) throw ArgumentError('FA03 duplicate caseId: ${c.caseId}');}
  return out;
}
Map<String,String> _terminalMap(Map<String,String> input){final out=<String,String>{}; for(final e in input.entries){out[_text(e.key,'terminalId')]=_text(e.value,'loadId');} if(out.isEmpty) throw ArgumentError('FA03 terminal mapping empty.'); return out;}
Map<String,Object?> _object(Object? v,String f){if(v is! Map) throw FormatException('$f must be object.'); return Map<String,Object?>.from(v);}
String _mapText(Map<String,Object?> m,String k){final v=m[k]; if(v is! String) throw FormatException('$k must be text.'); return _text(v,k);}
String _text(String v,String f){final n=v.trim(); if(n.isEmpty) throw ArgumentError.value(v,f,'Must not be empty.'); return n;}
String _sha(String v,String f){final n=_text(v,f); if(!RegExp(r'^[0-9a-f]{64}$').hasMatch(n)) throw ArgumentError.value(v,f,'Must be lowercase SHA-256.'); return n;}
Elv5Rational _rational(Object? v,String f){if(v is! Map) throw FormatException('$f must be rational map.'); return Elv5Rational.fromMap(Map<String,Object?>.from(v));}
