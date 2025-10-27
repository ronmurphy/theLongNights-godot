#!/bin/bash
# Script to remove LFS tracking and pull actual asset files
# For use on other machines after LFS has been removed from the repo

echo "=== Removing Git LFS from theLongNights-godot ==="
echo ""

# Check if git-lfs is installed
if ! command -v git-lfs &> /dev/null; then
    echo "Git LFS is not installed. Installing..."
    sudo pacman -S git-lfs
fi

# Initialize git-lfs for this repo (if not already done)
echo "Initializing Git LFS..."
git lfs install

# Untrack assets from LFS
echo "Untracking assets folder from LFS..."
git lfs untrack "assets/**"

# Fetch and pull the actual files from Git
echo "Pulling actual asset files from repository..."
git pull

echo ""
echo "=== Done! ==="
echo "All LFS pointers should now be replaced with actual files."
echo "You can verify by running: file assets/art/blocks/gold-sides.jpg"
