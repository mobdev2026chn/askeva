export interface Lead {
  id: string;
  name: string;
  role: string;
  company: string;
  email: string;
  phone: string;
  location: string;
  status: 'new' | 'contacted' | 'followup';
  event: string;
  capturedAt: string;
  capturedBy: string;
  tags: string[];
  note: string;
  score: number;
  scoreBreak: ScoreBreak;
  followUp: FollowUp;
  reminder: Reminder | null;
  activity: Activity[];
}

export interface ScoreBreak {
  designation: number;
  company: number;
  email: number;
  brochure: number;
  event: number;
}

export interface FollowUp {
  date: string;
  daysFromNow: number;
  overdue: boolean;
  suggested: string;
}

export interface Reminder {
  label: string;
  when: string;
}

export interface Activity {
  t: string;
  k: 'scan' | 'call' | 'note' | 'tag' | 'email';
  text: string;
}

export interface User {
  id: string;
  name: string;
  role: string;
  company: string;
  region: string;
  phone: string;
  email: string;
  website: string;
}

export interface TeamMember {
  id: string;
  name: string;
  role: string;
  region: string;
  captured: number;
  todayDelta: number;
}

export interface AppState {
  screen: string;
  leads: Lead[];
  currentLeadId: string | null;
  user: User;
  syncStatus: 'synced' | 'syncing' | 'error';
}
