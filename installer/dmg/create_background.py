#!/usr/bin/env python3
"""
Create a beautiful DMG background image with the cute cat mascot.
Window size: 540x380 (compact but elegant)
"""

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import math

# DMG window dimensions (compact size as requested)
WIDTH = 540
HEIGHT = 380

# Retina display support (2x)
RETINA_WIDTH = WIDTH * 2
RETINA_HEIGHT = HEIGHT * 2

def create_gradient_background(width, height):
    """Create a beautiful gradient background with soft purple/blue tones"""
    img = Image.new('RGBA', (width, height))
    draw = ImageDraw.Draw(img)

    # Gradient colors - elegant purple theme matching app's deepPurple
    top_color = (103, 58, 183)       # Deep purple
    mid_color = (156, 120, 210)      # Soft purple
    bottom_color = (235, 228, 248)   # Very light lavender

    for y in range(height):
        ratio = y / height
        # Smooth cubic interpolation for elegance
        ratio_smooth = ratio * ratio * (3 - 2 * ratio)

        if ratio_smooth < 0.4:
            r = ratio_smooth / 0.4
            color = (
                int(top_color[0] + (mid_color[0] - top_color[0]) * r),
                int(top_color[1] + (mid_color[1] - top_color[1]) * r),
                int(top_color[2] + (mid_color[2] - top_color[2]) * r),
            )
        else:
            r = (ratio_smooth - 0.4) / 0.6
            color = (
                int(mid_color[0] + (bottom_color[0] - mid_color[0]) * r),
                int(mid_color[1] + (bottom_color[1] - mid_color[1]) * r),
                int(mid_color[2] + (bottom_color[2] - mid_color[2]) * r),
            )
        draw.line([(0, y), (width, y)], fill=color)

    return img

def add_soft_glow(img):
    """Add soft glowing orbs for depth and elegance"""
    overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, 'RGBA')
    width, height = img.size

    # Very subtle, small glowing orbs
    glows = [
        (width * 0.08, height * 0.15, 80, (255, 255, 255, 25)),
        (width * 0.92, height * 0.1, 60, (255, 255, 255, 20)),
        (width * 0.05, height * 0.85, 50, (255, 255, 255, 18)),
    ]

    for cx, cy, radius, color in glows:
        # Create radial gradient for each glow
        for r in range(radius, 0, -2):
            alpha = int(color[3] * (1 - (radius - r) / radius) ** 2)
            current_color = (color[0], color[1], color[2], alpha)
            bbox = (cx - r, cy - r, cx + r, cy + r)
            draw.ellipse(bbox, fill=current_color)

    # Blur for smoothness
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=20))

    # Composite
    return Image.alpha_composite(img, overlay)

def create_elegant_arrow():
    """Create a modern, elegant arrow"""
    arrow_width = 180
    arrow_height = 60

    arrow = Image.new('RGBA', (arrow_width * 2, arrow_height * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(arrow)

    center_y = arrow_height

    # Arrow color with gradient effect - white with slight purple tint
    arrow_color = (255, 255, 255, 220)
    shadow_color = (103, 58, 183, 100)

    # Draw shadow first
    shadow_offset = 4
    body_start = 30
    body_end = arrow_width * 2 - 80
    body_thickness = 8

    # Shadow
    draw.rounded_rectangle(
        [body_start + shadow_offset, center_y - body_thickness + shadow_offset,
         body_end + shadow_offset, center_y + body_thickness + shadow_offset],
        radius=body_thickness,
        fill=shadow_color
    )

    # Arrow body (rounded rectangle)
    draw.rounded_rectangle(
        [body_start, center_y - body_thickness, body_end, center_y + body_thickness],
        radius=body_thickness,
        fill=arrow_color
    )

    # Arrow head (triangle)
    head_size = 28
    head_points = [
        (body_end - 5, center_y - head_size),   # Top
        (body_end + head_size + 15, center_y),  # Right point
        (body_end - 5, center_y + head_size),   # Bottom
    ]

    # Shadow for head
    shadow_head_points = [
        (p[0] + shadow_offset, p[1] + shadow_offset) for p in head_points
    ]
    draw.polygon(shadow_head_points, fill=shadow_color)

    # Head
    draw.polygon(head_points, fill=arrow_color)

    return arrow

def add_subtle_shine(img):
    """Add a subtle shine effect at the top"""
    width, height = img.size
    overlay = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, 'RGBA')

    # Top shine gradient
    for y in range(int(height * 0.3)):
        alpha = int(20 * (1 - y / (height * 0.3)) ** 2)
        draw.line([(0, y), (width, y)], fill=(255, 255, 255, alpha))

    return Image.alpha_composite(img, overlay)

def main():
    # Create base gradient
    print("Creating gradient background...")
    bg = create_gradient_background(RETINA_WIDTH, RETINA_HEIGHT)

    # Add soft glowing elements
    print("Adding soft glow effects...")
    bg = add_soft_glow(bg)

    # Add subtle top shine
    bg = add_subtle_shine(bg)

    # Load and place the cat mascot
    print("Adding cat mascot...")
    try:
        cat = Image.open('../../assets/images/cat.png').convert('RGBA')

        # Resize cat to be decorative but not overwhelming
        cat_height = 240
        cat_ratio = cat_height / cat.height
        cat_width = int(cat.width * cat_ratio)
        cat = cat.resize((cat_width, cat_height), Image.Resampling.LANCZOS)

        # Position in bottom-right corner with good margin
        cat_x = RETINA_WIDTH - cat_width - 60
        cat_y = RETINA_HEIGHT - cat_height - 40

        # Add soft shadow under cat
        shadow = Image.new('RGBA', (cat_width + 40, 60), (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.ellipse([20, 10, cat_width + 20, 50], fill=(80, 40, 120, 40))
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=15))
        bg.paste(shadow, (cat_x - 20, cat_y + cat_height - 40), shadow)

        # Paste cat
        bg.paste(cat, (cat_x, cat_y), cat)

    except Exception as e:
        print(f"Warning: Could not load cat image: {e}")

    # Create and place arrow
    print("Creating arrow...")
    arrow = create_elegant_arrow()
    arrow_x = (RETINA_WIDTH - arrow.width) // 2
    arrow_y = (RETINA_HEIGHT - arrow.height) // 2 - 30
    bg.paste(arrow, (arrow_x, arrow_y), arrow)

    # Save the background
    print("Saving background images...")

    # Save retina version
    bg.save('background@2x.png', 'PNG')
    print(f"Saved: background@2x.png ({RETINA_WIDTH}x{RETINA_HEIGHT})")

    # Save standard version
    bg_standard = bg.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
    bg_standard.save('background.png', 'PNG')
    print(f"Saved: background.png ({WIDTH}x{HEIGHT})")

    print("\nDone! Background images created successfully.")
    print(f"DMG window size: {WIDTH}x{HEIGHT}")

if __name__ == '__main__':
    main()
