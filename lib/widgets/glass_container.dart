import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';

class GlassContainer extends StatefulWidget {
  final Widget child;
  final double blur;
  final double? opacity;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity,
    this.borderRadius,
    this.padding,
    this.margin,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final cardColor = widget.opacity != null
        ? Colors.white.withValues(alpha: widget.opacity!)
        : theme.cardColor;

    Color currentBorderColor = theme.borderColor;
    Color currentCardColor = cardColor;
    List<BoxShadow> currentShadows = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 10,
        spreadRadius: -2,
      ),
    ];
    double currentBorderWidth = 1.5;

    if (_isHovered) {
      switch (theme.glowEffectType) {
        case GlowEffectType.none:
          break;
        case GlowEffectType.outerGlow:
          currentShadows = [
            BoxShadow(
              color: theme.glowColor.withValues(alpha: 0.6),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ];
          break;
        case GlowEffectType.neonBorder:
          currentBorderColor = theme.glowColor;
          currentBorderWidth = 2.5;
          currentShadows = [
            BoxShadow(
              color: theme.glowColor.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ];
          break;
        case GlowEffectType.innerFill:
          currentCardColor = Color.alphaBlend(
            theme.glowColor.withValues(alpha: 0.3),
            cardColor,
          );
          break;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            boxShadow: currentShadows,
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: widget.padding ?? const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: currentCardColor,
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
                  border: Border.all(
                    color: currentBorderColor,
                    width: currentBorderWidth,
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
