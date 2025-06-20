import 'package:flutter/material.dart';

class DescriptionWidget extends StatefulWidget {
  final String description;
  final int maxLines;

  const DescriptionWidget({
    Key? key,
    required this.description,
    this.maxLines = 3,
  }) : super(key: key);

  @override
  State<DescriptionWidget> createState() => _DescriptionWidgetState();
}

class _DescriptionWidgetState extends State<DescriptionWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF006064),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.4,
                ),
                maxLines: _expanded ? null : widget.maxLines,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              if (widget.description.length > 150 || calculateLines(widget.description) > widget.maxLines) 
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    _expanded ? "Show less" : "See more...",
                    style: const TextStyle(
                      color: Color(0xFF00ACC1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to estimate the number of lines in the text
  int calculateLines(String text) {
    // Assuming an average of 45 characters per line
    // This is a rough estimation
    const int charsPerLine = 45;
    return (text.length / charsPerLine).ceil();
  }
} 