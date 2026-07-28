import { Lead } from '../types';

export interface DuplicateCheck {
  type: 'exact' | 'possible' | 'new';
  existing?: Lead;
  score?: number;
  diffs?: {
    [key: string]: { old: string; new: string };
  };
}

/**
 * Duplicate Detection Service
 * Identifies existing leads that match new scanned cards
 */
export class DuplicateService {
  /**
   * Check if a lead is a duplicate of any existing lead
   * Returns three types:
   * - 'exact': 100% match (same name, email, phone, company)
   * - 'possible': 85%+ match (2+ key fields match)
   * - 'new': No match found
   */
  static checkDuplicate(newLead: Lead, existingLeads: Lead[]): DuplicateCheck {
    // First try to find exact match
    for (const existing of existingLeads) {
      if (this.isExactMatch(newLead, existing)) {
        return {
          type: 'exact',
          existing,
          score: 100,
        };
      }
    }

    // Then try to find possible matches
    for (const existing of existingLeads) {
      const score = this.calculateMatchScore(newLead, existing);
      if (score >= 0.85) {
        const diffs = this.findDifferences(newLead, existing);
        return {
          type: 'possible',
          existing,
          score: Math.round(score * 100),
          diffs,
        };
      }
    }

    // No duplicates found
    return { type: 'new' };
  }

  /**
   * Check if two leads are exact matches
   * All key fields must match exactly
   */
  private static isExactMatch(lead1: Lead, lead2: Lead): boolean {
    return (
      lead1.name.toLowerCase() === lead2.name.toLowerCase() &&
      lead1.email.toLowerCase() === lead2.email.toLowerCase() &&
      lead1.phone === lead2.phone &&
      lead1.company.toLowerCase() === lead2.company.toLowerCase()
    );
  }

  /**
   * Calculate match score (0-1) based on field similarity
   * Uses: email, phone, company as primary matching fields
   */
  private static calculateMatchScore(lead1: Lead, lead2: Lead): number {
    const scores: number[] = [];

    // Email match (40% weight if primary matching field)
    if (lead1.email && lead2.email) {
      const emailMatch =
        lead1.email.toLowerCase() === lead2.email.toLowerCase() ? 1 : 0.3;
      scores.push(emailMatch * 0.4);
    }

    // Phone match (40% weight if primary matching field)
    if (lead1.phone && lead2.phone) {
      const phoneMatch = lead1.phone === lead2.phone ? 1 : this.phoneSimilarity(lead1.phone, lead2.phone);
      scores.push(phoneMatch * 0.4);
    }

    // Company match (15% weight)
    if (lead1.company && lead2.company) {
      const companyMatch =
        lead1.company.toLowerCase() === lead2.company.toLowerCase() ? 1 : 0.2;
      scores.push(companyMatch * 0.15);
    }

    // Name match (5% weight as least reliable field)
    if (lead1.name && lead2.name) {
      const nameMatch =
        lead1.name.toLowerCase() === lead2.name.toLowerCase() ? 1 : 0;
      scores.push(nameMatch * 0.05);
    }

    return scores.length > 0 ? scores.reduce((a, b) => a + b, 0) : 0;
  }

  /**
   * Calculate phone number similarity
   * Returns 1 if identical, partial score if similar (handles formatting differences)
   */
  private static phoneSimilarity(phone1: string, phone2: string): number {
    // Remove all non-digit characters for comparison
    const digits1 = phone1.replace(/\D/g, '');
    const digits2 = phone2.replace(/\D/g, '');

    if (digits1 === digits2) return 1;

    // Check if one contains the other (partial match)
    if (digits1.includes(digits2) || digits2.includes(digits1)) {
      return 0.9;
    }

    // Check last 7 digits (common local number matching)
    if (
      digits1.slice(-7) === digits2.slice(-7) &&
      digits1.slice(-7) !== ''
    ) {
      return 0.8;
    }

    return 0;
  }

  /**
   * Find differences between new and existing lead
   * Returns only fields that differ
   */
  private static findDifferences(
    newLead: Lead,
    existingLead: Lead,
  ): { [key: string]: { old: string; new: string } } {
    const diffs: { [key: string]: { old: string; new: string } } = {};
    const fieldsToCheck: (keyof Lead)[] = [
      'name',
      'role',
      'company',
      'email',
      'phone',
      'location',
    ];

    for (const field of fieldsToCheck) {
      const newValue = String(newLead[field] || '').toLowerCase();
      const oldValue = String(existingLead[field] || '').toLowerCase();

      if (newValue !== oldValue && newValue !== '' && oldValue !== '') {
        diffs[field] = {
          old: String(existingLead[field] || ''),
          new: String(newLead[field] || ''),
        };
      }
    }

    return diffs;
  }
}

export default DuplicateService;
