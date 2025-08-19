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
      return {'error': 'Error: [${response.statusCode}]\n${response.body}'};
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
  final String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<String> getChatResponse(String message) async {
    if (_apiKey.isEmpty) {
      return 'API key not found. Check your .env file.';
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'user', 'content': message}
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
