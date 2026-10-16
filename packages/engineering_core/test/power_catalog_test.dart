import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('P1 strict power catalog codec', () {
    test('generic power-only catalog round-trips without discipline identity',
        () {
      final catalog = _catalog();
      final decoded = PowerRootCatalog.fromMap(catalog.toMap());

      expect(decoded.code, 'TEST_POWER');
      expect(decoded.power.componentDefinitions.single.code, 'GENERIC_PSU');
      expect(
        canonicalEngineeringJsonV1(decoded.toMap()),
        canonicalEngineeringJsonV1(catalog.toMap()),
      );
      expect(decoded.contentSha256, catalog.contentSha256);
    });

    test('definition references are exact-edition and content-addressed', () {
      final catalog = _catalog();
      final first = catalog.power.definitionRef(
        catalogId: catalog.id,
        catalogVersion: catalog.version,
        kind: PowerDefinitionKind.port,
        code: 'DC_OUT',
      );
      final second = catalog.power.definitionRef(
        catalogId: catalog.id,
        catalogVersion: catalog.version,
        kind: PowerDefinitionKind.port,
        code: 'dc_out',
      );

      expect(first.definitionCode, 'DC_OUT');
      expect(first.definitionVersion, '1');
      expect(first.contentSha256, second.contentSha256);
      expect(first.contentSha256, hasLength(64));
    });

    test('unknown mandatory schema rejects instead of legacy fallback', () {
      final map = _catalog().toMap();
      map['schema'] = 'electra.elv4-power-catalog.v2';
      expect(
        () => PowerRootCatalog.fromMap(map),
        throwsFormatException,
      );

      final power = Map<String, Object?>.from(
        map['power'] as Map<String, Object?>,
      );
      power['schema'] = 'electra.elv4-power-definitions.v2';
      map['schema'] = powerRootCatalogSchemaV1;
      map['power'] = power;
      expect(
        () => PowerRootCatalog.fromMap(map),
        throwsFormatException,
      );
    });

    test('unresolved connector protocol or interface references reject import',
        () {
      final catalog = _catalog();
      final port = PowerPortDefinition(
        code: 'BAD_OUT',
        sourceRef: 'fixture:bad',
        kind: PowerCatalogPortKind.power,
        direction: PowerCatalogDirection.output,
        capacity: 1,
        connectorCode: 'MISSING',
        protocolCode: 'DC_POWER',
        interfaceCode: 'DC_OUT_IF',
        powerDirection: PowerCatalogDirection.output,
        voltage: _voltage(),
        nameplateLimitW: _r('20'),
      );
      expect(
        () => PowerCatalogExtension(
          connectors: catalog.power.connectors,
          protocols: catalog.power.protocols,
          interfaces: catalog.power.interfaces,
          portDefinitions: [port],
          componentDefinitions: [
            PowerComponentDefinition(
              code: 'GENERIC_PSU',
              sourceRef: 'fixture:psu',
              portCodes: const ['BAD_OUT'],
              transferCodes: const [],
              capabilities: const [PowerCatalogCapability.source],
              supplyOrigin: PowerSupplyOrigin.externalDeclared,
            ),
          ],
          compatibilityDefinitions: catalog.power.compatibilityDefinitions,
        ),
        throwsArgumentError,
      );
    });
  });
}

PowerRootCatalog _catalog() {
  final extension = PowerCatalogExtension(
    connectors: [
      PowerConnectorDefinition(
        code: 'TERMINAL_2',
        contactCount: 2,
        sourceRef: 'fixture:terminal',
      ),
    ],
    protocols: [
      PowerProtocolDefinition(
        code: 'DC_POWER',
        portKinds: const [PowerCatalogPortKind.power],
        sourceRef: 'fixture:dc',
      ),
    ],
    interfaces: [
      PowerInterfaceDefinition(
        code: 'DC_OUT_IF',
        portCode: 'DC_OUT',
        sourceRef: 'fixture:out-if',
      ),
      PowerInterfaceDefinition(
        code: 'DC_IN_IF',
        portCode: 'DC_IN',
        sourceRef: 'fixture:in-if',
      ),
    ],
    portDefinitions: [
      PowerPortDefinition(
        code: 'DC_OUT',
        sourceRef: 'fixture:out',
        kind: PowerCatalogPortKind.power,
        direction: PowerCatalogDirection.output,
        capacity: 1,
        connectorCode: 'TERMINAL_2',
        protocolCode: 'DC_POWER',
        interfaceCode: 'DC_OUT_IF',
        powerDirection: PowerCatalogDirection.output,
        voltage: _voltage(),
        nameplateLimitW: _r('20'),
      ),
      PowerPortDefinition(
        code: 'DC_IN',
        sourceRef: 'fixture:in',
        kind: PowerCatalogPortKind.power,
        direction: PowerCatalogDirection.input,
        capacity: 1,
        connectorCode: 'TERMINAL_2',
        protocolCode: 'DC_POWER',
        interfaceCode: 'DC_IN_IF',
        powerDirection: PowerCatalogDirection.input,
        voltage: _voltage(),
        nameplateDemandW: _r('10'),
      ),
    ],
    componentDefinitions: [
      PowerComponentDefinition(
        code: 'GENERIC_PSU',
        sourceRef: 'fixture:psu',
        portCodes: const ['DC_OUT'],
        transferCodes: const [],
        capabilities: const [PowerCatalogCapability.source],
        supplyOrigin: PowerSupplyOrigin.externalDeclared,
      ),
    ],
    policyDefinitions: [
      PowerPolicyDefinition(
        code: 'NO_RESERVE',
        sourceRef: 'fixture:policy',
        purpose: PowerPolicyPurpose.supplyReserve,
        reserveMultiplier: PowerRational.one,
        extensionPolicy: PowerExtensionPolicy.none,
      ),
    ],
    compatibilityDefinitions: [
      PowerCompatibilityDefinition(
        code: 'DC_FEED',
        sourceRef: 'fixture:compat',
        familyCodes: const ['ACS', 'CCTV', 'FIRE', 'LAN'],
        layer: PowerCompatibilityLayer.power,
        flow: PowerCompatibilityFlow.directed,
        portCodeA: 'DC_OUT',
        portCodeB: 'DC_IN',
        protocolCodeA: 'DC_POWER',
        protocolCodeB: 'DC_POWER',
        interfaceCodeA: 'DC_OUT_IF',
        interfaceCodeB: 'DC_IN_IF',
      ),
    ],
  );
  return PowerRootCatalog(
    id: 'fictional-power-v1',
    code: 'TEST_POWER',
    version: '1',
    source: 'fictional product-neutral fixture',
    power: extension,
    metadata: const {'label': 'Power fixture'},
  );
}

PowerVoltageEnvelope _voltage() => PowerVoltageEnvelope(
      currentKind: PowerCurrentKind.dc,
      minV: _r('24'),
      nominalV: _r('24'),
      maxV: _r('24'),
    );

PowerRational _r(String value) => PowerRational.fromWireDecimal(value);
