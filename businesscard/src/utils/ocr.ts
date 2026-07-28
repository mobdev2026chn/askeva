import { Lead } from '../types';
import { CURRENT_USER } from './data';
import { parseCardTextWithGemini } from '../services/api/geminiParser';

// Note: expo-file-system is intentionally NOT used here.
// We receive base64 directly from expo-camera's takePictureAsync({ base64: true })
// to avoid FileSystem native module issues in Expo Go.

export interface ExtractedCard {
  name: string;
  role: string;
  company: string;
  email: string;
  phone: string;
  location: string;
  confidence: {
    name: number;
    role: number;
    company: number;
    email: number;
    phone: number;
    location: number;
  };
  rawText: string;

  /**
   * OCR/card metadata
   */
  cardQuality?: number;
  cardDetected?: boolean;
  cardOrientation?: number;

  /**
   * Optional debugging/validation metadata.
   * Existing screens can safely ignore these fields.
   */
  ocrProvider?: string;
  ocrTextLength?: number;
  ocrError?: string;
  validationWarnings?: string[];
}

type Confidence = ExtractedCard['confidence'];

type OCRAttemptConfig = {
  name: string;
  engine: 1 | 2;
  scale: boolean;
  isTable: boolean;
  detectOrientation: boolean;
};

type OCRAttemptResult = {
  text: string;
  ok: boolean;
  error?: string;
  exitCode?: number;
  attemptName: string;
  statusCode?: number;
  rateLimited?: boolean;
};

type OCRSpaceParsedResult = {
  ParsedText?: string;
  ErrorMessage?: string | string[];
  ErrorDetails?: string | string[];
};

type OCRSpaceResponse = {
  ParsedResults?: OCRSpaceParsedResult[];
  OCRExitCode?: number;
  IsErroredOnProcessing?: boolean;
  ErrorMessage?: string | string[];
  ErrorDetails?: string | string[];
  ProcessingTimeInMilliseconds?: string;
};

const EMPTY_CONFIDENCE: Confidence = {
  name: 0,
  role: 0,
  company: 0,
  email: 0,
  phone: 0,
  location: 0,
};

export class OCRService {
  private static readonly OCR_SPACE_URL = 'https://api.ocr.space/parse/image';

  /**
   * Important:
   * - "helloworld" is OCR.space's public test key. It is useful only for MVP testing.
   * - For startup/demo reliability, replace it with your own OCR.space API key.
   */
  private static readonly OCR_SPACE_API_KEY = 'helloworld';

  private static readonly REQUEST_TIMEOUT_MS = 25000;

  /**
   * Queue OCR requests so fast repeated captures do not hit the API in parallel.
   * Parallel OCR calls are one common reason the second/third capture returns empty text.
   */
  private static ocrQueue: Promise<void> = Promise.resolve();

  private static async runOneAtATime<T>(task: () => Promise<T>): Promise<T> {
    const previousTask = this.ocrQueue;
    let releaseCurrentTask: () => void = () => undefined;

    this.ocrQueue = new Promise<void>(resolve => {
      releaseCurrentTask = resolve;
    });

    await previousTask.catch(() => undefined);

    try {
      return await task();
    } finally {
      releaseCurrentTask();
    }
  }

  /**
   * Main OCR entry point using OCR.space API.
   *
   * Accepts base64 string directly from expo-camera's takePictureAsync({ base64: true }).
   * Returns raw extracted OCR text.
   */
  static async analyzeImageAndExtractText(base64Image: string): Promise<string> {
    return this.runOneAtATime(async () => {
      console.log('=== 📸 OCR: analyzeImageAndExtractText (OCR.space) ===');

      const cleanBase64 = this.cleanBase64(base64Image);

      if (!this.isValidBase64Image(cleanBase64)) {
        console.warn('⚠️ Invalid or empty base64 image data. OCR skipped.');
        return '';
      }

      const sizeKB = Math.round(cleanBase64.length / 1024);
      console.log(`📊 Image base64 size: ${sizeKB} KB`);

      const attempts: OCRAttemptConfig[] = [
        {
          name: 'engine2_scaled_orientation',
          engine: 2,
          scale: true,
          isTable: false,
          detectOrientation: true,
        },
        {
          name: 'engine1_scaled_orientation',
          engine: 1,
          scale: true,
          isTable: false,
          detectOrientation: true,
        },
        {
          name: 'engine2_table_scaled',
          engine: 2,
          scale: true,
          isTable: true,
          detectOrientation: true,
        },
        {
          name: 'engine2_no_scale',
          engine: 2,
          scale: false,
          isTable: false,
          detectOrientation: false,
        },
      ];

      let lastError = '';

      for (let i = 0; i < attempts.length; i++) {
        const attempt = attempts[i];

        try {
          console.log(`🚀 Starting OCR.space API attempt ${i + 1}/${attempts.length}: ${attempt.name}`);

          const result = await this.callOCRSpace(cleanBase64, attempt);
          const normalizedText = this.normalizeRawText(result.text);

          if (normalizedText.length > 0) {
            console.log(
              `✅ OCR.space recognition complete using ${attempt.name}. Extracted ${normalizedText.length} characters.`,
            );
            return normalizedText;
          }

          lastError = result.error || `Attempt ${attempt.name} returned empty text`;
          console.warn(`⚠️ ${lastError}`);

          if (result.rateLimited || result.statusCode === 429) {
            console.warn('⚠️ OCR.space rate limit hit. Stop retrying immediately.');
            break;
          }
        } catch (error) {
          lastError = this.errorToString(error);
          console.warn(`⚠️ OCR attempt ${attempt.name} failed:`, lastError);
        }

        // Small delay before retry. Helps with repeated captures and OCR.space throttling.
        if (i < attempts.length - 1) {
          await this.sleep(500 + i * 300);
        }
      }

      console.warn(
        `⚠️ OCR.space returned no text after ${attempts.length} attempts. Last error: ${lastError || 'Unknown OCR error'
        }`,
      );

      return '';
    });
  }

