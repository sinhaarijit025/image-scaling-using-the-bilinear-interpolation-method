from PIL import Image
import numpy as np
import os

# --- Configuration ---
W_IN = 860
H_IN = 821
INPUT_IMAGE = "7.png" # Place an RGB image in the same folder
OUTPUT_HEX = "7.hex"
# ---------------------
def image_to_hex_rgb():
    if not os.path.exists(INPUT_IMAGE):
        print(f"Error: Could not find '{INPUT_IMAGE}'.")
        return

    # Open the image and convert it to RGB
    img = Image.open(INPUT_IMAGE).convert('RGB')
    
    # Resize to exactly match the hardware's expected input dimensions
    img = img.resize((W_IN, H_IN))
    
    # Convert to a numpy array. 
    # Shape will be (H_IN, W_IN, 3). Flattening makes it [R,G,B, R,G,B...]
    pixel_data = np.array(img).flatten()
    
    # Write each byte (R, then G, then B) as a 2-digit hex value
    with open(OUTPUT_HEX, 'w') as f:
        for val in pixel_data:
            f.write(f"{val:02X}\n")
            
    print(f"Success: Wrote {len(pixel_data)} bytes ({len(pixel_data)//3} pixels) to {OUTPUT_HEX}")
    print(f"Image dimensions: {W_IN}x{H_IN} (RGB - 3 Channels)")

if __name__ == "__main__":
    image_to_hex_rgb()