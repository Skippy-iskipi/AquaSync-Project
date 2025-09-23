import 'dart:async';
import 'package:flutter/material.dart';
import '../services/smart_search_service.dart';
import '../screens/fish_search_page.dart';

class SmartSearchWidget extends StatefulWidget {
  final Function(String) onSearchChanged;
  final Function(List<Map<String, dynamic>>) onSearchResults;
  final String hintText;
  final bool showAutocomplete;
  final VoidCallback? onClear;
  final List<Map<String, dynamic>>? availableFish;
  final Map<String, int>? selectedFish;
  final Function(String)? onFishSelected;

  const SmartSearchWidget({
    super.key,
    required this.onSearchChanged,
    required this.onSearchResults,
    this.hintText = 'Search fish by name, attributes, or properties...',
    this.showAutocomplete = true,
    this.onClear,
    this.availableFish,
    this.selectedFish,
    this.onFishSelected,
  });

  @override
  State<SmartSearchWidget> createState() => SmartSearchWidgetState();
}

class SmartSearchWidgetState extends State<SmartSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;
  String _lastQuery = '';
  Timer? _debounceTimer;

  void clearSearch() {
    _controller.clear();
    setState(() {
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


  void _clearSearch() {
    _controller.clear();
    setState(() {
      _isSearching = false;
    });
    widget.onSearchChanged('');
    widget.onSearchResults([]);
  }

  void _openSearchPage() async {
    // Only open search page if we have the required data
    if (widget.availableFish != null && 
        widget.selectedFish != null && 
        widget.onFishSelected != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FishSearchPage(
            onSearchChanged: widget.onSearchChanged,
            onSearchResults: widget.onSearchResults,
            onFishSelected: widget.onFishSelected!,
            availableFish: widget.availableFish!,
            selectedFish: widget.selectedFish!,
            initialQuery: _controller.text,
          ),
        ),
      );
      
      // If user selected a fish from search page, update our local state
      if (result != null && result is String) {
        _controller.text = result;
        _performSearch(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openSearchPage,
      child: Container(
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
          readOnly: widget.availableFish != null && 
                   widget.selectedFish != null && 
                   widget.onFishSelected != null,
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
                : widget.availableFish != null && 
                  widget.selectedFish != null && 
                  widget.onFishSelected != null
                  ? const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16)
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
            if (widget.availableFish != null && 
                widget.selectedFish != null && 
                widget.onFishSelected != null) {
              _openSearchPage();
            } else {
              _focusNode.unfocus();
            }
          },
          onTap: () {
            if (widget.availableFish != null && 
                widget.selectedFish != null && 
                widget.onFishSelected != null) {
              _openSearchPage();
            }
          },
        ),
      ),
    );
  }
}
