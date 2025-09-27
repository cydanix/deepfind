#! /bin/bash

echo "Resetting all permissions for DeepFind..."

# Reset all permissions
echo "Resetting all TCC permissions..."
sudo tccutil reset All com.deepfind

# Reset specific permissions (more targeted approach)
echo "Resetting specific permissions..."
sudo tccutil reset Microphone com.deepfind
sudo tccutil reset Accessibility com.deepfind
sudo tccutil reset AppleEvents com.deepfind

echo "Permissions have been reset. Please restart the app."
echo "Note: You may need to restart your computer for changes to take full effect."
