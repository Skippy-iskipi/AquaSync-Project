import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class OpenAIService {
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
}
