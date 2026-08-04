import 'package:sqflite/sqflite.dart';

import '../models/user_profile.dart';
import 'app_database.dart';

/// ============================================================================
/// 用户资料本地缓存访问对象
/// 断网时也能显示昵称、店铺名
/// ============================================================================
class ProfileDao {
  const ProfileDao();

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<UserProfile?> findById(String id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.tableProfiles,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserProfile.fromDb(rows.first);
  }

  Future<void> upsert(UserProfile profile) async {
    final Database db = await _db;
    await db.insert(
      AppDatabase.tableProfiles,
      profile.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final Database db = await _db;
    await db.delete(
      AppDatabase.tableProfiles,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
