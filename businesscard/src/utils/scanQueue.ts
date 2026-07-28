import { ExtractedCard, OCRService } from './ocr';
import { Lead } from '../types';

export interface QueuedCard {
  id: string;
  lead: Lead;
  extracted: ExtractedCard;
  imageUri?: string;
  createdAt: string;
}

class ScanQueueService {
  private static queue: QueuedCard[] = [];

  static addCard(extracted: ExtractedCard, imageUri?: string): QueuedCard {
    const lead = OCRService.createLeadFromExtraction(extracted);
    const queuedCard: QueuedCard = {
      id: lead.id,
      lead,
      extracted,
      imageUri,
      createdAt: new Date().toISOString(),
    };

    this.queue = [queuedCard, ...this.queue];
    return queuedCard;
  }

  static getCards(): QueuedCard[] {
    return [...this.queue];
  }

  static removeCard(id: string): void {
    this.queue = this.queue.filter(card => card.id !== id);
  }

  static clear(): void {
    this.queue = [];
  }

  static count(): number {
    return this.queue.length;
  }
}

export default ScanQueueService;
