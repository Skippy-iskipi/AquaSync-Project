import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/smart_search_service.dart';
import '../widgets/fish_info_dialog.dart';
import '../config/api_config.dart';

class FishSearchPage extends StatefulWidget {
  final Function(String) onSearchChanged;
  final Function(List<Map<String, dynamic>>) onSearchResults;
  final Function(String) onFishSelected;
  final List<Map<String, dynamic>> availableFish;
  final Map<String, int> selectedFish;
  final String initialQuery;

  const FishSearchPage({
    super.key,
    required this.onSearchChanged,
    required this.onSearchResults,
    required this.onFishSelected,
    required this.availableFish,
    required this.selectedFish,
    this.initialQuery = '',
  });

  @override
  State<FishSearchPage> createState() => _FishSearchPageState();
}

class _FishSearchPageState extends State<FishSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showSuggestions = true;
  String _lastQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _focusNode.requestFocus();
    _controller.addListener(_onTextChanged);
    
    // Load initial suggestions if no query
    if (widget.initialQuery.isEmpty) {
      _loadInitialSuggestions();
    } else {
      _performSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text.trim();
    
    if (query != _lastQuery) {
      _lastQuery = query;
      
      // Debounce search to avoid too many API calls
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (query.isNotEmpty) {
          _performSearch(query);
        }
      });
      
      // Update suggestions immediately for better UX
      if (query.isNotEmpty) {
        _updateSuggestions(query);
      } else {
        setState(() {
          _suggestions = [];
          _showSuggestions = true;
          _searchResults = [];
        });
        _loadInitialSuggestions();
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    
    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    try {
      final results = await SmartSearchService.searchFish(
        query: query,
        limit: 100,
        minSimilarity: 0.01,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
        });
        widget.onSearchResults(results);
        widget.onSearchChanged(query);
      }
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
        widget.onSearchResults([]);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _updateSuggestions(String query) async {
    try {
      final suggestions = await SmartSearchService.getAutocompleteSuggestions(
        query: query,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
        });
      }
    } catch (e) {
      print('Error getting suggestions: $e');
    }
  }

  Future<void> _loadInitialSuggestions() async {
    try {
      // Get popular fish names as initial suggestions
      final popularFish = widget.availableFish
          .take(10)
          .map((fish) => fish['common_name'] as String)
          .where((name) => name.isNotEmpty)
          .toList();
      
      if (mounted) {
        setState(() {
          _suggestions = popularFish;
        });
      }
    } catch (e) {
      print('Error loading initial suggestions: $e');
    }
  }

  void _selectSuggestion(String suggestion) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    
    setState(() {
      _showSuggestions = false;
    });
    
    _performSearch(suggestion);
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _suggestions = [];
      _searchResults = [];
      _showSuggestions = true;
    });
    _loadInitialSuggestions();
    widget.onSearchChanged('');
    widget.onSearchResults([]);
  }

  void _selectFish(String fishName) {
    widget.onFishSelected(fishName);
    Navigator.pop(context);
  }

  Widget _buildFishImage(String fishName) {
    if (fishName.isEmpty) {
      return Icon(
        FontAwesomeIcons.fish,
        color: Colors.grey.shade400,
        size: 32,
      );
    }

    final imageUrl = '${ApiConfig.baseUrl}/fish-image/${Uri.encodeComponent(fishName)}';
    
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      cacheWidth: 150,
      cacheHeight: 150,
      filterQuality: FilterQuality.low,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade200,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF00BCD4)),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade200,
          child: Icon(
            FontAwesomeIcons.fish,
            color: Colors.grey.shade400,
            size: 28,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00BCD4)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Search Fish',
          style: TextStyle(
            color: Color(0xFF00BCD4),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search fish by name, attributes, or properties...',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                ),
                prefixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                          ),
                        ),
                      )
                    : const Icon(Icons.search, color: Color(0xFF00BCD4)),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
              style: const TextStyle(fontSize: 16),
              onSubmitted: (value) {
                _focusNode.unfocus();
              },
            ),
          ),
          
          // Content
          Expanded(
            child: _isSearching
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Searching...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF00BCD4),
                          ),
                        ),
                      ],
                    ),
                  )
                : _showSuggestions
                    ? _buildSuggestionsList()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_suggestions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.fish,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Start typing to search for fish',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00BCD4),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = _suggestions[index];
              return ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildFishImage(suggestion),
                  ),
                ),
                title: Text(
                  suggestion,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Tap to search',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () => _selectSuggestion(suggestion),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.fish,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No fish found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try different search terms',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Search Results (${_searchResults.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00BCD4),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showSuggestions = true;
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to suggestions'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00BCD4),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final fish = _searchResults[index];
              final fishName = fish['common_name'] as String? ?? 'Unknown';
              final scientificName = fish['scientific_name'] as String? ?? 'Unknown';
              final isSelected = widget.selectedFish.containsKey(fishName);
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00BCD4) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildFishImage(fishName),
                    ),
                  ),
                  title: Text(
                    fishName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? const Color(0xFF00BCD4) : Colors.black87,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scientificName,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.water_drop,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                fish['water_type']?.toString() ?? 'Unknown',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.psychology,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  fish['temperament']?.toString() ?? 'Unknown',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showFishInfoDialog(fishName),
                        icon: const Icon(Icons.info_outline),
                        color: const Color(0xFF00BCD4),
                      ),
                      ElevatedButton(
                        onPressed: () => _selectFish(fishName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? Colors.red : const Color(0xFF00BCD4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isSelected ? 'Remove' : 'Add',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showFishInfoDialog(fishName),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFishInfoDialog(String fishName) {
    showDialog(
      context: context,
      builder: (context) => FishInfoDialog(fishName: fishName),
    );
  }
}