  private static async callOCRSpace(
    cleanBase64: string,
    config: OCRAttemptConfig,
  ): Promise<OCRAttemptResult> {
    const dataUri = `data:image/jpeg;base64,${cleanBase64}`;

    const body = this.toFormUrlEncoded({
      base64Image: dataUri,
      language: 'eng',
      isOverlayRequired: 'false',
      scale: String(config.scale),
      isTable: String(config.isTable),
      detectOrientation: String(config.detectOrientation),
      filetype: 'JPG',
      OCREngine: String(config.engine),
    });

    const response = await this.withTimeout(
      fetch(this.OCR_SPACE_URL, {
        method: 'POST',
        headers: {
          apikey: this.OCR_SPACE_API_KEY,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cache-Control': 'no-cache',
          Pragma: 'no-cache',
        },
        body,
      }),
      this.REQUEST_TIMEOUT_MS,
    );

    if (!response.ok) {
      return {
        text: '',
        ok: false,
        attemptName: config.name,
        error: `HTTP ${response.status}`,
        statusCode: response.status,
        rateLimited: response.status === 429,
      };
    }

    let payload: OCRSpaceResponse;

    try {
      payload = (await response.json()) as OCRSpaceResponse;
    } catch (error) {
      return {
        text: '',
        ok: false,
        attemptName: config.name,
        error: `Invalid JSON response: ${this.errorToString(error)}`,
      };
    }

    const parsedResults = Array.isArray(payload.ParsedResults) ? payload.ParsedResults : [];
    const text = parsedResults
      .map(item => item?.ParsedText || '')
      .filter(Boolean)
      .join('\n')
      .trim();

    const apiError =
      this.flattenMessage(payload.ErrorMessage) ||
      this.flattenMessage(payload.ErrorDetails) ||
      parsedResults
        .map(item => this.flattenMessage(item?.ErrorMessage) || this.flattenMessage(item?.ErrorDetails))
        .filter(Boolean)
        .join(' | ');

    const hasProcessingError = Boolean(payload.IsErroredOnProcessing);
    const hasText = text.length > 0;

    return {
      text,
      ok: !hasProcessingError && hasText,
      error: hasText ? undefined : apiError || `OCR returned empty text. ExitCode: ${payload.OCRExitCode ?? 'unknown'}`,
      exitCode: payload.OCRExitCode,
      attemptName: config.name,
    };
  }

  /**
   * Parse business card text using safer heuristics.
   *
   * Goals:
   * - Do not mark address lines as company.
   * - Do not mark random service words as name/company.
   * - Validate email and phone before assigning confidence.
   * - Keep extraction stable across repeated captures.
   */
  private static parseBusinessCardTextFallback(text: string): Partial<ExtractedCard> {
    const extracted: Partial<ExtractedCard> = this.createBlankExtractedCard(text);

    const rawLines = this.getCleanLines(text);
    if (rawLines.length === 0) {
      extracted.validationWarnings = ['OCR returned empty text after retries'];
      return extracted;
    }

    const claimed = new Set<number>();

    const roleKeywords = [
      'ceo',
      'cto',
      'cfo',
      'coo',
      'cmo',
      'founder',
      'co-founder',
      'director',
      'manager',
      'engineer',
      'architect',
      'specialist',
      'executive',
      'president',
      'vice president',
      'lead',
      'head',
      'consultant',
      'officer',
      'analyst',
      'associate',
      'partner',
      'principal',
      'developer',
      'designer',
      'scientist',
      'coordinator',
      'advocate',
      'attorney',
      'lawyer',
      'legal',
      'sales',
      'marketing',
      'operations',
      'business development',
      'proprietor',
      'chairman',
      'managing director',
    ];

    const companyKeywords = [
      'pvt',
      'private limited',
      'limited',
      'ltd',
      'llp',
      'inc',
      'llc',
      'corp',
      'corporation',
      'co.',
      'company',
      'solutions',
      'technologies',
      'technology',
      'tech',
      'systems',
      'services',
      'enterprises',
      'industries',
      'consulting',
      'consultants',
      'group',
      'global',
      'international',
      'ventures',
      'studios',
      'agency',
      'labs',
      'analytics',
      'software',
      'digital',
      'automations',
      'associates',
      'traders',
      'exports',
      'imports',
      'education',
      'hotels',
      'hospitality',
      'paulsons',
    ];

    // 1) Email
    const emailCandidate = this.extractEmail(rawLines);
    if (emailCandidate) {
      extracted.email = emailCandidate.value;
      extracted.confidence!.email = emailCandidate.confidence;
      claimed.add(emailCandidate.lineIndex);
    }

    // 2) Phone
    const phoneCandidate = this.extractPhone(rawLines, claimed);
    if (phoneCandidate) {
      extracted.phone = phoneCandidate.value;
      extracted.confidence!.phone = phoneCandidate.confidence;
      claimed.add(phoneCandidate.lineIndex);
    }

    // 3) Name
    const nameCandidate = this.extractName(rawLines, claimed, roleKeywords, companyKeywords);
    if (nameCandidate) {
      extracted.name = nameCandidate.value;
      extracted.confidence!.name = nameCandidate.confidence;
      claimed.add(nameCandidate.lineIndex);
    }

    // 4) Role
    const roleCandidate = this.extractKeywordLine(rawLines, claimed, roleKeywords, 'role');
    if (roleCandidate) {
      extracted.role = roleCandidate.value;
      extracted.confidence!.role = roleCandidate.confidence;
      claimed.add(roleCandidate.lineIndex);
    }

    // 5) Company
    const companyCandidate = this.extractCompany(rawLines, claimed, companyKeywords, roleKeywords);
    if (companyCandidate) {
      extracted.company = companyCandidate.value;
      extracted.confidence!.company = companyCandidate.confidence;
      claimed.add(companyCandidate.lineIndex);
    }

    // 6) Location
    const locationCandidate = this.extractLocation(rawLines, claimed);
    if (locationCandidate) {
      extracted.location = locationCandidate.value;
      extracted.confidence!.location = locationCandidate.confidence;
      locationCandidate.lineIndexes.forEach(index => claimed.add(index));
    }

    // 7) Final validation cleanup
    this.validateAndCleanExtractedCard(extracted, rawLines);

    return extracted;
  }

