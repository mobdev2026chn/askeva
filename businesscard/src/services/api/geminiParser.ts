export interface GeminiParsedCard {
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
  cardDetected: boolean;
  cardQuality: number;
  aiError?: string;
}

/**
 * IMPORTANT:
 * - For Android emulator, use: http://10.0.2.2:3001
 * - For iOS simulator / web on same laptop, use: http://localhost:3001
 * - For Expo Go on real phone, use your laptop IPv4 address:
 *   example: http://192.168.0.28:3001
 */
const BACKEND_URL = 'http://192.168.0.28:3001';

const REQUEST_TIMEOUT_MS = 15000;

function normalizeConfidence(confidence: any) {
  return {
    name: Number(confidence?.name ?? 0),
    role: Number(confidence?.role ?? 0),
    company: Number(confidence?.company ?? 0),
    email: Number(confidence?.email ?? 0),
    phone: Number(confidence?.phone ?? 0),
    location: Number(confidence?.location ?? 0),
  };
}

function normalizeParsedCard(data: any, rawText: string): GeminiParsedCard {
  return {
    name: String(data?.name || ''),
    role: String(data?.role || ''),
    company: String(data?.company || ''),
    email: String(data?.email || ''),
    phone: String(data?.phone || ''),
    location: String(data?.location || ''),
    confidence: normalizeConfidence(data?.confidence),
    rawText: String(data?.rawText || rawText || ''),
    cardDetected: Boolean(data?.cardDetected),
    cardQuality: Number(data?.cardQuality ?? 0),
    aiError: data?.aiError ? String(data.aiError) : undefined,
  };
}

async function fetchWithTimeout(
  url: string,
  options: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeoutId);
  }
}

export async function parseCardTextWithGemini(
  rawText: string,
): Promise<GeminiParsedCard | null> {
  try {
    const text = rawText?.trim() || '';

    if (text.length < 5) {
      return null;
    }

    const response = await fetchWithTimeout(
      `${BACKEND_URL}/api/gemini/parse-card`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ rawText: text }),
      },
      REQUEST_TIMEOUT_MS,
    );

    if (!response.ok) {
      console.error('Gemini parser backend error:', response.status);
      return null;
    }

    const data = await response.json();
    return normalizeParsedCard(data, text);
  } catch (error) {
    console.error('Gemini parser request failed:', error);
    return null;
  }
}
