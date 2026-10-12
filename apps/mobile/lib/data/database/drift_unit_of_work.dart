import '../../application/project_repositories.dart';
import 'app_database.dart';

final class DriftUnitOfWork implements LocalUnitOfWork {
  DriftUnitOfWork(this.database);

  final AppDatabase database;

  @override
  Future<T> run<T>(Future<T> Function() action) {
    return database.transaction(action);
  }
}
