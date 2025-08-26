import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aquasync/config/api_config.dart';

class FishImagesGrid extends StatefulWidget {
  final String fishName;
  final int initialDisplayCount;
  final bool showTitle; // Add option to show/hide title

  const FishImagesGrid({
    Key? key,
    required this.fishName,
    this.initialDisplayCount = 2, // Default to showing 2 images initially
    this.showTitle = false, // Default to not showing title since it's shown externally
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

  // Simple in-memory cache for URLs per fish name
  static final Map<String, List<String>> _imageCache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheTtl = Duration(minutes: 10);
  // Memoized pending fetches to curb duplicate round-trips during rebuilds
  static final Map<String, Future<List<String>>> _pendingFetch = {};

  // No longer needed when using backend route; kept if we later need local sanitization
  String _folderFromName(String name) {
    final noSpaces = name.replaceAll(' ', '');
    return noSpaces.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  }

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
      // 1) Serve from cache if fresh
      final cached = _imageCache[widget.fishName];
      final fetchedAt = _cacheTime[widget.fishName];
      final cacheFresh = fetchedAt != null && DateTime.now().difference(fetchedAt) < _cacheTtl;
      if (cached != null && cacheFresh && cached.isNotEmpty) {
        setState(() {
          _imageUrls = List<String>.from(cached);
          _isLoading = false;
        });
        return;
      }

      // Call backend route multiple times in PARALLEL to gather several random images
      final desiredCount = 4; // fetch up to 4 images
      final nowTs = DateTime.now().millisecondsSinceEpoch;
      Future<List<String>> startFetch() async {
        final futures = <Future>[
          for (int i = 0; i < desiredCount; i++)
            ApiConfig.makeRequestWithFailover(
              endpoint: '/fish-image/${Uri.encodeComponent(widget.fishName.replaceAll(' ', ''))}?i=$i&t=$nowTs',
              method: 'GET',
            )
        ];
        final results = await Future.wait(futures, eagerError: false);
        final urls = <String>[];
        final seen = <String>{};
        for (final resp in results) {
          if (resp != null && resp.statusCode >= 200 && resp.statusCode < 300) {
            try {
              print('Fish Images Grid - Response Body: ${resp.body}');
              final data = json.decode(resp.body);
              print('Fish Images Grid - Parsed Data: $data');
              print('Fish Images Grid - Data Type: ${data.runtimeType}');
              
              if (data is Map && data['url'] != null) {
                final url = data['url'].toString();
                print('Fish Images Grid - Found URL: $url');
                if (url.isNotEmpty && !seen.contains(url)) {
                  urls.add(url);
                  seen.add(url);
                  print('Fish Images Grid - Added URL to list');
                }
              } else {
                print('Fish Images Grid - Unexpected data structure: $data');
              }
            } catch (e) {
              print('Error parsing image response: $e');
            }
          } else {
            print('Fish Images Grid - Bad response: ${resp?.statusCode}, Body: ${resp?.body}');
          }
        }
        return urls;
      }

      final urls = await (_pendingFetch[widget.fishName] ??= startFetch());
      _pendingFetch.remove(widget.fishName);

      setState(() {
        _imageUrls = urls;
        _isLoading = false;
      });

      // 2) Populate cache
      if (urls.isNotEmpty) {
        _imageCache[widget.fishName] = List<String>.from(urls);
        _cacheTime[widget.fishName] = DateTime.now();
      }
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
        // Only show title if requested
        if (widget.showTitle) ...[
          const Text(
            'Images',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF006064),
            ),
          ),
          const SizedBox(height: 16),
        ],

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
            final imageUrl = _imageUrls[index];
            // Compute size-aware decode targets for lightweight rendering
            final screenWidth = MediaQuery.of(context).size.width;
            // Rough available width for each tile (2 columns, ~24px total padding+spacing)
            final tileWidth = ((screenWidth - 24) / 2).clamp(80.0, 400.0);
            final tileHeight = (tileWidth / 1.2).clamp(60.0, 400.0);
            return GestureDetector(
              onTap: () => _showFullScreenImage(imageUrl),
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  // Size-aware decode for performance
                  cacheWidth: tileWidth.toInt(),
                  cacheHeight: tileHeight.toInt(),
                  filterQuality: FilterQuality.low,
                  // Lightweight loading indicator
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 24),
                    );
                  },
                ),
              ),
            );
          },
        ),

        // "See more" / "See less" button - Updated styling and positioning
        if (hasMoreImages)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                icon: Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: const Color(0xFF006064),
                ),
                label: Text(
                  _expanded ? 'See less' : 'See more',
                  style: const TextStyle(
                    color: Color(0xFF006064),
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (context, error, stack) {
                      return const Center(
                        child: Icon(Icons.error_outline, color: Colors.white, size: 50),
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