# AskEva Business Card Scanning App - Codebase Analysis

## Executive Summary

This React Native (Expo) application is a **partially implemented** business card scanning and lead management system. The current implementation focuses on **UI screens and navigation** with mock data, but **all core business logic is missing**:

- ❌ **OCR extraction** - Not implemented
- ❌ **Field mapping** - Not implemented  
- ❌ **Duplicate detection** - Not implemented
- ❌ **Data persistence** - Not implemented
- ❌ **Image processing** - Not implemented

The original web-based implementation (JSX files) contains a complete reference implementation of all these features, but was not ported to React Native.

---

## 1. CAMERA SCANNING FLOW

### Current Implementation: `src/screens/ScanScreen.tsx`

**Status:** ✅ UI Complete | ❌ Processing Missing

#### What's Implemented:
- ✅ Camera permission handling with `expo-camera`
- ✅ Frame overlay for card positioning
- ✅ Flip camera button (back/front)
- ✅ Capture button UI
- ✅ Photo capture via `cameraRef.current.takePictureAsync()`

#### What's Missing:
```typescript
// Lines 29-42 - takePicture() function
const takePicture = async () => {
  // ...
  const photo = await cameraRef.current.takePictureAsync();
  // ❌ IMAGE NOT PROCESSED - just shows alert
  Alert.alert('Success', 'Card captured! Processing...', [
    { text: 'Continue', onPress: () => navigation.goBack() },
  ]);
};
```

**Issues:**
1. Photo captured but immediately discarded
2. No image passed to OCR service
3. No state management for captured image
4. No navigation to review/processing screen

---

## 2. OCR EXTRACTION LOGIC

### Current Implementation: **NONE**

**Status:** ❌ Completely Missing

### Reference Implementation: `screens-1.jsx` (Web Version)

The original web implementation has a complete OCR pipeline:

```jsx
// ScreenProcessing - Lines 437-525 in screens-1.jsx
// Shows 4-step OCR process with timing:
const steps = [
  { k: 'detect',  l: 'Detecting edges' },        // 500ms
  { k: 'ocr',     l: 'Reading text · OCR' },     // +550ms = 1050ms
  { k: 'parse',   l: 'Parsing fields' },         // +450ms = 1500ms
  { k: 'dedupe',  l: 'Checking for duplicates' }, // +450ms = 1950ms
];
```

**What Should Happen:**
1. **Edge Detection** - Prepare image for OCR
2. **OCR Reading** - Extract text from business card using vision API
3. **Field Parsing** - Map extracted text to Lead fields
4. **Duplicate Check** - Compare against existing leads

### Missing Dependencies:
- No vision API integration (Google Vision, Tesseract, etc.)
- No image processing library
- No service layer for OCR calls
- No confidence scoring system

### Expected Output:
```typescript
interface ExtractedCard {
  name: string;        // confidence: 0-1
  role: string;        // confidence: 0-1
  company: string;     // confidence: 0-1
  email: string;       // confidence: 0-1
  phone: string;       // confidence: 0-1
  location: string;    // confidence: 0-1
  conf: {              // confidence scores per field
    name: 0.95;
    role: 0.88;
    company: 0.92;
    email: 0.99;
    phone: 0.87;
    location: 0.74;
  }
}
```

---

## 3. FIELD MAPPING PROCESS

### Current Implementation: **NONE**

**Status:** ❌ Completely Missing

### Reference Implementation: `screens-1.jsx` Lines 561-715

The web version has full field mapping logic in **ScreenReview**:

**Current Review Screen Structure (Expected):**
```tsx
// Should show 6-8 fields with confidence indicators:
- Name         [✓] confidence: 0.95
- Role         [⚠] confidence: 0.74  ← Low confidence
- Company      [✓] confidence: 0.92
- Email        [✓] confidence: 0.99
- Phone        [✓] confidence: 0.87
- Location     [⚠] confidence: 0.68  ← Flagged
```

**Mapping to Lead Model:**
```typescript
// From types/index.ts
interface Lead {
  name: string;        // ← mapped from extracted card.name
  role: string;        // ← mapped from extracted card.role
  company: string;     // ← mapped from extracted card.company
  email: string;       // ← mapped from extracted card.email
  phone: string;       // ← mapped from extracted card.phone
  location: string;    // ← mapped from extracted card.location
  status: 'new' | 'contacted' | 'followup';
  event: string;
  capturedAt: string;
  capturedBy: string;
  // ... other fields
}
```

