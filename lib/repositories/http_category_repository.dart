import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:habo/model/category.dart';
import 'category_repository.dart';

/// HTTP implementation of the CategoryRepository interface.
/// This class handles category operations via HTTP API.
class HttpCategoryRepository implements CategoryRepository {
  final int userId;
  static const String _baseUrl = 'http://10.0.2.2:5000'; // Default Android emulator localhost

  HttpCategoryRepository(this.userId);

  Uri _uri(String path, [Map<String, String>? params]) {
    return Uri.parse('$_baseUrl/$userId/categories$path')
        .replace(queryParameters: params);
  }

  @override
  Future<List<Category>> getAllCategories() async {
    final response = await http.get(_uri(''));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch categories: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['categories'] as List)
        .map((c) => Category.fromJson(c))
        .toList();
  }

  @override
  Future<int> createCategory(Category category) async {
    final response = await http.post(
      _uri('/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(category.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create category: ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    return responseData['id'];
  }

  @override
  Future<void> updateCategory(Category category) async {
    final response = await http.post(
      _uri('/update/${category.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(category.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update category: ${response.body}');
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    final response = await http.post(_uri('/delete/$id'));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete category: ${response.body}');
    }
  }

  @override
  Future<Category?> findCategoryById(int id) async {
    final response = await http.get(_uri('/$id'));

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to find category: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return Category.fromJson(data['category']);
  }

  @override
  Future<List<Category>> getCategoriesForHabit(int habitId) async {
    final response = await http.get(_uri('/habit/$habitId'));

    if (response.statusCode != 200) {
      throw Exception('Failed to get categories for habit: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['categories'] as List)
        .map((c) => Category.fromJson(c))
        .toList();
  }

  @override
  Future<void> updateHabitCategories(int habitId, List<Category> categories) async {
    final categoryIds = categories.map((c) => c.id).toList();
    
    final response = await http.post(
      _uri('/habit/$habitId/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'categoryIds': categoryIds}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update habit categories: ${response.body}');
    }
  }

  @override
  Future<void> addHabitToCategory(int habitId, int categoryId) async {
    final response = await http.post(
      _uri('/habit/$habitId/add/$categoryId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add habit to category: ${response.body}');
    }
  }

  @override
  Future<void> removeHabitFromCategory(int habitId, int categoryId) async {
    final response = await http.post(
      _uri('/habit/$habitId/remove/$categoryId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove habit from category: ${response.body}');
    }
  }
}