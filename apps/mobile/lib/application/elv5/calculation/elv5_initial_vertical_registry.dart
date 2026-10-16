import '../cctv/cctv02_runtime.dart';
import '../cctv/cctv03_runtime.dart';
import '../cctv/elv5_cctv_persistence.dart';
import '../fire/elv5_fire_persistence.dart';
import '../fire/fa02_runtime.dart';
import '../lan/elv3_realized_link_facts.dart';
import '../lan/elv5_lan_persistence.dart';
import '../lan/lan01_runtime.dart';
import '../power/elv4_operating_fact_source.dart';
import 'elv5_calculation_runtime.dart';
import 'elv5_capture_guard.dart';

/// First production vertical slice backed entirely by persisted ELV3/ELV4/ELV5
/// facts. Processes with mandatory evidence gaps are intentionally not
/// registered: a missing adapter is safer than a nominal calculation that could
/// publish an unsupported PASS.
Elv5ProcessCalculationRegistry buildElv5InitialVerticalRegistry({
  required Elv5CctvMutationStore cctvStore,
  required Elv5LanMutationStore lanStore,
  required Elv5FireMutationStore fireStore,
  required Elv3RealizedLinkFactSource elv3LinkFacts,
  required Elv4OperatingFactSource powerOperatingFacts,
  required Elv5CaptureRevisionSource captureRevisions,
  DateTime Function()? nowUtc,
}) {
  Elv5ProcessInputResolver<I> guarded<I>(Elv5ProcessInputResolver<I> inner) =>
      Elv5RevisionGuardedInputResolver<I>(
        inner: inner,
        revisions: captureRevisions,
      );

  return Elv5ProcessCalculationRegistry(<Elv5ProcessCalculationAdapter>[
    Elv5TypedProcessCalculationAdapter(
      resolver: guarded(
        Cctv02PersistedInputResolver(store: cctvStore, nowUtc: nowUtc),
      ),
      executor: buildCctv02Executor(nowUtc: nowUtc),
    ),
    Elv5TypedProcessCalculationAdapter(
      resolver: guarded(
        Cctv03PersistedInputResolver(store: cctvStore, nowUtc: nowUtc),
      ),
      executor: buildCctv03Executor(nowUtc: nowUtc),
    ),
    Elv5TypedProcessCalculationAdapter(
      resolver: guarded(
        Lan01PersistedInputResolver(
          lanStore: lanStore,
          elv3Facts: elv3LinkFacts,
          nowUtc: nowUtc,
        ),
      ),
      executor: buildLan01Executor(nowUtc: nowUtc),
    ),
    Elv5TypedProcessCalculationAdapter(
      resolver: guarded(
        Fa02PersistedInputResolver(
          fireStore: fireStore,
          powerFacts: powerOperatingFacts,
          nowUtc: nowUtc,
        ),
      ),
      executor: buildFa02Executor(nowUtc: nowUtc),
    ),
  ]);
}
