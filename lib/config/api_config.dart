import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Get Supabase URL and Anon Key from .env
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  // List of available server URLs to try in order
  static const List<String> serverUrls = [
    //'https://aquasync.onrender.com',
    'http://192.168.7.114:8000',
    'http://172.20.10.2:8000',
  ];
  
  // Current active server URL index (starts with the first one)
  static int _activeServerIndex = 0;
  
  // Timeout for API requests
  static const Duration timeout = Duration(seconds: 10);

  // Get the current active base URL
  static String get baseUrl => serverUrls[_activeServerIndex];
  
  // Try the next server in the list
  static bool tryNextServer() {
    if (_activeServerIndex < serverUrls.length - 1) {
      _activeServerIndex++;
      print('Switching to next server: ${serverUrls[_activeServerIndex]}');
      return true;
    }
    // If we're already at the last server, reset to the first one
    if (_activeServerIndex == serverUrls.length - 1) {
      print('All servers failed. Resetting to first server.');
      _activeServerIndex = 0;
    }
    return false;
  }

  // API Endpoints
  static String get fishSpeciesEndpoint => '$baseUrl/fish-species';
  static String get fishListEndpoint => '$baseUrl/fish-list';
  static String get checkGroupEndpoint => '$baseUrl/check-group';
  static String get calculateRequirementsEndpoint =>
      '$baseUrl/calculate-water-requirements/';
  static String get calculateCapacityEndpoint =>
      '$baseUrl/calculate-fish-capacity/';
  static String get predictEndpoint => '$baseUrl/predict';
  static String get saveFishCalculationEndpoint => '$baseUrl/save-fish-calculation/';
  static String get saveDietCalculationEndpoint => '$baseUrl/save-diet-calculation/';

  // Get fish image URL - ensures proper encoding
  static String getFishImageUrl(String fishName) {
    // Encode the name properly to handle special characters
    String encodedName = Uri.encodeComponent(fishName);

    // Return the full URL to database-powered endpoint
    print('Getting image for fish: $fishName -> $encodedName');
    print('Full image URL: $baseUrl/fish-image/$encodedName');
    return '$baseUrl/fish-image/$encodedName';
  }

  // Get multiple images for a specific fish from the database
  static List<String> getFishImagesFromDb(String fishName, {bool forceRefresh = false}) {
    // Generate a list of URLs by adding random parameters to force different cache entries
    final List<String> urls = [];
    
    // Get the base URL for this fish
    String baseImageUrl = getFishImageUrl(fishName);
    
    // Use a timestamp shared across all images but with different indices
    // This helps with cache consistency while still allowing cache busting
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Generate 4 image URLs with unique cache busters
    // Each request will fetch a random image from the database's fish_images table
    // The backend uses "ORDER BY RANDOM() LIMIT 1" to select a different image each time
    for (int i = 0; i < 4; i++) {
      urls.add('$baseImageUrl?timestamp=$timestamp&index=$i');
    }
    
    return urls;
  }

  // Check server connection with failover support
  static Future<bool> checkServerConnection() async {
    bool connected = false;
    int initialServerIndex = _activeServerIndex;
    
    // Try all servers in sequence until one works
    for (int attempt = 0; attempt < serverUrls.length; attempt++) {
      try {
        print('Trying to connect to ${serverUrls[_activeServerIndex]}');
        final response = await http.get(
          Uri.parse(baseUrl),
          headers: {'Accept': 'application/json'}
        ).timeout(timeout);
        
        connected = response.statusCode >= 200 && response.statusCode < 300;
        
        if (connected) {
          print('Successfully connected to ${serverUrls[_activeServerIndex]}');
          return true;
        } else {
          print('Connection failed with status code ${response.statusCode}');
          tryNextServer();
        }
      } catch (e) {
        print('Connection error: $e');
        // Try the next server
        tryNextServer();
      }
    }
    
    // If all servers failed and we started with a different server,
    // restore the initial server index
    if (!connected && initialServerIndex != _activeServerIndex) {
      _activeServerIndex = initialServerIndex;
    }
    
    return connected;
  }
  
  // Helper method to make a request with automatic failover
  static Future<http.Response?> makeRequestWithFailover({
    required String endpoint,
    String method = 'GET',
    Map<String, String>? headers,
    Object? body,
  }) async {
    // Ensure endpoint starts with /
    String normalizedEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    
    int initialServerIndex = _activeServerIndex;
    
    for (int attempt = 0; attempt < serverUrls.length; attempt++) {
      try {
        http.Response response;
        final uri = Uri.parse('${serverUrls[_activeServerIndex]}$normalizedEndpoint');
        
        print('Trying $method request to ${serverUrls[_activeServerIndex]}$normalizedEndpoint');
        
        if (method == 'GET') {
          response = await http.get(
            uri,
            headers: headers ?? {'Accept': 'application/json'}
          ).timeout(timeout);
        } else if (method == 'POST') {
          response = await http.post(
            uri,
            headers: headers ?? {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: body
          ).timeout(timeout);
        } else {
          throw Exception('Unsupported method: $method');
        }
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('Request successful');
          return response;
        } else {
          print('Request failed with status code: ${response.statusCode}');
          // Try the next server
          tryNextServer();
        }
      } catch (e) {
        print('Request error: $e');
        // Try the next server
        tryNextServer();
      }
    }
    
    // If all servers failed and we started with a different server,
    // restore the initial server index
    if (initialServerIndex != _activeServerIndex) {
      _activeServerIndex = initialServerIndex;
    }
    
    return null;
  }
}
