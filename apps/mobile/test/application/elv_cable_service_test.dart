import 'package:electra_mobile/application/elv_cable_command.dart';
import 'package:electra_mobile/application/elv_cable_command_service.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

TerminationPolicy _policy() => TerminationPolicy(
  mode: TerminationPolicyMode.bothEnds,
  terminalRequired: true,
);

CableDefinition _definition(String code) => CableDefinition(
  code: code,
  label: code,
  mediaCode: 'COPPER',
  resourceDefinitions: [
    CableResourceDefinition(
      identity: '__WHOLE_CABLE__',
      kind: CableResourceKind.wholeCable,
      allocatable: true,
      atomic: false,
      childResourceIds: const ['COND-1'],
      terminationPolicy: _policy(),
    ),
    CableResourceDefinition(
      identity: 'COND-1',
      kind: CableResourceKind.conductor,
      allocatable: true,
      atomic: true,
      parentResourceId: '__WHOLE_CABLE__',
      terminationPolicy: _policy(),
    ),
  ],
);

void main() {
  test('change definition uses optimistic revision and archive is forward-only', () async {
    final first = _definition('CABLE-A');
    final second = _definition('CABLE-B');
    final store = _FakeCableStore({'CABLE-A': first, 'CABLE-B': second});
    final session = _FakeSession(store);
    final service = DefaultElvCableCommandService(
      unitOfWork: _FakeUow(session),
      originDeviceId: 'test',
      now: () => DateTime.utc(2026, 10, 14),
    );

    final created = await service.create(
      CreateCableCommand(
        commandId: 'create',
        projectId: 'project',
        cableId: 'cable',
        label: 'C-01',
        name: 'Cable',
        definitionRef: store.refFor('CABLE-A'),
      ),
    );
    expect(created, isA<ElvCommandSuccess<Cable>>());

    final changed = await service.changeDefinition(
      ChangeCableDefinitionRefCommand(
        commandId: 'change',
        projectId: 'project',
        cableId: 'cable',
        expectedRevision: 1,
        definitionRef: store.refFor('CABLE-B'),
      ),
    );
    expect((changed as ElvCommandSuccess<Cable>).value.revision, 2);
    expect(changed.value.definitionRef.definitionCode, 'CABLE-B');

    final stale = await service.archive(
      const ArchiveCableCommand(
        commandId: 'archive-stale',
        projectId: 'project',
        cableId: 'cable',
        expectedRevision: 1,
      ),
    );
    expect(
      (stale as ElvCommandFailureResult<Cable>).failure.code,
      'ELV_REVISION_CONFLICT',
    );

    final archived = await service.archive(
      const ArchiveCableCommand(
        commandId: 'archive',
        projectId: 'project',
        cableId: 'cable',
        expectedRevision: 2,
      ),
    );
    expect((archived as ElvCommandSuccess<Cable>).value.lifecycleState,
        CableLifecycleState.archived);
  });
}

final class _FakeUow implements ElvWriteUnitOfWork<ElvCableWriteSession> {
  const _FakeUow(this.session);
  final ElvCableWriteSession session;

  @override
  Future<T> run<T>(Future<T> Function(ElvCableWriteSession session) action) =>
      action(session);
}

final class _FakeSession implements ElvCableWriteSession {
  _FakeSession(this.cables);

  @override
  final _FakeCableStore cables;

  @override
  final _FakeLedger commandLedger = _FakeLedger();

  @override
  final ElvCableDependencyStore cableDependencies = _NoDependencies();
}

final class _FakeLedger implements ElvCommandLedgerStore {
  final Map<String, ElvCommandLedgerEntry> entries = {};

  @override
  Future<ElvCommandLedgerEntry?> find(String projectId, String commandId) async =>
      entries['$projectId/$commandId'];

  @override
  Future<void> save(ElvCommandLedgerEntry entry) async {
    entries['${entry.projectId}/${entry.commandId}'] = entry;
  }
}

final class _NoDependencies implements ElvCableDependencyStore {
  @override
  Future<List<String>> blockingDependencyIds(String projectId, String cableId) async =>
      const [];

  @override
  Future<bool> hasCanonicalRunHistory(String projectId, String cableId) async => false;

  @override
  Future<bool> hasConsumingAllocation(String projectId, String cableId) async => false;

  @override
  Future<bool> hasResourceSelectionHistory(String projectId, String cableId) async => false;
}

final class _FakeCableStore implements ElvCableWriteStore {
  _FakeCableStore(this.definitions);

  final Map<String, CableDefinition> definitions;
  final Map<String, Cable> values = {};

  CableDefinitionRef refFor(String code) {
    final definition = definitions[code]!;
    return CableDefinitionRef(
      catalogId: 'catalog',
      catalogVersion: '1',
      definitionCode: code,
      definitionContentHash: cableDefinitionContentHashV1(definition),
    );
  }

  @override
  Future<bool> projectExists(String projectId) async => projectId == 'project';

  @override
  Future<Cable?> findCable(String projectId, String cableId) async => values[cableId];

  @override
  Future<CableDefinition> resolveDefinition(
    String projectId,
    CableDefinitionRef ref,
  ) async {
    final definition = definitions[ref.definitionCode];
    if (definition == null ||
        cableDefinitionContentHashV1(definition) != ref.definitionContentHash) {
      throw StateError('not found');
    }
    return definition;
  }

  @override
  Future<bool> activeLabelExists(String projectId, String normalizedLabel) async =>
      values.values.any(
        (cable) =>
            cable.projectId == projectId &&
            cable.lifecycleState == CableLifecycleState.active &&
            cable.normalizedLabel == normalizedLabel,
      );

  @override
  Future<bool> insertCable(Cable cable) async {
    if (values.containsKey(cable.id) ||
        await activeLabelExists(cable.projectId, cable.normalizedLabel)) {
      return false;
    }
    values[cable.id] = cable;
    return true;
  }

  @override
  Future<bool> updateDefinition({
    required String projectId,
    required String cableId,
    required int expectedRevision,
    required CableDefinitionRef definitionRef,
  }) async {
    final current = values[cableId];
    if (current == null || current.revision != expectedRevision) return false;
    values[cableId] = Cable(
      id: current.id,
      projectId: current.projectId,
      label: current.label,
      name: current.name,
      definitionRef: definitionRef,
      lifecycleState: current.lifecycleState,
      revision: current.revision + 1,
    );
    return true;
  }

  @override
  Future<bool> archiveCable({
    required String projectId,
    required String cableId,
    required int expectedRevision,
  }) async {
    final current = values[cableId];
    if (current == null ||
        current.projectId != projectId ||
        current.revision != expectedRevision ||
        current.lifecycleState != CableLifecycleState.active) {
      return false;
    }
    values[cableId] = Cable(
      id: current.id,
      projectId: current.projectId,
      label: current.label,
      name: current.name,
      definitionRef: current.definitionRef,
      lifecycleState: CableLifecycleState.archived,
      revision: current.revision + 1,
    );
    return true;
  }
}
