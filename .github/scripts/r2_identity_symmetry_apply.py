from pathlib import Path

core = Path('packages/engineering_core/lib/src/engineering_reference_catalog.dart')
text = core.read_text()
needle = """        if (portTemplates
                .map((port) => port.code.trim().toUpperCase())
                .toSet()
                .length !=
            portTemplates.length)
          'Duplicate port template code.',
        for (final port in portTemplates) ...port.validate(),
        if (portInterfaceCodes.keys.any(
          (code) => !portTemplates.any((port) => port.code == code),
        ))
          'Interface binding references an unknown port template.',"""
replacement = """        if (portTemplates
                .map((port) => normalizeEngineeringReferenceCode(port.code))
                .toSet()
                .length !=
            portTemplates.length)
          'Duplicate port template code.',
        if (portTemplates.any(
          (port) => port.code != normalizeEngineeringReferenceCode(port.code),
        ))
          'Port template codes must use canonical engineering identity.',
        for (final port in portTemplates) ...port.validate(),
        if (portInterfaceCodes.keys.any(
          (code) => code != normalizeEngineeringReferenceCode(code),
        ))
          'Interface binding keys must use canonical port identity.',
        if (portInterfaceCodes.keys.any(
          (code) => !portTemplates.any(
            (port) =>
                normalizeEngineeringReferenceCode(port.code) ==
                normalizeEngineeringReferenceCode(code),
          ),
        ))
          'Interface binding references an unknown port template.',"""
assert needle in text
core.write_text(text.replace(needle, replacement, 1))

p5 = Path('apps/mobile/lib/application/engineering_reference_revision_preview.dart')
text = p5.read_text()
needle = """    final nextProfile =
        candidate.profiles
            .where((item) => item.code == binding.profileCode)
            .firstOrNull;
    if (nextProfile == null) {"""
replacement = """    ComponentEngineeringProfile? nextProfile;
    try {
      nextProfile = candidate.profile(binding.profileCode);
    } catch (_) {
      nextProfile = null;
    }
    if (nextProfile == null) {"""
assert needle in text
p5.write_text(text.replace(needle, replacement, 1))

p6 = Path('apps/mobile/lib/application/engineering_reference_adoption_repository.dart')
text = p6.read_text()
text = text.replace(
"""    required this.candidateCatalogVersion,
    required this.profileCode,
    required this.reviewedBindingFingerprint,""",
"""    required this.candidateCatalogVersion,
    required String profileCode,
    required this.reviewedBindingFingerprint,""",
1,
)
text = text.replace(
"""  }) : reviewedConnectionIds = List.unmodifiable(""",
"""  }) : profileCode = normalizeEngineeringReferenceCode(profileCode),
       reviewedConnectionIds = List.unmodifiable(""",
1,
)
p6.write_text(text)
