import os
import re

def update_file(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Update the top level body to use Stack for the background and header image
    old_body = r"""      body: Container\(
        // The background stage lighting effect
        decoration: BoxDecoration\(
          color: const Color\(0xFF07040D\), // very dark purple/black base
          image: DecorationImage\(
            image: const AssetImage\('assets/images/stage_lights\.jpg'\),
            fit: BoxFit\.cover, // cover to fill the area
            alignment: Alignment\.topRight,
            // Apply a strong color filter so the text stays readable
            colorFilter: ColorFilter\.mode\(
              const Color\(0xFF07040D\)\.withValues\(alpha: 0\.6\), 
              BlendMode\.darken,
            \),
          \),
        \),
        child: Column\("""
    
    new_body = """      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.8, -1.0),
                radius: 1.5,
                colors: [
                  Color(0xFF6B1BFF),
                  Color(0xFF2A0A73),
                  Color(0xFF07040D),
                  Color(0xFF07040D),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
          // Stage Lights only at top right, fading out
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.black, Colors.black87, Colors.transparent],
                  stops: [0.0, 0.4, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'assets/images/stage_lights.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topRight,
              ),
            ),
          ),
          // Content
          Column("""
          
    content = re.sub(old_body, new_body, content)
    
    # 2. Add closing bracket for the Stack at the end of the body
    # We find the matching end of body. The body is the child of Scaffold.
    # It ends with:
    #       ),
    #     );
    #   }
    # Let's replace:
    old_end = r"""        \),
      \),
    \);
  \}
\}"""
    new_end = """        ),
        ],
      ),
    );
  }
}"""
    # Try regex matching the end
    content = re.sub(old_end, new_end, content)
    
    # 3. Replace LogoBimbomixer with Image.asset in the header
    old_logo = r"""                    Container\(
                      decoration: BoxDecoration\(
                        shape: BoxShape\.circle,
                        boxShadow: \[
                          BoxShadow\(
                            color: const Color\(0xFFB142F5\)\.withValues\(alpha: 0\.5\),
                            blurRadius: 20,
                            spreadRadius: 2,
                          \)
                        \]
                      \),
                      child: const LogoBimbomixer\(width: 80, height: 80, baseColor: Colors\.white\),
                    \),"""
    
    new_logo = """                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB142F5).withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ],
                        image: const DecorationImage(
                          // Using a placeholder until the user uploads the B&W logo
                          image: AssetImage('assets/images/logo_bimbomixer_bw.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),"""
    
    content = re.sub(old_logo, new_logo, content)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Updated {file_path}")

update_file("lib/screens/payment_summary_screen.dart")
update_file("lib/screens/invoice_summary_screen.dart")
