import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  Acs01RequirementNode role(String id, Acs01RoleCode role, int count,
          [Acs01RequirementKind kind = Acs01RequirementKind.atLeast]) =>
      Acs01RequirementNode.roleCount(
        nodeId: id,
        kind: kind,
        role: role,
        count: count,
      );

  Acs01ComponentCapabilities cap(
    String id,
    Set<Acs01RoleCode> roles, {
    bool share = false,
  }) =>
      Acs01ComponentCapabilities(
        componentId: id,
        allowedRoles: roles,
        allowRoleSharing: share,
      );

  Acs01RoleAssignment assign(String id, String componentId, Acs01RoleCode role) =>
      Acs01RoleAssignment(
        assignmentId: id,
        componentId: componentId,
        role: role,
      );

  test('selects explicit exit-button alternative', () {
    final root = Acs01RequirementNode.group(
      nodeId: 'root',
      kind: Acs01RequirementKind.allOf,
      children: [
        role('entry', Acs01RoleCode.entryReader, 1),
        role('lock', Acs01RoleCode.lock, 1),
        Acs01RequirementNode.group(
          nodeId: 'exit-choice',
          kind: Acs01RequirementKind.anyOf,
          children: [
            role('exit-button', Acs01RoleCode.exitButton, 1),
            role('exit-reader', Acs01RoleCode.exitReader, 1),
          ],
        ),
      ],
    );
    final result = const Acs01RoleCompletenessKernel().evaluate(Acs01Input(
      doorId: 'door-1',
      profileId: 'profile-1',
      rootRequirement: root,
      assignmentClosureComplete: true,
      assignments: [
        assign('a1', 'entry-reader', Acs01RoleCode.entryReader),
        assign('a2', 'lock-1', Acs01RoleCode.lock),
        assign('a3', 'exit-button-1', Acs01RoleCode.exitButton),
      ],
      capabilities: [
        cap('entry-reader', {Acs01RoleCode.entryReader}),
        cap('lock-1', {Acs01RoleCode.lock}),
        cap('exit-button-1', {Acs01RoleCode.exitButton}),
      ],
    ));
    expect(result.status, Acs01AssessmentStatus.pass);
    final alternative = result.nodeResults.singleWhere((r) => r.nodeId == 'exit-choice');
    expect(alternative.selectedChildNodeIds, ['exit-button']);
  });

  test('exact-two contact rule passes at two and fails at three', () {
    Acs01Result evaluate(int count) {
      final assignments = <Acs01RoleAssignment>[];
      final capabilities = <Acs01ComponentCapabilities>[];
      for (var i = 0; i < count; i++) {
        assignments.add(assign('a$i', 'c$i', Acs01RoleCode.doorContact));
        capabilities.add(cap('c$i', {Acs01RoleCode.doorContact}));
      }
      return const Acs01RoleCompletenessKernel().evaluate(Acs01Input(
        doorId: 'door',
        profileId: 'profile',
        rootRequirement: role(
          'contacts',
          Acs01RoleCode.doorContact,
          2,
          Acs01RequirementKind.exactly,
        ),
        assignments: assignments,
        capabilities: capabilities,
        assignmentClosureComplete: true,
      ));
    }

    expect(evaluate(2).status, Acs01AssessmentStatus.pass);
    final over = evaluate(3);
    expect(over.status, Acs01AssessmentStatus.fail);
    expect(over.nodeResults.single.margin, -1);
  });

  test('missing required role fails only when closure is complete', () {
    Acs01Result evaluate(bool complete) =>
        const Acs01RoleCompletenessKernel().evaluate(Acs01Input(
          doorId: 'door',
          profileId: 'profile',
          rootRequirement: role('contact', Acs01RoleCode.doorContact, 1),
          assignments: const [],
          capabilities: const [],
          assignmentClosureComplete: complete,
        ));

    expect(evaluate(true).status, Acs01AssessmentStatus.fail);
    expect(evaluate(false).status, Acs01AssessmentStatus.unresolved);
  });

  test('forbidden role sharing fails even if requirements are numerically satisfied', () {
    final root = Acs01RequirementNode.group(
      nodeId: 'root',
      kind: Acs01RequirementKind.allOf,
      children: [
        role('exit', Acs01RoleCode.exitButton, 1),
        role('emergency', Acs01RoleCode.emergencyRelease, 1),
      ],
    );
    final result = const Acs01RoleCompletenessKernel().evaluate(Acs01Input(
      doorId: 'door',
      profileId: 'profile',
      rootRequirement: root,
      assignments: [
        assign('a1', 'shared', Acs01RoleCode.exitButton),
        assign('a2', 'shared', Acs01RoleCode.emergencyRelease),
      ],
      capabilities: [
        cap('shared', {
          Acs01RoleCode.exitButton,
          Acs01RoleCode.emergencyRelease,
        }),
      ],
      assignmentClosureComplete: true,
    ));

    expect(result.status, Acs01AssessmentStatus.fail);
    expect(result.illegalSharingComponentIds, ['shared']);
    expect(result.governingNodeId, 'ACS01_ILLEGAL_ROLE_SHARING');
  });
}
