import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medivault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Cached prescriptions table
    await db.execute('''
      CREATE TABLE cached_prescriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prescription_id TEXT UNIQUE,
        user_id TEXT NOT NULL,
        image_cid TEXT NOT NULL,
        image_url TEXT,
        file_name TEXT,
        mime_type TEXT,
        extracted_data TEXT,
        is_encrypted INTEGER DEFAULT 0,
        created_at TEXT,
        cached_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Cached vaults table
    await db.execute('''
      CREATE TABLE cached_vaults (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vault_id TEXT UNIQUE,
        owner_id TEXT NOT NULL,
        vault_name TEXT NOT NULL,
        description TEXT,
        created_at TEXT,
        cached_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Cached vault members table
    await db.execute('''
      CREATE TABLE cached_vault_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id TEXT UNIQUE,
        vault_id TEXT NOT NULL,
        member_email TEXT NOT NULL,
        role TEXT,
        created_at TEXT,
        cached_at TEXT NOT NULL,
        FOREIGN KEY (vault_id) REFERENCES cached_vaults (vault_id)
      )
    ''');

    // Medication reminders table
    await db.execute('''
      CREATE TABLE medication_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        medicine_name TEXT NOT NULL,
        hour INTEGER NOT NULL,
        minute INTEGER NOT NULL,
        duration_days INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        meal_timing TEXT DEFAULT 'any time',
        created_at TEXT NOT NULL
      )
    ''');

    // Adherence log table
    await db.execute('''
      CREATE TABLE adherence_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reminder_id INTEGER NOT NULL,
        medicine_name TEXT NOT NULL,
        action TEXT NOT NULL,
        action_date TEXT NOT NULL,
        action_time TEXT NOT NULL,
        FOREIGN KEY (reminder_id) REFERENCES medication_reminders(id)
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS medication_reminders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          medicine_name TEXT NOT NULL,
          hour INTEGER NOT NULL,
          minute INTEGER NOT NULL,
          duration_days INTEGER NOT NULL,
          start_date TEXT NOT NULL,
          is_active INTEGER DEFAULT 1,
          meal_timing TEXT DEFAULT 'any time',
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add meal_timing column for users upgrading from v2
      try {
        await db.execute(
          "ALTER TABLE medication_reminders ADD COLUMN meal_timing TEXT DEFAULT 'any time'",
        );
      } catch (_) {
        // Column may already exist if the table was freshly created in v2 upgrade.
      }
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS adherence_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reminder_id INTEGER NOT NULL,
          medicine_name TEXT NOT NULL,
          action TEXT NOT NULL,
          action_date TEXT NOT NULL,
          action_time TEXT NOT NULL,
          FOREIGN KEY (reminder_id) REFERENCES medication_reminders(id)
        )
      ''');
    }
  }

  // Prescription CRUD operations
  Future<int> cachePrescription(Map<String, dynamic> prescription) async {
    final db = await database;
    prescription['cached_at'] = DateTime.now().toIso8601String();
    prescription['sync_status'] = 'synced';

    return await db.insert(
      'cached_prescriptions',
      prescription,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedPrescriptions(
    String userId,
  ) async {
    final db = await database;
    return await db.query(
      'cached_prescriptions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getCachedPrescription(
    String prescriptionId,
  ) async {
    final db = await database;
    final results = await db.query(
      'cached_prescriptions',
      where: 'prescription_id = ?',
      whereArgs: [prescriptionId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> searchPrescriptions(
    String userId,
    String query,
  ) async {
    final db = await database;
    return await db.query(
      'cached_prescriptions',
      where: 'user_id = ? AND (file_name LIKE ? OR extracted_data LIKE ?)',
      whereArgs: [userId, '%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> filterPrescriptionsByDate(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    return await db.query(
      'cached_prescriptions',
      where: 'user_id = ? AND created_at BETWEEN ? AND ?',
      whereArgs: [
        userId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> deleteCachedPrescription(String prescriptionId) async {
    final db = await database;
    return await db.delete(
      'cached_prescriptions',
      where: 'prescription_id = ?',
      whereArgs: [prescriptionId],
    );
  }

  // Vault CRUD operations
  Future<int> cacheVault(Map<String, dynamic> vault) async {
    final db = await database;
    vault['cached_at'] = DateTime.now().toIso8601String();
    vault['sync_status'] = 'synced';

    return await db.insert(
      'cached_vaults',
      vault,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedVaults(String userId) async {
    final db = await database;
    return await db.query(
      'cached_vaults',
      where: 'owner_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  // Clear all cache
  Future<void> clearCache() async {
    final db = await database;
    await db.delete('cached_prescriptions');
    await db.delete('cached_vaults');
    await db.delete('cached_vault_members');
    await db.delete('medication_reminders');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // ── Medication Reminder CRUD ──────────────────────────────────────

  /// Inserts a single medication reminder row.
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    reminder['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('medication_reminders', reminder);
  }

  /// Inserts multiple reminders in a batch (one per medicine+time combination).
  Future<void> insertReminders(List<Map<String, dynamic>> reminders) async {
    final db = await database;
    final batch = db.batch();
    for (final r in reminders) {
      r['created_at'] = DateTime.now().toIso8601String();
      batch.insert('medication_reminders', r);
    }
    await batch.commit(noResult: true);
  }

  /// Returns all active reminders for a given user, ordered by hour/minute.
  Future<List<Map<String, dynamic>>> getActiveReminders(String userId) async {
    final db = await database;
    return await db.query(
      'medication_reminders',
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
      orderBy: 'hour ASC, minute ASC',
    );
  }

  /// Returns all reminders (active + inactive) for a given user.
  Future<List<Map<String, dynamic>>> getAllReminders(String userId) async {
    final db = await database;
    return await db.query(
      'medication_reminders',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'hour ASC, minute ASC',
    );
  }

  /// Deletes a reminder by its row id.
  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete(
      'medication_reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Updates editable fields of a reminder.
  Future<int> updateReminder(
    int id, {
    required String medicineName,
    required int hour,
    required int minute,
    required int durationDays,
    required String mealTiming,
  }) async {
    final db = await database;
    return await db.update(
      'medication_reminders',
      {
        'medicine_name': medicineName,
        'hour': hour,
        'minute': minute,
        'duration_days': durationDays,
        'meal_timing': mealTiming,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Sets is_active = 0 for reminders whose start_date + duration has passed.
  Future<int> deactivateExpiredReminders(String userId) async {
    final db = await database;
    final now = DateTime.now();
    // Fetch active reminders and check expiry in Dart (SQLite date math is limited).
    final actives = await getActiveReminders(userId);
    int deactivated = 0;
    for (final r in actives) {
      final start = DateTime.tryParse(r['start_date'] as String);
      final duration = r['duration_days'] as int;
      if (start != null && now.isAfter(start.add(Duration(days: duration)))) {
        await db.update(
          'medication_reminders',
          {'is_active': 0},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
        deactivated++;
      }
    }
    return deactivated;
  }

  // ── Adherence Tracking ─────────────────────────────────────────────

  /// Log a Taken or Not Now action for a reminder.
  Future<int> logAdherenceAction({
    required int reminderId,
    required String medicineName,
    required String action,
  }) async {
    final db = await database;
    final now = DateTime.now();
    return await db.insert('adherence_log', {
      'reminder_id': reminderId,
      'medicine_name': medicineName,
      'action': action,
      'action_date': now.toIso8601String().substring(0, 10),
      'action_time': now.toIso8601String(),
    });
  }

  /// Get adherence stats for a specific reminder.
  /// Returns {taken: N, not_now: N, total_days: N}.
  Future<Map<String, int>> getAdherenceStats(int reminderId) async {
    final db = await database;
    final taken = await db.rawQuery(
      'SELECT COUNT(DISTINCT action_date) as c FROM adherence_log WHERE reminder_id = ? AND action = ?',
      [reminderId, 'taken'],
    );
    final notNow = await db.rawQuery(
      'SELECT COUNT(DISTINCT action_date) as c FROM adherence_log WHERE reminder_id = ? AND action = ?',
      [reminderId, 'not_now'],
    );
    final totalDays = await db.rawQuery(
      'SELECT COUNT(DISTINCT action_date) as c FROM adherence_log WHERE reminder_id = ?',
      [reminderId],
    );
    return {
      'taken': (taken.first['c'] as int?) ?? 0,
      'not_now': (notNow.first['c'] as int?) ?? 0,
      'total_days': (totalDays.first['c'] as int?) ?? 0,
    };
  }

  /// Get all adherence logs for a specific reminder, newest first.
  Future<List<Map<String, dynamic>>> getAdherenceLogs(int reminderId) async {
    final db = await database;
    return await db.query(
      'adherence_log',
      where: 'reminder_id = ?',
      whereArgs: [reminderId],
      orderBy: 'action_time DESC',
    );
  }

  /// Get all adherence logs for all reminders of a user, newest first.
  Future<List<Map<String, dynamic>>> getAllAdherenceLogs(String userId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT al.* FROM adherence_log al
      INNER JOIN medication_reminders mr ON al.reminder_id = mr.id
      WHERE mr.user_id = ?
      ORDER BY al.action_time DESC
    ''',
      [userId],
    );
  }
}
