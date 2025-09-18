import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/smart_search_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SmartSearchWidget extends StatefulWidget {
  final Function(String) onSearchChanged;
  final Function(List<Map<String, dynamic>>) onSearchResults;
  final String hintText;
  final bool showAutocomplete;
  final VoidCallback? onClear;

  const SmartSearchWidget({
    super.key,
    required this.onSearchChanged,
    required this.onSearchResults,
    this.hintText = 'Search fish by name, attributes, or properties...',
    this.showAutocomplete = true,
    this.onClear,
  });

  @override
  State<SmartSearchWidget> createState() => SmartSearchWidgetState();
}

class SmartSearchWidgetState extends State<SmartSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;
  String _lastQuery = '';
  Timer? _debounceTimer;

  void clearSearch() {
    _controller.clear();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _isSearching = false;
      _lastQuery = '';
    });
    widget.onSearchChanged('');
    widget.onSearchResults([]);
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
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
        _performSearch(query);
      });
      
      // Update suggestions immediately for better UX
      if (widget.showAutocomplete && query.isNotEmpty) {
        _updateSuggestions(query);
      } else {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    }
  }

  void _onFocusChanged() {
    setState(() {
      _showSuggestions = _focusNode.hasFocus && 
                        widget.showAutocomplete && 
                        _controller.text.isNotEmpty;
    });
    
    // Hide suggestions when focus is lost (keyboard dismissed)
    if (!_focusNode.hasFocus) {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await SmartSearchService.searchFish(
        query: query,
        limit: 100,
        minSimilarity: 0.01, // Very low threshold to catch more results
      );

      if (mounted) {
        widget.onSearchResults(results);
        widget.onSearchChanged(query);
      }
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
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
        limit: 8,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty && _focusNode.hasFocus;
        });
      }
    } catch (e) {
      print('Error getting suggestions: $e');
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
      _showSuggestions = false;
    });
    widget.onSearchChanged('');
    widget.onSearchResults([]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: widget.hintText,
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
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
            ),
            style: const TextStyle(fontSize: 16),
            onSubmitted: (value) {
              _focusNode.unfocus();
              setState(() {
                _showSuggestions = false;
              });
            },
          ),
        ),
        
        // Suggestions dropdown
        if (_showSuggestions && _suggestions.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = _calculateMaxHeight(context);
              return SafeArea(
                child: ClipRect(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    height: maxHeight, // Use explicit height instead of constraints
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Suggestions list
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: _suggestions.length <= 5 
                        ? const NeverScrollableScrollPhysics() 
                        : const ClampingScrollPhysics(),
                    itemCount: _suggestions.length > 8 ? 9 : _suggestions.length, // Limit to 8 items + "show more"
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      // Show "more results" indicator if we have more than 8 suggestions
                      if (index == 8 && _suggestions.length > 8) {
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          title: Text(
                            '${_suggestions.length - 8} more results...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          onTap: () {
                            // Optionally implement "show all" functionality
                            setState(() {
                              _showSuggestions = false;
                            });
                          },
                        );
                      }
                      
                      final suggestion = _suggestions[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          _getSuggestionIcon(suggestion),
                          size: 18,
                          color: const Color(0xFF00BCD4),
                        ),
                        title: Text(
                          suggestion,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectSuggestion(suggestion),
                      );
                    },
                  ),
                ),
              ],
            ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Calculate maximum height for suggestions dropdown based on keyboard visibility
  double _calculateMaxHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight;
    
    // Calculate based on available space
    const searchInputHeight = 60.0; // Approximate height of search input
    const padding = 60.0; // Top and bottom padding
    const buffer = 200.0; // Extra buffer space for safe area and other UI elements
    
    // Calculate available space for suggestions
    final availableSpace = availableHeight - searchInputHeight - padding - buffer;
    
    // Use very conservative percentages
    final maxPercentage = keyboardHeight > 0 ? 0.15 : 0.25; // Very conservative
    final maxAllowedHeight = screenHeight * maxPercentage;
    
    // Calculate based on item count (each item is ~48px + divider)
    const itemHeight = 48.0;
    const dividerHeight = 1.0;
    const tipsHeight = 40.0; // Search tips height
    final maxItems = 8; // Limit to 8 items max
    final calculatedHeight = tipsHeight + (maxItems * (itemHeight + dividerHeight));
    
    // Use the most restrictive constraint
    final height1 = availableSpace.clamp(100.0, 250.0); // Available space constraint
    final height2 = maxAllowedHeight.clamp(100.0, 250.0); // Percentage constraint
    final height3 = calculatedHeight.clamp(100.0, 250.0); // Item count constraint
    
    return [height1, height2, height3].reduce((a, b) => a < b ? a : b);
  }

  IconData _getSuggestionIcon(String suggestion) {
    final lower = suggestion.toLowerCase();
    
    if (lower.contains('fish') || RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+$').hasMatch(suggestion)) {
      return FontAwesomeIcons.fish; // Scientific names or fish names
    } else if (['freshwater', 'saltwater', 'marine'].any((term) => lower.contains(term))) {
      return Icons.water_drop;
    } else if (['peaceful', 'aggressive', 'semi-aggressive'].any((term) => lower.contains(term))) {
      return Icons.psychology;
    } else if (['schooling', 'solitary', 'community'].any((term) => lower.contains(term))) {
      return Icons.group;
    } else if (['omnivore', 'carnivore', 'herbivore'].any((term) => lower.contains(term))) {
      return Icons.restaurant;
    } else if (['beginner', 'intermediate', 'expert'].any((term) => lower.contains(term))) {
      return Icons.star;
    } else if (['top', 'mid', 'bottom', 'all'].any((term) => lower.contains(term))) {
      return Icons.layers;
    } else {
      return Icons.search;
    }
  }
}


