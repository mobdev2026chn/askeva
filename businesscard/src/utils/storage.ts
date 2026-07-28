import AsyncStorage from '@react-native-async-storage/async-storage';
import { Lead } from '../types';
import { SEED_LEADS } from './data';

const LEADS_STORAGE_KEY = 'askeva_leads';

/**
 * Storage Service - Handle all data persistence operations
 */
export class StorageService {
  /**
   * Initialize storage with seed data if empty
   */
  static async initialize(): Promise<void> {
    try {
      const existing = await AsyncStorage.getItem(LEADS_STORAGE_KEY);
      if (!existing) {
        // Initialize with seed data on first run
        await AsyncStorage.setItem(LEADS_STORAGE_KEY, JSON.stringify(SEED_LEADS));
      }
    } catch (error) {
      console.error('Storage initialization error:', error);
    }
  }

  /**
   * Get all leads from storage
   */
  static async getLeads(): Promise<Lead[]> {
    try {
      const data = await AsyncStorage.getItem(LEADS_STORAGE_KEY);
      return data ? JSON.parse(data) : [];
    } catch (error) {
      console.error('Error loading leads:', error);
      return [];
    }
  }

  /**
   * Save a new lead to storage
   */
  static async saveLead(lead: Lead): Promise<void> {
    try {
      const leads = await this.getLeads();
      // Check if lead already exists by ID
      const existingIndex = leads.findIndex(l => l.id === lead.id);
      if (existingIndex >= 0) {
        leads[existingIndex] = lead; // Update
      } else {
        leads.push(lead); // Add new
      }
      await AsyncStorage.setItem(LEADS_STORAGE_KEY, JSON.stringify(leads));
    } catch (error) {
      console.error('Error saving lead:', error);
      throw error;
    }
  }

  /**
   * Update an existing lead
   */
  static async updateLead(leadId: string, updates: Partial<Lead>): Promise<void> {
    try {
      const leads = await this.getLeads();
      const index = leads.findIndex(l => l.id === leadId);
      if (index >= 0) {
        leads[index] = { ...leads[index], ...updates };
        await AsyncStorage.setItem(LEADS_STORAGE_KEY, JSON.stringify(leads));
      }
    } catch (error) {
      console.error('Error updating lead:', error);
      throw error;
    }
  }

  /**
   * Delete a lead
   */
  static async deleteLead(leadId: string): Promise<void> {
    try {
      const leads = await this.getLeads();
      const filtered = leads.filter(l => l.id !== leadId);
      await AsyncStorage.setItem(LEADS_STORAGE_KEY, JSON.stringify(filtered));
    } catch (error) {
      console.error('Error deleting lead:', error);
      throw error;
    }
  }

  /**
   * Merge two leads (update existing with new data, keeping some old fields)
   */
  static async mergeLead(existingId: string, newLeadData: Partial<Lead>): Promise<void> {
    try {
      const leads = await this.getLeads();
      const index = leads.findIndex(l => l.id === existingId);
      if (index >= 0) {
        const existing = leads[index];
        // Merge: keep old values for unchanged fields, update changed ones
        const merged: Lead = {
          ...existing,
          ...newLeadData,
          id: existing.id, // Never change ID
          activity: [
            ...(existing.activity || []),
            {
              t: this.getTimeAgo(new Date()),
              k: 'note' as const,
              text: 'Updated with new contact information',
            },
          ],
        };
        leads[index] = merged;
        await AsyncStorage.setItem(LEADS_STORAGE_KEY, JSON.stringify(leads));
      }
    } catch (error) {
      console.error('Error merging lead:', error);
      throw error;
    }
  }

  /**
   * Clear all leads (for testing)
   */
  static async clearAll(): Promise<void> {
    try {
      await AsyncStorage.removeItem(LEADS_STORAGE_KEY);
    } catch (error) {
      console.error('Error clearing storage:', error);
    }
  }

  /**
   * Format time as "X h", "X m", etc.
   */
  private static getTimeAgo(date: Date): string {
    const minutes = Math.floor((Date.now() - date.getTime()) / 60000);
    if (minutes < 1) return 'now';
    if (minutes < 60) return `${minutes}m`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h`;
    const days = Math.floor(hours / 24);
    return `${days}d`;
  }
}

export default StorageService;
