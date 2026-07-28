# AskEva Mobile App - Setup & Installation Guide

## Project Overview

AskEva is a business card scanning and lead management application built with **React Native** using **Expo**, designed to run on Android devices (including Expo Go).

### Features
- 🔐 User authentication (Login)
- 📸 Business card scanning with camera
- 👥 Lead list and management
- 📊 Lead scoring and analytics
- 📈 Team performance dashboard (LMS)
- 🏢 Personal business card profile

## Prerequisites

Before you get started, ensure you have:

1. **Node.js** (v18 or higher)
   - Download from: https://nodejs.org/

2. **Expo CLI** (installed globally)
   ```bash
   npm install -g expo-cli
   ```

3. **Expo Go App** (on your Android device)
   - Download from: Google Play Store
   - Search for "Expo Go"

4. **Git** (optional, for version control)

## Installation

### Step 1: Install Dependencies

Navigate to the project directory and install all dependencies:

```bash
cd "Business card scanning system"
npm install
```

This will install:
- `expo` - Expo framework
- `react-native` - React Native libraries
- `@react-navigation/*` - Navigation libraries
- `expo-camera` - Camera access
- Other supporting libraries

### Step 2: Verify Project Structure

Your project should have this structure:

```
Business card scanning system/
├── src/
│   ├── screens/          # All screen components
│   ├── components/       # Reusable UI components
│   ├── utils/           # Utilities (theme, data)
│   ├── types/           # TypeScript type definitions
│   └── App.tsx          # Main app component
├── package.json         # Dependencies
├── app.json            # Expo configuration
├── babel.config.js     # Babel configuration
├── tsconfig.json       # TypeScript configuration
└── index.js            # Entry point
```

## Running the App

### Option 1: Using Expo Go (Recommended for Testing)

#### On Windows/Mac:

1. **Start the development server:**
   ```bash
   npm start
   ```

   You'll see output like:
   ```
   Starting Expo Go on http://localhost:19000...
   ```

2. **Scan the QR code:**
   - A QR code will appear in the terminal or on the Metro Bundler web page
   - Open Expo Go on your Android device
   - Tap "Scan QR Code"
   - Point camera at the QR code

3. **App loads automatically** on your device!

#### Direct Commands:

```bash
# Start with Android-specific optimizations
npm run android

# Or start fresh without cache
npm start -- --clear
```

### Option 2: Building APK for Installation

To create a standalone Android app:

```bash
# Build APK
expo build:android --release-channel=production

# Or use the new EAS Build service
eas build --platform android
```

This creates an APK you can install directly on any Android device.

## Development Workflow

### Making Changes

1. **Edit any file in `src/`**
   - Changes auto-reload in Expo Go
   - No need to rebuild!

2. **Restart the app** (if needed):
   - Press `r` in the terminal
   - Or shake your device and tap "Refresh"

### File Organization

- **Screens** (`src/screens/`)
  - `LoginScreen.tsx` - Authentication
  - `HomeScreen.tsx` - Dashboard
  - `LeadListScreen.tsx` - All leads
  - `LeadDetailScreen.tsx` - Individual lead
  - `ScanScreen.tsx` - Camera scanning
  - `MyCardScreen.tsx` - Profile
  - `LMSScreen.tsx` - Team analytics

- **Components** (`src/components/`)
  - `ui.tsx` - Reusable UI (buttons, cards, icons, etc.)

- **Utilities** (`src/utils/`)
  - `theme.ts` - Colors and theme
  - `data.ts` - Mock data

## Key Features

### 1. Camera Integration
- Uses `expo-camera` for business card scanning
- Requires camera permission (requested at runtime)
- Frame overlay helps position cards correctly

### 2. Navigation
- **Stack Navigator** for screens (Login → Main App)
- **Tab Navigator** for bottom tabs (Home, Leads, Scan, LMS, My Card)
- Native Android back gesture support

### 3. Data Management
- Mock data in `src/utils/data.ts`
- TypeScript types for type safety
- State management with React hooks

### 4. Styling
- Consistent theming with AskEva brand colors
- CSS-in-JS with StyleSheet
- Responsive layouts using Flexbox

## Troubleshooting

### "No compatible version found"
```bash
npm install --force
npm install expo@latest
```

### Camera permission denied
- On Android, go to Settings → Apps → AskEva → Permissions → Camera
- Enable camera permission
- Restart the app

### App crashes on startup
- Clear Expo cache: `npm start -- --clear`
- Reinstall node_modules: `rm -rf node_modules && npm install`

### QR code not scanning
- Ensure good lighting
- Try web version: `npm run web` (opens in browser)
- Terminal output shows URL you can type in Expo Go

### Port 19000 already in use
```bash
# Kill the process or use a different port
npm start -- --port 19001
```

## Adding New Features

### Add a New Screen

1. Create file `src/screens/NewScreen.tsx`:
```typescript
import React from 'react';
import { View, SafeAreaView } from 'react-native';
import { AppBar } from '../components/ui';
import { EVA } from '../utils/theme';

export default function NewScreen({ navigation }: any) {
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: EVA.surface }}>
      <AppBar title="New Screen" />
      <View>{/* Your content */}</View>
    </SafeAreaView>
  );
}
```

2. Add to navigation in `src/App.tsx`:
```typescript
<Stack.Screen name="NewScreen" component={NewScreen} />
```

### Add Icons
Edit `src/components/ui.tsx` and add to the `iconMap` in the `Icon` component.

## Testing Features

### Mock Authentication
- Email: `priya.rao@askeva.io`
- Password: Any value (not validated in prototype)

### Sample Data
- 3 pre-loaded leads
- Team leaderboard with mock stats
- Activity history

## Performance Tips

1. **Use React DevTools:**
   ```bash
   npm install -g react-devtools
   react-devtools
   ```

2. **Monitor app size:**
   - APK size ~40-60MB (typical React Native app)
   - Compress images in `assets/` folder

3. **Optimize re-renders:**
   - Use `React.memo()` for list items
   - Implement `useMemo()` for expensive calculations

## Next Steps

1. **Replace Mock Data:**
   - Connect to real API in `src/utils/data.ts`
   - Add AsyncStorage for persistence

2. **Implement OCR:**
   - Integrate Google Vision API or similar
   - Process captured business card images

3. **Add Backend Sync:**
   - REST API or Firebase
   - Real-time sync status

4. **Push Notifications:**
   - Use `expo-notifications`
   - For reminders and follow-ups

## Useful Commands

```bash
npm start                    # Start dev server
npm run android             # Start for Android
npm run web                 # Start web version
npm run eject               # Convert to bare React Native
expo prebuild               # Prepare for native compilation
eas build                   # Build with EAS Build service
```

## Resources

- **Expo Docs:** https://docs.expo.dev
- **React Native Docs:** https://reactnative.dev
- **React Navigation:** https://reactnavigation.org
- **Expo Camera:** https://docs.expo.dev/camera/overview/

## Support

For issues:
1. Check the terminal output for error messages
2. Clear cache: `npm start -- --clear`
3. Restart Expo Go on your device
4. Check device logs: `adb logcat` (if using Android emulator)

---

**Happy Coding! 🚀**
