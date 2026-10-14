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
text = text.replace(needle, replacement, 1)
needle = """        if ([id, code, version, source].any((value) => value.trim().isEmpty))
          'Catalog identity, code, version and provenance are required.',
        if (profiles.isEmpty) 'Provide at least one engineering profile.',"""
replacement = """        if ([id, code, version, source].any((value) => value.trim().isEmpty))
          'Catalog identity, code, version and provenance are required.',
        if (code != normalizeEngineeringReferenceCode(code))
          'Catalog code must use canonical engineering identity.',
        if (profiles.isEmpty) 'Provide at least one engineering profile.',"""
assert needle in text
core.write_text(text.replace(needle, replacement, 1))

p5 = Path('apps/mobile/lib/application/engineering_reference_revision_preview.dart')
text = p5.read_text()
needle = """  final candidateProfiles = {
    for (final profile in candidate.profiles) profile.code: profile,
  };"""
replacement = """  final candidateProfiles = {
    for (final profile in candidate.profiles)
      normalizeEngineeringReferenceCode(profile.code): profile,
  };"""
assert needle in text
text = text.replace(needle, replacement, 1)
text = text.replace(
"final candidateProfile = candidateProfiles[binding.profileCode];",
"final candidateProfile = candidateProfiles[normalizeEngineeringReferenceCode(binding.profileCode)];",
1,
)
p5.write_text(text)

p6 = Path('apps/mobile/lib/application/engineering_reference_adoption_repository.dart')
text = p6.read_text()
needle = """    required this.candidateCatalogVersion,
    required this.profileCode,
    required this.reviewedBindingFingerprint,"""
replacement = """    required this.candidateCatalogVersion,
    required String profileCode,
    required this.reviewedBindingFingerprint,"""
assert needle in text
text = text.replace(needle, replacement, 1)
needle = """  }) : reviewedConnectionIds = List.unmodifiable("""
replacement = """  }) : profileCode = normalizeEngineeringReferenceCode(profileCode),
       reviewedConnectionIds = List.unmodifiable("""
assert needle in text
p6.write_text(text.replace(needle, replacement, 1))
