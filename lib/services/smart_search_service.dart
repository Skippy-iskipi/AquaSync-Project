import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class SmartSearchService {

  static Future<List<Map<String, dynamic>>> searchFish({
    required String query,
    int limit = 100,
    double minSimilarity = 0.3,
  }) async {
    try {
      print('DEBUG FAST API: Starting search for "$query"');
      
      // Use fast Python BM25 API
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/search/fish?q=${Uri.encodeComponent(query)}&limit=$limit&min_score=$minSimilarity'),
        headers: {'Content-Type': 'application/json'},
      );

      print('DEBUG FAST API: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        print('DEBUG FAST API: Found ${results.length} results');
        
        return results.cast<Map<String, dynamic>>();
      } else {
        print('DEBUG FAST API: Error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  static Future<List<String>> getAutocompleteSuggestions({
    required String query,
    int limit = 8,
  }) async {
    try {
      print('DEBUG FAST API: Getting autocomplete for "$query"');
      
      // Use fast Python BM25 API
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/search/autocomplete?q=${Uri.encodeComponent(query)}&limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      print('DEBUG FAST API: Autocomplete response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final suggestions = data['suggestions'] as List<dynamic>;
        print('DEBUG FAST API: Found ${suggestions.length} suggestions');
        
        return suggestions.cast<String>();
      } else {
        print('DEBUG FAST API: Autocomplete error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Autocomplete error: $e');
      return [];
    }
  }


  // Advanced search with filters
  static Future<List<Map<String, dynamic>>> searchFishWithFilters({
    required String query,
    String? waterType,
    String? temperament,
    String? careLevel,
    double? minTankSize,
    double? maxSize,
    int limit = 100,
    double minSimilarity = 0.3,
  }) async {
    try {
      final results = await searchFish(
        query: query,
        limit: limit * 2, // Get more results to filter
        minSimilarity: minSimilarity,
      );

      // Apply filters
      final filteredResults = results.where((fish) {
        if (waterType != null && 
            fish['water_type']?.toString().toLowerCase() != waterType.toLowerCase()) {
          return false;
        }
        
        if (temperament != null && 
            fish['temperament']?.toString().toLowerCase() != temperament.toLowerCase()) {
          return false;
        }
        
        if (careLevel != null && 
            fish['care_level']?.toString().toLowerCase() != careLevel.toLowerCase()) {
          return false;
        }
        
        if (minTankSize != null) {
          final tankSize = _parseNumericValue(fish['minimum_tank_size_(l)']);
          if (tankSize == null || tankSize < minTankSize) return false;
        }
        
        if (maxSize != null) {
          final size = _parseNumericValue(fish['max_size_(cm)']);
          if (size == null || size > maxSize) return false;
        }
        
        return true;
      }).toList();

      return filteredResults.take(limit).toList();
    } catch (e) {
      print('Filtered search error: $e');
      return [];
    }
  }

  static double? _parseNumericValue(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(str);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }
}
