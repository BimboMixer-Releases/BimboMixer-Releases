import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';

class NeonButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const NeonButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>().currentColors;
    
    // Gradiente dinamico
    final gradient = LinearGradient(
      colors: [theme.secondary, theme.blueNeon],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: theme.secondary.withValues(alpha: 0.5),
                      blurRadius: 15,
                      offset: const Offset(-4, 0),
                    ),
                    BoxShadow(
                      color: theme.blueNeon.withValues(alpha: 0.5),
                      blurRadius: 15,
                      offset: const Offset(4, 0),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: theme.secondary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(-2, 0),
                    ),
                    BoxShadow(
                      color: theme.blueNeon.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(2, 0),
                    ),
                  ],
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
