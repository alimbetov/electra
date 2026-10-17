import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/fire/fa01_address_capacity_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa01_address_capacity_contract_write.dart';
import 'package:electra_mobile/application/elv5/fire/fa07_topology_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa07_topology_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa01_address_capacity_contract_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa07_topology_contract_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps FA-01 and FA-07 editions immutable with design CAS', () async {
    final db=AppDatabase(NativeDatabase.memory());addTearDown(db.close);await _seed(db);
    final fa01=DriftFa01AddressCapacityContractStore(db,originDeviceId:'test',nowUtc:()=>DateTime.utc(2026,10,17));
    await fa01.replace(ReplaceFa01AddressCapacityContractCommand(projectId:'p',designRevisionId:'d',bindingId:'fa01-binding',expectedBindingRevision:null,expectedDesignRevision:1,contract:_fa01(5)));
    final first=await fa01.loadActiveForLoop(projectId:'p',designRevisionId:'d',loopId:'loop-1');expect(first,isNotNull);expect(first!.bindingRevision,1);final firstRef=first.evidenceRef;
    await fa01.replace(ReplaceFa01AddressCapacityContractCommand(projectId:'p',designRevisionId:'d',bindingId:'fa01-binding',expectedBindingRevision:1,expectedDesignRevision:2,contract:_fa01(6)));
    final second=await fa01.loadActiveForLoop(projectId:'p',designRevisionId:'d',loopId:'loop-1');expect(second!.bindingRevision,2);expect(second.evidenceRef,isNot(firstRef));

    final fa07=DriftFa07TopologyContractStore(db,originDeviceId:'test',nowUtc:()=>DateTime.utc(2026,10,17));
    await fa07.replace(ReplaceFa07TopologyContractCommand(projectId:'p',designRevisionId:'d',bindingId:'fa07-binding',expectedBindingRevision:null,expectedDesignRevision:3,contract:_fa07('e4')));
    final topo1=await fa07.loadActiveForLoop(projectId:'p',designRevisionId:'d',loopId:'loop-1');expect(topo1!.bindingRevision,1);final topoRef=topo1.evidenceRef;
    await fa07.replace(ReplaceFa07TopologyContractCommand(projectId:'p',designRevisionId:'d',bindingId:'fa07-binding',expectedBindingRevision:1,expectedDesignRevision:4,contract:_fa07('e5')));
    final topo2=await fa07.loadActiveForLoop(projectId:'p',designRevisionId:'d',loopId:'loop-1');expect(topo2!.bindingRevision,2);expect(topo2.evidenceRef,isNot(topoRef));

    final revision=await db.customSelect("SELECT revision FROM project_design_revisions WHERE id = 'd'").getSingle();expect(revision.read<int>('revision'),5);
    final evidence=await db.customSelect("SELECT evidence_ref FROM elv_revision_aggregate_evidence_records WHERE aggregate_id = 'loop-1'").get();expect(evidence,hasLength(4));
  });
}

Fa01AddressCapacityContract _fa01(int addressLimit)=>Fa01AddressCapacityContract(loopId:'loop-1',deviceLimit:10,addressLimit:addressLimit,requiredDeviceSpare:1,requiredAddressSpare:1,profileAddressConsumption:const <String,int>{'single':1},profileDeviceCountContribution:const <String,int>{'single':1});

Fa07TopologyContract _fa07(String lastEdge)=>Fa07TopologyContract(loopId:'loop-1',topologyProfile:Fa07TopologyProfileIdentity(profileCode:'CLASS-A',editionId:'v1',contentHash:_hash('a')),expectedFa01MembershipFingerprint:_hash('b'),sourceNodeId:'source',returnNodeId:'return',deviceNodeIdByDeviceId:const <String,String>{'d1':'n1'},edges:<Fa07EdgeContract>[Fa07EdgeContract(edgeId:'e1',fromNodeId:'source',toNodeId:'n1'),Fa07EdgeContract(edgeId:lastEdge,fromNodeId:'n1',toNodeId:'return')],permittedBranchNodeIds:const <String>[],maxBranchNodes:0,requiredFaultCases:const <String>[],faultScenarios:const <Fa07FaultScenarioContract>[]);

Future<void> _seed(AppDatabase db) async {await db.customStatement('PRAGMA foreign_keys = OFF');const now='2026-10-17T00:00:00.000Z';await db.customStatement("INSERT INTO projects (id, name, measurement_system, default_structural_height_mm, default_finished_ceiling_height_mm, created_at, updated_at, origin_device_id) VALUES ('p','Project','METRIC',3000,2700,'$now','$now','test')");await db.customStatement("INSERT INTO project_design_revisions (id, project_id, code, sequence, state, revision, created_at, updated_at, origin_device_id) VALUES ('d','p','R1',1,'WORKING',1,'$now','$now','test')");}
String _hash(String c)=>List<String>.filled(64,c).join();