**Missing Features:**
1. No confidence score display
2. No field edit capability
3. No validation rules
4. No field transformation/normalization
5. No user correction workflow

### React Native ScanScreen Issue:
The current `LeadDetailScreen.tsx` just displays mock data - there's no screen that collects/reviews OCR results before saving.

---

## 4. SAVE/STORAGE LOGIC

### Current Implementation: Partial Mock

**Status:** ⚠️ UI Present | ❌ Persistence Missing

### What Exists:
1. **Mock Data:** `src/utils/data.ts`
   - `SEED_LEADS` array with 2 sample leads
   - Used in LeadListScreen and LeadDetailScreen
   - Stored in component state only

2. **Data Model:** `src/types/index.ts`
   - Complete TypeScript interfaces for Lead, User, etc.
   - Properly structured for persistence

3. **UI for Display:** `src/screens/LeadListScreen.tsx`
   ```tsx
   const [leads, setLeads] = useState<Lead[]>(SEED_LEADS);
   // ❌ Only local state, not persisted
   ```

### What's Missing:

#### 1. **Local Storage (AsyncStorage)**
```typescript
// Should be added but isn't:
import AsyncStorage from '@react-native-async-storage/async-storage';

// Save lead
const saveLead = async (lead: Lead) => {
  const leads = await AsyncStorage.getItem('leads');
  const existing = leads ? JSON.parse(leads) : [];
  existing.push(lead);
  await AsyncStorage.setItem('leads', JSON.stringify(existing));
};

// Load leads on app start
useEffect(() => {
  const loadLeads = async () => {
    const leads = await AsyncStorage.getItem('leads');
    if (leads) setLeads(JSON.parse(leads));
  };
  loadLeads();
}, []);
```

**Package available but not used:**
```json
"@react-native-async-storage/async-storage": "2.2.0"
```

#### 2. **Backend API**
- No API service layer
- No sync mechanism
- No user authentication integration
- No lead upload/sync to server

#### 3. **Generated Fields**
The Lead model expects these computed fields on creation:
```typescript
status: 'new',                      // ❌ Not set
event: 'SaaStock 2026',             // ❌ Not set
capturedAt: '2 h',                  // ❌ Not set (should be timestamp)
capturedBy: 'priya',                // ❌ Not set (should use logged-in user)
score: 87,                          // ❌ Not calculated
scoreBreak: { ... },                // ❌ Not calculated
activity: [{ t, k, text }],         // ❌ Not initialized
```

---

## 5. DUPLICATE DETECTION LOGIC

### Current Implementation: **NONE**

**Status:** ❌ Completely Missing

### Reference Implementation: `screens-1.jsx` Lines 722-890

The web version has 3 duplicate states with full UI:

#### **State 1: EXACT Duplicate (100% match)**
```typescript
// All fields match existing lead
{
  matchType: 'exact',
  existing: { id: 'rohan', name: 'Rohan Mehta', ... },
  incoming: { name: 'Rohan Mehta', ... },
  confidence: 100
}
// Result: Don't create new record, show existing lead
```

#### **State 2: POSSIBLE Duplicate (85-99% match)**
```typescript
// Phone + company match, but other fields differ
{
  matchType: 'possible',
  matchScore: 92,
  existing: Lead,
  incoming: Lead,
  diffs: {
    role: { from: 'VP, Sales', to: 'VP, Engineering' },
    email: { from: 'old@email.com', to: 'new@email.com' },
    location: { from: 'Mumbai', to: 'Bangalore' }
  }
}
// Result: Show merge UI, let user pick which fields to update
```

#### **State 3: NO Duplicate**
```typescript
// No matching records found
{
  matchType: 'new'
}
// Result: Create new lead
```

### Duplicate Detection Algorithm:
The web version uses a matching strategy:

```javascript
// From screens-1.jsx - implied logic:
function findDuplicate(incoming) {
  // Try to find exact match (all fields)
  const exact = leads.find(l => 
    l.name === incoming.name &&
    l.phone === incoming.phone &&
    l.company === incoming.company &&
    l.email === incoming.email
  );
  
  if (exact) return { matchType: 'exact', existing: exact };
  
  // Try to find possible match (phone + company)
  const possible = leads.find(l =>
    (l.phone === incoming.phone && l.company === incoming.company) ||
    (l.email === incoming.email && l.phone === incoming.phone)
  );
  
  if (possible) {
    const score = calculateMatchScore(possible, incoming);
    if (score > 0.85) {
      return { matchType: 'possible', existing: possible, score };
    }
  }
  
  return { matchType: 'new' };
}
```

