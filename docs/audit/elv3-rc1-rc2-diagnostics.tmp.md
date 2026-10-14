# Temporary ELV3 RC1-RC2 diagnostics

```text
00:00 +0: loading /home/runner/work/electra/electra/apps/mobile/test/data/elv_p3_runtime_closure_test.dart
../../packages/engineering_core/lib/src/elv_cable_reference.dart:83:9: Error: 'code' was already initialized by this constructor.
  })  : code = code.trim().toUpperCase(),
        ^
../../packages/engineering_core/lib/src/elv_cable_reference.dart:84:9: Error: 'mediaCode' was already initialized by this constructor.
        mediaCode = mediaCode.trim().toUpperCase(),
        ^
../../packages/engineering_core/lib/src/elv_cable_reference.dart:85:9: Error: 'categoryCode' was already initialized by this constructor.
        categoryCode = _normalizeNullable(categoryCode),
        ^
../../packages/engineering_core/lib/src/elv_cable_reference.dart:86:9: Error: 'conductorMaterialCode' was already initialized by this constructor.
        conductorMaterialCode = _normalizeNullable(conductorMaterialCode),
        ^
../../packages/engineering_core/lib/src/elv_cable_reference.dart:87:9: Error: 'shieldingCode' was already initialized by this constructor.
        shieldingCode = _normalizeNullable(shieldingCode),
        ^
../../packages/engineering_core/lib/src/elv_cable_reference.dart:88:9: Error: 'firePerformanceCode' was already initialized by this constructor.
        firePerformanceCode = _normalizeNullable(firePerformanceCode),
        ^
../../packages/engineering_core/lib/src/elv_cable_termination.dart:12:9: Error: 'resourceIdentity' was already initialized by this constructor.
  })  : resourceIdentity = resourceIdentity.trim().toUpperCase(),
        ^
../../packages/engineering_core/lib/src/elv_cable_termination.dart:13:9: Error: 'endpointTerminalRef' was already initialized by this constructor.
        endpointTerminalRef = _normalizeNullable(endpointTerminalRef),
        ^
../../packages/engineering_core/lib/src/elv_cable_termination.dart:14:9: Error: 'terminationRole' was already initialized by this constructor.
        terminationRole = _normalizeNullable(terminationRole);
        ^
../../packages/engineering_core/lib/src/elv_pathway_context.dart:122:33: Error: A value of type 'String?' can't be assigned to a variable of type 'String'.
        cursor = projectContexts[cursor]?.parentContextId;
                                ^
../../packages/engineering_core/lib/src/elv_physical_compatibility_profile.dart:99:20: Error: The super constructor has no corresponding named parameter.
    required super.selector,
                   ^
../../packages/engineering_core/lib/src/elv_physical_compatibility_profile.dart:153:9: Error: 'code' was already initialized by this constructor.
  })  : code = code.trim().toUpperCase(),
        ^
00:00 +0 -1: loading /home/runner/work/electra/electra/apps/mobile/test/data/elv_p3_runtime_closure_test.dart [E]
  Failed to load "/home/runner/work/electra/electra/apps/mobile/test/data/elv_p3_runtime_closure_test.dart":
  Compilation failed for testPath=/home/runner/work/electra/electra/apps/mobile/test/data/elv_p3_runtime_closure_test.dart: ../../packages/engineering_core/lib/src/elv_cable_reference.dart:83:9: Error: 'code' was already initialized by this constructor.
    })  : code = code.trim().toUpperCase(),
          ^
  ../../packages/engineering_core/lib/src/elv_cable_reference.dart:84:9: Error: 'mediaCode' was already initialized by this constructor.
          mediaCode = mediaCode.trim().toUpperCase(),
          ^
  ../../packages/engineering_core/lib/src/elv_cable_reference.dart:85:9: Error: 'categoryCode' was already initialized by this constructor.
          categoryCode = _normalizeNullable(categoryCode),
          ^
  ../../packages/engineering_core/lib/src/elv_cable_reference.dart:86:9: Error: 'conductorMaterialCode' was already initialized by this constructor.
          conductorMaterialCode = _normalizeNullable(conductorMaterialCode),
          ^
  ../../packages/engineering_core/lib/src/elv_cable_reference.dart:87:9: Error: 'shieldingCode' was already initialized by this constructor.
          shieldingCode = _normalizeNullable(shieldingCode),
          ^
  ../../packages/engineering_core/lib/src/elv_cable_reference.dart:88:9: Error: 'firePerformanceCode' was already initialized by this constructor.
          firePerformanceCode = _normalizeNullable(firePerformanceCode),
          ^
  ../../packages/engineering_core/lib/src/elv_cable_termination.dart:12:9: Error: 'resourceIdentity' was already initialized by this constructor.
    })  : resourceIdentity = resourceIdentity.trim().toUpperCase(),
          ^
  ../../packages/engineering_core/lib/src/elv_cable_termination.dart:13:9: Error: 'endpointTerminalRef' was already initialized by this constructor.
          endpointTerminalRef = _normalizeNullable(endpointTerminalRef),
          ^
  ../../packages/engineering_core/lib/src/elv_cable_termination.dart:14:9: Error: 'terminationRole' was already initialized by this constructor.
          terminationRole = _normalizeNullable(terminationRole);
          ^
  ../../packages/engineering_core/lib/src/elv_pathway_context.dart:122:33: Error: A value of type 'String?' can't be assigned to a variable of type 'String'.
          cursor = projectContexts[cursor]?.parentContextId;
                                  ^
  ../../packages/engineering_core/lib/src/elv_physical_compatibility_profile.dart:99:20: Error: The super constructor has no corresponding named parameter.
      required super.selector,
                     ^
  ../../packages/engineering_core/lib/src/elv_physical_compatibility_profile.dart:153:9: Error: 'code' was already initialized by this constructor.
    })  : code = code.trim().toUpperCase(),
          ^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /home/runner/work/electra/electra/apps/mobile/test/data/elv_p3_runtime_closure_test.dart: loading /home/runner/work/electra/electra/apps/mobile/test/data/elv_p3_runtime_closure_test.dart
```
