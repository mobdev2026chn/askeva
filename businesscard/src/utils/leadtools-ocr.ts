/**
 * LEADTOOLS Business Card Recognition Service
 * On-device OCR for business card scanning with structured field extraction
 *
 * This service provides:
 * - Card detection and orientation correction
 * - Structured field extraction (name, title, company, email, phone, etc.)
 * - Per-field confidence scoring
 * - Fully on-device processing (no cloud calls, better privacy)
 *
 * Integration: This service wraps LEADTOOLS BCE (Business Card Engine)
 * For production use, install the LEADTOOLS SDK and configure native bindings.
 */

export interface LeadtoolsCardResult {
  /**
   * Detected business card image (preprocessed, rotated if needed)
   */
  cardImage: string; // base64

  /**
   * Card detected in frame (true = valid card region found, false = no card)
   */
  cardDetected: boolean;

  /**
   * Card orientation in degrees (0, 90, 180, 270)
   */
  cardOrientation: number;

  /**
   * Structured fields extracted from the card
   */
  fields: {
    // Primary identification
    name?: {
      value: string;
      confidence: number; // 0-1
      boundingBox?: { x: number; y: number; width: number; height: number };
    };
    title?: {
      value: string;
      confidence: number;
      boundingBox?: { x: number; y: number; width: number; height: number };
    };
    company?: {
      value: string;
      confidence: number;
      boundingBox?: { x: number; y: number; width: number; height: number };
    };

    // Contact info
    email?: {
      value: string;
      confidence: number;
      boundingBox?: { x: number; y: number; width: number; height: number };
    };
    phone?: {
      value: string;
      confidence: number;
      boundingBox?: { x: number; y: number; width: number; height: number };
    };
    website?: {
      value: string;
      confidence: number;
      boundingBox?: { x: number; y: number; width: number; height: number };
    };

    // Location / Address
    address?: {
      value: string;
      confidence: number;
      boundingBox?: { x: number; y: number; width: number; height: number };
    };
    city?: {
      value: string;
      confidence: number;
      boundingBox?: { x: number; y: number; width: number; height: number };
    };
    state?: {
      value: string;
      confidence: number;
      boundingBox?: { x: number; y: number; width: number; height: number };
    };
    zipcode?: {
      value: string;
      confidence: number;
      boundingBox?: { x: number; y: number; width: number; height: number };
    };
    country?: {
      value: string;
      confidence: number;
      boundingBox?: { x: number; y: number; width: number; height: number };
    };
  };

  /**
   * Overall card quality score (0-1)
   * Indicates how legible/extractable the card is
   */
  cardQuality: number;

  /**
   * Processing metadata
   */
  metadata: {
    processingTime: number; // milliseconds
    imageWidth: number;
    imageHeight: number;
    dpi?: number;
  };
}

/**
 * LEADTOOLS Business Card Recognition Service
 *
 * Provides on-device business card OCR with structured field extraction.
 * Full privacy — no data leaves the device.
 */
export class LeadtoolsOCRService {
  /**
   * Initialize the LEADTOOLS engine
   * Call this once on app startup
   */
  static async initialize(): Promise<void> {
    // In production, this would initialize the LEADTOOLS runtime
    // For now, this is a placeholder for the full implementation
    console.log('✅ LEADTOOLS OCR Service initialized (on-device mode)');
  }

  /**
   * Detect if a business card is present in the image
   *
   * Returns:
   * - cardDetected: true if valid card region found
   * - confidence: detection confidence (0-1)
   * - boundingBox: location of detected card in the image
   *
   * @param base64Image - Raw base64 image from camera
   */
  static async detectCard(
    base64Image: string,
  ): Promise<{
    cardDetected: boolean;
    confidence: number;
    boundingBox?: { x: number; y: number; width: number; height: number };
  }> {
    if (!base64Image || base64Image.length === 0) {
      console.warn('⚠️ No image data provided to card detection');
      return { cardDetected: false, confidence: 0 };
    }

    try {
      console.log('🔍 Detecting business card in image...');
      // LEADTOOLS card detection would analyze image characteristics:
      // - Rectangular regions with text-like patterns
      // - Color contrast and brightness levels
      // - Edge detection for card boundaries

      // For production integration:
      // const detection = await LEADTOOLS_BCE.detectCard(base64Image);
      // return detection;

      // Placeholder: Return mock detection
      // In real implementation, LEADTOOLS would return actual detection
      return {
        cardDetected: true,
        confidence: 0.92,
        boundingBox: { x: 50, y: 100, width: 300, height: 200 },
      };
    } catch (error) {
      console.error('❌ Card detection error:', error);
      return { cardDetected: false, confidence: 0 };
    }
  }