### Missing Implementation Checklist:
- ❌ Duplicate detection service
- ❌ Match scoring algorithm
- ❌ Diff calculation
- ❌ Smart merge UI
- ❌ Merge/update logic
- ❌ Duplicate review screen

---

## 6. LEAD LIST DISPLAY

### Current Implementation: `src/screens/LeadListScreen.tsx`

**Status:** ✅ UI Complete | ⚠️ Data Mock Only

#### What's Implemented:
- ✅ Lead card rendering
- ✅ Search by name/company
- ✅ Filter by status (All, New, Contacted, Follow-up)
- ✅ Score badge with color coding (green ≥80, orange <80)
- ✅ Lead metadata display (captured time, capturedBy)
- ✅ Tags/chips display
- ✅ Empty state
- ✅ Navigation to LeadDetailScreen

#### Data Source:
```typescript
// LeadListScreen.tsx - Line 15
const [leads, setLeads] = useState<Lead[]>(SEED_LEADS);
// ❌ Only 2 mock leads from src/utils/data.ts
```

#### What Works:
```typescript
// Filtering
const filtered = leads.filter((lead) => {
  const matchesSearch = lead.name.toLowerCase().includes(searchText.toLowerCase());
  const matchesFilter = !filterStatus || lead.status === filterStatus;
  return matchesSearch && matchesFilter;
});

// Display
renderLead = ({ item }: { item: Lead }) => (
  // Shows: name, role, company, score, tags
);
```

#### What's Missing:
1. **Data Persistence**: Changes to leads list don't persist
2. **Add New Leads**: No way to add new leads from scan (flow broken)
3. **Real Data**: Only 2 mock leads hardcoded
4. **Sync Indicator**: No indication if data is synced with backend
5. **Edit Inline**: Can view detail but updating doesn't persist

---

## 7. DATA FLOW DIAGRAM

### Current (Broken) Flow:

```
┌─────────────┐
│  ScanScreen │  ← User taps camera
└──────┬──────┘
       │
       ├─ Camera Permission Check ✅
       │
       ├─ Take Photo ✅
       │
       └─ Alert.alert("Success") ❌
          └─ Navigate.goBack()
             
             ❌ NO DATA TRANSFER
             ❌ IMAGE DISCARDED
             ❌ NO OCR
             ❌ NO LEAD CREATED
```

### Expected Flow (from web version):

```
┌────────────────────────────────────────────────────────────┐
│ ScanScreen (Camera)                                        │
│ - Take photo ✅                                            │
│ - Pass image to OCR service                               │
└────────┬─────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│ ScreenProcessing (OCR Pipeline)                            │
│ - Detect edges (500ms)                                    │
│ - OCR reading (500-1000ms)                                │
│ - Parse fields (400-500ms)                                │
│ - Check duplicates (400-500ms)                            │
│ ✅ Output: ExtractedCard with confidence scores           │
└────────┬─────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│ ScreenReview (Field Review & Edit)                        │
│ - Display extracted fields with confidence               │
│ - Allow user to edit/correct fields                      │
│ - Highlight low-confidence fields                        │
│ ✅ Output: Reviewed Lead data                             │
└────────┬─────────────────────────────────────────────────┘
         │
         ▼ (Trigger duplicate check)
┌────────────────────────────────────────────────────────────┐
│ ScreenDuplicate (Conflict Resolution)                     │
│ Case 1 (EXACT): Show existing lead, don't save new      │
│ Case 2 (POSSIBLE): Show merge UI, let user pick updates │
│ Case 3 (NEW): Proceed to save                            │
│ ✅ Output: Final Lead to save or merge decision          │
└────────┬─────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│ ScreenSaving (Save to Storage)                            │
│ - Save to local storage (AsyncStorage)                   │
│ - Sync to backend API                                    │
│ - Update activity log                                    │
│ ✅ Output: Saved Lead added to list                       │
└────────┬─────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│ ScreenSuccess (Confirmation)                              │
│ - Show saved lead preview                                │
│ - Show next action buttons                               │
└────────────────────────────────────────────────────────────┘
         │
         ▼
    LeadListScreen (Updated with new lead)
```

---

## 8. CURRENT vs INTENDED SCREEN FLOW

### App Navigation: `src/App.tsx`

