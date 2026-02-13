import 'dart:convert';
import 'package:http/http.dart' as http;

/// HTTP implementation for managing habit scheduling rules.
///
/// This repository talks to the Flask backend in `backend/routes/rules.py`.
///
/// IMPORTANT BACKEND CONTRACT:
/// - GET    /<user_id>/rules
///   Returns: { "result": [ { "day": int, "hour": int, "minute": int, "active": bool, ... } ] }
/// - POST   /<user_id>/rules/add?habit=&day=&hour=&minute=&active=
/// - POST   /<user_id>/rules/update?habit=
/// - POST   /<user_id>/rules/delete?habit=
///
/// NOTE: Habo's notification system uses rules internally, but the app does not
/// currently expose rule management through the UI. Rules are typically managed
/// locally via SQLite. This HTTP repository is provided for backend integration
/// if you want to sync rules in the future.
class HttpRuleRepository {
  final int userId;

  /// NOTE: This should point at the same host/port your Flask app uses
  /// (see `backend/app.py`).
  static const String _baseUrl = 'http://192.168.2.19:5000';

  HttpRuleRepository(this.userId);

  Uri _uri(String path, [Map<String, String>? params]) {
    return Uri.parse('$_baseUrl/$userId/rules$path')
        .replace(queryParameters: params);
  }

  /// Get all rules for the user.
  ///
  /// Returns a list of rule objects from the backend.
  /// The backend returns: { "result": [ {...}, {...} ] }
  Future<List<Map<String, dynamic>>> getAllRules() async {
    final response = await http.get(_uri(''));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch rules from backend: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> rawRules = decoded['result'] as List<dynamic>? ?? [];

    return rawRules
        .map((rule) => rule as Map<String, dynamic>)
        .toList();
  }

  /// Add a new rule for a habit.
  ///
  /// [habitName] The name of the habit this rule applies to.
  /// [day] Day of the week (0-6, where 0 = Monday or Sunday depending on convention).
  /// [hour] Hour of the day in 24-hour format (0-23).
  /// [minute] Minute of the hour (0-59).
  /// [active] Whether this rule is enabled.
  ///
  /// Returns the response message from the backend.
  Future<String> addRule({
    required String habitName,
    required int day,
    required int hour,
    required int minute,
    required bool active,
  }) async {
    final response = await http.post(
      _uri('/add', {
        'habit': habitName,
        'day': day.toString(),
        'hour': hour.toString(),
        'minute': minute.toString(),
        'active': active.toString(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to add rule in backend: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    return decoded['result'] as String? ?? 'Rule added successfully';
  }

  /// Update rules for a habit.
  ///
  /// [habitName] The name of the habit whose rules should be updated.
  ///
  /// NOTE: The backend's current implementation calls `user.update_rule(habit_name)`
  /// which appears to trigger some rule recalculation. The exact behavior depends
  /// on your backend implementation.
  ///
  /// Returns the response message from the backend.
  Future<String> updateRule(String habitName) async {
    final response = await http.post(
      _uri('/update', {'habit': habitName}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update rule in backend: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    return decoded['result'] as String? ?? 'Rule updated successfully';
  }

  /// Delete all rules associated with a habit.
  ///
  /// [habitName] The name of the habit whose rules should be deleted.
  ///
  /// Returns the response message from the backend.
  Future<String> deleteRule(String habitName) async {
    final response = await http.post(
      _uri('/delete', {'habit': habitName}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete rule in backend: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    return decoded['result'] as String? ?? 'Rule deleted successfully';
  }

  /// Get rules for a specific habit by name.
  ///
  /// [habitName] The name of the habit.
  ///
  /// Returns a filtered list of rules that match the habit name.
  Future<List<Map<String, dynamic>>> getRulesForHabit(String habitName) async {
    final allRules = await getAllRules();
    return allRules
        .where((rule) => rule['habit'] == habitName)
        .toList();
  }
}
