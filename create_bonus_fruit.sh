#!/bin/bash
# Script to create a blue brilliant bonus fruit sprite
# This creates a 32x32 pixel blue fruit image

cd "$(dirname "$0")/assets"

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ImageMagick is not installed. Please install it with:"
    echo "  sudo apt-get install imagemagick"
    exit 1
fi

# Create a bright blue circular fruit with a shine effect
convert -size 32x32 xc:none \
    -fill "rgb(0,150,255)" -draw "circle 16,16 16,4" \
    -fill "rgb(100,200,255)" -draw "circle 12,12 12,8" \
    -fill "rgb(200,230,255)" -draw "circle 10,10 10,7" \
    bonus_fruit.png

echo "Created bonus_fruit.png successfully!"
echo "Location: $(pwd)/bonus_fruit.png"
