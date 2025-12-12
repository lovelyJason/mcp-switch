import os
import sys
from PIL import Image

def generate_tray_icon(source_path):
    print(f"Generating tray icon from: {source_path}")
    try:
        if not os.path.exists(source_path):
            print(f"Error: Source file not found: {source_path}")
            return False

        img = Image.open(source_path).convert("RGBA")
        
        # Standard macOS tray icon sizes
        # 16x16 (1x), 32x32 (2x) - usually for "Menu Bar Extra"
        # Let's generate a 32x32 icon which covers standard Retina displays.
        # Ideally we should strictly follow macOS template rules, but for now a small resize is enough.
        
        target_size = (32, 32) 
        tray_icon = img.resize(target_size, Image.Resampling.LANCZOS)
        
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(script_dir)
        output_path = os.path.join(project_root, "assets", "images", "tray_icon.png")
        
        tray_icon.save(output_path)
        print(f"Saved tray icon to: {output_path}")
        return True
        
    except Exception as e:
        print(f"Error generating tray icon: {e}")
        return False

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    default_source = os.path.join(project_root, "assets", "images", "logo.png")
    
    source = sys.argv[1] if len(sys.argv) > 1 else default_source
    
    if generate_tray_icon(source):
        print("✅ Tray icon generated successfully.")
    else:
        print("❌ Failed to generate tray icon.")