  /**
   * Full OCR pipeline: base64 image → OCR.space → raw text → validated ExtractedCard.
   */
  static async extractCard(base64Image: string): Promise<ExtractedCard> {
    try {
      console.log('=== 🚀 OCR Pipeline Start (OCR.space + Gemini + local inference) ===');

      const cleanBase64 = this.cleanBase64(base64Image);
      const imageLooksValid = this.isValidBase64Image(cleanBase64);

      const rawText = imageLooksValid ? await this.analyzeImageAndExtractText(cleanBase64) : '';
      const rawLines = this.getCleanLines(rawText);

      /**
       * Step 1: Always run the local parser first.
       * Reason: it is free, stable, and gives us email/phone even if AI/backend fails.
       */
      const localParsed = this.parseBusinessCardTextFallback(rawText) as ExtractedCard;

      /**
       * Step 2: Try Gemini AI parsing.
       * If Gemini is unavailable, localhost is wrong, or the server is down,
       * the app still continues with local parsing.
       */
      const shouldAskGemini = this.shouldUseGemini(localParsed, rawLines);
      const geminiParsed = shouldAskGemini ? await this.tryGeminiParsing(rawText) : null;

      if (!shouldAskGemini) {
        console.log('✅ Local parser result is strong enough. Skipping Gemini to save free quota.');
      }

      let extracted = this.chooseBestExtraction(localParsed, geminiParsed) as ExtractedCard;

      /**
       * Step 3: Important deterministic fix.
       * Some design cards hide the name/company inside the email:
       *   hariprakash@cecilturtle.com
       * In that case, OCR and Gemini may only return email + phone.
       * This rule fills:
       *   name    -> Hariprakash
       *   company -> Cecil Turtle
       */
      this.validateAndCleanExtractedCard(extracted, rawLines);

      const hasAnyUsefulField = Boolean(
        extracted.name ||
        extracted.role ||
        extracted.company ||
        extracted.email ||
        extracted.phone ||
        extracted.location,
      );

      const quality = this.calculateExtractionQuality(extracted, imageLooksValid);

      /**
       * Do NOT immediately mark a clear captured image as "cardDetected=false"
       * only because OCR.space returned empty text.
       */
      extracted.cardDetected = imageLooksValid || hasAnyUsefulField || rawText.trim().length > 0;
      extracted.cardQuality = quality;
      extracted.cardOrientation = 0;
      extracted.ocrProvider = geminiParsed ? 'ocr.space + gemini + local-inference' : 'ocr.space + local-inference';
      extracted.ocrTextLength = rawText.length;

      if (imageLooksValid && rawText.trim().length === 0) {
        extracted.ocrError = 'OCR returned empty text after retries';
        extracted.validationWarnings = [
          ...(extracted.validationWarnings || []),
          'The image was captured, but OCR returned empty text. This is usually an OCR API/retry issue, not always a blur issue.',
        ];
      }

      console.log('=== ✅ OCR Pipeline Complete ===');
      console.log('Extracted result:', extracted);
      console.log(`📊 Card extraction quality: ${Math.round((extracted.cardQuality || 0) * 100)}%`);

      return extracted;
    } catch (error) {
      console.error('❌ OCR pipeline error:', error);

      return {
        ...this.createBlankExtractedCard(''),
        cardDetected: false,
        cardQuality: 0,
        cardOrientation: 0,
        ocrProvider: 'ocr.space + gemini + local-inference',
        ocrTextLength: 0,
        ocrError: this.errorToString(error),
        validationWarnings: ['OCR pipeline crashed and returned a safe blank card'],
      };
    }
  }

  private static shouldUseGemini(localParsed: ExtractedCard, rawLines: string[]): boolean {
    if (!localParsed.rawText || localParsed.rawText.trim().length < 5) {
      return false;
    }

    // validateAndCleanExtractedCard already performs deterministic fixes:
    // - removes labels like "Delete", "Name", "Mail ID"
    // - infers company from business email domain
    // - infers name from email if needed
    this.validateAndCleanExtractedCard(localParsed, rawLines);

    const hasStrongContact = Boolean(localParsed.email && localParsed.phone);
    const hasValidName = Boolean(localParsed.name && !this.isBadLabelValue(localParsed.name));
    const hasValidCompany = Boolean(localParsed.company && !this.isSuspiciousCompanyValue(localParsed.company));

    // Save Gemini free quota when local deterministic extraction has the core fields.
    if (hasStrongContact && hasValidName && hasValidCompany) {
      return false;
    }

    // Ask Gemini only for incomplete or confusing cards.
    return true;
  }

  private static async tryGeminiParsing(rawText: string): Promise<ExtractedCard | null> {
    if (!rawText || rawText.trim().length < 5) {
      return null;
    }

    try {
      const gemini = await parseCardTextWithGemini(rawText);

      if (!gemini) {
        return null;
      }

      const extracted: ExtractedCard = {
        ...this.createBlankExtractedCard(gemini.rawText || rawText),
        name: gemini.name || '',
        role: gemini.role || '',
        company: gemini.company || '',
        email: gemini.email || '',
        phone: gemini.phone || '',
        location: gemini.location || '',
        confidence: {
          ...EMPTY_CONFIDENCE,
          ...(gemini.confidence || {}),
        },
        rawText: gemini.rawText || rawText,
        cardDetected: Boolean(gemini.cardDetected),
        cardQuality: gemini.cardQuality ?? 0,
        ocrProvider: 'gemini',
      };

      this.validateAndCleanExtractedCard(extracted, this.getCleanLines(extracted.rawText));
      return extracted;
    } catch (error) {
      console.warn('⚠️ Gemini parsing failed, using local parser:', this.errorToString(error));
      return null;
    }
  }

