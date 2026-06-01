# Pipelined Bilinear Image Scaler in Verilog

## Overview
This repository contains a purely hardware-based implementation of a bilinear image scaling algorithm written in Verilog. It is designed to resize images (e.g., upscaling or downscaling) by calculating the weighted average of the four nearest pixels. 

To maximize clock speeds and hardware efficiency, this module avoids costly floating-point operations and division circuits by utilizing **Q8 fixed-point mathematics** and a **4-stage processing pipeline**.

## Key Features
* **4-Stage Pipeline:** Coordinates, memory mapping, address calculation, and pixel blending are broken into distinct pipeline stages to ensure high throughput.
* **Fixed-Point Math (Q8):** Uses fractional scaling (multiplying by 256) and hardware bit-shifting to perform rapid "division" without dedicated division circuits.
* **Highly Parameterized:** Easily customizable for different input/output resolutions (e.g., scaling up to 4K) and color channels by modifying the top-level parameters.
* **Parallel Channel Processing:** Unrolled hardware loops process RGB color channels simultaneously in a single clock cycle.
* **Memory Efficient:** Computes 1D flattened memory addresses directly from 2D coordinates for seamless integration with block RAMs.

## How it Works
1. **Stage 1 (Coordinate Generation):** Scans the grid of the target output resolution.
2. **Stage 2 (Input Mapping):** Maps the output coordinates back to the original image using fixed-point fractional scaling.
3. **Stage 3 (Address Calculation):** Calculates the exact 1D memory addresses for the four surrounding input pixels (Top-Left, Top-Right, Bottom-Left, Bottom-Right).
4. **Stage 4 (Bilinear Blending):** Calculates the inverted distance weights, multiplies them by the stored pixel colors, and accumulates the sum. The final result is bit-shifted to normalize the 8-bit color value.
