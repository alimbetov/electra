import 'package:drift/drift.dart';

/// Executes a raw SQLite statement while preserving Drift's typed-variable
/// calling convention at repository boundaries.
///
/// `customStatement` forwards positional arguments directly to sqlite3, where
/// `Variable<T>` and `DateTime` are not legal bind values. Queries and updates
/// should continue to use Drift's `variables:` API; this adapter exists only
/// for low-level statements that cannot use generated table APIs.
///
/// Raw statements may legitimately bind SQL NULL. Accepting `Object?` here
/// keeps nullable values out of Drift's non-null `Variable<T extends Object>`
/// generic while retaining the same conversion for typed variables.
Future<void> runRawStatement(
  DatabaseConnectionUser database,
  String statement, [
  List<Object?> variables = const [],
]) => database.customStatement(
  statement,
  variables.map(_sqliteValue).toList(growable: false),
);

Object? _sqliteValue(Object? variable) {
  if (variable is Variable) {
    final value = variable.value;
    if (value is DateTime) {
      return value.toUtc().millisecondsSinceEpoch ~/
          Duration.millisecondsPerSecond;
    }
    return value;
  }
  if (variable is DateTime) {
    return variable.toUtc().millisecondsSinceEpoch ~/
        Duration.millisecondsPerSecond;
  }
  return variable;
}
