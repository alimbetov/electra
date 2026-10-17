import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reopening an initialized database does not request catalog writes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'electra-read-only-reopen-',
      );
      final file = File('${directory.path}/catalog.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await directory.delete(recursive: true);
      });
      // The first open seeds the bundled definitions. SQL fault guards make any
      // later INSERT (including INSERT OR IGNORE) deterministic rather than
      // depending on the scheduler to reproduce a competing writer lock.
      await db.customSelect('SELECT 1').get();
      final families = await db.select(db.engineeringFamilyDefinitions).get();
      final documents = await db.select(db.normativeDocuments).get();
      expect(families, isNotEmpty);
      expect(documents, isNotEmpty);
      for (final table in [
        'engineering_family_definitions',
        'normative_documents',
      ]) {
        await db.customStatement(
          "CREATE TRIGGER reject_reopen_$table BEFORE INSERT ON $table BEGIN SELECT RAISE(ABORT, 'REOPEN_CATALOG_WRITE'); END",
        );
      }
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      expect(await db.select(db.engineeringFamilyDefinitions).get(), families);
      expect(await db.select(db.normativeDocuments).get(), documents);
    },
  );
}
