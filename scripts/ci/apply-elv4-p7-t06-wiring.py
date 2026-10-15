from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, got {count}: {old[:120]!r}')
    path.write_text(text.replace(old, new, 1))


controller = ROOT / 'apps/mobile/lib/application/power_workspace_controller.dart'
text = controller.read_text()
if 'final ElvWorkspaceCommandService? routingService;' not in text:
    text = text.replace(
        '[ElvPhysicalRoutingWorkspaceService], and undo/redo through the explicit',
        '[ElvWorkspaceCommandService], and undo/redo through the explicit',
        1,
    )
    text = text.replace(
        'final ElvPhysicalRoutingWorkspaceService? routingService;',
        'final ElvWorkspaceCommandService? routingService;',
        1,
    )
    controller.write_text(text)

runtime = ROOT / 'apps/mobile/lib/data/repositories/drift_elv_reviewed_routing_runtime.dart'
text = runtime.read_text()
if 'implements ElvWorkspaceCommandService, ElvRevisionCommandHistoryService' not in text:
    text = text.replace(
        'implements ElvWorkspaceCommandExecutor, ElvRevisionCommandHistoryService',
        'implements ElvWorkspaceCommandService, ElvRevisionCommandHistoryService',
        1,
    )
    runtime.write_text(text)

providers = ROOT / 'apps/mobile/lib/app/providers.dart'
text = providers.read_text()
import_line = "import '../data/repositories/drift_elv_reviewed_routing_runtime.dart';\n"
if import_line not in text:
    anchor = "import '../data/repositories/drift_power_workspace_repository.dart';\n"
    if anchor not in text:
        raise SystemExit('providers import anchor missing')
    text = text.replace(anchor, anchor + import_line, 1)
provider_block = """
final elvReviewedRoutingRuntimeProvider =
    Provider<DriftElvReviewedRoutingRuntime>((ref) {
      return DriftElvReviewedRoutingRuntime(
        ref.watch(databaseProvider),
        originDeviceId: 'local-device',
        idGenerator: ref.watch(idGeneratorProvider),
      );
    });

"""
if 'final elvReviewedRoutingRuntimeProvider =' not in text:
    anchor = 'final powerWorkspaceRepositoryProvider = Provider<PowerWorkspaceRepository>(\n'
    if anchor not in text:
        raise SystemExit('providers power workspace anchor missing')
    text = text.replace(anchor, provider_block + anchor, 1)
providers.write_text(text)

screen = ROOT / 'apps/mobile/lib/features/editor/persisted_room_editor_screen.dart'
text = screen.read_text()
old = """  PowerWorkspaceController _newPowerController() => PowerWorkspaceController(
    repository: ref.read(powerWorkspaceRepositoryProvider),
  );
"""
new = """  PowerWorkspaceController _newPowerController() {
    final routingRuntime = ref.read(elvReviewedRoutingRuntimeProvider);
    return PowerWorkspaceController(
      repository: ref.read(powerWorkspaceRepositoryProvider),
      routingService: routingRuntime,
      historyService: routingRuntime,
    );
  }
"""
if old in text:
    text = text.replace(old, new, 1)
elif 'routingService: routingRuntime' not in text:
    raise SystemExit('persisted editor controller anchor missing')
screen.write_text(text)
