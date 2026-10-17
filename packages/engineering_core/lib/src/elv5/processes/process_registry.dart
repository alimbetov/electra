import 'process_code.dart';
import 'process_definition.dart';
import 'process_versions.dart';

final class Elv5ProcessDescriptor {
  Elv5ProcessDescriptor({
    required this.code,
    required this.legalScopes,
    required this.baseWorkloadClass,
    required this.complexityCode,
  }) : versions = Elv5ProcessVersions.v1(code) {
    if (legalScopes.isEmpty) {
      throw ArgumentError('ELV5 process must have at least one legal scope.');
    }
    if (complexityCode.trim().isEmpty) {
      throw ArgumentError('complexityCode must be non-empty.');
    }
  }

  final Elv5ProcessCode code;
  final Elv5ProcessVersions versions;
  final Set<Elv5ScopeKind> legalScopes;
  final Elv5WorkloadClass baseWorkloadClass;
  final String complexityCode;
}

/// P1 code-owned closed process inventory. Discipline kernels are attached in
/// P3-P6; project payloads cannot add process codes or executable formulas.
abstract final class Elv5ProcessCatalog {
  static final List<Elv5ProcessDescriptor> all = List.unmodifiable(
    <Elv5ProcessDescriptor>[
      _d(Elv5ProcessCode.cctv01, Elv5WorkloadClass.medium, 'O(Vf*Vz)'),
      _d(Elv5ProcessCode.cctv02, Elv5WorkloadClass.large, 'O(F)+O(F log F)'),
      _d(Elv5ProcessCode.cctv03, Elv5WorkloadClass.large, 'O(N log N)'),
      _d(Elv5ProcessCode.cctv04, Elv5WorkloadClass.small, 'O(K)'),
      _d(Elv5ProcessCode.cctv05, Elv5WorkloadClass.medium, 'O(A+C)'),
      _d(Elv5ProcessCode.cctv06, Elv5WorkloadClass.medium, 'O(P)'),
      _d(Elv5ProcessCode.lan01, Elv5WorkloadClass.medium, 'O(P)'),
      _d(Elv5ProcessCode.lan02, Elv5WorkloadClass.medium, 'O(P+A)'),
      _d(Elv5ProcessCode.lan03, Elv5WorkloadClass.small, 'O(K)'),
      _d(Elv5ProcessCode.lan04, Elv5WorkloadClass.medium, 'O(P*R),R_BOUNDED'),
      _d(Elv5ProcessCode.lan05, Elv5WorkloadClass.medium, 'O(P+E)'),
      _d(Elv5ProcessCode.lan06, Elv5WorkloadClass.medium, 'O(N)'),
      _d(Elv5ProcessCode.lan07, Elv5WorkloadClass.medium, 'O(P+A+M)'),
      _d(Elv5ProcessCode.acs01, Elv5WorkloadClass.medium, 'O(A+R)'),
      _d(Elv5ProcessCode.acs02, Elv5WorkloadClass.medium, 'O(R+A)'),
      _d(Elv5ProcessCode.acs03, Elv5WorkloadClass.medium, 'O(E+K),E_BOUNDED'),
      _d(Elv5ProcessCode.acs04, Elv5WorkloadClass.medium, 'O(C+R)'),
      _d(Elv5ProcessCode.acs05, Elv5WorkloadClass.medium, 'O(S+C)'),
      _d(Elv5ProcessCode.acs06, Elv5WorkloadClass.medium, '5*O(V+E)'),
      _d(Elv5ProcessCode.fa01, Elv5WorkloadClass.large, 'O(D+A)'),
      _d(Elv5ProcessCode.fa02, Elv5WorkloadClass.large, 'O(D*C)'),
      _d(Elv5ProcessCode.fa03, Elv5WorkloadClass.medium, 'O(E+K)'),
      _d(Elv5ProcessCode.fa04, Elv5WorkloadClass.medium, 'O(C+R)'),
      _d(Elv5ProcessCode.fa05, Elv5WorkloadClass.medium, 'O(S+C)'),
      _d(Elv5ProcessCode.fa06, Elv5WorkloadClass.large, 'O(D+E)'),
      _d(Elv5ProcessCode.fa07, Elv5WorkloadClass.medium, 'O(V+E)'),
      _d(Elv5ProcessCode.fa08, Elv5WorkloadClass.medium, 'O(P+R)'),
    ],
  );

  static final Map<Elv5ProcessCode, Elv5ProcessDescriptor> byCode =
      Map.unmodifiable(<Elv5ProcessCode, Elv5ProcessDescriptor>{
    for (final descriptor in all) descriptor.code: descriptor,
  });

  static Elv5ProcessDescriptor require(Elv5ProcessCode code) =>
      byCode[code] ?? (throw StateError('Unregistered ELV5 process: $code'));

  static Elv5ProcessDescriptor _d(
    Elv5ProcessCode code,
    Elv5WorkloadClass workload,
    String complexity,
  ) =>
      Elv5ProcessDescriptor(
        code: code,
        legalScopes: const <Elv5ScopeKind>{Elv5ScopeKind.design},
        baseWorkloadClass: workload,
        complexityCode: complexity,
      );
}
