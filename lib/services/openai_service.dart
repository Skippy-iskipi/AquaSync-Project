import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'food_calculation_service.dart';

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

    // Fetch portion_grams from fish_species table
    double? portionGrams;
    try {
      final response = await Supabase.instance.client
          .from('fish_species')
          .select('portion_grams')
          .or('common_name.ilike.%$commonName%,scientific_name.ilike.%$scientificName%')
          .limit(1)
          .single();
      
      portionGrams = response['portion_grams']?.toDouble();
    } catch (e) {
      print('Error fetching portion_grams for $commonName: $e');
    }

    // Format portion size from database or use fallback
    String portionSizeText;
    if (portionGrams != null && portionGrams > 0) {
      if (portionGrams >= 1.0) {
        portionSizeText = "${portionGrams.toStringAsFixed(1)}g per feeding";
      } else {
        portionSizeText = "${(portionGrams * 1000).toStringAsFixed(0)}mg per feeding";
      }
    } else {
      portionSizeText = "Use database portion_grams value";
    }

    final prompt = """
You are an aquarium expert and enthusiast. Focus ONLY on aquarium care and feeding for the following fish:

Common Name: $commonName
Scientific Name: $scientificName
Portion Size: $portionSizeText

Return a structured JSON object with these exact values:
{
  "diet_type": "e.g. Omnivore, Carnivore, Herbivore",
  "preferred_foods": ["Specific food types for this fish species"],
  "feeding_frequency": "e.g. 2 times per day",
  "portion_size": "$portionSizeText",
  "fasting_schedule": "e.g. Skip feeding on Wednesday and Sunday",
  "oxygen_needs": "e.g. High - requires air pump",
  "filtration_needs": "e.g. Moderate - sponge filter recommended",
  "overfeeding_risks": "e.g. Can cause bloating and water fouling",
  "behavioral_notes": "e.g. May compete with others during feeding",
  "tankmate_feeding_conflict": "e.g. Avoid slow eaters in same tank"
}

CRITICAL: Use the exact portion_size provided above. Do NOT generate or modify the portion amount.
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
          {'role': 'system', 'content': 'You are an aquarium expert. Use the EXACT portion_size provided in the prompt from the database. Do NOT generate or modify portion amounts. Focus on other care aspects like diet type, preferred foods, and feeding schedule.'},
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
      return await getFallbackDietRecommendations(fishSelections.keys.toList(), fishSelections);
    }

    final fishList = fishSelections.entries.map((e) => '${e.value} ${e.key}').join(', ');
    final prompt = '''
    You are an expert aquarist specializing in fish nutrition. For an aquarium containing: $fishList, create a detailed and practical feeding plan.

    Return a single, clean JSON object with the following structure:
    - "feeding_schedule": An object with "frequency" (e.g., "2 times per day") and "times" (e.g., "Morning and Evening").
    - "portion_per_feeding": A single, well-formatted string detailing what to feed for EACH feeding session. Group foods by fish species if they have different needs. Use newlines (\n) to separate different food items.
    - "feeding_notes": A concise string with 1-2 essential care tips for this specific group of fish.

    Example for 5 guppies and 3 mollies:
    {
      "feeding_schedule": {
        "frequency": "2 times per day",
        "times": "Morning and Evening"
      },
      "portion_per_feeding": "For Guppies & Mollies: A small pinch of high-quality flakes.\nFor Mollies: 1/4 of an algae wafer in the evening.",
      "feeding_notes": "Mollies appreciate vegetable matter. Ensure flakes are crushed small enough for Guppies. Remove uneaten food after 5 minutes."
    }

    RULES:
    - Be VERY specific with amounts and units (e.g., "1 small pinch of tropical flakes", "3-4 pellets", "1/4 algae wafer", "2-3 pieces of bloodworms", "1 small scoop of brine shrimp").
    - Always include specific units: pellets, pinches, pieces, scoops, wafers, teaspoons, etc.
    - Never use vague terms like "appropriate amount" or "small amount" without units.
    - The "portion_per_feeding" string should be ready for display, using \n for line breaks.
    - Provide only the JSON object, with no additional text or explanations.
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
          {'role': 'system', 'content': 'You are an aquarium care expert. Provide specific, practical diet recommendations for mixed fish tanks in JSON format.'},
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
        return await _parseDietResponse(content, fishSelections.keys.toList());
      } catch (e) {
        print('Error parsing diet response: $e');
        return await getFallbackDietRecommendations(fishSelections.keys.toList(), fishSelections);
      }
    } else {
      return await getFallbackDietRecommendations(fishSelections.keys.toList(), fishSelections);
    }
  }

  /// Generate specific portion recommendations with proper units and per-fish calculations
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
- Use specific measurements with units: "1 tiny pinch", "1 small pinch", "5-8 pellets", "2-3 pieces", "1/4 teaspoon", etc.
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

  static Future<Map<String, dynamic>> _parseDietResponse(String response, List<String> fishList) async {
    try {
      // Clean up the response to ensure it's valid JSON
      final cleanedResponse = response.trim().replaceAll('```json', '').replaceAll('```', '');
      final jsonResponse = jsonDecode(cleanedResponse);

      final schedule = jsonResponse['feeding_schedule'];
      final portionDetails = jsonResponse['portion_per_feeding'] as String? ?? 'A small pinch of flakes or a few pellets.';
      final notes = jsonResponse['feeding_notes'] as String? ?? 'Remove uneaten food after 5 minutes.';

      // Basic food type extraction from portion details for consumption calculation
      final foodTypes = <String>{};
      if (portionDetails.toLowerCase().contains('flake')) foodTypes.add('flakes');
      if (portionDetails.toLowerCase().contains('pellet')) foodTypes.add('pellets');
      if (portionDetails.toLowerCase().contains('algae')) foodTypes.add('algae wafers');
      if (portionDetails.toLowerCase().contains('frozen')) foodTypes.add('frozen food');
      if (foodTypes.isEmpty) foodTypes.add('flakes'); // Default

      final dailyConsumption = <String, double>{};
      for (final foodType in foodTypes) {
        double consumption = 0.3; // Default
        if (foodType.contains('flake')) {
          consumption = 0.5;
        } else if (foodType.contains('pellet')) {
          consumption = 0.3;
        } else if (foodType.contains('algae')) {
          consumption = 0.2;
        } else if (foodType.contains('frozen')) {
          consumption = 0.4;
        }
        dailyConsumption[foodType] = consumption;
      }

      // Add realistic food duration calculations
      final foodDurationData = <String, dynamic>{};
      for (final foodType in foodTypes) {
        final containerSizes = FoodCalculationService.getStandardContainerSizes(foodType);
        final durations = <Map<String, dynamic>>[];
        
        for (final container in containerSizes) {
          final duration = await FoodCalculationService.calculateFoodDuration(
            fishSelections: fishList.asMap().map((index, fish) => MapEntry(fish, 1)),
            foodType: foodType,
            containerSizeGrams: container['grams'],
          );
          durations.add({
            'container_size': container['size'],
            'duration': duration['duration_readable'],
            'duration_days': duration['duration_days'],
          });
        }
        foodDurationData[foodType] = durations;
      }

      return {
        'food_types': foodTypes.toList(),
        'feeding_schedule': {
          'frequency': schedule['frequency'] ?? '2 times per day',
          'times': schedule['times'] ?? 'Morning and evening',
        },
        'feeding_notes': notes,
        'daily_consumption': dailyConsumption,
        'portion_per_feeding': portionDetails.replaceAll('\\n', '\n'),
        'recommended_foods': foodTypes.toList(),
        'special_considerations': 'Remove uneaten food after 5 minutes to maintain water quality.',
        'food_duration_data': foodDurationData,
      };
      } catch (e) {
        print('Error parsing JSON diet response: $e');
        return await getFallbackDietRecommendations(fishList, fishList.asMap().map((index, fish) => MapEntry(fish, 1)));
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

  /// Fallback diet recommendations with validated consumption rates and proper units
  static Future<Map<String, dynamic>> getFallbackDietRecommendations(List<String> fishList, [Map<String, int>? fishSelections]) async {
    print('Using fallback diet recommendations with validated consumption rates');
    
    // Calculate total daily consumption based on validated per-fish rates (in g/day)
    final Map<String, double> dailyConsumption = {};
    double totalDailyConsumptionG = 0.0;
    
    // Use fishSelections if provided, otherwise default to 1 of each
    final Map<String, int> quantities = fishSelections ?? 
        {for (String fish in fishList) fish: 1};
    
    for (final fishName in fishList) {
      final quantity = quantities[fishName] ?? 1;
      final fishNameLower = fishName.toLowerCase();
      
      // Validated per-fish daily consumption rates (g/day) based on species data
      double perFishConsumptionG = 0.05; // Default fallback
      
      if (fishNameLower.contains('guppy')) {
        perFishConsumptionG = 0.05; // 0.04-0.06g flakes/day per fish
      } else if (fishNameLower.contains('molly')) {
        perFishConsumptionG = 0.10; // 0.08-0.12g flakes/day per fish
      } else if (fishNameLower.contains('platy')) {
        perFishConsumptionG = 0.07; // Medium livebearer
      } else if (fishNameLower.contains('betta')) {
        perFishConsumptionG = 0.06; // Medium-sized fish
      } else if (fishNameLower.contains('tetra')) {
        perFishConsumptionG = 0.02; // Very small schooling fish
      }
      
      // Calculate total consumption for this species
      final totalForSpeciesG = perFishConsumptionG * quantity;
      totalDailyConsumptionG += totalForSpeciesG;
      
      print('$fishName ($quantity fish): ${perFishConsumptionG}g/fish/day × $quantity = ${totalForSpeciesG.toStringAsFixed(3)}g/day');
      
      // Distribute across food types based on species needs
      if (fishNameLower.contains('molly')) {
        // Mollies need more vegetable matter (60% flakes, 40% algae)
        dailyConsumption['flakes'] = (dailyConsumption['flakes'] ?? 0) + (totalForSpeciesG * 0.6);
        dailyConsumption['algae wafers'] = (dailyConsumption['algae wafers'] ?? 0) + (totalForSpeciesG * 0.4);
      } else if (fishNameLower.contains('betta')) {
        // Bettas prefer pellets
        dailyConsumption['betta pellets'] = (dailyConsumption['betta pellets'] ?? 0) + totalForSpeciesG;
      } else {
        // Most fish primarily eat flakes
        dailyConsumption['flakes'] = (dailyConsumption['flakes'] ?? 0) + totalForSpeciesG;
      }
    }
    
    print('Total daily consumption: ${totalDailyConsumptionG.toStringAsFixed(3)}g/day');
    print('Daily consumption breakdown: $dailyConsumption');
    
    // Generate portion descriptions with proper units
    String portionDescription = '';
    for (final fishName in fishList) {
      final quantity = quantities[fishName] ?? 1;
      final fishNameLower = fishName.toLowerCase();
      
      if (portionDescription.isNotEmpty) portionDescription += '\n';
      
      if (fishNameLower.contains('guppy')) {
        portionDescription += 'For $quantity Guppy(s): 1 small pinch of tropical flakes per feeding (~${(0.025 * quantity).toStringAsFixed(2)}g)';
      } else if (fishNameLower.contains('molly')) {
        portionDescription += 'For $quantity Molly(s): 1-2 pinches of tropical flakes (~${(0.03 * quantity).toStringAsFixed(2)}g) + 1/4 algae wafer in evening (~${(0.02 * quantity).toStringAsFixed(2)}g)';
      } else if (fishNameLower.contains('platy')) {
        portionDescription += 'For $quantity Platy(s): 1-2 pinches of tropical flakes per feeding (~${(0.035 * quantity).toStringAsFixed(2)}g)';
      } else if (fishNameLower.contains('betta')) {
        portionDescription += 'For $quantity Betta(s): 3-4 betta pellets per feeding (~${(0.03 * quantity).toStringAsFixed(2)}g)';
      } else if (fishNameLower.contains('tetra')) {
        portionDescription += 'For $quantity Tetra(s): 1 small pinch of micro flakes per feeding (~${(0.01 * quantity).toStringAsFixed(2)}g)';
      } else {
        portionDescription += 'For $quantity $fishName(s): 1 small pinch of appropriate food per feeding (~${(0.025 * quantity).toStringAsFixed(2)}g)';
      }
    }
    
    // Add realistic food duration calculations for fallback
    final foodDurationData = <String, dynamic>{};
    if (fishSelections != null) {
      for (final foodType in dailyConsumption.keys) {
        final containerSizes = FoodCalculationService.getStandardContainerSizes(foodType);
        final durations = <Map<String, dynamic>>[];
        
        for (final container in containerSizes) {
          final duration = await FoodCalculationService.calculateFoodDuration(
            fishSelections: fishSelections,
            foodType: foodType,
            containerSizeGrams: container['grams'],
          );
          durations.add({
            'container_size': container['size'],
            'duration': duration['duration_readable'],
            'duration_days': duration['duration_days'],
          });
        }
        foodDurationData[foodType] = durations;
      }
    }

    return {
      'food_types': dailyConsumption.keys.toList(),
      'feeding_schedule': {
        'frequency': '2 times per day',
        'times': 'Morning (8-9 AM) and Evening (6-7 PM)'
      },
      'feeding_notes': 'Feed only what fish can consume in 2-3 minutes. Remove uneaten food promptly. Daily amounts are split across 2 feedings. Weights are approximate - adjust based on fish behavior and water quality.',
      'daily_consumption': dailyConsumption,
      'total_daily_consumption_g': totalDailyConsumptionG,
      'portion_per_feeding': portionDescription,
      'recommended_foods': dailyConsumption.keys.toList(),
      'special_considerations': 'Remove uneaten food after 2-3 minutes to maintain water quality. Monitor fish behavior and adjust portions accordingly.',
      'food_duration_data': foodDurationData,
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
