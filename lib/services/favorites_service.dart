import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class FavoritesService {
  static const String _favoritesCacheKey = 'favorite_fish_cache';
  static final FavoritesService _instance = FavoritesService._internal();

  factory FavoritesService() {
    return _instance;
  }

  FavoritesService._internal();

  final StreamController<Set<String>> _favoritesController = StreamController<Set<String>>.broadcast();
  Stream<Set<String>> get favoritesStream => _favoritesController.stream;

  Set<String> _favoriteFish = {};

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritesCacheKey);
    if (favorites != null) {
      _favoriteFish = favorites.toSet();
    }
    _favoritesController.add(_favoriteFish);
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesCacheKey, _favoriteFish.toList());
  }

  void toggleFavorite(String commonName) {
    if (_favoriteFish.contains(commonName)) {
      _favoriteFish.remove(commonName);
    } else {
      _favoriteFish.add(commonName);
    }
    _saveFavorites();
    _favoritesController.add(_favoriteFish);
  }

  bool isFavorite(String commonName) {
    return _favoriteFish.contains(commonName);
  }
  
  Set<String> getFavorites() {
    return _favoriteFish;
  }

  void dispose() {
    _favoritesController.close();
  }
}