  private static chooseBestExtraction(localParsed: ExtractedCard, geminiParsed: ExtractedCard | null): ExtractedCard {
    if (!geminiParsed) {
      return localParsed;
    }

    const localScore = this.extractionValueScore(localParsed);
    const geminiScore = this.extractionValueScore(geminiParsed);

    // Prefer Gemini only if it gives equal or better useful fields.
    // This prevents AI from replacing a good local result with blanks.
    if (geminiScore >= localScore) {
      return geminiParsed;
    }

    // Merge useful Gemini fields into local result without losing local fields.
    return {
      ...localParsed,
      name: localParsed.name || geminiParsed.name || '',
      role: localParsed.role || geminiParsed.role || '',
      company: localParsed.company || geminiParsed.company || '',
      email: localParsed.email || geminiParsed.email || '',
      phone: localParsed.phone || geminiParsed.phone || '',
      location: localParsed.location || geminiParsed.location || '',
      confidence: {
        name: Math.max(localParsed.confidence?.name || 0, geminiParsed.confidence?.name || 0),
        role: Math.max(localParsed.confidence?.role || 0, geminiParsed.confidence?.role || 0),
        company: Math.max(localParsed.confidence?.company || 0, geminiParsed.confidence?.company || 0),
        email: Math.max(localParsed.confidence?.email || 0, geminiParsed.confidence?.email || 0),
        phone: Math.max(localParsed.confidence?.phone || 0, geminiParsed.confidence?.phone || 0),
        location: Math.max(localParsed.confidence?.location || 0, geminiParsed.confidence?.location || 0),
      },
      validationWarnings: Array.from(
        new Set([...(localParsed.validationWarnings || []), ...(geminiParsed.validationWarnings || [])]),
      ),
    };
  }

  private static extractionValueScore(extracted: Partial<ExtractedCard>): number {
    let score = 0;

    if (extracted.name) score += 3;
    if (extracted.company) score += 3;
    if (extracted.email) score += 4;
    if (extracted.phone) score += 4;
    if (extracted.role) score += 2;
    if (extracted.location) score += 1;

    const confidence = extracted.confidence || EMPTY_CONFIDENCE;
    score +=
      confidence.name +
      confidence.company +
      confidence.email +
      confidence.phone +
      confidence.role +
      confidence.location;

    return score;
  }

  /**
   * Convert an ExtractedCard into the Lead model.
   */
  static createLeadFromExtraction(
    extracted: ExtractedCard,
    eventName: string = 'Event',
  ): Lead {
    const now = new Date();
    const safeName = extracted.name?.trim() || 'New Lead';
    const id = safeName.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') + '_' + Date.now();

    const safeConfidence: Confidence = {
      ...EMPTY_CONFIDENCE,
      ...(extracted.confidence || {}),
    };

    const lead: Lead = {
      id,
      name: safeName,
      role: extracted.role || '',
      company: extracted.company || '',
      email: extracted.email || '',
      phone: extracted.phone || '',
      location: extracted.location || '',
      status: 'new',
      event: eventName,
      capturedAt: this.getTimeAgo(now),
      capturedBy: CURRENT_USER.id,
      tags: [],
      note: '',
      score: this.calculateScore({
        ...extracted,
        confidence: safeConfidence,
      }),
      scoreBreak: {
        designation: Math.round(safeConfidence.role * 20),
        company: Math.round(safeConfidence.company * 20),
        email: Math.round(safeConfidence.email * 20),
        brochure: 0,
        event: 18,
      },
      followUp: {
        date: this.getFollowUpDate(now),
        daysFromNow: 3,
        overdue: false,
        suggested: 'Follow-up after event',
      },
      reminder: null,
      activity: [
        {
          t: this.getTimeAgo(now),
          k: 'scan',
          text: extracted.company
            ? `Captured business card for ${extracted.company}`
            : 'Captured business card',
        },
      ],
    };

    return lead;
  }

  private static createBlankExtractedCard(rawText: string): ExtractedCard {
    return {
      name: '',
      role: '',
      company: '',
      email: '',
      phone: '',
      location: '',
      confidence: { ...EMPTY_CONFIDENCE },
      rawText,
      cardDetected: false,
      cardQuality: 0,
      cardOrientation: 0,
      ocrProvider: 'ocr.space',
      ocrTextLength: rawText.length,
      validationWarnings: [],
    };
  }

  private static cleanBase64(base64Image?: string | null): string {
    if (!base64Image || typeof base64Image !== 'string') {
      return '';
    }

    return base64Image
      .trim()
      .replace(/^data:image\/[a-zA-Z0-9+.-]+;base64,/, '')
      .replace(/\s+/g, '');
  }

  private static isValidBase64Image(cleanBase64: string): boolean {
    if (!cleanBase64 || cleanBase64.length < 1024) {
      return false;
    }

    // base64 length cannot have remainder 1 when divided by 4.
    if (cleanBase64.length % 4 === 1) {
      return false;
    }

    return /^[A-Za-z0-9+/]+={0,2}$/.test(cleanBase64);
  }

  private static toFormUrlEncoded(params: Record<string, string>): string {
    return Object.keys(params)
      .map(key => `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`)
      .join('&');
  }

