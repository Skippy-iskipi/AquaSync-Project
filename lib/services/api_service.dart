import 'dart:convert';
import '../config/api_config.dart';

class ApiService {
  Future<List<String>> getFishSpecies() async {
    try {
      final response = await ApiConfig.makeRequestWithFailover(
        endpoint: '/fish-species',
        method: 'GET',
      );
      
      if (response != null) {
        List<dynamic> data = json.decode(response.body);
        return data.map((item) => item.toString()).toList();
      } else {
        throw Exception('Failed to load fish species: No available servers');
      }
    } catch (e) {
      throw Exception('Error fetching fish species: $e');
    }
  }

  Future<String> getFishImage(String fishName) async {
    try {
      // Extract just the endpoint part from the URL
      String normalizedName = fishName.trim().replaceAll(' ', '_');
      String encodedName = Uri.encodeComponent(normalizedName.replaceAll(' ', ''));
      
      final response = await ApiConfig.makeRequestWithFailover(
        endpoint: '/fish-image/$encodedName',
        method: 'GET',
      );
      
      if (response != null) {
        return response.body;
      } else {
        throw Exception('Failed to load fish image: No available servers');
      }
    } catch (e) {
      throw Exception('Error fetching fish image: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFishList() async {
    try {
      final response = await ApiConfig.makeRequestWithFailover(
        endpoint: '/fish-list',
        method: 'GET',
      );
      
      if (response != null) {
        List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to load fish list: No available servers');
      }
    } catch (e) {
      throw Exception('Error fetching fish list: $e');
    }
  }

  Future<Map<String, dynamic>> checkGroupCompatibility(List<String> fishNames) async {
    try {
      final response = await ApiConfig.makeRequestWithFailover(
        endpoint: '/check-group',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({'fish_names': fishNames}),
      );
      
      if (response != null) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to check compatibility: No available servers');
      }
    } catch (e) {
      throw Exception('Error checking compatibility: $e');
    }
  }

  Future<Map<String, dynamic>> calculateWaterRequirements(Map<String, int> fishSelections) async {
    try {
      final response = await ApiConfig.makeRequestWithFailover(
        endpoint: '/calculate-water-requirements',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({'fish_selections': fishSelections}),
      );
      
      if (response != null) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to calculate water requirements: No available servers');
      }
    } catch (e) {
      throw Exception('Error calculating water requirements: $e');
    }
  }

  Future<Map<String, dynamic>> calculateFishCapacity(double tankVolume, Map<String, int> fishSelections) async {
    try {
      final response = await ApiConfig.makeRequestWithFailover(
        endpoint: '/calculate-fish-capacity',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: json.encode({
          'tank_volume': tankVolume,
          'fish_selections': fishSelections,
        }),
      );
      
      if (response != null) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to calculate fish capacity: No available servers');
      }
    } catch (e) {
      throw Exception('Error calculating fish capacity: $e');
    }
  }

  Future<bool> checkServerConnection() async {
    return ApiConfig.checkServerConnection();
  }
} 