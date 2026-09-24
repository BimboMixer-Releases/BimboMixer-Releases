import os
import re

def update_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Replace gradient with image
    old_gradient = r"""        // The background stage lighting effect
        decoration: const BoxDecoration\(
          gradient: RadialGradient\(
            center: Alignment\(0.8, -1.0\),
            radius: 1.5,
            colors: \[
              Color\(0xFF6B1BFF\), // Strong purple spotlight
              Color\(0xFF2A0A73\),
              Color\(0xFF07040D\),
              Color\(0xFF07040D\),
            \],
            stops: \[0.0, 0.3, 0.7, 1.0\],
          \),
        \),"""
    
    new_decoration = """        // The background stage lighting effect
        decoration: BoxDecoration(
          color: const Color(0xFF07040D), // very dark purple/black base
          image: DecorationImage(
            image: const AssetImage('assets/images/stage_lights.jpg'),
            fit: BoxFit.cover, // cover to fill the area
            alignment: Alignment.topRight,
            // Apply a strong color filter so the text stays readable
            colorFilter: ColorFilter.mode(
              const Color(0xFF07040D).withValues(alpha: 0.6), 
              BlendMode.darken,
            ),
          ),
        ),"""
        
    content = re.sub(old_gradient, new_decoration, content)
    
    # Increase opacity of LogoBimbomixer watermark
    old_opacity = r"""opacity: 0.04,"""
    new_opacity = """opacity: 0.15,"""
    content = re.sub(old_opacity, new_opacity, content)
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Updated {file_path}")

update_file("lib/screens/payment_summary_screen.dart")
update_file("lib/screens/invoice_summary_screen.dart")
