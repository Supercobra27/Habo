import 'dart:convert';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:habo/constants.dart';
import 'package:habo/habits/habit.dart';
import 'package:habo/model/habit_data.dart';
import 'package:habo/repositories/habit_repository.dart';
import 'package:http/http.dart' as http;

/// HTTP implementation of [HabitRepository] that talks to the Flask backend
/// in `backend/routes/habits.py`.
///
/// IMPORTANT BACKEND CONTRACT (for you to implement/keep in sync):
/// - GET    /<user_id>/habits
///   Returns: { "habits": [ { "habit_name": str, "habit_id": int|str,
///                            "is_device": bool, "streak": int, ... } ] }
/// - POST   /<user_id>/habits/add?name=&device=
/// - POST   /<user_id>/habits/update?name=&field=&value=
/// - POST   /<user_id>/habits/delete?name=
///
/// See comments in the Python backend files for what should be extended
/// to better match Habo's full `HabitData` model.
class HttpHabitRepository implements HabitRepository {
  final int userId;

  /// NOTE: This should point at the same host/port your Flask app uses
  /// (see `backend/app.py`).
  static const String _baseUrl = 'http://192.168.2.19:5000';

  HttpHabitRepository(this.userId);

  Uri _uri(String path, [Map<String, String>? params]) {
    return Uri.parse('$_baseUrl/$userId/habits$path')
        .replace(queryParameters: params);
  }

  @override
  Future<List<Habit>> getAllHabits() async {
    final response = await http.get(_uri(''));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch habits from backend: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> rawHabits = decoded['habits'] as List<dynamic>? ?? [];

    // Map backend Habit dataclass → Habo Habit/HabitData.
    return rawHabits
        .map((raw) => _fromBackendJson(raw as Map<String, dynamic>))
        .toList();
  }

  /// Create a new habit.
  ///
  /// Current backend only accepts `name` and `device` and does not return an id.
  /// We therefore:
  /// 1. POST /add
  /// 2. Re-fetch all habits and try to match on title to discover the id.
  ///
  /// TODO(backend): Have /add return the created habit (including id) so this
  /// round‑trip is not necessary.
  @override
  Future<int> createHabit(Habit habit) async {
    final response = await http.post(
      _uri('/add', {
        'name': habit.habitData.title,
        // Backend interprets `device` → is_device; we invert archived here.
        'device': (!habit.habitData.archived).toString(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create habit in backend: '
        '${response.statusCode} ${response.body}',
      );
    }

    // Best-effort: find the newly created habit by name.
    final all = await getAllHabits();
    try {
      final created =
          all.firstWhere((h) => h.habitData.title == habit.habitData.title);
      return created.habitData.id ?? 0;
    } catch (_) {
      // Fallback when we cannot uniquely identify the habit.
      return 0;
    }
  }

  /// Update a habit.
  ///
  /// Current backend only supports generic "field/value" updates and the
  /// example route only toggles `is_device`. For now we only sync archive
  /// state; the rest of the fields remain local to the app.
  ///
  /// TODO(backend + frontend):
  /// - Add a proper JSON body endpoint (e.g. PUT /<user_id>/habits/<id>)
  ///   that accepts the full HabitData payload from Habo.
  @override
  Future<void> updateHabit(Habit habit) async {
    final response = await http.post(
      _uri('/update', {
        'name': habit.habitData.title,
        'field': 'is_device',
        'value': (!habit.habitData.archived).toString(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update habit in backend: '
        '${response.statusCode} ${response.body}',
      );
    }
  }

  /// Delete by numeric id by first resolving the corresponding name and then
  /// calling the existing delete‑by‑name route.
  ///
  /// TODO(backend): Provide a delete‑by‑id route so we do not need the lookup
  /// round‑trip.
  @override
  Future<void> deleteHabit(int id) async {
    final habit = await findHabitById(id);
    if (habit == null) {
      // Nothing to delete on the backend.
      return;
    }
    await deleteHabitByName(habit.habitData.title);
  }

  Future<void> deleteHabitByName(String name) async {
    final response = await http.post(
      _uri('/delete', {'name': name}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete habit in backend: '
        '${response.statusCode} ${response.body}',
      );
    }
  }

  @override
  Future<Habit?> findHabitById(int id) async {
    final habits = await getAllHabits();
    try {
      return habits.firstWhere((h) => h.habitData.id == id);
    } catch (_) {
      return null;
    }
  }

  /// The backend currently has no concept of "order", so we only adjust order
  /// locally for now.
  ///
  /// TODO(backend): add a field to persist display order and an endpoint to
  /// update it in bulk.
  @override
  Future<void> updateHabitsOrder(List<Habit> habits) async {
    // No-op on backend; order is handled in-memory/UI only for now.
  }

  /// Clear all habits by repeatedly calling delete on each one.
  ///
  /// NOTE: This can be slow on high habit counts; a dedicated backend endpoint
  /// would be preferable.
  @override
  Future<void> deleteAllHabits() async {
    final habits = await getAllHabits();
    for (final habit in habits) {
      if (habit.habitData.id != null) {
        await deleteHabit(habit.habitData.id!);
      }
    }
  }

  /// Insert a batch of habits, one‑by‑one.
  ///
  /// TODO(backend): Support a bulk insert endpoint if backup/restore should
  /// go through HTTP instead of local SQLite.
  @override
  Future<void> insertHabits(List<Habit> habits) async {
    for (final habit in habits) {
      await createHabit(habit);
    }
  }

  /// Helper: map backend Habit dataclass JSON → Habo Habit/HabitData.
  ///
  /// Backend example object (from `objects/habit.py`):
  /// {
  ///   "habit_name": "Push‑ups",
  ///   "assoc_dev_id": ...,
  ///   "assoc_mqtt_topic": "...",
  ///   "habit_id": 1,
  ///   "is_device": true,
  ///   "streak": 5,
  ///   ...
  /// }
  Habit _fromBackendJson(Map<String, dynamic> json) {
    final rawId = json['habit_id'];
    int? id;
    if (rawId is int) {
      id = rawId;
    } else if (rawId is String) {
      id = int.tryParse(rawId);
    }

    final isDevice = json['is_device'] as bool? ?? true;

    return Habit(
      habitData: HabitData(
        id: id,
        // Backend does not currently provide position; we default to 0.
        position: 0,
        title: json['habit_name'] as String? ?? 'Unnamed habit',
        // Two‑day rule, cues, routines, etc. are not modeled on the backend
        // yet so we default them here.
        twoDayRule: false,
        cue: '',
        routine: '',
        reward: '',
        showReward: false,
        advanced: false,
        notification: false,
        notTime: const TimeOfDay(hour: 8, minute: 0),
        events: SplayTreeMap<DateTime, List>(),
        sanction: '',
        showSanction: false,
        accountant: '',
        habitType: HabitType.boolean,
        targetValue: 100.0,
        partialValue: 10.0,
        unit: '',
        categories: const [],
        // In this mapping we treat "device" habits as active (not archived).
        archived: !isDevice,
      ),
    );
  }
}
