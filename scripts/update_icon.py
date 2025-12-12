import os
import sys
import subprocess
from PIL import Image, ImageDraw

def mask_image_to_squircle(image_path, output_path):
    print(f"Processing image: {image_path}")
    try:
        img = Image.open(image_path).convert("RGBA")
        
        # Resize to standard size if needed (e.g., 1024x1024)
        target_size = (1024, 1024)
        img = img.resize(target_size, Image.Resampling.LANCZOS)
        
        # Create mask
        mask = Image.new("L", target_size, 0)
        draw = ImageDraw.Draw(mask)
        
        # Draw standard macOS squircle (approx 22.37% radius)
        w, h = target_size
        corner_radius = int(w * 0.2237)
        draw.rounded_rectangle((0, 0, w, h), radius=corner_radius, fill=255)
        
        # Apply mask
        result = Image.new("RGBA", target_size)
        result.paste(img, (0, 0), mask=mask)
        
        # Save
        result.save(output_path)
        print(f"Saved processed icon to: {output_path}")
        return True
        
    except Exception as e:
        print(f"Error processing image: {e}")
        return False

def run_flutter_icons():
    print("Running flutter_launcher_icons...")
    try:
        # Run flutter pub run flutter_launcher_icons
        # Assuming we are in project root or scripts folder
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        cmd = ["flutter", "pub", "run", "flutter_launcher_icons"]
        subprocess.run(cmd, check=True, cwd=project_root)
        print("Successfully updated native icons.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to run flutter_launcher_icons: {e}")
        return False
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/update_icon.py <path_to_source_image>")
        sys.exit(1)
        
    source_image = sys.argv[1]
    
    if not os.path.exists(source_image):
        print(f"Error: File not found: {source_image}")
        sys.exit(1)
        
    # Determine output path (assets/images/logo.png)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    assets_logo_path = os.path.join(project_root, "assets", "images", "logo.png")
    
    print("--- Step 1: Processing Image ---")
    if mask_image_to_squircle(source_image, assets_logo_path):
        print("\n--- Step 2: Updating Native Config ---")
        if run_flutter_icons():
            print("\n✅ Done! The app icon has been updated.")
            print("Please rebuild your app (e.g., 'flutter run -d macos') to see the changes.")
        else:
            print("\n❌ Failed to update native icons.")
    else:
        print("\n❌ Failed to process image.")
