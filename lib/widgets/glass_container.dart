import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';
import '../utils/app_colors.dart';

class GlassContainer extends StatefulWidget {
  final Widget child;
  final double blur;
  final double? opacity;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity,
    this.borderRadius,
    this.padding,
    this.margin,
    this.borderColor,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<AppThemeProvider>();
    final theme = themeProvider.currentColors;
    
    // Sfondo molto scuro per le card (come da immagine)
    final cardColor = widget.opacity != null
        ? themeProvider.panelBackground.withValues(alpha: widget.opacity!)
        : themeProvider.panelBackground;

    // Se viene fornito un borderColor, questo diventa un NeonContainer (es. le 4 card in alto)
    // Altrimenti è un container normale con un bordo sottilissimo
    final baseBorderColor = widget.borderColor ?? AppColors.cardBorder;
    
    Color currentBorderColor = baseBorderColor;
    Color currentCardColor = cardColor;
    
    // Se è un neon container, aggiungiamo sempre un po' di glow.
    // Altrimenti solo un po' d'ombra scura base.
    List<BoxShadow> currentShadows = widget.borderColor != null 
        ? [
            BoxShadow(
              color: widget.borderColor!.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: -1,
            ),
            BoxShadow(
              color: widget.borderColor!.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: -1,
            )
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: -2,
            ),
          ];

    double currentBorderWidth = widget.borderColor != null ? 1.5 : 1.0;

    if (_isHovered) {
      if (widget.borderColor == null) {
        currentBorderColor = theme.primary.withValues(alpha: 0.5);
        currentShadows = [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ];
      } else {
        // Se è già neon, intensifica l\'effetto all\'hover
        currentShadows = [
          BoxShadow(
            color: widget.borderColor!.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: widget.borderColor!.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 0,
          )
        ];
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
