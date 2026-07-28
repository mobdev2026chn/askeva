#!/bin/bash
# AskEva Android App - Installation & Run Script

echo "================================"
echo "  AskEva Android App Setup"
echo "================================"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed!"
    echo "Please download from https://nodejs.org/"
    exit 1
fi

echo "✅ Node.js found: $(node --version)"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed!"
    exit 1
fi

echo "✅ npm found: $(npm --version)"
echo ""

# Install Expo CLI globally if not already installed
if ! command -v expo &> /dev/null; then
    echo "📦 Installing Expo CLI globally..."
    npm install -g expo-cli
    echo "✅ Expo CLI installed"
else
    echo "✅ Expo CLI already installed: $(expo --version)"
fi

echo ""
echo "📥 Installing project dependencies..."
npm install

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ All dependencies installed successfully!"
    echo ""
    echo "================================"
    echo "  Installation Complete! 🎉"
    echo "================================"
    echo ""
    echo "📱 Next Steps:"
    echo "1. Download 'Expo Go' from Google Play Store"
    echo "2. Run: npm start"
    echo "3. Scan the QR code with Expo Go"
    echo ""
    echo "💡 Useful Commands:"
    echo "  npm start          - Start development server"
    echo "  npm run android    - Start for Android"
    echo "  npm run web        - Start web version"
    echo ""
else
    echo ""
    echo "❌ Installation failed. Please check the errors above."
    exit 1
fi
