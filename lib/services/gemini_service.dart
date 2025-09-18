import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class GeminiService {
  // You can get a free API key from: https://makersuite.google.com/app/apikey
  // IMPORTANT: Replace this with your new API key if the current one is suspended
  static const String _apiKey = 'YOUR_NEW_GEMINI_API_KEY'; // Get a new key from Google AI Studio
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _model = 'gemini-pro';
  
  // Rate limiting
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 1500); // 1.5 seconds between requests

  /// Generate fish description using Gemini AI
  static Future<String> generateFishDescription(String commonName, String scientificName) async {
    try {
      final prompt = '''
Generate a brief, informative description of the $commonName fish (scientific name: $scientificName).
Focus on:
- Physical characteristics
- Natural habitat
- Interesting facts
- Why it's popular in aquariums

Keep it under 100 words and make it engaging for aquarium enthusiasts.
''';

      final response = await _makeGeminiRequest(prompt);
      return response.isNotEmpty ? response : _getFallbackDescription(commonName, scientificName);
    } catch (e) {
      print('Gemini AI error: $e');
      return _getFallbackDescription(commonName, scientificName);
    }
  }

  /// Generate care recommendations using Gemini AI
  static Future<Map<String, dynamic>> generateCareRecommendations(String commonName, String scientificName) async {
    try {
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

      final prompt = '''
Generate care recommendations for $commonName fish (scientific name: $scientificName).
Portion Size: $portionSizeText

Return structured JSON:
{
  "diet_type": "e.g. Omnivore, Carnivore, Herbivore",
  "preferred_foods": ["Specific foods for this fish species"],
  "feeding_frequency": "e.g. 2 times per day",
  "portion_size": "$portionSizeText",
  "fasting_schedule": "e.g. Skip feeding on Wednesday and Sunday",
  "oxygen_needs": "e.g. High - requires air pump",
  "filtration_needs": "e.g. Moderate - sponge filter recommended",
  "overfeeding_risks": "e.g. Can cause bloating and water fouling",
  "behavioral_notes": "e.g. May compete with others during feeding",
  "tankmate_feeding_conflict": "e.g. Avoid slow eaters in same tank"
}

CRITICAL: Use the exact portion_size provided above from the database. Do NOT generate or modify the portion amount.
''';

      final response = await _makeGeminiRequest(prompt);
      return response.isNotEmpty ? _parseCareRecommendations(response, commonName) : _getFallbackCareRecommendations(commonName);
    } catch (e) {
      print('Gemini AI error: $e');
      return _getFallbackCareRecommendations(commonName);
    }
  }

  /// Explain incompatibility reasons using Gemini AI
  static Future<List<String>> explainIncompatibilityReasons(
      String fish1, String fish2, List<String> reasons) async {
    try {
      final prompt = '''
For each of the following reasons, provide a detailed, user-friendly explanation for why it makes these two fish incompatible for an aquarium. Keep each explanation concise, between 2 to 3 sentences long.

Fish 1: $fish1
Fish 2: $fish2
Reasons to explain:
${reasons.map((r) => '- $r').join('\n')}

Provide detailed explanations for each reason in the order provided.
''';

      final response = await _makeGeminiRequest(prompt);
      if (response.isNotEmpty) {
        // Split by lines and filter out empty ones
        final explanations = response
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => line.replaceAll(RegExp(r'^[-•\d\.\s]+'), '').trim())
            .where((line) => line.isNotEmpty)
            .toList();
        
        // Ensure we have the right number of explanations
        if (explanations.length >= reasons.length) {
          return explanations.take(reasons.length).toList();
        }
      }
      
      return _generateFallbackExplanations(fish1, fish2, reasons);
    } catch (e) {
      print('Gemini AI error: $e');
      return _generateFallbackExplanations(fish1, fish2, reasons);
    }
  }

  /// Generate oxygen and filtration needs using Gemini AI
  static Future<Map<String, String>> generateOxygenAndFiltrationNeeds(String commonName, String scientificName) async {
    try {
      final prompt = '''
You are an aquarium expert. Focus ONLY on the aquarium care of the following fish.

Common Name: $commonName
Scientific Name: $scientificName

Return a JSON object with the following keys and short, user-friendly values:

{
  "oxygen_needs": "e.g. High - requires air pump or surface agitation",
  "filtration_needs": "e.g. Moderate - sponge or hang-on-back filter recommended"
}

Only return the JSON. Do not include explanations or any text outside the JSON object.
''';

      final response = await _makeGeminiRequest(prompt);
      if (response.isNotEmpty) {
        try {
          // Try to extract JSON from the response
          final jsonStart = response.indexOf('{');
          final jsonEnd = response.lastIndexOf('}');
          if (jsonStart != -1 && jsonEnd != -1) {
            final jsonString = response.substring(jsonStart, jsonEnd + 1);
            final parsed = jsonDecode(jsonString);

            return {
              'oxygen_needs': parsed['oxygen_needs'] ?? 'N/A',
              'filtration_needs': parsed['filtration_needs'] ?? 'N/A',
            };
          }
        } catch (e) {
          print('Error parsing JSON response: $e');
        }
      }
      
      return _getFallbackOxygenAndFiltration(commonName);
    } catch (e) {
      print('Gemini AI error: $e');
      return _getFallbackOxygenAndFiltration(commonName);
    }
  }

  /// Generate comprehensive diet recommendations for multiple fish species
  static Future<Map<String, dynamic>> generateDietRecommendations(Map<String, int> fishSelections) async {
    try {
      final fishList = fishSelections.keys.toList();
      
      // Get fish-specific information to make recommendations more personalized
      final fishInfo = await _getFishCharacteristics(fishList);
      
      final prompt = '''
You are an aquarium care expert. Generate SPECIFIC diet recommendations for an aquarium containing these fish: ${fishList.join(', ')}.

FISH CHARACTERISTICS:
${fishInfo.map((fish) => '- ${fish['name'] ?? 'Unknown'}: ${fish['diet_type'] ?? 'omnivore'} diet, ${fish['feeding_behavior'] ?? 'mid-water feeder'}, ${fish['size'] ?? 'medium'} size').join('\n')}

REQUIREMENTS:
- Analyze each fish's specific dietary needs and feeding behavior
- Consider compatibility between different species' feeding habits
- Provide recommendations that work for ALL fish in the tank
- Be specific about food types, feeding levels, and timing

Provide the response in this format:

FOOD TYPES:
- [Specific food type] (feeding level: surface/mid-water/bottom)
- [Specific food type] (feeding level: surface/mid-water/bottom)
- [Specific food type] (feeding level: surface/mid-water/bottom)

FEEDING SCHEDULE:
- Frequency: [X] times per day
- Best times: [specific times like "8:00 AM and 6:00 PM"]

FEEDING NOTES:
- [Specific note about feeding these particular fish]
- [Specific note about food removal and water quality]
- [Specific note about mixed species considerations]

IMPORTANT: Make recommendations SPECIFIC to these fish species. Do not give generic advice.
''';

      final response = await _makeGeminiRequest(prompt);
      
      if (response.isNotEmpty) {
        return await _parseDietResponse(response, fishList);
      }

      return await getFallbackDietRecommendations(fishList);
    } catch (e) {
      print('Error generating diet recommendations: $e');
      return await getFallbackDietRecommendations(fishSelections.keys.toList());
    }
  }

  /// Generate specific portion recommendations for individual fish species
  static Future<Map<String, dynamic>> generatePortionRecommendation(String fishName, int quantity, List<String> availableFoodTypes) async {
    try {
      // Get specific fish information
      final fishInfo = await _getFishCharacteristics([fishName]);
      final fishData = fishInfo.isNotEmpty ? fishInfo.first : null;
      
      final prompt = '''
Generate SPECIFIC portion recommendations for $quantity $fishName fish.

FISH INFORMATION:
${fishData != null ? '- Diet: ${fishData['diet_type'] ?? 'omnivore'}\n- Size: ${fishData['size'] ?? 'medium'}\n- Feeding behavior: ${fishData['feeding_behavior'] ?? 'mid-water feeder'}' : '- Standard aquarium fish'}
- Available food types: ${availableFoodTypes.join(', ')}

REQUIREMENTS:
- Consider the fish's specific dietary needs (${fishData?['diet_type'] ?? 'omnivore'})
- Account for fish size (${fishData?['size'] ?? 'medium'})
- Factor in quantity ($quantity fish)
- Choose the most appropriate food type from available options

Provide:
1. PORTION SIZE: [Specific portion like "3-4 small pellets" or "1/2 pinch of flakes"]
2. FOOD TYPE: [Choose from: ${availableFoodTypes.join(', ')}]
3. REASONING: [Explain why this specific food and portion for $fishName]

Be specific to $fishName - do not give generic advice.
''';

      final response = await _makeGeminiRequest(prompt);
      
      if (response.isNotEmpty) {
        return await _parsePortionResponse(response, fishName, quantity, availableFoodTypes);
      }
      
      return await _getFallbackPortionRecommendation(fishName, quantity, availableFoodTypes);
    } catch (e) {
      print('Error generating portion recommendation for $fishName: $e');
      return await _getFallbackPortionRecommendation(fishName, quantity, availableFoodTypes);
    }
  }

  /// Generate feeding notes for multiple fish species
  static Future<String> generateFeedingNotes(List<String> fishNames) async {
    try {
      // Get fish-specific information
      final fishInfo = await _getFishCharacteristics(fishNames);
      
      final prompt = """
Generate SPECIFIC feeding notes for an aquarium with these fish: ${fishNames.join(', ')}.

FISH CHARACTERISTICS:
${fishInfo.map((fish) => '- ${fish['name'] ?? 'Unknown'}: ${fish['diet_type'] ?? 'omnivore'} diet, ${fish['feeding_behavior'] ?? 'mid-water feeder'}').join('\n')}

REQUIREMENTS:
- Output exactly 3 lines
- Each line must be a short, plain sentence
- Make advice SPECIFIC to these fish species
- Do not include species names or headings
- Content:
  1) Feeding frequency and timing specific to these fish
  2) Food removal timing considering these species' eating habits
  3) Care note relevant to these specific fish combinations

IMPORTANT: Make advice specific to these fish - avoid generic aquarium advice.
""";

      final response = await _makeGeminiRequest(prompt);
      
      if (response.isNotEmpty) {
        return response;
      }
      
      return _getFallbackFeedingNotes();
    } catch (e) {
      print('Error generating feeding notes: $e');
      return _getFallbackFeedingNotes();
    }
  }

  /// Make request to Gemini AI API with rate limiting and retry logic
  static Future<String> _makeGeminiRequest(String prompt) async {
    // Check if API key is configured
    if (!isConfigured) {
      print('❌ Gemini API key not configured. Please set your API key in gemini_service.dart');
      return '';
    }
    
    const int maxRetries = 3;
    const Duration retryDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🤖 Gemini AI Request: Sending prompt (attempt $attempt/$maxRetries)...');
        
        // Rate limiting - ensure minimum interval between requests
        if (_lastRequestTime != null) {
          final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
          if (timeSinceLastRequest < _minRequestInterval) {
            final waitTime = _minRequestInterval - timeSinceLastRequest;
            print('🤖 Rate limiting: Waiting ${waitTime.inMilliseconds}ms before request...');
            await Future.delayed(waitTime);
          }
        }
        
        // Add delay between retry attempts
        if (attempt > 1) {
          await Future.delayed(retryDelay * attempt);
        }
        
        final response = await http.post(
          Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text': prompt,
                  },
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.7,
              'topK': 40,
              'topP': 0.95,
              'maxOutputTokens': 1024,
            },
          }),
        ).timeout(const Duration(seconds: 30));

        print('🤖 Gemini Response Status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('🤖 Parsed response data: $data');
          
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final content = data['candidates'][0]['content'];
            if (content['parts'] != null && content['parts'].isNotEmpty) {
              final generatedText = content['parts'][0]['text'] ?? '';
              print('🤖 Raw Gemini Response: $generatedText');
              
              if (generatedText.isNotEmpty) {
                // Clean up the response
                String cleanText = generatedText.trim();
                
                // Remove common AI prefixes/suffixes
                cleanText = cleanText.replaceAll(RegExp(r'^(AI:|Assistant:|Response:|Here|The|Based on|For|To|1\.|2\.|3\.|4\.|5\.)\s*', caseSensitive: false), '');
                cleanText = cleanText.replaceAll(RegExp(r'\s*(Thank you|Hope this helps|Let me know if you need more help|Let me|I hope|This should|Feel free).*$', caseSensitive: false), '');
                
                print('🤖 Cleaned Gemini Response: $cleanText');
                
                if (cleanText.isNotEmpty && cleanText.length > 15) {
                  print('🤖 Gemini Response successful, length: ${cleanText.length}');
                  _lastRequestTime = DateTime.now(); // Update last request time
                  return cleanText;
                }
              }
            }
          }
        } else if (response.statusCode == 429) {
          print('🤖 Rate limit exceeded (429). Waiting before retry...');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: 5 * attempt)); // Exponential backoff
            continue;
          }
        } else {
          print('🤖 HTTP Error: ${response.statusCode} - ${response.body}');
        }
        
        // If we get here, the request failed
        if (attempt < maxRetries) {
          print('🤖 Attempt $attempt failed, retrying...');
          continue;
        }
        
      } catch (e) {
        print('🤖 Gemini AI error on attempt $attempt: $e');
        if (attempt < maxRetries) {
          print('🤖 Retrying in ${retryDelay.inSeconds} seconds...');
          continue;
        }
      }
    }
    
    print('🤖 All attempts failed, returning empty response');
    return '';
  }

  /// Fallback description when API fails
  static String _getFallbackDescription(String commonName, String scientificName) {
    return 'The $commonName is a fascinating aquarium fish known for its unique characteristics. '
           'This species, scientifically classified as $scientificName, makes an excellent addition '
           'to community aquariums and is popular among both beginners and experienced aquarists.';
  }

  /// Fallback care recommendations when API fails
  static Map<String, dynamic> _getFallbackCareRecommendations(String commonName) {
    return {
      'diet_type': 'Omnivore',
      'preferred_foods': ['High-quality flake food', 'Pellets', 'Live or frozen foods'],
      'feeding_frequency': '2-3 times daily',
      'portion_size': 'Small amounts consumed in 2-3 minutes',
      'fasting_schedule': 'One fasting day per week',
      'overfeeding_risks': 'Can lead to water quality issues and obesity',
      'behavioral_notes': 'Generally peaceful community fish',
      'tankmate_feeding_conflict': 'Feed at different tank levels to avoid competition',
      'temperature_range': '22-28°C (72-82°F)',
      'ph_range': '6.5-7.5',
      'minimum_tank_size': '20 L (5 gallons)',
      'water_type': 'Freshwater',
      'temperament': 'Peaceful',
      'care_level': 'Easy',
    };
  }

  /// Parse care recommendations from API response
  static Map<String, dynamic> _parseCareRecommendations(String summary, String commonName) {
    // Try to extract structured information from the summary
    final recommendations = _getFallbackCareRecommendations(commonName);
    
    // Update with any specific information found in the summary
    if (summary.toLowerCase().contains('carnivore')) {
      recommendations['diet_type'] = 'Carnivore';
    } else if (summary.toLowerCase().contains('herbivore')) {
      recommendations['diet_type'] = 'Herbivore';
    }
    
    if (summary.toLowerCase().contains('aggressive')) {
      recommendations['temperament'] = 'Aggressive';
    } else if (summary.toLowerCase().contains('shy')) {
      recommendations['temperament'] = 'Shy';
    }
    
    return recommendations;
  }

  /// Generate fallback explanations when API fails
  static List<String> _generateFallbackExplanations(String fish1, String fish2, List<String> reasons) {
    return reasons.map((reason) {
      if (reason.toLowerCase().contains('size')) {
        return 'Size differences between $fish1 and $fish2 can cause stress and potential injury. Larger fish may bully smaller ones, while smaller fish may struggle to compete for food and territory.';
      } else if (reason.toLowerCase().contains('temperament')) {
        return 'Temperament conflicts between $fish1 and $fish2 can lead to aggressive behavior and stress. Aggressive fish may harm peaceful ones, disrupting the tank harmony.';
      } else if (reason.toLowerCase().contains('water')) {
        return 'Different water parameter requirements between $fish1 and $fish2 make it difficult to maintain optimal conditions for both species. This can lead to health issues and stress.';
      } else if (reason.toLowerCase().contains('diet')) {
        return 'Dietary differences between $fish1 and $fish2 can cause feeding conflicts and nutritional imbalances. Some fish may outcompete others for food, leading to malnutrition.';
      } else {
        return 'The $reason between $fish1 and $fish2 makes them incompatible tankmates. This can lead to stress, aggression, and health problems for both species.';
      }
    }).toList();
  }

  /// Fallback oxygen and filtration needs when API fails
  static Map<String, String> _getFallbackOxygenAndFiltration(String commonName) {
    return {
      'oxygen_needs': 'Moderate - standard aquarium setup should be sufficient',
      'filtration_needs': 'Standard - basic filter recommended for water quality',
    };
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
    // Get fish characteristics to provide more specific fallback
    final fishInfo = await _getFishCharacteristics(fishList);
    
    // Determine appropriate food types based on fish characteristics
    final hasSurfaceFeeders = fishInfo.any((fish) => fish['feeding_behavior']?.contains('surface') == true);
    final hasBottomFeeders = fishInfo.any((fish) => fish['feeding_behavior']?.contains('bottom') == true);
    final hasCarnivores = fishInfo.any((fish) => fish['diet_type']?.contains('carnivore') == true);
    final hasHerbivores = fishInfo.any((fish) => fish['diet_type']?.contains('herbivore') == true);
    
    final foodTypes = <Map<String, dynamic>>[];
    
    if (hasSurfaceFeeders) {
      foodTypes.add({
        'name': 'flakes',
        'feeding_level': 'surface',
        'nutritional_role': hasCarnivores ? 'protein' : 'mixed',
        'example_brands_or_forms': ['TetraMin Flakes', 'API Tropical Flakes']
      });
    }
    
    foodTypes.add({
      'name': 'sinking pellets',
      'feeding_level': 'mid-water',
      'nutritional_role': hasCarnivores ? 'protein' : 'mixed',
      'example_brands_or_forms': ['Hikari Sinking Wafers', 'Omega One Pellets']
    });
    
    if (hasBottomFeeders || hasHerbivores) {
      foodTypes.add({
        'name': 'algae wafers',
        'feeding_level': 'bottom',
        'nutritional_role': 'vegetable',
        'example_brands_or_forms': ['Hikari Algae Wafers', 'Fluval Bug Bites Algae']
      });
    }
    
    // If no specific foods added, add default
    if (foodTypes.isEmpty) {
      foodTypes.add({
        'name': 'flakes',
        'feeding_level': 'surface',
        'nutritional_role': 'mixed',
        'example_brands_or_forms': ['TetraMin Flakes', 'API Tropical Flakes']
      });
    }
    
    return {
      'food_types': foodTypes,
      'feeding_schedule': {
        'frequency_per_day': 2,
        'recommended_times': ['8:00 AM', '6:00 PM']
      },
      'feeding_notes': [
        'Feed in small amounts that fish can finish within 2–3 minutes.',
        'Remove uneaten food promptly to maintain water quality.',
        'Adjust portions depending on fish activity and appetite.',
        'Provide a mix of protein and vegetable-based foods for balance.'
      ]
    };
  }

  /// Fallback portion recommendation when AI fails
  static Future<Map<String, dynamic>> _getFallbackPortionRecommendation(String fishName, int quantity, List<String> availableFoodTypes) async {
    // Get fish characteristics for more specific fallback
    final fishInfo = await _getFishCharacteristics([fishName]);
    final fishData = fishInfo.isNotEmpty ? fishInfo.first : null;
    
    String foodType = availableFoodTypes.isNotEmpty ? availableFoodTypes.first : 'pellets';
    String portionSize = '2-3 small $foodType';
    
    // Adjust based on fish characteristics
    if (fishData != null) {
      final dietType = fishData['diet_type'] ?? 'omnivore';
      final size = fishData['size'] ?? 'medium';
      final feedingBehavior = fishData['feeding_behavior'] ?? 'mid-water feeder';
      
      // Choose appropriate food type based on feeding behavior
      if (feedingBehavior.contains('surface') && availableFoodTypes.contains('flakes')) {
        foodType = 'flakes';
      } else if (feedingBehavior.contains('bottom') && availableFoodTypes.contains('algae wafers')) {
        foodType = 'algae wafers';
      }
      
      // Adjust portion size based on fish size and quantity
      if (size == 'small') {
        portionSize = quantity == 1 ? '1-2 small $foodType' : '${quantity * 2}-${quantity * 3} small $foodType';
      } else if (size == 'large') {
        portionSize = quantity == 1 ? '3-4 $foodType' : '${quantity * 3}-${quantity * 4} $foodType';
      } else {
        portionSize = quantity == 1 ? '2-3 $foodType' : '${quantity * 2}-${quantity * 3} $foodType';
      }
    }
    
    return {
      'portion_size': portionSize,
      'food_type': foodType,
      'reasoning': 'Tailored portion for $quantity ${fishData?['name'] ?? fishName} (${fishData?['diet_type'] ?? 'omnivore'} diet, ${fishData?['size'] ?? 'medium'} size)',
    };
  }

  /// Fallback feeding notes when AI fails
  static String _getFallbackFeedingNotes() {
    return 'Feed 2-3 times daily in small amounts. Remove uneaten food after 5 minutes. Adjust portions based on fish activity and appetite.';
  }

  /// Get fish characteristics from local database
  static Future<List<Map<String, String>>> _getFishCharacteristics(List<String> fishNames) async {
    // Skip external API call and use local database directly
    return _getLocalFishCharacteristics(fishNames);
  }

  /// Process fish data from API
  static List<Map<String, String>> _processFishData(dynamic data, List<String> fishNames) {
    final List<Map<String, String>> result = [];
    
    if (data is List) {
      for (final fish in data) {
        if (fish is Map && fishNames.contains(fish['common_name'])) {
          result.add(<String, String>{
            'name': fish['common_name'] ?? '',
            'diet_type': fish['diet_type'] ?? 'omnivore',
            'feeding_behavior': fish['feeding_behavior'] ?? 'mid-water',
            'size': fish['size'] ?? 'medium',
          });
        }
      }
    }
    
    return result;
  }

  /// Local fish characteristics database
  static List<Map<String, String>> _getLocalFishCharacteristics(List<String> fishNames) {
    final Map<String, Map<String, String>> fishDatabase = {
      'guppy': {
        'name': 'Guppy',
        'diet_type': 'omnivore',
        'feeding_behavior': 'surface feeder',
        'size': 'small',
      },
      'betta': {
        'name': 'Betta',
        'diet_type': 'carnivore',
        'feeding_behavior': 'surface feeder',
        'size': 'small',
      },
      'goldfish': {
        'name': 'Goldfish',
        'diet_type': 'omnivore',
        'feeding_behavior': 'bottom feeder',
        'size': 'large',
      },
      'tetra': {
        'name': 'Tetra',
        'diet_type': 'omnivore',
        'feeding_behavior': 'mid-water feeder',
        'size': 'small',
      },
      'angelfish': {
        'name': 'Angelfish',
        'diet_type': 'carnivore',
        'feeding_behavior': 'mid-water feeder',
        'size': 'medium',
      },
      'cichlid': {
        'name': 'Cichlid',
        'diet_type': 'omnivore',
        'feeding_behavior': 'bottom feeder',
        'size': 'medium',
      },
      'platy': {
        'name': 'Platy',
        'diet_type': 'omnivore',
        'feeding_behavior': 'surface feeder',
        'size': 'small',
      },
      'molly': {
        'name': 'Molly',
        'diet_type': 'omnivore',
        'feeding_behavior': 'surface feeder',
        'size': 'small',
      },
      'swordtail': {
        'name': 'Swordtail',
        'diet_type': 'omnivore',
        'feeding_behavior': 'surface feeder',
        'size': 'small',
      },
      'neon tetra': {
        'name': 'Neon Tetra',
        'diet_type': 'omnivore',
        'feeding_behavior': 'mid-water feeder',
        'size': 'small',
      },
      'corydoras': {
        'name': 'Corydoras',
        'diet_type': 'omnivore',
        'feeding_behavior': 'bottom feeder',
        'size': 'small',
      },
      'pleco': {
        'name': 'Pleco',
        'diet_type': 'herbivore',
        'feeding_behavior': 'bottom feeder',
        'size': 'large',
      },
      'shrimp': {
        'name': 'Shrimp',
        'diet_type': 'omnivore',
        'feeding_behavior': 'bottom feeder',
        'size': 'small',
      },
      'snail': {
        'name': 'Snail',
        'diet_type': 'herbivore',
        'feeding_behavior': 'bottom feeder',
        'size': 'small',
      },
    };
    
    final List<Map<String, String>> result = [];
    
    for (final fishName in fishNames) {
      final lowerName = fishName.toLowerCase();
      
      // Try exact match first
      if (fishDatabase.containsKey(lowerName)) {
        final fishData = fishDatabase[lowerName]!;
        result.add(Map<String, String>.from(fishData));
        continue;
      }
      
      // Try partial matches
      for (final entry in fishDatabase.entries) {
        if (lowerName.contains(entry.key) || entry.key.contains(lowerName)) {
          result.add(Map<String, String>.from(entry.value));
          break;
        }
      }
      
      // If no match found, add default characteristics
      if (!result.any((fish) => fish['name']?.toLowerCase() == lowerName)) {
        result.add(<String, String>{
          'name': fishName,
          'diet_type': 'omnivore',
          'feeding_behavior': 'mid-water feeder',
          'size': 'medium',
        });
      }
    }
    
    return result;
  }

  /// Check if API key is configured
  static bool get isConfigured => _apiKey != 'YOUR_GEMINI_API_KEY' && _apiKey.isNotEmpty;
  
  /// Get API usage info
  static String get apiInfo => 'Gemini AI API - Free tier: 15 requests/minute, 1500 requests/day';
}
