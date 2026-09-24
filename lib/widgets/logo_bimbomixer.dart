import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LogoBimbomixer extends StatelessWidget {
  final double width;
  final double height;
  final Color baseColor;

  const LogoBimbomixer({
    super.key,
    this.width = 160.0,
    this.height = 160.0,
    this.baseColor = const Color(0xFFFFD700), // Neon Yellow/Gold
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(width * 0.2),
        border: Border.all(
          color: baseColor.withValues(alpha: 0.3),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.1),
            blurRadius: 15.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner glowing circle
          Container(
            width: width * 0.85,
            height: height * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: baseColor,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.4),
                  blurRadius: 10.0,
                  spreadRadius: 1.0,
                ),
              ],
            ),
          ),
          
          // Outer glass reflection (simulate the glass app icon look)
          Positioned(
            top: 4.0,
            left: 4.0,
            right: 4.0,
            bottom: 4.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.0,
                ),
              ),
            ),
          ),

          // Texts
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // BIMBOMIXER (Sans-serif bold)
              Text(
                'BIMBOMIXER',
                style: GoogleFonts.inter(
                  fontSize: width * 0.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: baseColor,
                  shadows: [
                    Shadow(
                      color: baseColor,
                      blurRadius: 8.0,
                    ),
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 2.0,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
              // Contabilità (Cursive, positioned slightly overlapping)
              Transform.translate(
                offset: Offset(0, -(height * 0.05)),
                child: Text(
                  'Contabilità',
                  style: GoogleFonts.dancingScript(
                    fontSize: width * 0.24,
                    fontWeight: FontWeight.w700,
                    color: baseColor,
                    shadows: [
                      Shadow(
                        color: baseColor,
                        blurRadius: 10.0,
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 2.0,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
