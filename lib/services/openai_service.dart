import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class OpenAIService {

  static Future<Map<String, String>> generateOxygenAndFiltrationNeeds(String commonName, String scientificName) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return {'error': 'API key not found. Check your .env file.'};
    }

    final prompt = """
You are an aquarium expert. Focus ONLY on the aquarium care of the following fish.

Common Name: $commonName
Scientific Name: $scientificName

Return a JSON object with the following keys and short, user-friendly values:

{
  "oxygen_needs": "e.g. High - requires air pump or surface agitation",
  "filtration_needs": "e.g. Moderate - sponge or hang-on-back filter recommended"
}

Only return the JSON. Do not include explanations or any text outside the JSON object.
""";

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {
            'role': 'system',
            'content': 'You are an aquarium expert. Only provide aquarium-specific care advice. Never mention wild habitats. Only return the JSON response as instructed.'
          },
          {
            'role': 'user',
            'content': prompt
          }
        ],
        'temperature': 0.7,
        'max_tokens': 300,
      }),
    );

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        final jsonStart = content.indexOf('{');
        final jsonEnd = content.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final jsonString = content.substring(jsonStart, jsonEnd + 1);
          final parsed = jsonDecode(jsonString);

          return {
            'oxygen_needs': parsed['oxygen_needs'] ?? 'N/A',
            'filtration_needs': parsed['filtration_needs'] ?? 'N/A',
          };
        }
        return {'error': 'No JSON found in response.'};
      } catch (e) {
        return {'error': 'Failed to parse JSON: $e'};
      }
    } else {
      return {'error': 'Error:  [${response.statusCode}]\n${response.body}'};
    }
  }

  // Cache-aware wrapper: returns cached AI explanations if available, else calls OpenAI
  static Future<List<String>> getOrExplainIncompatibilityReasons(
    String fish1,
    String fish2,
    List<String> baseReasons,
  ) async {
    try {
      // Build a deterministic cache key without external hash deps
      final reasonsJoined = baseReasons.join('||');
      final keyPayload = jsonEncode({
        'f1': fish1.trim().toLowerCase(),
        'f2': fish2.trim().toLowerCase(),
        'reasons': reasonsJoined,
      });
      final keyBase64 = base64Url.encode(utf8.encode(keyPayload));
      final cacheKey = 'ai_explanations_v1:$keyBase64';

      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      // Call OpenAI to generate explanations
      final explanations = await explainIncompatibilityReasons(fish1, fish2, baseReasons);

      // Cache only if the response looks valid (non-error and non-empty)
      if (explanations.isNotEmpty && !explanations[0].startsWith('Error:') && !explanations[0].contains('API key not found')) {
        await prefs.setStringList(cacheKey, explanations);
      }

      return explanations;
    } catch (e) {
      // On any caching error, just fall back to base reasons to avoid user impact
      return baseReasons;
    }
  }

  static Future<List<String>> explainIncompatibilityReasons(
      String fish1, String fish2, List<String> reasons) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return ['API key not found. Check your .env file.'];
    }

    final prompt =
        "For each of the following reasons, provide a detailed, user-friendly explanation for why it makes these two fish incompatible for an aquarium. Keep each explanation concise, between 2 to 3 sentences long.\n"
        "Fish 1: $fish1\n"
        "Fish 2: $fish2\n"
        "Reasons to explain:\n- ${reasons.join('\n- ')}\n\n"
        "Respond ONLY with a JSON object with a single key 'explanations' which holds an array of strings. Each string in the array must be the detailed explanation for the corresponding reason in the order provided.";

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo-1106',
        'response_format': { 'type': 'json_object' },
        'messages': [
          {'role': 'system', 'content': 'You are a helpful assistant designed to output a JSON array of explanations.'},
          {'role': 'user', 'content': prompt}
        ]
      }),
    );

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        final content = jsonDecode(data['choices'][0]['message']['content']);
        final explanations = List<String>.from(content['explanations']);
        return explanations.where((e) => e.isNotEmpty).toList();
      } catch (e) {
        print('Error parsing OpenAI JSON response: $e');
        return ['Failed to parse detailed explanation from AI.'];
      }
    } else {
      return ['Error: ${response.statusCode}\n${response.body}'];
    }
  }

  static Future<String> generateFishDescription(String commonName, String scientificName) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return 'API key not found. Check your .env file.';
    }

    final prompt = "Provide a concise, user-friendly care and description summary for the following fish:\n"
        "Common Name: $commonName\n"
        "Scientific Name: $scientificName\n"
        "Focus on aquarium care, temperament, and interesting facts. Limit to 4-6 sentences.";

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'user', 'content': prompt}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return content.trim();
    } else {
      return 'Error: ${response.statusCode}\n${response.body}';
    }
  }

  static Future<Map<String, dynamic>> analyzeUnidentifiedFish(File imageFile) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return {'error': 'API key not found. Check your .env file.'};
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final prompt = "Identify the fish in this image. "
        "Return a JSON object with keys: common_name, scientific_name, water_type, confidence_level, "
        "care_notes, distinctive_features, temperature_range, pH_range, social_behavior, tank_size.";

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4-vision-preview',
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                }
              }
            ]
          }
        ],
        'max_tokens': 500,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      try {
        // Try to extract JSON from the response
        final jsonStart = content.indexOf('{');
        final jsonEnd = content.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final jsonString = content.substring(jsonStart, jsonEnd + 1);
          return jsonDecode(jsonString);
        }
        return {'error': 'No JSON found in response.'};
      } catch (e) {
        return {'error': 'Failed to parse AI response: $e'};
      }
    } else {
      return {'error': 'Error: ${response.statusCode}\n${response.body}'};
    }
  }

  static Future<Map<String, dynamic>> generateCareRecommendations(String commonName, String scientificName) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return {'error': 'API key not found. Check your .env file.'};
    }

    final prompt = """
You are an aquarium expert and enthusiast. Focus ONLY on aquarium care and feeding for the following fish (ignore wild/natural habitat behaviors):

Common Name: $commonName
Scientific Name: $scientificName

Return a structured JSON object with short, user-friendly values for each key, based on best aquarium practices. Do NOT explain or add extra text outside JSON. Here are the required keys:
{
  "diet_type": "e.g. Omnivore, Carnivore, Herbivore",
  "preferred_foods": ["e.g. Bloodworms", "Algae wafers", "Pellets"],
  "feeding_frequency": "e.g. 2 times per day",
  "portion_size": "e.g. 2-4 small pellets, a small pinch of flakes, or 1-2 algae wafers (give a quantity, not a time)",
  "fasting_schedule": "e.g. Skip feeding on Wednesday and Sunday, or 1 to 2 non-consecutive days per week (give days or number of days, not a time)",
  "oxygen_needs": "e.g. High - requires air pump",
  "filtration_needs": "e.g. Moderate - sponge filter recommended",
  "overfeeding_risks": "e.g. Can cause bloating and water fouling",
  "behavioral_notes": "e.g. May compete with others during feeding",
  "tankmate_feeding_conflict": "e.g. Avoid slow eaters in same tank"
}

For 'portion_size', always give a quantity (like number of pellets, wafers, or a pinch), not a time. For 'fasting_schedule', always give specific days or number of non-consecutive days per week. Do NOT include feeding style. Only return the JSON object. Do NOT mention wild/natural habitat or behaviors. All advice must be for aquarium environments only.
""";

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {'role': 'system', 'content': 'You are an aquarium expert and enthusiast. Only provide advice for aquarium care and feeding. Never mention wild or natural habitat. For portion size, always give a quantity (e.g. number of pellets, wafers, or a pinch), not a time. For fasting schedule, always give specific days or number of non-consecutive days per week. Do NOT include feeding style.'},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
        'max_tokens': 500
      }),
    );

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        final jsonStart = content.indexOf('{');
        final jsonEnd = content.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final jsonString = content.substring(jsonStart, jsonEnd + 1);
          return jsonDecode(jsonString);
        }
        return {'error': 'No JSON found in response.'};
      } catch (e) {
        return {'error': 'Failed to parse JSON: $e'};
      }
    } else {
      return {'error': 'Error: ${response.statusCode}\n${response.body}'};
    }
  }

  /// Generate comprehensive diet recommendations for multiple fish species
  static Future<Map<String, dynamic>> generateDietRecommendations(Map<String, int> fishSelections) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return await getFallbackDietRecommendations(fishSelections.keys.toList());
    }

    final fishList = fishSelections.keys.toList();
    final prompt = '''
You are an aquarium care expert. Generate CONCISE diet recommendations for an aquarium containing these fish: ${fishList.join(', ')}.

REQUIREMENTS:
- Provide group-based portion calculations (not per individual fish)
- Consider fish age (adult/baby) - adults need smaller portions
- Use simple measurements: "tiny pinch", "small pinch", "5-8 pellets"
- If different fish eat same food, total their portions together
- If different fish eat different foods, list separately

Provide the response in this format:

FOOD TYPES:
- [Food type] (for: [fish names that eat this])

FEEDING SCHEDULE:
- Frequency: [X] times per day
- Best times: [morning/evening or specific times]

FEEDING NOTES:
- [One concise note about feeding this group]

Example: 5 guppies + 3 mollies = "tiny pinch of flakes" (for guppies) + "small pinch of flakes" (for mollies) = "small pinch of flakes" (total)

Be concise and group-focused. Avoid overwhelming details.
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {'role': 'system', 'content': 'You are an aquarium care expert. Provide specific, practical diet recommendations for mixed fish tanks.'},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
        'max_tokens': 800,
      }),
    );

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return await _parseDietResponse(content, fishList);
      } catch (e) {
        print('Error parsing diet response: $e');
        return await getFallbackDietRecommendations(fishList);
      }
    } else {
      return await getFallbackDietRecommendations(fishList);
    }
  }

  /// Generate specific portion recommendations for individual fish species
  static Future<Map<String, dynamic>> generatePortionRecommendation(String fishName, int quantity, List<String> availableFoodTypes) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return await _getFallbackPortionRecommendation(fishName, quantity, availableFoodTypes);
    }

    final prompt = '''