**Current Stack:**
```
Login
└─ Main (Tab Navigator)
   ├─ Home (HomeScreen)
   ├─ Leads (LeadListScreen)
   ├─ Scan (ScanScreen) ← BROKEN
   ├─ LMS (LMSScreen)
   └─ My Card (MyCardScreen)

Modal Stack:
└─ LeadDetail (LeadDetailScreen) - for viewing existing leads
```

**Missing Screens** (from web version):
```
├─ ScreenCrop (Image crop/rotate) - after capture
├─ ScreenProcessing (OCR loading) - during OCR
├─ ScreenReview (Field editing) - review extracted data
├─ ScreenDuplicate (Merge UI) - resolve conflicts
├─ ScreenSaving (Save confirmation) - during save
└─ ScreenSuccess (Success screen) - after save
```

---

## 9. COMPONENT SUMMARY

### Implemented Components: `src/components/ui.tsx`

```typescript
✅ Icon         - Icon rendering (25+ icons)
✅ AppBar       - Header with title/subtitle
✅ Button       - Primary, secondary, ghost variants
✅ Card         - Content container
✅ Chip         - Tag/label component
✅ TextInput    - Text field component
```

### Screens Status:

| Screen | UI | Logic | State | Data | Notes |
|--------|----|----|-------|----|-------|
| LoginScreen | ✅ | ⚠️ Mock | ❌ | ❌ | Email/OTP, no real auth |
| HomeScreen | ✅ | ✅ Partial | ✅ | ❌ Mock | Dashboard with mock data |
| LeadListScreen | ✅ | ✅ Partial | ✅ | ❌ Mock | Search/filter works, no persistence |
| LeadDetailScreen | ✅ | ✅ | ✅ | ❌ Mock | Display only, mock lead lookup |
| ScanScreen | ✅ | ❌ | ⚠️ | ❌ | **CRITICAL: Image discarded** |
| MyCardScreen | ✅ | ✅ | ✅ | ⚠️ | Hardcoded user data from utils/data.ts |
| LMSScreen | ✅ | ✅ | ✅ | ⚠️ | Mock team data from utils/data.ts |

---

## 10. MISSING SERVICES/UTILITIES

### Not Implemented:

```typescript
// NO IMAGE PROCESSING SERVICE
// NO OCR SERVICE
// NO DUPLICATE DETECTION SERVICE
// NO FIELD MAPPING SERVICE
// NO STORAGE SERVICE
// NO API SERVICE
// NO AUTHENTICATION SERVICE (beyond mock)
```

### Package Dependencies Available:

```json
{
  "@react-native-async-storage/async-storage": "2.2.0",  // ← Not used
  "expo-camera": "~17.0.10",                             // ← Partially used
  "react-native": "0.81.5"                               // ← Used for UI
}
```

### Missing Packages Needed:

```json
{
  "firebase": "^11.0.0",              // Backend + auth
  // OR
  "react-native-quick-base64": "^2.x",// Image processing
  "tesseract.js-core": "^5.x",        // OCR (offline)
  // OR
  "@google-cloud/vision": "^4.x",    // Google Vision API
  "react-native-fs": "^2.x",          // File system access
  "uuid": "^9.x"                      // Lead ID generation
}
```

---

## 11. BROKEN/INCOMPLETE FEATURES

### Critical Issues:

| Issue | Severity | Component | Fix Required |
|-------|----------|-----------|--------------|
| **Image discarded after capture** | 🔴 CRITICAL | ScanScreen | Process image with OCR service |
| **No OCR pipeline** | 🔴 CRITICAL | Missing service | Implement or integrate OCR API |
| **No duplicate detection** | 🔴 CRITICAL | Missing service | Add duplicate checking logic |
| **No data persistence** | 🔴 CRITICAL | All screens | Implement AsyncStorage + backend |
| **No field review screen** | 🔴 CRITICAL | Navigation | Add ScreenReview component |
| **No duplicate UI** | 🔴 CRITICAL | Navigation | Add ScreenDuplicate component |
| **No new lead creation** | 🔴 CRITICAL | LeadListScreen | Wire up scan → create → list flow |
| **No field mapping** | 🟠 HIGH | Missing service | Map OCR output to Lead model |
| **No confidence scoring** | 🟠 HIGH | Missing service | Add OCR confidence per field |
| **No sync mechanism** | 🟠 HIGH | Missing service | Implement backend sync |
| **Mock authentication** | 🟠 HIGH | LoginScreen | Integrate real auth |
| **Hardcoded user data** | 🟠 HIGH | MyCardScreen | Load from user profile |

---

## 12. RECOMMENDATIONS FOR FIXES

