import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FishImagesGrid extends StatefulWidget {
  final String fishName;
  final int initialDisplayCount;

  const FishImagesGrid({
    Key? key,
    required this.fishName,
    this.initialDisplayCount = 2, // Default to showing 2 images initially
  }) : super(key: key);

  @override
  State<FishImagesGrid> createState() => _FishImagesGridState();
}

class _FishImagesGridState extends State<FishImagesGrid> {
  bool _isLoading = true;
  List<String> _imageUrls = [];
  String? _errorMessage;
  int _loadedImages = 0;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadFishImages();
  }

  Future<void> _loadFishImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadedImages = 0;
    });

    try {
      // Get multiple fish images from the database
      final imageUrls = ApiConfig.getFishImagesFromDb(widget.fishName);
      setState(() {
        _imageUrls = imageUrls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading images: $e';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_imageUrls.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No additional images found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Determine how many images to display based on expanded state
    final displayCount = _expanded ? _imageUrls.length : widget.initialDisplayCount;
    // Calculate if we need a "See more" button
    final hasMoreImages = _imageUrls.length > widget.initialDisplayCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Images',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF006064),
          ),
        ),
        const SizedBox(height: 16),
        
        if (_loadedImages == 0 && !_isLoading)
          
        // Display the grid with the determined number of images
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, 
            childAspectRatio: 1.2, // Make images slightly wider than tall
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: displayCount,
          itemBuilder: (context, index) {
            // For now, just fetch the same endpoint for each image (unless you have multiple images per fish)
            return GestureDetector(
              onTap: () => _showFullScreenImage(widget.fishName),
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FutureBuilder<http.Response>(
                  future: http.get(Uri.parse(ApiConfig.getFishImageUrl(widget.fishName))),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                      );
                    }
                    final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
                    final String? base64Image = jsonData['image_data'];
                    if (base64Image == null || base64Image.isEmpty) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                      );
                    }
                    final String base64Str = base64Image.contains(',') ? base64Image.split(',')[1] : base64Image;
                    return Image.memory(
                      base64Decode(base64Str),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    );
                  },
                ),
              ),
            );
          },
        ),
        
        // "See more" / "Show less" button
        if (hasMoreImages)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _expanded ? "Show less" : "See more...",
                    style: const TextStyle(
                      color: Color(0xFF00ACC1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF00ACC1),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Center(
                  child: FutureBuilder<http.Response>(
                    future: http.get(Uri.parse(imageUrl)),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.statusCode != 200) {
                        return const Center(
                          child: Icon(Icons.error_outline, color: Colors.white, size: 50),
                        );
                      }
                      final Map<String, dynamic> jsonData = json.decode(snapshot.data!.body);
                      final String? base64Image = jsonData['image_data'];
                      if (base64Image == null || base64Image.isEmpty) {
                        return const Center(
                          child: Icon(Icons.error_outline, color: Colors.white, size: 50),
                        );
                      }
                      final String base64Str = base64Image.contains(',') ? base64Image.split(',')[1] : base64Image;
                      return Image.memory(
                        base64Decode(base64Str),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 