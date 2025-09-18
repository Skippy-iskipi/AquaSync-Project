import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class FishSpeciesService {
  /// Fetch fish species data from Supabase
  static Future<List<Map<String, dynamic>>> fetchFishSpeciesData() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/fish-species/all'),
        headers: {'Accept': 'application/json'}
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> fishList = json.decode(response.body);
        return fishList.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to fetch fish species: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching fish species data: $e');
      return [];
    }
  }

  /// Get fish species data by common name
  static Future<Map<String, dynamic>?> getFishSpeciesByName(String commonName) async {
    try {
      final allFish = await fetchFishSpeciesData();
      final result = allFish.where(
        (fish) => fish['common_name']?.toString().toLowerCase() == commonName.toLowerCase(),
      ).firstOrNull;
      return result;
    } catch (e) {
      print('Error fetching fish species by name: $e');
      return null;
    }
  }

  /// Get multiple fish species data by common names
  static Future<Map<String, Map<String, dynamic>>> getFishSpeciesByNames(List<String> commonNames) async {
    try {
      final allFish = await fetchFishSpeciesData();
      final Map<String, Map<String, dynamic>> result = {};
      
      for (final name in commonNames) {
        final fish = allFish.where(
          (fish) => fish['common_name']?.toString().toLowerCase() == name.toLowerCase(),
        ).firstOrNull;
        if (fish != null) {
          result[name] = fish;
        }
      }
      
      return result;
    } catch (e) {
      print('Error fetching fish species by names: $e');
      return {};
    }
  }

  /// Parse portion grams from string or number to double
  static double parsePortionGrams(dynamic portionGramsValue) {
    if (portionGramsValue == null) return 0.0;
    
    try {
      // If it's already a number, convert it
      if (portionGramsValue is num) {
        return portionGramsValue.toDouble();
      }
      
      // If it's a string, parse it
      if (portionGramsValue is String) {
        if (portionGramsValue.isEmpty) return 0.0;
        // Remove any non-numeric characters except decimal point
        final cleaned = portionGramsValue.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.parse(cleaned);
      }
      
      return 0.0;
    } catch (e) {
      print('Error parsing portion grams: $e');
      return 0.0;
    }
  }

  /// Parse feeding frequency to get number of times per day (returns the first number found)
  static int parseFeedingFrequency(String? frequencyStr) {
    if (frequencyStr == null || frequencyStr.isEmpty) return 2; // Default to 2 times per day
    
    final lower = frequencyStr.toLowerCase();
    
    // Look for numbers in the string
    final numberMatch = RegExp(r'(\d+)').firstMatch(lower);
    if (numberMatch != null) {
      return int.tryParse(numberMatch.group(1)!) ?? 2;
    }
    
    // Look for text patterns
    if (lower.contains('once') || lower.contains('1 time')) return 1;
    if (lower.contains('twice') || lower.contains('2 times')) return 2;
    if (lower.contains('three') || lower.contains('3 times')) return 3;
    if (lower.contains('four') || lower.contains('4 times')) return 4;
    if (lower.contains('five') || lower.contains('5 times')) return 5;
    
    return 2; // Default fallback
  }

  /// Get the original feeding frequency string for display
  static String getFeedingFrequencyDisplay(String? frequencyStr) {
    if (frequencyStr == null || frequencyStr.isEmpty) return '2 times per day';
    return frequencyStr;
  }

  /// Format feeding times based on frequency
  static String formatFeedingTimes(int frequency) {
    switch (frequency) {
      case 1:
        return 'Morning (8-10 AM)';
      case 2:
        return 'Morning (8-10 AM) and evening (6-8 PM)';
      case 3:
        return 'Morning (8-10 AM), afternoon (2-4 PM), and evening (6-8 PM)';
      case 4:
        return 'Morning (8-9 AM), noon (12-1 PM), afternoon (3-4 PM), and evening (7-8 PM)';
      case 5:
        return 'Early morning (7-8 AM), late morning (10-11 AM), afternoon (2-3 PM), evening (6-7 PM), and night (9-10 PM)';
      default:
        return 'Morning, afternoon, and evening';
    }
  }

  /// Parse preferred food string into list
  static List<String> parsePreferredFood(String? preferredFoodStr) {
    if (preferredFoodStr == null || preferredFoodStr.isEmpty) {
      return ['fish food']; // Default fallback
    }
    
    // Split by common delimiters and clean up
    final foods = preferredFoodStr
        .split(RegExp(r'[,;|]'))
        .map((food) => food.trim())
        .where((food) => food.isNotEmpty)
        .toList();
    
    return foods.isNotEmpty ? foods : ['fish food'];
  }

  /// Calculate total portion for multiple fish of the same species
  static double calculateTotalPortion(double portionGrams, int quantity) {
    return portionGrams * quantity;
  }

  /// Format portion display with proper units
  static String formatPortionDisplay(double grams) {
    // Convert to mg if portion is less than 0.1g for better readability
    if (grams < 0.1) {
      final milligrams = grams * 1000; // Convert g to mg
      return '${milligrams.toStringAsFixed(milligrams % 1 == 0 ? 0 : 1)}mg';
    } else {
      // Use grams for larger portions
      return '${grams.toStringAsFixed(grams % 1 == 0 ? 0 : 1)}g';
    }
  }

  /// Generate feeding notes from database data
  static String generateFeedingNotes(Map<String, Map<String, dynamic>> fishData) {
    if (fishData.isEmpty) {
      return 'Feed 2 times daily.\nRemove uneaten food after 5 minutes.';
    }

    // Get unique feeding notes
    final notes = fishData.values
        .map((fish) => fish['feeding_notes']?.toString())
        .where((note) => note != null && note.isNotEmpty)
        .toSet()
        .toList();

    if (notes.isEmpty) {
      return 'Remove uneaten food after 5 minutes.';
    }

    // If multiple fish with different notes, show each with bullet points
    if (fishData.length > 1 && notes.length > 1) {
      final List<String> bulletNotes = [];
      fishData.forEach((name, fish) {
        final note = fish['feeding_notes']?.toString();
        if (note != null && note.isNotEmpty) {
          bulletNotes.add('$name: $note');
        }
      });
      return bulletNotes.join('\n');
    }

    // Single note or all fish have same note
    return notes.first!;
  }
}
