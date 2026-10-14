from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(rel: str, old: str, new: str) -> None:
    path = ROOT / rel
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{rel}: expected one anchor, got {count}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))


replace_once(
    'packages/engineering_core/lib/src/elv_cable_resource_definition.dart',
    "  CableResourceDefinition({\n    required this.identity,\n    required this.kind,\n    required this.allocatable,\n    required this.atomic,\n    required this.terminationPolicy,\n    this.parentResourceId,\n",
    "  CableResourceDefinition({\n    required String identity,\n    required this.kind,\n    required this.allocatable,\n    required this.atomic,\n    required this.terminationPolicy,\n    String? parentResourceId,\n",
)

replace_once(
    'packages/engineering_core/lib/src/elv_cable_reference.dart',
    "  CableDefinition({\n    required this.code,\n    required this.label,\n    required this.mediaCode,\n    required Iterable<CableResourceDefinition> resourceDefinitions,\n    this.deprecated = false,\n    this.categoryCode,\n    this.conductorMaterialCode,\n    this.shieldingCode,\n    this.firePerformanceCode,\n",
    "  CableDefinition({\n    required String code,\n    required this.label,\n    required String mediaCode,\n    required Iterable<CableResourceDefinition> resourceDefinitions,\n    this.deprecated = false,\n    String? categoryCode,\n    String? conductorMaterialCode,\n    String? shieldingCode,\n    String? firePerformanceCode,\n",
)

replace_once(
    'packages/engineering_core/lib/src/elv_cable_termination.dart',
    "  CableTerminationMapping({\n    required this.id,\n    required this.allocationId,\n    required this.resourceIdentity,\n    required this.end,\n    required this.endpointPortId,\n    this.endpointTerminalRef,\n    this.terminationRole,\n",
    "  CableTerminationMapping({\n    required this.id,\n    required this.allocationId,\n    required String resourceIdentity,\n    required this.end,\n    required this.endpointPortId,\n    String? endpointTerminalRef,\n    String? terminationRole,\n",
)

replace_once(
    'packages/engineering_core/lib/src/elv_pathway_context.dart',
    "      var cursor = parentId;\n",
    "      String? cursor = parentId;\n",
)

replace_once(
    'packages/engineering_core/lib/src/elv_physical_compatibility_profile.dart',
    "  AllowedEnvironmentClassRule({\n    required super.selector,\n    required this.dimension,\n    required Iterable<String> allowedCodes,\n  }) : allowedCodes = _codes(allowedCodes);\n",
    "  AllowedEnvironmentClassRule({\n    required PhysicalCompatibilitySelector selector,\n    required this.dimension,\n    required Iterable<String> allowedCodes,\n  })  : allowedCodes = _codes(allowedCodes),\n        super(selector);\n",
)

replace_once(
    'packages/engineering_core/lib/src/elv_physical_compatibility_profile.dart',
    "  PhysicalCompatibilityProfile({\n    required this.code,\n    required this.label,\n    required Iterable<PhysicalCompatibilityRule> rules,\n    this.deprecated = false,\n  })  : code = code.trim().toUpperCase(),\n",
    "  PhysicalCompatibilityProfile({\n    required String code,\n    required this.label,\n    required Iterable<PhysicalCompatibilityRule> rules,\n    this.deprecated = false,\n  })  : code = code.trim().toUpperCase(),\n",
)

print('ELV3 core compilation remediation applied')