  private static async withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
    let timeoutHandle: ReturnType<typeof setTimeout> | undefined;

    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        reject(new Error(`OCR request timed out after ${timeoutMs}ms`));
      }, timeoutMs);
    });

    try {
      return await Promise.race([promise, timeoutPromise]);
    } finally {
      if (timeoutHandle) {
        clearTimeout(timeoutHandle);
      }
    }
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  private static normalizeRawText(text: string): string {
    if (!text) {
      return '';
    }

    return text
      .replace(/\r/g, '\n')
      .replace(/[ \t]+/g, ' ')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  private static getCleanLines(text: string): string[] {
    if (!text) {
      return [];
    }

    return this.normalizeRawText(text)
      .split('\n')
      .flatMap(line => {
        const cleaned = this.cleanLine(line);
        // OCR.space sometimes puts multiple columns on one row with large spaces or pipes.
        return cleaned.split(/\s{3,}|\t+|\s+\|\s+/g);
      })
      .map(line => this.cleanLine(line))
      .filter(line => line.length > 0);
  }

  private static cleanLine(line: string): string {
    return line
      .replace(/[“”]/g, '"')
      .replace(/[‘’]/g, "'")
      .replace(/\b8\b/g, '&')
      .replace(/\s+/g, ' ')
      .replace(/\s+([,.;:])/g, '$1')
      .trim();
  }

  private static extractEmail(lines: string[]): { value: string; confidence: number; lineIndex: number } | null {
    const emailRe = /[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/;

    for (let i = 0; i < lines.length; i++) {
      const match = lines[i].match(emailRe);
      if (!match) continue;

      const email = match[0].toLowerCase().replace(/[;,]+$/g, '');
      if (!this.isValidEmail(email)) continue;

      return {
        value: email,
        confidence: 0.98,
        lineIndex: i,
      };
    }

    return null;
  }

  private static extractPhone(
    lines: string[],
    claimed: Set<number>,
  ): { value: string; confidence: number; lineIndex: number } | null {
    const candidates: { value: string; digits: string; lineIndex: number }[] = [];

    for (let i = 0; i < lines.length; i++) {
      if (claimed.has(i)) continue;

      const line = lines[i];
      if (line.includes('@')) continue;

      const phoneLikeMatches = line.match(/(?:\+?\d[\d\s().-]{7,}\d)/g) || [];

      for (const rawMatch of phoneLikeMatches) {
        const normalized = this.normalizePhone(rawMatch);
        const digits = normalized.replace(/\D/g, '');

        if (this.isValidPhoneDigits(digits)) {
          candidates.push({
            value: normalized,
            digits,
            lineIndex: i,
          });
        }
      }
    }

    if (candidates.length === 0) {
      return null;
    }

    // Prefer Indian mobile-like 10-digit numbers starting with 6-9.
    const preferred =
      candidates.find(item => /^[6-9]\d{9}$/.test(item.digits.slice(-10))) ||
      candidates.find(item => item.digits.length >= 10) ||
      candidates[0];

    return {
      value: preferred.value,
      confidence: 0.95,
      lineIndex: preferred.lineIndex,
    };
  }

  private static extractName(
    lines: string[],
    claimed: Set<number>,
    roleKeywords: string[],
    companyKeywords: string[],
  ): { value: string; confidence: number; lineIndex: number } | null {
    const maxSearchLines = Math.min(lines.length, 6);

    for (let i = 0; i < maxSearchLines; i++) {
      if (claimed.has(i)) continue;

      const line = this.cleanPersonName(lines[i]);
      const lower = line.toLowerCase();

      if (!line) continue;
      if (this.isBadLabelValue(line)) continue;
      if (line.includes('@')) continue;
      if (this.hasPhone(line)) continue;
      if (this.isWebsiteLine(line)) continue;
      if (this.isAddressLike(line)) continue;
      if (this.containsKeyword(lower, roleKeywords)) continue;
      if (this.containsKeyword(lower, companyKeywords)) continue;

      const words = line.split(/\s+/).filter(Boolean);
      const hasLetter = /[A-Za-z]/.test(line);
      const startsLikeName = /^(dr\.?|mr\.?|mrs\.?|ms\.?|prof\.?)?\s*[A-Z]/.test(line);
      const reasonableLength = line.length >= 3 && line.length <= 80;
      const reasonableWords = words.length >= 1 && words.length <= 8;

      if (hasLetter && startsLikeName && reasonableLength && reasonableWords) {
        return {
          value: line,
          confidence: 0.88,
          lineIndex: i,
        };
      }
    }

    return null;
  }

  private static extractKeywordLine(
    lines: string[],
    claimed: Set<number>,
    keywords: string[],
    type: 'role' | 'company',
  ): { value: string; confidence: number; lineIndex: number } | null {
    for (let i = 0; i < lines.length; i++) {
      if (claimed.has(i)) continue;

      const line = this.cleanLine(lines[i]);
      const lower = line.toLowerCase();

      if (!line || this.isBadLabelValue(line) || line.includes('@') || this.hasPhone(line) || this.isWebsiteLine(line)) {
        continue;
      }

      if (type === 'role' && this.isAddressLike(line)) {
        continue;
      }

      if (type === 'company' && this.isSuspiciousCompanyValue(line)) {
        continue;
      }

      if (this.containsKeyword(lower, keywords)) {
        return {
          value: line,
          confidence: type === 'role' ? 0.88 : 0.82,
          lineIndex: i,
        };
      }
    }

    return null;
  }

  private static extractCompany(
    lines: string[],
    claimed: Set<number>,
    companyKeywords: string[],
    roleKeywords: string[],
  ): { value: string; confidence: number; lineIndex: number } | null {
    const keywordCompany = this.extractKeywordLine(lines, claimed, companyKeywords, 'company');

    if (keywordCompany && !this.isAddressLike(keywordCompany.value)) {
      return keywordCompany;
    }

    // Fallback: choose a clean upper/top line that is not name, role, phone, email, website, or address.
    for (let i = 0; i < Math.min(lines.length, 8); i++) {
      if (claimed.has(i)) continue;

      const line = this.cleanLine(lines[i]);
      const lower = line.toLowerCase();

      if (!line) continue;
      if (this.isBadLabelValue(line) || this.isSuspiciousCompanyValue(line)) continue;
      if (line.includes('@')) continue;
      if (this.hasPhone(line)) continue;
      if (this.isWebsiteLine(line)) continue;
      if (this.isAddressLike(line)) continue;
      if (this.containsKeyword(lower, roleKeywords)) continue;

      const words = line.split(/\s+/).filter(Boolean);
      const hasLetters = /[A-Za-z]/.test(line);
      const reasonableLength = line.length >= 3 && line.length <= 70;

      if (hasLetters && reasonableLength && words.length <= 7) {
        return {
          value: line,
          confidence: 0.55,
          lineIndex: i,
        };
      }
    }

    return null;
  }

  private static extractLocation(
    lines: string[],
    claimed: Set<number>,
  ): { value: string; confidence: number; lineIndexes: number[] } | null {
    const addressLines: { value: string; index: number; score: number }[] = [];

    for (let i = 0; i < lines.length; i++) {
      if (claimed.has(i)) continue;

      const line = this.cleanLine(lines[i]);

      if (!line || line.includes('@') || this.hasPhone(line) || this.isWebsiteLine(line)) {
        continue;
      }

      const score = this.addressScore(line);
      if (score >= 2) {
        addressLines.push({ value: line, index: i, score });
      }
    }

    if (addressLines.length === 0) {
      return null;
    }

    addressLines.sort((a, b) => b.score - a.score);

    // Pick up to two best address lines, then restore original order.
    const selected = addressLines
      .slice(0, 2)
      .sort((a, b) => a.index - b.index);

    return {
      value: selected.map(item => item.value).join(', '),
      confidence: 0.8,
      lineIndexes: selected.map(item => item.index),
    };
  }

  private static validateAndCleanExtractedCard(extracted: Partial<ExtractedCard>, lines: string[]): void {
    const warnings: string[] = [...(extracted.validationWarnings || [])];

    extracted.rawText = extracted.rawText || '';
    extracted.name = this.cleanPersonName(extracted.name || '');
    extracted.role = this.cleanLine(extracted.role || '');
    extracted.company = this.cleanLine(extracted.company || '');
    extracted.email = (extracted.email || '').toLowerCase().trim();
    extracted.phone = this.normalizePhone(extracted.phone || '');
    extracted.location = this.cleanLine(extracted.location || '');

    if (extracted.email && !this.isValidEmail(extracted.email)) {
      warnings.push('Invalid email removed');
      extracted.email = '';
      extracted.confidence!.email = 0;
    }

    if (extracted.phone) {
      const digits = extracted.phone.replace(/\D/g, '');
      if (!this.isValidPhoneDigits(digits)) {
        warnings.push('Invalid phone number removed');
        extracted.phone = '';
        extracted.confidence!.phone = 0;
      }
    }

    if (extracted.company && this.isSuspiciousCompanyValue(extracted.company)) {
      warnings.push('Company looked invalid/suspicious, so it was removed');
      extracted.company = '';
      extracted.confidence!.company = 0;
    }

    if (
      extracted.name &&
      (this.isBadLabelValue(extracted.name) ||
        this.isAddressLike(extracted.name) ||
        this.hasPhone(extracted.name) ||
        extracted.name.includes('@'))
    ) {
      warnings.push('Name looked invalid/label-like, so it was removed');
      extracted.name = '';
      extracted.confidence!.name = 0;
    }

    if (extracted.role && (this.isBadLabelValue(extracted.role) || this.isAddressLike(extracted.role))) {
      warnings.push('Role looked invalid/address-like, so it was removed');
      extracted.role = '';
      extracted.confidence!.role = 0;
    }

    // If name is missing after cleanup, try to find a better real name from OCR lines.
    if (!extracted.name) {
      const betterName = this.findBestNameFromLines(lines, extracted.email, extracted.phone);

      if (betterName) {
        extracted.name = betterName;
        extracted.confidence!.name = Math.max(extracted.confidence!.name || 0, 0.86);
        warnings.push('Name recovered from OCR line cleanup');
      }
    }

    // Special design-card fix: infer missing/bad name/company from a business email.
    this.applyEmailDomainInference(extracted, warnings);

    // If role is still missing, try a final search from all lines.
    if (!extracted.role) {
      const roleWords = ['director', 'manager', 'engineer', 'head', 'legal', 'advocate', 'founder', 'ceo', 'cto'];
      const roleLine = lines.find(line => this.containsKeyword(line.toLowerCase(), roleWords) && !this.isAddressLike(line));
      if (roleLine) {
        extracted.role = this.cleanLine(roleLine);
        extracted.confidence!.role = 0.78;
      }
    }

    extracted.validationWarnings = Array.from(new Set(warnings));
  }

  private static applyEmailDomainInference(extracted: Partial<ExtractedCard>, warnings: string[]): void {
    if (!extracted.email || !this.isValidEmail(extracted.email)) {
      return;
    }

    const emailParts = this.getEmailParts(extracted.email);
    if (!emailParts) {
      return;
    }

    const currentName = (extracted.name || '').trim().toLowerCase();
    const nameMissing = !currentName || currentName === 'new lead' || this.isBadLabelValue(extracted.name || '');

    if (nameMissing) {
      const inferredName = this.inferNameFromEmailLocalPart(emailParts.localPart);

      if (inferredName) {
        extracted.name = inferredName;
        extracted.confidence!.name = Math.max(extracted.confidence!.name || 0, 0.62);
        warnings.push('Name inferred from email local-part');
      }
    }

    if (!extracted.company || this.isSuspiciousCompanyValue(extracted.company)) {
      const inferredCompany = this.inferCompanyFromEmailDomain(emailParts.domain);

      if (inferredCompany) {
        extracted.company = inferredCompany;
        extracted.confidence!.company = Math.max(extracted.confidence!.company || 0, 0.68);
        warnings.push('Company inferred from email domain');
      }
    }
  }

  private static getEmailParts(email: string): { localPart: string; domain: string } | null {
    const cleanEmail = email.toLowerCase().trim();
    const parts = cleanEmail.split('@');

    if (parts.length !== 2 || !parts[0] || !parts[1]) {
      return null;
    }

    return {
      localPart: parts[0],
      domain: parts[1].replace(/^www\./, ''),
    };
  }

  private static inferNameFromEmailLocalPart(localPart: string): string {
    const genericLocalParts = new Set([
      'info',
      'contact',
      'support',
      'sales',
      'admin',
      'hello',
      'team',
      'office',
      'enquiry',
      'enquiries',
      'care',
      'help',
      'mail',
      'hr',
      'jobs',
      'career',
      'careers',
    ]);

    let value = localPart.toLowerCase().split('+')[0];
    value = value.replace(/[0-9]+/g, '');
    value = value.replace(/[._-]+/g, ' ');
    value = value.trim();

    if (!value || value.length < 3 || genericLocalParts.has(value)) {
      return '';
    }

    return this.titleCase(value);
  }

  private static inferCompanyFromEmailDomain(domain: string): string {
    const publicDomains = new Set([
      'gmail.com',
      'yahoo.com',
      'outlook.com',
      'hotmail.com',
      'icloud.com',
      'proton.me',
      'protonmail.com',
      'aol.com',
      'live.com',
      'msn.com',
      'rediffmail.com',
      'ymail.com',
    ]);

    const cleanDomain = domain.toLowerCase().replace(/^www\./, '');

    if (publicDomains.has(cleanDomain)) {
      return '';
    }

    const brandOverrides: Record<string, string> = {
      cecilturtle: 'Cecil Turtle',
      geniebox: 'Geniebox',
      paulsons: 'Paulsons',
    };

    const baseDomain = cleanDomain.split('.')[0];

    if (!baseDomain || baseDomain.length < 3) {
      return '';
    }

    if (brandOverrides[baseDomain]) {
      return brandOverrides[baseDomain];
    }

    const separated = baseDomain
      .replace(/[0-9]+/g, '')
      .replace(/[-_]+/g, ' ')
      .trim();

    if (!separated || separated.length < 3) {
      return '';
    }

    if (separated.includes(' ')) {
      return this.titleCase(separated);
    }

    const dictionarySplit = this.splitJoinedDomainWords(separated);
    return this.titleCase(dictionarySplit || separated);
  }

  private static splitJoinedDomainWords(value: string): string {
    const knownWords = [
      'cecil',
      'turtle',
      'genie',
      'box',
      'tech',
      'soft',
      'software',
      'solution',
      'solutions',
      'system',
      'systems',
      'digital',
      'global',
      'media',
      'studio',
      'studios',
      'lab',
      'labs',
      'consulting',
      'consultants',
      'group',
      'india',
      'export',
      'exports',
      'import',
      'imports',
      'hotel',
      'hotels',
      'education',
      'academy',
      'health',
      'care',
      'finance',
      'foods',
      'textiles',
    ];

    const words = new Set(knownWords);
    const dp: Array<string[] | null> = Array(value.length + 1).fill(null);
    dp[0] = [];

    for (let i = 0; i < value.length; i++) {
      if (!dp[i]) continue;

      for (let j = i + 3; j <= value.length; j++) {
        const piece = value.slice(i, j);
        if (words.has(piece)) {
          const candidate = [...dp[i]!, piece];
          if (!dp[j] || candidate.length < dp[j]!.length) {
            dp[j] = candidate;
          }
        }
      }
    }

    const result = dp[value.length];
    return result && result.length > 1 ? result.join(' ') : '';
  }

  private static titleCase(value: string): string {
    return value
      .split(/\s+/)
      .filter(Boolean)
      .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(' ');
  }

  private static isBadLabelValue(value?: string): boolean {
    if (!value) {
      return true;
    }

    const cleaned = value
      .toLowerCase()
      .replace(/[¿?.,:;|_~`'"()[\]{}<>-]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    const badLabels = new Set([
      'delete',
      'name',
      'full name',
      'mail id',
      'email',
      'email id',
      'email address',
      'website',
      'web site',
      'social media',
      'phone',
      'phone number',
      'mobile',
      'mobile number',
      'contact',
      'please reach us at',
    ]);

    return (
      cleaned.length < 2 ||
      badLabels.has(cleaned) ||
      cleaned.includes('social media') ||
      cleaned.includes('website') ||
      cleaned.includes('mail id') ||
      cleaned.includes('please reach')
    );
  }

  private static isSuspiciousCompanyValue(value?: string): boolean {
    if (!value) {
      return true;
    }

    const cleaned = this.cleanLine(value);

    return (
      this.isBadLabelValue(cleaned) ||
      cleaned.includes('¿') ||
      cleaned.startsWith('?') ||
      cleaned.includes('@') ||
      this.hasPhone(cleaned) ||
      this.isAddressLike(cleaned) ||
      cleaned.length <= 2
    );
  }

  private static findBestNameFromLines(lines: string[], email?: string, phone?: string): string {
    const cleanEmail = (email || '').toLowerCase().trim();
    const phoneDigits = (phone || '').replace(/\D/g, '');

    const roleWords = [
      'founder',
      'ceo',
      'cto',
      'cfo',
      'coo',
      'director',
      'manager',
      'engineer',
      'developer',
      'designer',
      'head',
      'officer',
      'consultant',
      'advocate',
      'analyst',
      'executive',
      'legal',
    ];

    const companyWords = [
      'pvt',
      'ltd',
      'llp',
      'inc',
      'company',
      'solutions',
      'technologies',
      'systems',
      'services',
      'group',
      'global',
      'software',
      'digital',
    ];

    for (const rawLine of lines.slice(0, 8)) {
      const line = this.cleanPersonName(rawLine);
      const lower = line.toLowerCase();
      const lineDigits = line.replace(/\D/g, '');

      if (!line) continue;
      if (this.isBadLabelValue(line)) continue;
      if (cleanEmail && lower.includes(cleanEmail)) continue;
      if (phoneDigits && lineDigits.includes(phoneDigits)) continue;
      if (line.includes('@')) continue;
      if (this.hasPhone(line)) continue;
      if (this.isWebsiteLine(line)) continue;
      if (this.isAddressLike(line)) continue;
      if (this.containsKeyword(lower, roleWords)) continue;
      if (this.containsKeyword(lower, companyWords)) continue;
      if (line.length > 45) continue;

      const hasLetter = /[A-Za-z]/.test(line);
      const mostlyNameChars = /^[A-Za-z .]+$/.test(line);
      const wordCount = line.split(/\s+/).filter(Boolean).length;

      if (hasLetter && mostlyNameChars && wordCount <= 5) {
        return line;
      }
    }

    return '';
  }

  private static cleanPersonName(name: string): string {
    return this.cleanLine(name)
      .replace(/\s*,\s*$/g, '')
      .replace(/\s{2,}/g, ' ')
      .trim();
  }

  private static normalizePhone(phone: string): string {
    if (!phone) {
      return '';
    }

    const corrected = phone
      .replace(/[Oo]/g, '0')
      .replace(/[Il|]/g, '1')
      .replace(/([0-9])[Ss]/g, '$15')
      .replace(/[Ss]([0-9])/g, '5$1')
      .replace(/[Bb]([0-9])/g, '8$1')
      .replace(/([0-9])[Bb]/g, '$18')
      .replace(/[Zz]/g, '2');

    const cleaned = corrected
      .replace(/[^\d+]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    const digits = cleaned.replace(/\D/g, '');

    if (digits.length === 10) {
      return digits.replace(/(\d{5})(\d{5})/, '$1 $2');
    }

    if (digits.length === 12 && digits.startsWith('91')) {
      return `+91 ${digits.slice(2, 7)} ${digits.slice(7)}`;
    }

    if (phone.trim().startsWith('+')) {
      return `+${digits}`;
    }

    return digits || cleaned;
  }

  private static isValidEmail(email: string): boolean {
    return /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/.test(email);
  }

  private static isValidPhoneDigits(digits: string): boolean {
    if (!digits) {
      return false;
    }

    if (/^[6-9]\d{9}$/.test(digits)) {
      return true;
    }

    if (/^91[6-9]\d{9}$/.test(digits)) {
      return true;
    }

    return digits.length >= 10 && digits.length <= 15;
  }

  private static hasPhone(line: string): boolean {
    const matches = line.match(/(?:\+?\d[\d\s().-]{7,}\d)/g) || [];
    return matches.some(match => this.isValidPhoneDigits(match.replace(/\D/g, '')));
  }

  private static isWebsiteLine(line: string): boolean {
    const lower = line.toLowerCase();
    return (
      lower.startsWith('www.') ||
      lower.includes('http://') ||
      lower.includes('https://') ||
      /\b[a-z0-9-]+\.(com|in|org|net|io|co|ai|edu|biz)\b/.test(lower)
    );
  }

  private static isAddressLike(line: string): boolean {
    return this.addressScore(line) >= 2;
  }

  private static addressScore(line: string): number {
    const lower = line.toLowerCase();
    let score = 0;

    const addressWords = [
      'road',
      'rd',
      'street',
      'st',
      'avenue',
      'ave',
      'nagar',
      'colony',
      'layout',
      'floor',
      'block',
      'building',
      'complex',
      'tower',
      'city',
      'district',
      'state',
      'near',
      'opp',
      'opposite',
      'pincode',
      'pin',
      'po',
      'post',
      'kilpauk',
      'chennai',
      'puducherry',
      'pondicherry',
      'bangalore',
      'bengaluru',
      'mumbai',
      'delhi',
      'hyderabad',
      'pune',
      'kolkata',
      'coimbatore',
      'india',
      'usa',
      'uk',
      'uae',
      'singapore',
    ];

    if (/\b\d{6}\b/.test(lower)) score += 2; // Indian PIN code
    if (/\b\d{5}(?:-\d{4})?\b/.test(lower)) score += 1; // ZIP-like
    if (/[,#/-]/.test(line) && /\d/.test(line)) score += 1;
    if (this.containsKeyword(lower, addressWords)) score += 2;
    if (/\b(no\.?|flat|door|plot)\s*[\w/-]+/i.test(line)) score += 1;

    return score;
  }

  private static containsKeyword(lowerText: string, keywords: string[]): boolean {
    return keywords.some(keyword => {
      const safeKeyword = keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      return new RegExp(`(^|\\b)${safeKeyword}(\\b|$)`, 'i').test(lowerText);
    });
  }

  private static calculateExtractionQuality(extracted: ExtractedCard, imageLooksValid: boolean): number {
    const confidence = {
      ...EMPTY_CONFIDENCE,
      ...(extracted.confidence || {}),
    };

    const weightedScore =
      confidence.name * 0.2 +
      confidence.role * 0.15 +
      confidence.company * 0.2 +
      confidence.email * 0.2 +
      confidence.phone * 0.15 +
      confidence.location * 0.1;

    // If the camera provided valid image data but OCR returned empty,
    // give a non-zero quality so UI does not mislabel it as a blur-only issue.
    if (weightedScore === 0 && imageLooksValid) {
      return 0.35;
    }

    return Math.max(0, Math.min(1, weightedScore));
  }

  private static calculateScore(extracted: ExtractedCard): number {
    const confidence = {
      ...EMPTY_CONFIDENCE,
      ...(extracted.confidence || {}),
    };

    const weights = {
      name: 0.25,
      role: 0.2,
      company: 0.2,
      email: 0.15,
      phone: 0.1,
      location: 0.1,
    };

    const score =
      confidence.name * weights.name +
      confidence.role * weights.role +
      confidence.company * weights.company +
      confidence.email * weights.email +
      confidence.phone * weights.phone +
      confidence.location * weights.location;

    return Math.round(score * 100);
  }

  private static getTimeAgo(date: Date): string {
    const minutes = Math.floor((Date.now() - date.getTime()) / 60000);
    if (minutes < 1) return 'now';
    if (minutes < 60) return `${minutes}m`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h`;
    return `${Math.floor(hours / 24)}d`;
  }

  private static getFollowUpDate(baseDate: Date): string {
    const d = new Date(baseDate);
    d.setDate(d.getDate() + 3);

    return d.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }

  private static flattenMessage(message?: string | string[]): string {
    if (!message) {
      return '';
    }

    return Array.isArray(message) ? message.join(' | ') : message;
  }

  private static errorToString(error: unknown): string {
    if (error instanceof Error) {
      return error.message;
    }

    try {
      return JSON.stringify(error);
    } catch {
      return String(error);
    }
  }
}

export default OCRService;