### Phase 1: Data Persistence (Foundation)
```
1. Set up AsyncStorage for local persistence
2. Create storage service layer
3. Load/save leads on app lifecycle
4. Update all screens to use persisted data
```

### Phase 2: Image Processing Pipeline
```
1. Implement image capture → storage
2. Add image preview/crop screen
3. Integrate OCR service (choose: Google Vision, Tesseract, etc.)
4. Create OCR service wrapper
5. Add processing loader screen
```

### Phase 3: Lead Creation Flow
```
1. Add field review screen
2. Implement field mapping
3. Add confidence scoring display
4. Add user correction workflow
5. Store extracted lead data
```

### Phase 4: Duplicate Detection
```
1. Implement duplicate detection algorithm
2. Create merge UI screen
3. Add smart merge logic
4. Show merge conflict resolution
```

### Phase 5: Backend Integration
```
1. Set up API service layer
2. Implement lead sync
3. Add real authentication
4. Implement cloud backup
```

---

## 13. FILE REFERENCE CHECKLIST

### React Native Implementation (Incomplete):
- ✅ `src/App.tsx` - Navigation setup
- ✅ `src/screens/ScanScreen.tsx` - Camera UI only
- ✅ `src/screens/LeadListScreen.tsx` - List UI only
- ✅ `src/screens/LeadDetailScreen.tsx` - Detail UI only
- ✅ `src/screens/HomeScreen.tsx` - Dashboard UI only
- ✅ `src/screens/MyCardScreen.tsx` - Profile UI only
- ✅ `src/screens/LMSScreen.tsx` - Analytics UI only
- ✅ `src/components/ui.tsx` - UI components
- ⚠️ `src/utils/data.ts` - Only mock data
- ⚠️ `src/utils/theme.ts` - Only styling
- ❌ `src/utils/ocr.ts` - MISSING
- ❌ `src/utils/storage.ts` - MISSING
- ❌ `src/utils/api.ts` - MISSING
- ❌ `src/utils/duplicate.ts` - MISSING
- ❌ `src/types/index.ts` - Has models, no validation

### Web Reference Implementation (Complete):
- ✅ `screens-1.jsx` - Full OCR, review, duplicate screens
- ✅ `screens-2.jsx` - Additional screens
- ✅ `screens-3.jsx` - More screens
- ✅ `app.jsx` - Navigation + state management
- ✅ `data.jsx` - Data models + mock scenarios

---

## 14. SUMMARY TABLE

| Feature | Status | Notes |
|---------|--------|-------|
| **Camera UI** | ✅ Done | Frame overlay, permissions, capture button |
| **Photo Capture** | ✅ Done | Image captured but immediately discarded |
| **Image Processing** | ❌ Missing | No crop/rotate/enhancement |
| **OCR Service** | ❌ Missing | No text extraction from image |
| **Field Extraction** | ❌ Missing | No parsing of extracted text |
| **Field Mapping** | ❌ Missing | OCR output → Lead model |
| **Confidence Scoring** | ❌ Missing | No per-field confidence |
| **Duplicate Detection** | ❌ Missing | No matching algorithm |
| **Merge UI** | ❌ Missing | No conflict resolution screen |
| **Field Review** | ❌ Missing | No edit before save screen |
| **Local Storage** | ❌ Missing | No AsyncStorage implementation |
| **Backend API** | ❌ Missing | No server sync |
| **Authentication** | ⚠️ Mock | Login screen exists, not functional |
| **Lead List Display** | ✅ Done | Works with mock data |
| **Lead Detail View** | ✅ Done | Works with mock data |
| **Dashboard/Home** | ✅ Done | Works with mock data |
| **Team Analytics** | ✅ Done | Works with mock data |
| **Personal Card** | ✅ Done | Shows hardcoded user |

---

## CONCLUSION

The application is essentially a **UI-only implementation** with complete navigation and component structure, but **zero core business logic**. The scanning workflow is completely broken because the captured image is immediately discarded. 

To make this a functional business card scanning app, you need to:

1. **Connect the OCR pipeline** - Choose an OCR provider (Google Vision, Tesseract, etc.)
2. **Implement data persistence** - Use AsyncStorage + optional backend
3. **Add the review screens** - Field review, duplicate detection UI
4. **Complete the save flow** - Store new leads, merge duplicates
5. **Integrate authentication** - Real user auth instead of mock

**Reference**: The original web implementation in `screens-1.jsx`, `app.jsx`, and `data.jsx` contains a complete working example of all these features that can be ported to React Native.
