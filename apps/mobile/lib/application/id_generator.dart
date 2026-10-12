import 'package:uuid/uuid.dart';

abstract interface class IdGenerator {
  String next();
}

final class UuidV7IdGenerator implements IdGenerator {
  UuidV7IdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String next() => _uuid.v7();
}

final class FixedSequenceIdGenerator implements IdGenerator {
  FixedSequenceIdGenerator(this._ids);

  final List<String> _ids;
  var _index = 0;

  @override
  String next() {
    if (_index >= _ids.length) {
      throw StateError('No test IDs remaining.');
    }
    return _ids[_index++];
  }
}
