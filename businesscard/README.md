# AskEva Android App - Quick Start

## 30-Second Setup

### 1. Install Dependencies
```bash
cd "Business card scanning system"
npm install
```

### 2. Start Development Server
```bash
npm start
```

### 3. Open in Expo Go
- Download **Expo Go** from Google Play Store
- Scan the QR code shown in terminal
- App loads on your device!

## What's Inside

✅ **Screens:**
- Login authentication
- Home dashboard with stats
- Lead list with search & filter
- Lead detail view
- Business card scanner (camera)
- Personal business card
- Team analytics dashboard

✅ **Features:**
- Tab-based navigation
- Beautiful AskEva brand colors
- Responsive layouts
- Mock data included
- TypeScript support

## First Time Running?

1. Make sure you have **Node.js** installed
2. Have **Expo Go** app on your Android phone
3. Run commands above
4. Point camera at QR code in terminal

## Can't See QR Code?

Open this URL in Expo Go instead:
```
expo.dev
```
Then manually enter your computer's IP shown in terminal.

## Making Changes

Edit any file in `src/` and changes appear instantly!

Press `r` in terminal to reload, or shake device → "Refresh"

## Next Steps

- Read [SETUP_GUIDE.md](./SETUP_GUIDE.md) for detailed instructions
- Check [src/screens](./src/screens) for screen code
- Modify [src/utils/data.ts](./src/utils/data.ts) to change sample data
- View [src/utils/theme.ts](./src/utils/theme.ts) to customize colors

## Common Issues

**"npm install fails"**
```bash
npm install --force
npm install expo@latest
```

**"Camera permission denied"**
→ Go to Settings → Apps → Permissions → Camera → Allow

**"Port already in use"**
```bash
npm start -- --port 19001
```

---

For full documentation, see `SETUP_GUIDE.md`
