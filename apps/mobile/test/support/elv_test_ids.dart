final class FixedSequenceIdGenerator {
  FixedSequenceIdGenerator([Iterable<String> values = const []])
      : _values = List<String>.from(values);

  final List<String> _values;
  int _index = 0;

  String next(String prefix) {
    if (_index < _values.length) return _values[_index++];
    _index++;
    return '$prefix${_index.toString().padLeft(3, '0')}';
  }
}

abstract final class ElvFixturePrefixes {
  static const project = 'PRJ-';
  static const revision = 'REV-';
  static const system = 'SYS-';
  static const component = 'CMP-';
  static const port = 'PORT-';
  static const connection = 'CONN-';
  static const catalog = 'CAT-';
  static const cable = 'CABLE-';
  static const allocation = 'ALLOC-';
  static const run = 'RUN-';
  static const traversal = 'TRV-';
  static const route = 'ROUTE-';
  static const node = 'NODE-';
  static const segment = 'SEG-';
  static const handoff = 'HANDOFF-';
  static const carrier = 'CARRIER-';
  static const context = 'CTX-';
}