Generate CONCISE portion recommendations for $quantity $fishName fish.

Available food types: ${availableFoodTypes.join(', ')}

REQUIREMENTS:
- Consider fish age (adult/baby) - adults need smaller portions
- For groups: calculate total portion for the group, not per individual
- Use simple measurements: "tiny pinch", "small pinch", "5-8 pellets", etc.
- Choose from available food types only

Provide ONLY:
1. PORTION SIZE: [Group total like "tiny pinch of flakes" or "5-8 micro pellets"]
2. FOOD TYPE: [Choose from: ${availableFoodTypes.join(', ')}]

Example: 5 guppies = "tiny pinch of flakes" or "5-8 micro pellets"
Example: 3 adult mollies = "small pinch of flakes" or "3-4 pellets"

Be concise and group-focused. No explanations needed.
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {'role': 'system', 'content': 'You are an aquarium expert. Provide specific portion recommendations for individual fish species.'},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
        'max_tokens': 400,
      }),
    );

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return await _parsePortionResponse(content, fishName, quantity, availableFoodTypes);
      } catch (e) {
        print('Error parsing portion response: $e');
        return await _getFallbackPortionRecommendation(fishName, quantity, availableFoodTypes);
      }
    } else {
      return await _getFallbackPortionRecommendation(fishName, quantity, availableFoodTypes);
    }
  }

  /// Generate feeding notes for multiple fish species
  static Future<String> generateFeedingNotes(List<String> fishNames) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return _getFallbackFeedingNotes();
    }

    final prompt = """
Generate CONCISE feeding notes for an aquarium with these fish: ${fishNames.join(', ')}.

REQUIREMENTS:
- Output exactly 2 lines maximum
- Each line must be a short, plain sentence
- Focus on group feeding behavior
- Do not include species names or headings
- Content:
  1) Simple feeding frequency (e.g., "Feed 2 times daily")
  2) One care tip for this fish group

IMPORTANT: Keep it simple and group-focused. Avoid overwhelming details.
""";

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {'role': 'system', 'content': 'You are an aquarium expert. Provide specific feeding notes for mixed fish tanks.'},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
        'max_tokens': 300,
      }),
    );

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content.trim();
      } catch (e) {
        print('Error parsing feeding notes: $e');
        return _getFallbackFeedingNotes();
      }
    } else {
      return _getFallbackFeedingNotes();
    }
  }

  /// Parse diet response from AI
  static Future<Map<String, dynamic>> _parseDietResponse(String response, List<String> fishList) async {
    try {
      final lines = response.split('\n');
      final foodTypes = <String>[];
      final feedingSchedule = <String, dynamic>{};
      final feedingNotes = <String>[];
      
      bool inFoodTypes = false;
      bool inSchedule = false;
      bool inNotes = false;
      
      for (final line in lines) {
        final trimmed = line.trim().toLowerCase();
        
        if (trimmed.contains('food types') || trimmed.contains('foods')) {
          inFoodTypes = true;
          inSchedule = false;
          inNotes = false;
          continue;
        }
        
        if (trimmed.contains('feeding schedule') || trimmed.contains('schedule')) {
          inFoodTypes = false;
          inSchedule = true;
          inNotes = false;
          continue;
        }
        
        if (trimmed.contains('feeding notes') || trimmed.contains('tips')) {
          inFoodTypes = false;
          inSchedule = false;
          inNotes = true;
          continue;
        }
        
        if (inFoodTypes && line.trim().isNotEmpty) {
          final food = line.trim().replaceAll(RegExp(r'^[-•*]\s*'), '');
          if (food.isNotEmpty && !food.contains(':')) {
            foodTypes.add(food);
          }
        }
        
        if (inSchedule && line.trim().isNotEmpty) {
          if (line.contains('times per day') || line.contains('frequency')) {
            final freqMatch = RegExp(r'(\d+)').firstMatch(line);
            if (freqMatch != null) {
              feedingSchedule['frequency'] = int.tryParse(freqMatch.group(1)!) ?? 2;
            }
          }
          if (line.contains('AM') || line.contains('PM') || line.contains('morning') || line.contains('evening')) {
            feedingSchedule['times'] = line.trim().replaceAll(RegExp(r'^[-•*]\s*'), '');
          }
        }
        
        if (inNotes && line.trim().isNotEmpty) {
          final note = line.trim().replaceAll(RegExp(r'^[-•*]\s*'), '');
          if (note.isNotEmpty && !note.contains(':')) {
            feedingNotes.add(note);
          }
        }
      }
      
      return {
        'food_types': foodTypes.isNotEmpty ? foodTypes : ['flakes', 'pellets', 'algae wafers'],
        'feeding_schedule': {
          'frequency': feedingSchedule['frequency'] ?? 2,
          'times': feedingSchedule['times'] ?? 'Morning and evening',
        },
        'feeding_notes': feedingNotes.isNotEmpty ? feedingNotes.join('\n') : 'Feed 2-3 times daily in small amounts. Remove uneaten food after 5 minutes.',
      };
    } catch (e) {
      print('Error parsing diet response: $e');
      return await getFallbackDietRecommendations(fishList);
    }
  }

  /// Parse portion response from AI
  static Future<Map<String, dynamic>> _parsePortionResponse(String response, String fishName, int quantity, List<String> availableFoodTypes) async {
    try {
      final lines = response.split('\n');
      String portionSize = '2-3 small pellets';
      String foodType = availableFoodTypes.isNotEmpty ? availableFoodTypes.first : 'pellets';
      
      for (final line in lines) {
        final trimmed = line.trim().toLowerCase();
        
        if (trimmed.contains('portion size') || trimmed.contains('portion')) {
          final portionMatch = RegExp(r'([^:]+)$').firstMatch(line);
          if (portionMatch != null) {
            portionSize = portionMatch.group(1)!.trim();
          }
        }
        
        if (trimmed.contains('food type') || trimmed.contains('food')) {
          for (final availableType in availableFoodTypes) {
            if (line.toLowerCase().contains(availableType.toLowerCase())) {
              foodType = availableType;
              break;
            }
          }
        }
      }
      
      return {
        'portion_size': portionSize,
        'food_type': foodType,
        'reasoning': 'AI-generated recommendation for $quantity $fishName fish',
      };
    } catch (e) {
      print('Error parsing portion response: $e');
      return await _getFallbackPortionRecommendation(fishName, quantity, availableFoodTypes);
    }
  }

  /// Fallback diet recommendations when AI fails
  static Future<Map<String, dynamic>> getFallbackDietRecommendations(List<String> fishList) async {
    final foodTypes = <String>['flakes', 'pellets', 'algae wafers'];
    
    return {
      'food_types': foodTypes,
      'feeding_schedule': {
        'frequency': 2,
        'times': 'Morning and evening'
      },
      'feeding_notes': 'Feed 2 times daily.\nRemove uneaten food after 5 minutes.',
    };
  }

  /// Fallback portion recommendation when AI fails
  static Future<Map<String, dynamic>> _getFallbackPortionRecommendation(String fishName, int quantity, List<String> availableFoodTypes) async {
    String foodType = availableFoodTypes.isNotEmpty ? availableFoodTypes.first : 'pellets';
    String portionSize;
    
    // Group-based portion calculation
    if (quantity <= 3) {
      portionSize = 'tiny pinch of $foodType';
    } else if (quantity <= 6) {
      portionSize = 'small pinch of $foodType';
    } else if (quantity <= 10) {
      portionSize = 'medium pinch of $foodType';
    } else {
      portionSize = 'large pinch of $foodType';
    }
    
    return {
      'portion_size': portionSize,
      'food_type': foodType,
      'reasoning': 'Group portion for $quantity $fishName fish',
    };
  }

  /// Fallback feeding notes when AI fails
  static String _getFallbackFeedingNotes() {
    return 'Feed 2 times daily.\nRemove uneaten food after 5 minutes.';
  }

  /// Check if API key is configured
  static bool get isConfigured {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    return apiKey.isNotEmpty;
  }

  /// Get API usage info
  static String get apiInfo => 'OpenAI API - GPT-4 model for advanced AI features';

  /// Get chat response from OpenAI
  static Future<String> getChatResponse(String message) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return 'API key not found. Check your .env file.';
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {'role': 'user', 'content': message}
        ],
        'temperature': 0.7,
        'max_tokens': 500,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return content.trim();
    } else {
      return 'Error: ${response.statusCode}\n${response.body}';
    }
  }
}


