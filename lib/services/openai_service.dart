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
        "Explain in detail why the following fish are incompatible in an aquarium:\n"
        "Fish 1: $fish1\nFish 2: $fish2\n"
        "Reasons: ${reasons.join('; ')}\n"
        "Provide a clear, user-friendly explanation for each reason.";

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
      // Split explanations by newlines or semicolons for a list
      return content.split(RegExp(r'[\n;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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
