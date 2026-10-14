import 'package:electra_mobile/application/elv_failure_probe.dart';

final class ArmedElvFailureProbe implements ElvFailureProbe {
  ArmedElvFailureProbe(this.armedPoint);

  final String armedPoint;
  int hits = 0;

  @override
  Future<void> hit(String point) async {
    if (point != armedPoint) return;
    hits++;
    throw ElvInjectedFailure(point);
  }
}

final class ElvInjectedFailure implements Exception {
  const ElvInjectedFailure(this.point);
  final String point;

  @override
  String toString() => 'ELV injected failure at $point';
}
