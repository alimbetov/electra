import 'dart:convert';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/lan/lan05_optical_section_evidence_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_lan05_optical_section_evidence_writer.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'persists exact attenuation and bumps link/design revisions atomically',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);

      final writer = DriftLan05OpticalSectionEvidenceWriter(
        db,
        originDeviceId: 'test',
        nowUtc: () => DateTime.utc(2026, 10, 17, 12),
      );
      await writer.replace(
        ReplaceLan05SectionEvidenceCommand(
          projectId: 'p',
          designRevisionId: 'd',
          linkId: 'link-1',
          realizedSectionId: 'section-1',
          expectedLinkRevision: 1,
          expectedDesignRevision: 1,
          profiles: <Lan05AttenuationProfileDraft>[
            Lan05AttenuationProfileDraft(
              wavelengthNm: Elv5Rational.integer(1310),
              minimumDbPerKm: Elv5Rational.parseDecimal('0.32'),
              maximumDbPerKm: Elv5Rational.parseDecimal('0.35'),
              evidenceRef: 'catalog:fiber-a:edition-1',
            ),
          ],
        ),
      );

      final section =
          await db
              .customSelect(
                "SELECT evidence_json FROM link_section_assignments WHERE binding_id = 'link-binding-1'",
              )
              .getSingle();
      final evidence =
          jsonDecode(section.read<String>('evidence_json'))
              as Map<String, dynamic>;
      expect(evidence['schema'], 'electra.elv5-optical-fiber-evidence.v1');
      final profile =
          (evidence['attenuationProfiles'] as List).single
              as Map<String, dynamic>;
      expect(profile['wavelengthNm'], <String, dynamic>{
        'denominator': '1',
        'numerator': '1310',
      });
      expect(profile['minDbPerKm'], <String, dynamic>{
        'denominator': '25',
        'numerator': '8',
      });
      expect(profile['maxDbPerKm'], <String, dynamic>{
        'denominator': '20',
        'numerator': '7',
      });

      final link =
          await db
              .customSelect(
                "SELECT revision FROM link_composition_bindings WHERE id = 'link-binding-1'",
              )
              .getSingle();
      final revision =
          await db
              .customSelect(
                "SELECT revision FROM project_design_revisions WHERE id = 'd'",
              )
              .getSingle();
      expect(link.read<int>('revision'), 2);
      expect(revision.read<int>('revision'), 2);
    },
  );

  test('stale link revision rejects before evidence mutation', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    final writer = DriftLan05OpticalSectionEvidenceWriter(
      db,
      originDeviceId: 'test',
    );

    await expectLater(
      writer.replace(
        ReplaceLan05SectionEvidenceCommand(
          projectId: 'p',
          designRevisionId: 'd',
          linkId: 'link-1',
          realizedSectionId: 'section-1',
          expectedLinkRevision: 2,
          expectedDesignRevision: 1,
          profiles: <Lan05AttenuationProfileDraft>[
            Lan05AttenuationProfileDraft(
              wavelengthNm: Elv5Rational.integer(1310),
              minimumDbPerKm: Elv5Rational.parseDecimal('0.32'),
              maximumDbPerKm: Elv5Rational.parseDecimal('0.35'),
              evidenceRef: 'catalog:fiber-a:edition-1',
            ),
          ],
        ),
      ),
      throwsStateError,
    );

    final section =
        await db
            .customSelect(
              "SELECT evidence_json FROM link_section_assignments WHERE binding_id = 'link-binding-1'",
            )
            .getSingle();
    expect(section.read<String>('evidence_json'), '{}');
  });
}

Future<void> _seed(AppDatabase db) async {
  const now = '2026-10-17T00:00:00.000Z';
  await db.customStatement('''
INSERT INTO projects (
  id, name, measurement_system, default_structural_height_mm,
  default_finished_ceiling_height_mm, created_at, updated_at, origin_device_id
) VALUES ('p', 'Project', 'METRIC', 3000, 2700, '$now', '$now', 'test')
''');
  await db.customStatement('''
INSERT INTO project_design_revisions (
  id, project_id, code, sequence, state, revision,
  created_at, updated_at, origin_device_id
) VALUES ('d', 'p', 'R1', 1, 'WORKING', 1, '$now', '$now', 'test')
''');
  await db.customStatement('''
INSERT INTO link_composition_bindings (
  project_id, design_revision_id, id, revision, created_at, updated_at,
  origin_device_id, link_id, policy_binding_id, composition_kind
) VALUES ('p', 'd', 'link-binding-1', 1, '$now', '$now', 'test',
  'link-1', 'policy-1', 'ORDERED')
''');
  await db.customStatement('''
INSERT INTO link_section_assignments (
  project_id, design_revision_id, binding_id, ordinal,
  realized_section_id, section_role, evidence_json
) VALUES ('p', 'd', 'link-binding-1', 0, 'section-1', 'PERMANENT', '{}')
''');
}
