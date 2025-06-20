import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; // Add Timer import
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../widgets/description_widget.dart';
import '../widgets/fish_images_grid.dart';
import '../services/openai_service.dart'; // Import OpenAI service

class FishListScreen extends StatefulWidget {
  final String title;
  final bool isSaltWater;

  const FishListScreen({
    super.key,
    required this.title,
    required this.isSaltWater,
  });

  @override
  State<FishListScreen> createState() => _FishListScreenState();
}

class _FishListScreenState extends State<FishListScreen> {
  List<Map<String, dynamic>> fishList = [];
  List<Map<String, dynamic>> filteredFishList = [];
  bool isLoading = true;
  String? error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchFishList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFishList(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredFishList = fishList;
      } else {
        filteredFishList = fishList.where((fish) {
          final name = fish['common_name']?.toString().toLowerCase() ?? '';
          final scientificName = fish['scientific_name']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) || 
                 scientificName.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> fetchFishList() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Check server connection first
      final isConnected = await ApiConfig.checkServerConnection();
      if (!isConnected) {
        setState(() {
          error = 'Cannot connect to server at ${ApiConfig.baseUrl}\nPlease make sure the server is running and accessible.';
          isLoading = false;
        });
        return;
      }

      print('Fetching fish list from: ${ApiConfig.baseUrl}/fish-list');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/fish-list'),
        headers: {'Connection': 'keep-alive'},
      ).timeout(ApiConfig.timeout);
      
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          fishList = data
              .map<Map<String, dynamic>>((item) => item as Map<String, dynamic>)
              .where((fish) => 
                (widget.isSaltWater && fish['water_type'] == 'Saltwater') ||
                (!widget.isSaltWater && fish['water_type'] == 'Freshwater'))
              .toList();
          filteredFishList = fishList;
          isLoading = false;
          error = null;
        });
      } else {
        print('Error response: ${response.body}');
        setState(() {
          error = 'Failed to load fish data: ${response.statusCode}\nResponse: ${response.body}';
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error fetching fish list: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        error = 'Error connecting to server: $e\nPlease make sure the server is running at ${ApiConfig.baseUrl}';
        isLoading = false;
      });
    }
  }
  
  void _showFishDetails(Map<String, dynamic> fish) {
    // Create a mutable copy of the fish object
    Map<String, dynamic> fishCopy = Map<String, dynamic>.from(fish);
    
    // Load the description and then show the details
    _loadDescriptionAndShowDetails(fishCopy);
  }
  
  // Method similar to _loadDescriptionAndShowResults in capture.dart
  Future<void> _loadDescriptionAndShowDetails(Map<String, dynamic> fish) async {
    final commonName = fish['common_name'] ?? 'Unknown';
    final scientificName = fish['scientific_name'] ?? 'Unknown';
    
    // Show loading dialog while generating the description
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.teal,
          ),
        ),
      ),
    );
    
    try {
      print('Attempting to generate description for $commonName ($scientificName)');
      
      // Generate description using OpenAI
      final description = await OpenAIService.generateFishDescription(
        commonName, 
        scientificName
      );
      
      // Add the description to the fish data
      fish['description'] = description;
      
      if (mounted) {
        Navigator.pop(context); // Close the loading dialog
        _showFishDetailsScreen(fish);
      }
    } catch (e) {
      print('Error loading description: $e');
      if (mounted) {
        Navigator.pop(context); // Close the loading dialog
        
        // Set a default error message for the description
        fish['description'] = 'Failed to generate description. Try again later.';
        _showFishDetailsScreen(fish);
      }
    }
  }
  
  void _showFishDetailsScreen(Map<String, dynamic> fish) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Fish Details',
                style: TextStyle(
                  color: Color(0xFF006064),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 300,
                    child: FutureBuilder<http.Response>(
                      future: http.get(Uri.parse(ApiConfig.getFishImageUrl(fish['common_name'] ?? ''))),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        }
                        final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
                        final String? base64Image = jsonData['image_data'];
                        if (base64Image == null || base64Image.isEmpty) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        }
                        final String base64Str = base64Image.contains(',') ? base64Image.split(',')[1] : base64Image;
                        return Image.memory(
                          base64Decode(base64Str),
                          width: double.infinity,
                          height: 300,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fish['common_name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          fish['scientific_name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Display the description using DescriptionWidget
                        DescriptionWidget(
                          description: fish['description'] ?? 'No description available.',
                          maxLines: 4,
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Fish Images Grid after the description
                        FishImagesGrid(
                          fishName: fish['common_name'] ?? '',
                          initialDisplayCount: 2,
                        ),
                        
                        const SizedBox(height: 30),
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20), // Increased spacing
                        _buildDetailRow('Water Type', fish['water_type'] ?? 'Unknown'),
                        _buildDetailRow('Maximum Size', '${fish['max_size']} cm'),
                        _buildDetailRow('Temperament', fish['temperament'] ?? 'Unknown'),
                        _buildDetailRow('Care Level', fish['care_level'] ?? 'Unknown'),
                        _buildDetailRow('Lifespan', fish['lifespan'] ?? 'Unknown'),
                        const SizedBox(height: 40), // Increased spacing
                        
                        // Add Habitat Information section
                        const Text(
                          'Habitat Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20), // Increased spacing
                        _buildDetailRow(
                          'Temperature Range',
                          fish['temperature_range'] ?? 'Unknown'
                        ),
                        _buildDetailRow('pH Range', fish['ph_range'] ?? 'Unknown'),
                        _buildDetailRow('Minimum Tank Size', 
                          fish['minimum_tank_size_(l)'] != null 
                            ? '${fish['minimum_tank_size_(l)']} L' 
                            : (fish['minimum_tank_size_l'] != null 
                                ? '${fish['minimum_tank_size_l']} L' 
                                : (fish['minimum_tank_size'] != null 
                                    ? '${fish['minimum_tank_size']} L' 
                                    : 'Unknown'))),
                        _buildDetailRow('Social Behavior', fish['social_behavior'] ?? 'Unknown'),
                        const SizedBox(height: 40), // Increased spacing
                        
                        const Text(
                          'Diet Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006064),
                          ),
                        ),
                        const SizedBox(height: 20), // Increased spacing
                        _buildDetailRow('Diet Type', fish['diet'] ?? 'Unknown'),
                        _buildDetailRow('Preferred Food', fish['preferred_food'] ?? 'Unknown'),
                        _buildDetailRow('Feeding Frequency', fish['feeding_frequency'] ?? 'Unknown'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF006064),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFishListImage(String? fishName) {
    return FutureBuilder<http.Response>(
      future: http.get(Uri.parse(ApiConfig.getFishImageUrl(fishName ?? ''))),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 120,
            height: 80,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
          return Container(
            width: 120,
            height: 80,
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
          );
        }
        final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
        final String? base64Image = jsonData['image_data'];
        if (base64Image == null || base64Image.isEmpty) {
          return Container(
            width: 120,
            height: 80,
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 24),
          );
        }
        final String base64Str = base64Image.contains(',') ? base64Image.split(',')[1] : base64Image;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(base64Str),
            width: 120,
            height: 80,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
  
  Widget build(BuildContext context) {
    
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF006064)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF006064),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterFishList,
                decoration: InputDecoration(
                  hintText: 'Search fish...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _filterFishList('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),
          // Fish List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: fetchFishList,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006064),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : filteredFishList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No fish found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: filteredFishList.length,
                            itemBuilder: (context, index) {
                              final fish = filteredFishList[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        spreadRadius: 1.5,
                                        blurRadius: 0,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      _showFishDetails(fish);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          buildFishListImage(fish['common_name']),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fish['common_name'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  fish['scientific_name'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                // Add description snippet if available
                                                if (fish['description'] != null && fish['description'].toString().isNotEmpty)
                                                  Text(
                                                    fish['description'].toString().length > 60
                                                        ? '${fish['description'].toString().substring(0, 60)}...'
                                                        : fish['description'].toString(),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Size: ${fish['max_size']} cm length',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                Text(
                                                  'Life Span: ${fish['lifespan']}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            color: Colors.grey[400],
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
} 