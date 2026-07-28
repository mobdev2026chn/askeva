# AskEva - Quick Command Reference

## 🚀 Start Here

### Windows Users
```bash
# Double-click this file to install
install.bat

# Then run
npm start
```

### Mac/Linux Users
```bash
# Make script executable
chmod +x install.sh

# Run installation
./install.sh

# Then run
npm start
```

---

## 📱 Running the App

### Development (with hot reload)
```bash
npm start
```
Scan QR code with Expo Go

### For Android Specifically
```bash
npm run android
```

### Web Version (testing)
```bash
npm run web
```

---

## 🔧 Common Commands

```bash
# Clear cache and restart
npm start -- --clear

# Kill previous process and restart on different port
npm start -- --port 19001

# Install dependencies (if npm install fails)
npm install --force

# Update Expo
npm install expo@latest

# Check installed versions
npm list react-native
npm list expo
```

---

## 📥 First Time Setup Checklist

- [ ] Install Node.js from nodejs.org
- [ ] Download Expo Go from Google Play Store
- [ ] Navigate to project folder
- [ ] Run `npm install` (takes 2-3 minutes)
- [ ] Run `npm start`
- [ ] Scan QR code with Expo Go
- [ ] See app on your phone!

---

## 🐛 If Something Goes Wrong

### "npm install" fails
```bash
npm install --force
npm cache clean --force
npm install
```

### Port already in use
```bash
# Use different port
npm start -- --port 19001
```

### Camera not working
```
Settings → Apps → Permissions → Camera → Allow
Restart Expo Go
```

### App crashes on startup
```bash
npm start -- --clear
# or
rm -rf node_modules
npm install
```

### Can't find QR code
Look in terminal - you should see:
```
To open the app with Expo Go, scan this QR code: 
[QR CODE HERE]
```

If you don't see it, URL is shown:
```
exp://your.ip.address:19000
```

Type this in Expo Go manually.

---

## 📂 Project Structure

```
src/
├── screens/          ← Edit these for new screens
├── components/       ← Edit for new UI elements
├── utils/
│   ├── theme.ts     ← Change colors here
│   └── data.ts      ← Mock data here
└── types/           ← TypeScript definitions
```

---

## 🎨 Customization

### Change Colors
Edit `src/utils/theme.ts`:
```typescript
export const EVA = {
  green: '#52C41A',  // ← Change this
  greenDeep: '#3B9612',
  // ... more colors
};
```

### Change Mock Data
Edit `src/utils/data.ts`:
```typescript
export const SEED_LEADS = [
  // Edit leads here
];
```

### Add New Screen
1. Create `src/screens/NewScreen.tsx`
2. Add to `src/App.tsx` navigation
3. File auto-reloads!

---

## ✨ Features to Explore

- **Tap a lead** to see details
- **Search for leads** by name
- **Tap Scan** to test camera (requires permission)
- **Filter by status** on Leads page
- **Check LMS** for team stats
- **Edit your card** on My Card page

---

## 🚢 Deploy When Ready

### Create APK for distribution
```bash
eas build --platform android
```

### Or use Expo's build service
```bash
expo build:android
```

---

## 📚 Documentation Files

- `README.md` - Quick overview
- `SETUP_GUIDE.md` - Detailed setup
- `CONVERSION_SUMMARY.md` - What was built
- This file - Quick reference

---

## 💬 Need Help?

**Q: How do I reload the app?**
A: Press `r` in terminal or shake device → Refresh

**Q: How do I edit code?**
A: Edit any file in `src/`, save, and see changes instantly!

**Q: Can I use it offline?**
A: Yes, mock data is local. No internet needed for testing.

**Q: Can I build it into an APK?**
A: Yes! Use `eas build --platform android` for standalone APK

---

## 🎯 Typical Workflow

1. Edit code in `src/`
2. Save file
3. Changes appear on phone automatically
4. If stuck, press `r` in terminal
5. Deploy when ready

**That's it!** 🎉

---

**Happy Coding!** 🚀
