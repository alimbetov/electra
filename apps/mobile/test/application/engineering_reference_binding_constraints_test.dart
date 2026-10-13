import 'dart:convert';
import 'dart:io';

import 'package:electra_mobile/application/engineering_reference_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('component binding roundtrips exact embedded constraint snapshot', () {
    final catalog = EngineeringReferenceCatalog.fromMap(
      jsonDecode(
        File('../../docs/examples/elv2-reference-catalog.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
    );
    final profile = catalog.profile('CAMERA');
    final binding = ComponentReferenceBinding(
      componentId: 'camera-1',
      catalogId: catalog.id,
      profileCode: profile.code,
      catalogVersion: catalog.version,
      profile: profile,
      portIds: const ['camera-port'],
    );

    final restored = ComponentReferenceBinding.fromMap(
      jsonDecode(jsonEncode(binding.toMap())) as Map<String, dynamic>,
    );

    expect(restored.profile.constraintsState, ProfileConstraintsState.defined);
    expect(
      restored.profile.constraints!.toMap(),
      profile.constraints!.toMap(),
    );
    expect(
      restored.profile.constraints!.mounting.allows(
        InstallationSurface.wall,
        MountingMethod.bracket,
      ),
      isTrue,
    );
  });
}
