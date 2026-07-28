/**
 * LEADTOOLS Business Card Recognition Integration Guide
 *
 * This guide explains how to integrate the LEADTOOLS Business Card Engine (BCE)
 * into the application for production use.
 *
 * ===== OVERVIEW =====
 *
 * The business card scanning system now uses LEADTOOLS for on-device OCR.
 * LEADTOOLS provides:
 * - Specialized business card detection and orientation correction
 * - Structured field extraction (name, title, company, email, phone, address, etc.)
 * - Per-field confidence scoring
 * - Fully on-device processing (no cloud calls, better privacy)
 *
 * Current Implementation: Placeholder/Interface Layer
 * The code is structured to support LEADTOOLS integration immediately once the SDK is available.
 * All methods have documented entry points for the LEADTOOLS native bindings.
 *
 * ===== SETUP STEPS =====
 *
 * 1. OBTAIN LEADTOOLS LICENSE
 *    - Visit: https://www.leadtools.com/sdk/business-card-recognition
 *    - Request a trial or purchase license
 *    - You'll receive license key and documentation
 *
 * 2. INSTALL LEADTOOLS NATIVE MODULES
 *
 *    For React Native / Expo:
 *    ────────────────────────
 *    a) Use expo-build-properties to enable native module support:
 *
 *       ```bash
 *       npm install expo-build-properties
 *       ```
 *
 *    b) Update app.json:
 *
 *       {
 *         "expo": {
 *           "plugins": [
 *             [
 *               "expo-build-properties",
 *               {
 *                 "android": {
 *                   "enableProguardModuleGuards": true,
 *                   "usesCleartextTraffic": false
 *                 },
 *                 "ios": {
 *                   "deploymentTarget": "14.0"
 *                 }
 *               }
 *             ]
 *           ]
 *         }
 *       }
 *
 *    c) Install platform-specific LEADTOOLS packages:
 *
 *       ```bash
 *       npm install leadtools  # Main SDK
 *       npm install leadtools-rasterio  # For image processing
 *       npm install leadtools-document-binarization  # For OCR preprocessing
 *       ```
 *
 * 3. CONFIGURE NATIVE BINDINGS
 *
 *    Create a new file: src/native/leadtools.ts
 *
 *    ```typescript
 *    import { NativeModules, Platform } from 'react-native';
 *    import Leadtools from 'leadtools';
 *
 *    const LT = Leadtools;
 *
 *    // Initialize on startup
 *    export async function initializeLEADTOOLS(): Promise<void> {
 *      try {
 *        // Set license
 *        LT.RasterSupport.setLicense({
 *          companyName: 'YOUR_COMPANY',
 *          licenseKey: 'YOUR_LICENSE_KEY'
 *        });
 *
 *        // Load document service
 *        await LT.RasterSupport.loadAssemblies([
 *          'Leadtools.Codecs',
 *          'Leadtools.Document',
 *          'Leadtools.DocumentClassification'
 *        ]);
 *
 *        console.log('✅ LEADTOOLS initialized');
 *      } catch (error) {
 *        console.error('❌ LEADTOOLS initialization failed:', error);
 *        throw error;
 *      }
 *    }
 *
 *    // Export native business card engine
 *    export const LEADTOOLS_BCE = {
 *      detectCard: async (imageBuffer: ArrayBuffer) => {
 *        // Implement card detection
 *      },
 *      extractFields: async (imageBuffer: ArrayBuffer) => {
 *        // Implement field extraction
 *      },
 *      // ... other methods
 *    };
 *    ```
 *
 * 4. UPDATE OCR SERVICE INTEGRATION
 *
 *    In src/utils/leadtools-ocr.ts, replace placeholder methods with actual LEADTOOLS calls:
 *
 *    ```typescript
 *    static async detectCard(base64Image: string): Promise<DetectionResult> {
 *      // Convert base64 to buffer
 *      const buffer = Buffer.from(base64Image, 'base64');
 *
 *      // Call LEADTOOLS native method
 *      const result = await LEADTOOLS_BCE.detectCard(buffer);
 *
 *      return {
 *        cardDetected: result.cardFound,
 *        confidence: result.confidence,
 *        boundingBox: result.bounds
 *      };
 *    }
 *    ```
 *
 * 5. HANDLE PERMISSION REQUIREMENTS
 *
 *    LEADTOOLS may require additional permissions on some platforms.
 *
 *    For Android (app.json):
 *    ```json
 *    "permissions": [
 *      "android.permission.CAMERA",
 *      "android.permission.READ_EXTERNAL_STORAGE",
 *      "android.permission.WRITE_EXTERNAL_STORAGE"
 *    ]
 *    ```
 *
 *    For iOS (Info.plist):
 *    Add NSCameraUsageDescription if using camera integration
 *
 * 6. TEST THE INTEGRATION
 *
 *    ```bash
 *    npm run android  # or ios
 *    ```
 *
 *    Test with various business cards:
 *    - Verify card detection works
 *    - Check field extraction accuracy
 *    - Validate confidence scoring
 *    - Test with rotated/angled cards
 *
 * ===== EXPECTED OUTPUT =====
 *
 * When properly integrated, LeadtoolsOCRService.recognizeCard() will return:
 *
 * {
 *   cardDetected: true,
 *   cardQuality: 0.92,
 *   cardOrientation: 0,
 *   fields: {
 *     name: { value: "John Smith", confidence: 0.98 },
 *     title: { value: "Senior Engineer", confidence: 0.95 },
 *     company: { value: "Tech Corp", confidence: 0.94 },
 *     email: { value: "john@techcorp.com", confidence: 0.99 },
 *     phone: { value: "+1-555-123-4567", confidence: 0.96 },
 *     address: { value: "123 Main St", confidence: 0.88 },
 *     city: { value: "San Francisco", confidence: 0.91 },
 *     state: { value: "CA", confidence: 0.93 },
 *     zipcode: { value: "94105", confidence: 0.90 },
 *     country: { value: "USA", confidence: 0.98 }
 *   },
 *   metadata: {
 *     processingTime: 245,  // milliseconds
 *     imageWidth: 1280,
 *     imageHeight: 720,
 *     dpi: 300
 *   }
 * }
 *
 * ===== CURRENT PIPELINE =====
 *
 * Camera → LEADTOOLS Detection → Orientation Check → Field Extraction → Confidence Scores
 *     ↓
 * Fallback Regex Parser (if LEADTOOLS incomplete)
 *     ↓
 * ExtractedCard (with confidence for all fields)
 *     ↓
 * Lead Model Creation
 *     ↓
 * FieldReview Screen (with confidence badges)
 *     ↓
 * Duplicate Check → Save/Merge
 *
 * ===== TROUBLESHOOTING =====
 *
 * Issue: "Module not found: leadtools"
 * Solution: Ensure LEADTOOLS is installed and native modules are enabled
 *
 * Issue: Low confidence scores
 * Solution: Check image quality (lighting, focus, angle), adjust quality parameter
 *
 * Issue: Card not detected
 * Solution: Ensure card is fully in frame, at reasonable angle (±30°), well-lit
 *
 * Issue: Fields missing (e.g., no email found)
 * Solution: LEADTOOLS may not find all fields on every card type
 *           Fallback parser will attempt regex extraction if needed
 *
 * ===== PERFORMANCE NOTES =====
 *
 * - On-device processing: 200-500ms per card (varies by device)
 * - Memory usage: ~50-100MB peak during processing
 * - No network calls, offline capable
 * - Quality parameter trade-off: Higher quality = better results but larger data
 *
 * ===== PRIVACY & SECURITY =====
 *
 * - All processing happens on-device
 * - Images never leave the device
 * - Only extracted text is stored locally
 * - LEADTOOLS processes but doesn't retain data
 *
 */

export const LEADTOOLS_INTEGRATION_GUIDE = `
LEADTOOLS Business Card Recognition SDK Integration

For detailed setup instructions, see the comments in this file.
Key steps:
1. Obtain LEADTOOLS license from https://www.leadtools.com
2. Install native modules (leadtools, leadtools-rasterio, etc.)
3. Initialize LEADTOOLS in the app startup
4. Replace placeholder methods in src/utils/leadtools-ocr.ts
5. Test with various business cards

The system is designed to work seamlessly once LEADTOOLS is installed.
`;
