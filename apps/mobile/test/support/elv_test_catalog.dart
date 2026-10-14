final class ElvTestCableDefinitionFixture {
  const ElvTestCableDefinitionFixture({
    required this.code,
    required this.resourceAtoms,
  });

  final String code;
  final List<String> resourceAtoms;
}

abstract final class ElvTestCatalog {
  static const cat6 = ElvTestCableDefinitionFixture(
    code: 'CAT6-4PAIR',
    resourceAtoms: ['PAIR-1', 'PAIR-2', 'PAIR-3', 'PAIR-4'],
  );

  static const eightCore = ElvTestCableDefinitionFixture(
    code: 'CONTROL-8CORE',
    resourceAtoms: [
      'CORE-1',
      'CORE-2',
      'CORE-3',
      'CORE-4',
      'CORE-5',
      'CORE-6',
      'CORE-7',
      'CORE-8',
    ],
  );

  static const twelveFiber = ElvTestCableDefinitionFixture(
    code: 'FIBER-12',
    resourceAtoms: [
      'FIBER-1',
      'FIBER-2',
      'FIBER-3',
      'FIBER-4',
      'FIBER-5',
      'FIBER-6',
      'FIBER-7',
      'FIBER-8',
      'FIBER-9',
      'FIBER-10',
      'FIBER-11',
      'FIBER-12',
    ],
  );
}
