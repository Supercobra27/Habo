import 'dart:convert';
import 'package:http/http.dart' as http;

/// HTTP implementation for managing habit log entries.
///
/// This repository talks to the Flask backend in `backend/routes/logs.py`.
///
/// IMPORTANT BACKEND CONTRACT:
/// - GET    /<user_id>/logs?name=<habit_name>
///   Returns: { "result": [ { "id": int, "habit_name": str, "state": str, "reported": bool, ... } ] }
/// - POST   /<user_id>/logs/add?name=&state=&reported=
/// - POST   /<user_id>/logs/update?id=&field=&value=
/// - POST   /<user_id>/logs/delete?id=
///
/// NOTE: Habo uses a different concept called "Events" (see `EventRepository`)
/// for calendar-based habit tracking. This `HttpLogRepository` is for your
/// backend's simpler log model (state strings, self_reported flags) which is
/// designed for IoT/device logging use cases.
///
/// If you want Habo to use your backend for events, you should implement the
/// Events API (see `HABO_API_SPECIFICATION.md`) instead of using this log repository.
class HttpLogRepository {
  final int userId;

  /// NOTE: This should point at the same host/port your Flask app uses
  /// (see `backend/app.py`).
  static const String _baseUrl = 'http://192.168.2.19:5000';

  HttpLogRepository(this.userId);

  Uri _uri(String path, [Map<String, String>? params]) {
    return Uri.parse('$_baseUrl/$userId/logs$path')
        .replace(queryParameters: params);
  }

  /// Get all logs for a specific habit.
  ///
  /// [habitName] The name of the habit. If null, returns all logs for the user.
  ///
  /// Returns a list of log entries. Each log entry is a map with fields like:
  /// - `id`: Log entry ID
  /// - `habit_name`: Name of the habit
  /// - `state`: State string (e.g., "NaV", "completed", etc.)
  /// - `reported`: Whether the log was self-reported
  /// - Additional fields depending on your backend schema
  Future<List<Map<String, dynamic>>> getLogs({String? habitName}) async {
    final Map<String, String>? params =
        habitName != null ? {'name': habitName} : null;

    final response = await http.get(_uri('', params));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch logs from backend: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> rawLogs = decoded['result'] as List<dynamic>? ?? [];

    return rawLogs
        .map((log) => log as Map<String, dynamic>)
        .toList();
  }

  /// Add a new log entry for a habit.
  ///
  /// [habitName] The name of the habit.
  /// [state] The state string (e.g., "NaV", "completed", "failed", etc.).
  /// [selfReported] Whether this log entry was self-reported by the user.
  ///
  /// Returns the response message from the backend.
  Future<String> addLog({
    required String habitName,
    required String state,
    required bool selfReported,
  }) async {
    final response = await http.post(
      _uri('/add', {
        'name': habitName,
        'state': state,
        'reported': selfReported.toString(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to add log in backend: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    return decoded['result'] as String? ?? 'Log added successfully';
  }

  /// Update a log entry.
  ///
  /// [logId] The ID of the log entry to update.
  /// [field] The field name to update (e.g., "state", "reported").
  /// [value] The new value for the field (as a string).
  ///
  /// NOTE: The backend does not validate field/value types, so ensure the value
  /// matches the expected type for the field.
  ///
  /// Returns the response message from the backend.
  Future<String> updateLog({
    required int logId,
    required String field,
    required String value,
  }) async {
    final response = await http.post(
      _uri('/update', {
        'id': logId.toString(),
        'field': field,
        'value': value,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update log in backend: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    return decoded['result'] as String? ?? 'Log updated successfully';
  }

  /// Delete a log entry.
  ///
  /// [logId] The ID of the log entry to delete.
  ///
  /// Returns the response message from the backend.
  Future<String> deleteLog(int logId) async {
    final response = await http.post(
      _uri('/delete', {'id': logId.toString()}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete log in backend: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    return decoded['result'] as String? ?? 'Log deleted successfully';
  }

  /// Get a specific log entry by ID.
  ///
  /// [logId] The ID of the log entry.
  ///
  /// Returns the log entry if found, null otherwise.
  ///
  /// NOTE: The backend doesn't have a direct "get by ID" endpoint, so this
  /// method fetches all logs and filters. Consider adding a dedicated endpoint
  /// if you need efficient lookups by ID.
  Future<Map<String, dynamic>?> getLogById(int logId) async {
    final allLogs = await getLogs();
    try {
      return allLogs.firstWhere((log) => log['id'] == logId);
    } catch (_) {
      return null;
    }
  }

  /// Get all logs for the user (across all habits).
  ///
  /// Returns a list of all log entries.
  Future<List<Map<String, dynamic>>> getAllLogs() async {
    return await getLogs();
  }
}