// Diet and Care Recommendation Generator
Future<String> generateDietAndCareRecommendation(String commonName, String scientificName) async {
  final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    return 'API key not found. Check your .env file.';
  }

  final prompt = "You are an expert aquarist. For the following fish species, provide a detailed and user-friendly summary of its diet and aquarium care requirements. "
      "Make the tone friendly yet informative, and write in paragraph form (no bullet points). Keep it concise but comprehensive.\n\n"
      "Common Name: $commonName\n"
      "Scientific Name: $scientificName\n\n"
      "Include details on:\n"
      "- Diet type (e.g., herbivore, omnivore)\n"
      "- Preferred foods and food forms (e.g., flakes, pellets, frozen, live)\n"
      "- Feeding style and frequency\n"
      "- Portion size and any fasting schedule\n"
      "- Behavioral notes while feeding (e.g., shy, aggressive)\n"
      "- Potential feeding conflicts with other fish\n"
      "- Overfeeding risks or signs\n"
      "- Oxygen pump requirement (low, medium, high)\n"
      "- Filtration needs (e.g., sponge filter, strong flow)\n\n"
      "End with a brief note (1-2 sentences) about the importance of proper feeding and clean water in keeping the fish healthy.";

  final response = await http.post(
    Uri.parse('https://api.openai.com/v1/chat/completions'),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'user', 'content': prompt}
      ]
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    return content.trim();
  } else {
    return 'Error: ${response.statusCode}\n${response.body}';
  }
}
