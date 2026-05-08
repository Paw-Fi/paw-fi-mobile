import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/moneko_database.dart';

final localDatabaseProvider = FutureProvider<MonekoDatabase>((ref) async {
  final database = await MonekoDatabase.openDefault();
  ref.onDispose(() {
    database.close();
  });
  return database;
});
