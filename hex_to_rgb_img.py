from PIL import Image
import numpy as np
import os

# --- Configuration ---
W_OUT = 3000
H_OUT = 2160
INPUT_HEX = "7_out.hex"
OUTPUT_IMAGE = "7_out.png"
# ---------------------

def hex_to_image_rgb():
    if not os.path.exists(INPUT_HEX):
        print(f"Error: Could not find '{INPUT_HEX}'.")
        return

    pixels = []
    
    print(f"Reading {INPUT_HEX}...")
    with open(INPUT_HEX, 'r') as f:
        for line in f:
            line = line.strip()
            
            # 1. Skip empty lines or full comment lines
            if not line or line.startswith("//") or line.startswith("#"):
                continue
                
            # 2. Strip away inline comments (e.g., "FF // pixel 1")
            pure_hex = line.split("//")[0].strip()
            
            # 3. Handle Verilog 'x' (unknown) or 'z' (high-Z) states safely
            if 'x' in pure_hex.lower() or 'z' in pure_hex.lower():
                pixels.append(0) # Default unknown memory to black
            else:
                try:
                    pixels.append(int(pure_hex, 16))
                except ValueError:
                    pass # Silently ignore any other weird text
    
    # We expect W * H pixels, and 3 bytes (R,G,B) per pixel
    expected_bytes = W_OUT * H_OUT * 3
    
    if len(pixels) != expected_bytes:
        print(f"Warning: Expected {expected_bytes} bytes, but found {len(pixels)}.")
    
    # Safely slice the array
    pixel_data = pixels[:expected_bytes]
    
    # Pad with black (0) if the simulation didn't finish completely
    if len(pixel_data) < expected_bytes:
        padding_needed = expected_bytes - len(pixel_data)
        pixel_data.extend([0] * padding_needed)
        print(f"Padded {padding_needed} missing bytes with black.")

    # Reshape the flat array back into a 3D image matrix: (Height, Width, 3 Colors)
    pixel_array = np.array(pixel_data, dtype=np.uint8).reshape((H_OUT, W_OUT, 3))
    
    # Convert numpy array back to an RGB image
    img = Image.fromarray(pixel_array, mode='RGB')
    img.save(OUTPUT_IMAGE)
    
    print(f"Success: Saved scaled RGB image to '{OUTPUT_IMAGE}'")
    print(f"Output dimensions: {W_OUT}x{H_OUT}")

if __name__ == "__main__":
    hex_to_image_rgb()