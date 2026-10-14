import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';

final class ElvDatabaseReopenHarness {
  ElvDatabaseReopenHarness(this.file);

  final File file;

  AppDatabase open() => AppDatabase(NativeDatabase(file));

  Future<AppDatabase> reopen(AppDatabase current) async {
    await current.close();
    return open();
  }
}
