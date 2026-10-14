from pathlib import Path

path = Path('packages/engineering_core/lib/src/engineering_reference_catalog.dart')
text = path.read_text()

needle = "import 'engineering_topology.dart';\n\nenum ReferenceDiscipline"
replacement = "import 'engineering_topology.dart';\n\nString normalizeEngineeringReferenceCode(String value) =>\n    value.trim().toUpperCase();\n\nenum ReferenceDiscipline"
assert needle in text
text = text.replace(needle, replacement, 1)

needle = """        if (profiles.map((profile) => profile.code).toSet().length !=\n            profiles.length)\n          'Profile codes must be unique.',"""
replacement = """        if (profiles.any(\n              (profile) =>\n                  profile.code != normalizeEngineeringReferenceCode(profile.code),\n            ) ||\n            profiles\n                    .map(\n                      (profile) =>\n                          normalizeEngineeringReferenceCode(profile.code),\n                    )\n                    .toSet()\n                    .length !=\n                profiles.length)\n          'Profile codes must be canonical and unique after normalization.',"""
assert needle in text
text = text.replace(needle, replacement, 1)

needle = """  ComponentEngineeringProfile profile(String code) =>\n      profiles.singleWhere((profile) => profile.code == code);"""
replacement = """  ComponentEngineeringProfile profile(String code) {\n    final normalized = normalizeEngineeringReferenceCode(code);\n    return profiles.singleWhere(\n      (profile) => normalizeEngineeringReferenceCode(profile.code) == normalized,\n    );\n  }"""
assert needle in text
text = text.replace(needle, replacement, 1)

path.write_text(text)