  /**
   * Correct card orientation (rotation) if needed
   *
   * LEADTOOLS automatically detects and reports card orientation:
   * - 0° = correct orientation
   * - 90°, 180°, 270° = rotated
   *
   * Returns rotated image if needed
   */
  static async correctOrientation(
    base64Image: string,
  ): Promise<{
    correctedImage: string;
    detectedOrientation: number;
  }> {
    if (!base64Image) {
      return { correctedImage: base64Image, detectedOrientation: 0 };
    }

    try {
      console.log('🔄 Checking card orientation...');
      // LEADTOOLS orientation detection analyzes text direction and card layout
      // For production:
      // const result = await LEADTOOLS_BCE.detectAndCorrectOrientation(base64Image);
      // return result;

      // Placeholder
      return { correctedImage: base64Image, detectedOrientation: 0 };
    } catch (error) {
      console.error('❌ Orientation correction error:', error);
      return { correctedImage: base64Image, detectedOrientation: 0 };
    }
  }

  /**
   * Extract structured business card fields using LEADTOOLS
   *
   * Returns individual fields with per-field confidence scores
   *
   * @param base64Image - Raw or preprocessed card image
   */
  static async extractStructuredFields(
    base64Image: string,
  ): Promise<LeadtoolsCardResult['fields']> {
    if (!base64Image || base64Image.length === 0) {
      console.warn('⚠️ No image data for field extraction');
      return {};
    }

    try {
      console.log('📋 Extracting structured fields from business card...');

      // LEADTOOLS Business Card Engine provides structured extraction:
      // - Name recognition trained on business card layouts
      // - Title/role classification
      // - Email/phone regex + validation
      // - Company name extraction
      // - Address parsing with city/state/zipcode separation
      // - Website URL detection

      // For production integration:
      // const result = await LEADTOOLS_BCE.extractCardFields(base64Image);
      // return this.mapLeadtoolsFieldsToInterface(result);

      // Placeholder: Return structure that will be filled by actual LEADTOOLS
      return {};
    } catch (error) {
      console.error('❌ Field extraction error:', error);
      return {};
    }
  }

  /**
   * Full card recognition pipeline
   *
   * Returns all extracted data + metadata
   *
   * @param base64Image - Raw base64 image from camera
   */
  static async recognizeCard(
    base64Image: string,
  ): Promise<LeadtoolsCardResult> {
    const startTime = Date.now();

    try {
      console.log('🚀 Starting LEADTOOLS business card recognition...');

      // Step 1: Detect card presence
      const detection = await this.detectCard(base64Image);
      if (!detection.cardDetected) {
        console.warn('⚠️ No business card detected in image');
        return {
          cardImage: base64Image,
          cardDetected: false,
          cardOrientation: 0,
          fields: {},
          cardQuality: 0,
          metadata: {
            processingTime: Date.now() - startTime,
            imageWidth: 0,
            imageHeight: 0,
          },
        };
      }

      // Step 2: Correct orientation
      const orientation = await this.correctOrientation(base64Image);

      // Step 3: Extract structured fields
      const fields = await this.extractStructuredFields(
        orientation.correctedImage,
      );

      // Step 4: Calculate overall card quality
      const cardQuality = this.calculateCardQuality(fields);

      const result: LeadtoolsCardResult = {
        cardImage: orientation.correctedImage,
        cardDetected: true,
        cardOrientation: orientation.detectedOrientation,
        fields,
        cardQuality,
        metadata: {
          processingTime: Date.now() - startTime,
          imageWidth: 0,
          imageHeight: 0,
        },
      };

      console.log('✅ Card recognition complete', {
        quality: cardQuality,
        fieldsExtracted: Object.keys(fields).length,
        time: `${result.metadata.processingTime}ms`,
      });

      return result;
    } catch (error) {
      console.error('❌ Card recognition pipeline error:', error);
      return {
        cardImage: base64Image,
        cardDetected: false,
        cardOrientation: 0,
        fields: {},
        cardQuality: 0,
        metadata: {
          processingTime: Date.now() - startTime,
          imageWidth: 0,
          imageHeight: 0,
        },
      };
    }
  }

  /**
   * Calculate overall card quality score based on extracted fields
   *
   * Quality = weighted average of field confidences
   * Missing critical fields (name, company) reduce quality
   */
  private static calculateCardQuality(
    fields: LeadtoolsCardResult['fields'],
  ): number {
    const weights = {
      name: 0.30,
      company: 0.25,
      email: 0.15,
      phone: 0.15,
      title: 0.15,
    };

    let totalWeight = 0;
    let weightedScore = 0;

    for (const [key, weight] of Object.entries(weights)) {
      const field = fields[key as keyof typeof fields];
      if (field && field.confidence > 0) {
        weightedScore += field.confidence * weight;
        totalWeight += weight;
      }
    }

    if (totalWeight === 0) return 0;
    return weightedScore / totalWeight;
  }

  /**
   * Map LEADTOOLS native fields to our interface
   *
   * This is called after LEADTOOLS returns raw results
   * Normalizes field names and confidence scores
   */
  private static mapLeadtoolsFieldsToInterface(
    nativeResult: any,
  ): LeadtoolsCardResult['fields'] {
    // In production, this would transform LEADTOOLS BCE output
    // to our standardized interface
    // For now, returns empty object (filled by actual SDK)
    return {};
  }
}

export default LeadtoolsOCRService;
