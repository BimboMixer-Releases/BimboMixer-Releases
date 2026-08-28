import 'package:flutter/material.dart';

class HoverGlowText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color glowColor;

  const HoverGlowText(
    this.text, {
    super.key,
    required this.style,
    this.glowColor = Colors.white,
  });

  @override
  State<HoverGlowText> createState() => _HoverGlowTextState();
}

class _HoverGlowTextState extends State<HoverGlowText> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: widget.style.copyWith(
          shadows: _isHovering
              ? [
                  Shadow(
                    color: widget.glowColor.withValues(alpha: 0.8),
                    blurRadius: 10.0,
                  ),
                  Shadow(
                    color: widget.glowColor.withValues(alpha: 0.4),
                    blurRadius: 20.0,
                  ),
                ]
              : [],
        ),
        child: Text(widget.text),
      ),
    );
  }
}
