import 'package:flutter/material.dart';

class ExpandableReason extends StatefulWidget {
  final String text;
  final int maxSentences;
  final int maxChars;
  final TextStyle? textStyle;
  final Color? linkColor;
  final TextAlign? textAlign;

  const ExpandableReason({
    Key? key,
    required this.text,
    this.maxSentences = 2,
    this.maxChars = 120,
    this.textStyle,
    this.linkColor,
    this.textAlign,
  }) : super(key: key);

  @override
  _ExpandableReasonState createState() => _ExpandableReasonState();
}

class _ExpandableReasonState extends State<ExpandableReason> {
  bool _isExpanded = false;
  late String _displayText;
  late bool _needsTruncation;

  @override
  void initState() {
    super.initState();
    _updateDisplayText();
  }

  @override
  void didUpdateWidget(ExpandableReason oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.maxSentences != widget.maxSentences ||
        oldWidget.maxChars != widget.maxChars) {
      _updateDisplayText();
    }
  }

  void _updateDisplayText() {
    final trimmed = widget.text.trim();
    if (trimmed.isEmpty) {
      _displayText = '';
      _needsTruncation = false;
      return;
    }

    // Check if we need to truncate
    _needsTruncation = trimmed.length > widget.maxChars || 
                      trimmed.split(RegExp(r'[.!?]+')).length > widget.maxSentences;

    if (!_needsTruncation) {
      _displayText = trimmed;
      return;
    }

    // Split into sentences (naive approach)
    final sentences = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
    
    // Take up to maxSentences sentences
    String result = sentences.take(widget.maxSentences).join(' ');
    
    // If we have more sentences, add ellipsis
    if (sentences.length > widget.maxSentences) {
      result = result.trim() + '...';
    }
    
    // Enforce max character limit
    if (result.length > widget.maxChars) {
      result = result.substring(0, widget.maxChars).trim();
      if (!result.endsWith('...')) {
        result += '...';
      }
    }
    
    _displayText = result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.brightness == Brightness.dark ? Colors.white : Colors.black87,
      height: 1.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isExpanded ? widget.text : _displayText,
          style: widget.textStyle ?? defaultStyle,
          textAlign: widget.textAlign ?? TextAlign.justify,
          maxLines: _isExpanded ? null : 2,
          overflow: _isExpanded ? null : TextOverflow.ellipsis,
        ),
        if (_needsTruncation)
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Text(
              _isExpanded ? 'Show less' : 'Show more',
              style: TextStyle(
                color: widget.linkColor ?? theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
