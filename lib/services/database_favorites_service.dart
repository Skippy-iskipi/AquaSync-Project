import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class DatabaseFavoritesService {
  static final DatabaseFavoritesService _instance = DatabaseFavoritesService._internal();
  factory DatabaseFavoritesService() => _instance;
  DatabaseFavoritesService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final StreamController<Set<String>> _favoritesController = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get favoritesStream => _favoritesController.stream;

  Set<String> _favoriteFish = {};

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Load favorites from database
  Future<void> loadFavorites() async {
    if (!isAuthenticated) {
      _favoriteFish = {};
      _favoritesController.add(_favoriteFish);
      return;
    }

    try {
      final response = await _supabase
          .from('user_favorites')
          .select('fish_common_name')
          .eq('user_id', currentUser!.id);

      _favoriteFish = response.map<String>((item) => item['fish_common_name'] as String).toSet();
      _favoritesController.add(_favoriteFish);
    } catch (error) {
      print('Error loading favorites: $error');
      _favoriteFish = {};
      _favoritesController.add(_favoriteFish);
    }
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String commonName) async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to manage favorites');
    }

    try {
      if (_favoriteFish.contains(commonName)) {
        // Remove from favorites
        await _supabase
            .from('user_favorites')
            .delete()
            .eq('user_id', currentUser!.id)
            .eq('fish_common_name', commonName);
        
        _favoriteFish.remove(commonName);
      } else {
        // Add to favorites
        await _supabase
            .from('user_favorites')
            .insert({
              'user_id': currentUser!.id,
              'fish_common_name': commonName,
              'created_at': DateTime.now().toIso8601String(),
            });
        
        _favoriteFish.add(commonName);
      }
      
      _favoritesController.add(_favoriteFish);
    } catch (error) {
      print('Error toggling favorite: $error');
      rethrow;
    }
  }

  // Check if fish is favorite
  bool isFavorite(String commonName) {
    return _favoriteFish.contains(commonName);
  }

  // Get all favorites
  Set<String> getFavorites() {
    return _favoriteFish;
  }

  // Clear all favorites
  Future<void> clearAllFavorites() async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to manage favorites');
    }

    try {
      await _supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', currentUser!.id);
      
      _favoriteFish.clear();
      _favoritesController.add(_favoriteFish);
    } catch (error) {
      print('Error clearing favorites: $error');
      rethrow;
    }
  }

  // Dispose resources
  void dispose() {
    _favoritesController.close();
  }
}
