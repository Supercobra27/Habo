import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'event_repository.dart';

/// HTTP implementation of the EventRepository interface.
/// This class handles habit event operations via HTTP API.
class HttpEventRepository implements EventRepository {
  final int userId;
  static const String _baseUrl = 'http://10.0.2.2:5000'; // Default Android emulator localhost

  HttpEventRepository(this.userId);

  Uri _uri(String path, [Map<String, String>? params]) {
    return Uri.parse('$_baseUrl/$userId/events$path')
        .replace(queryParameters: params);
  }

  @override
  Future<void> insertEvent(int habitId, DateTime date, List event) async {
    final response = await http.post(
      _uri('/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'habitId': habitId,
        'date': date.toIso8601String(),
        'eventData': event,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to insert event: ${response.body}');
    }
  }

  @override
  Future<void> deleteEvent(int habitId, DateTime date) async {
    final response = await http.post(
      _uri('/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'habitId': habitId,
        'date': date.toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete event: ${response.body}');
    }
  }

  @override
  Future<List<List>> getEventsForHabit(int habitId) async {
    final response = await http.get(
      _uri('/habit/$habitId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get events for habit: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['events'] as List).cast<List>();
  }

  @override
  Future<SplayTreeMap<DateTime, List>> getEventsMapForHabit(int habitId) async {
    final response = await http.get(
      _uri('/habit/$habitId/map'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get events map: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final map = SplayTreeMap<DateTime, List>();
    
    (data['events'] as Map<String, dynamic>).forEach((key, value) {
      map[DateTime.parse(key)] = List.from(value);
    });
    
    return map;
  }

  @override
  Future<void> deleteAllEventsForHabit(int habitId) async {
    final response = await http.post(
      _uri('/habit/$habitId/clear'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete all events for habit: ${response.body}');
    }
  }

  @override
  Future<void> insertEventsForHabit(int habitId, Map<DateTime, List> events) async {
    // Convert the Map to a format suitable for JSON
    final Map<String, dynamic> jsonEvents = {};
    events.forEach((dateTime, event) {
      jsonEvents[dateTime.toIso8601String()] = event;
    });

    final response = await http.post(
      _uri('/habit/$habitId/batch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'habitId': habitId,
        'events': jsonEvents,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to insert events batch: ${response.body}');
    }
  }

  @override
  Future<void> deleteAllEvents() async {
    final response = await http.post(_uri('/clear-all'));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete all events: ${response.body}');
    }
  }
}