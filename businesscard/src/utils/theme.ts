// Color palette and theme for AskEva (Premium Minimalist Light Mode)
export const EVA = {
  // Premium Polished Green (Based on Logo)
  green: '#58C536',
  greenDeep: '#45A528',
  greenSoft: '#EEF8E8',
  greenInk: '#16330D',
  greenGradient: ['#8CD443', '#58C536'] as const,
  
  // Neutral Light Mode scale
  ink: '#141714',
  body: '#4F5750',
  muted: '#8A968B',
  hairline: '#EAECE9',
  surface: '#FFFFFF',
  canvas: '#F7F8F6',
  chip: '#F2F4F0',
  
  // Status Colors
  warn: '#E5921A',
  warnSoft: '#FDF4E7',
  danger: '#DE3B40',
  dangerSoft: '#FCECEC',
  info: '#2B80ED',
  infoSoft: '#E6F0FD',

  // UI Shadows
  shadow: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.05,
    shadowRadius: 12,
    elevation: 2,
  },
  
  shadowLg: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 24,
    elevation: 4,
  },

  // Aliases used across screens
  bgColor: '#F7F8F6',
  text: '#141714',
  border: '#EAECE9',
  greyText: '#8A968B',
  orange: '#E5921A',
  red: '#DE3B40',
};

export const SCORE_FIELDS = [
  { k: 'designation', l: 'Designation match', max: 20 },
  { k: 'company', l: 'Company size', max: 20 },
  { k: 'email', l: 'Email replied', max: 20 },
  { k: 'brochure', l: 'Brochure opened', max: 20 },
  { k: 'event', l: 'Event relevance', max: 20 },
];

export function scoreBand(s: number): 'high' | 'mid' | 'low' {
  if (s >= 75) return 'high';
  if (s >= 40) return 'mid';
  return 'low';
}

export function getScoreColor(band: 'high' | 'mid' | 'low'): string {
  switch (band) {
    case 'high':
      return EVA.green;
    case 'mid':
      return EVA.warn;
    case 'low':
      return EVA.danger;
  }
}
