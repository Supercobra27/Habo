import 'package:habo/model/habo_model.dart';
import 'habit_repository.dart';
import 'event_repository.dart';
import 'backup_repository.dart';
import 'category_repository.dart';
import 'sqlite_habit_repository.dart';
import 'sqlite_event_repository.dart';
import 'sqlite_backup_repository.dart';
import 'sqlite_category_repository.dart';
import 'http_habit_repository.dart';

/// Factory for creating repository instances.
/// Provides centralized repository creation and dependency injection.
class RepositoryFactory {
  final HaboModel _haboModel;

  /// Toggle to switch between local SQLite and HTTP backend.
  ///
  /// - When `false` (default), the app behaves like stock Habo and uses only
  ///   the on‑device SQLite database.
  /// - When `true`, habits are loaded/saved via your Flask backend using
  ///   `HttpHabitRepository`. Events, categories and backup still use SQLite
  ///   until corresponding HTTP repositories and backend routes are implemented.
  ///
  /// To start using your backend, flip this to `true` and ensure the Flask app
  /// is running with the host/port configured in `HttpHabitRepository`.
  static const bool useRemoteBackend = false;

  /// Default user id used for backend calls.
  ///
  /// TODO: If you later add authentication / multi‑user support in the mobile
  /// app, thread the concrete user id through to this factory instead of using
  /// a constant.
  static const int defaultUserId = 1;

  late final HabitRepository _habitRepository;
  late final EventRepository _eventRepository;
  late final BackupRepository _backupRepository;
  late final CategoryRepository _categoryRepository;

  RepositoryFactory(this._haboModel) {
    if (useRemoteBackend) {
      // Habits via HTTP + backend, everything else still local.
      _habitRepository = HttpHabitRepository(defaultUserId);
      _eventRepository = SQLiteEventRepository(_haboModel);
      _backupRepository = SQLiteBackupRepository(_haboModel);
      _categoryRepository = SQLiteCategoryRepository(_haboModel);
    } else {
      // Pure SQLite (original Habo behaviour).
      _habitRepository = SQLiteHabitRepository(_haboModel);
      _eventRepository = SQLiteEventRepository(_haboModel);
      _backupRepository = SQLiteBackupRepository(_haboModel);
      _categoryRepository = SQLiteCategoryRepository(_haboModel);
    }
  }

  /// Gets the habit repository instance.
  HabitRepository get habitRepository => _habitRepository;

  /// Gets the event repository instance.
  EventRepository get eventRepository => _eventRepository;

  /// Gets the backup repository instance.
  BackupRepository get backupRepository => _backupRepository;

  /// Gets the category repository instance.
  CategoryRepository get categoryRepository => _categoryRepository;

  /// Disposes all repository instances.
  void dispose() {
    // Repositories don't need explicit disposal as they delegate to HaboModel
  }
}
