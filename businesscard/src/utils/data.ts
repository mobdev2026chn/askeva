import { Lead, User, TeamMember } from '../types';

export const CURRENT_USER: User = {
  id: 'priya',
  name: 'Priya Rao',
  role: 'Account Executive',
  company: 'AskEva',
  region: 'Bengaluru',
  phone: '+91 98453 21100',
  email: 'priya.rao@askeva.io',
  website: 'askeva.io',
};

export const TEAM: TeamMember[] = [
  { id: 'priya', name: 'Priya Rao', role: 'AE', region: 'Bengaluru', captured: 24, todayDelta: 6 },
  { id: 'arjun', name: 'Arjun Iyer', role: 'AE', region: 'Bengaluru', captured: 18, todayDelta: 4 },
  { id: 'neha', name: 'Neha Verma', role: 'SDR', region: 'Mumbai', captured: 14, todayDelta: 3 },
  { id: 'kabir', name: 'Kabir Sharma', role: 'SDR', region: 'Mumbai', captured: 11, todayDelta: 2 },
  { id: 'leah', name: 'Leah Fernandes', role: 'Manager', region: 'Bengaluru', captured: 7, todayDelta: 1 },
];

export const SEED_LEADS: Lead[] = [
  {
    id: 'rohan',
    name: 'Rohan Mehta',
    role: 'VP, Sales',
    company: 'Zinith Analytics',
    email: 'rohan.m@zinith.io',
    phone: '+91 98213 44021',
    location: 'Mumbai, MH',
    status: 'contacted',
    event: 'SaaStock 2026',
    capturedAt: '2 h',
    capturedBy: 'priya',
    tags: ['Met at booth', 'Requested deck'],
    note: 'Met Rohan at the Zinith Analytics booth. He asked us to send the product overview deck next week.',
    score: 87,
    scoreBreak: { designation: 18, company: 17, email: 18, brochure: 16, event: 18 },
    followUp: { date: 'May 22, 2026', daysFromNow: 3, overdue: false, suggested: '3 days after event' },
    reminder: { label: 'Send product overview', when: 'in 2 days · 10 AM' },
    activity: [
      { t: '2 h', k: 'scan', text: 'Captured at SaaStock booth #B12' },
      { t: '1 h', k: 'call', text: 'Spoke for 8 min about the booth demo' },
      { t: '45m', k: 'note', text: 'Added note about product overview deck' },
      { t: '20m', k: 'tag', text: 'Tagged with Met at booth' },
    ],
  },
  {
    id: 'aisha',
    name: 'Sample',
    role: 'CTO',
    company: 'Lumen Labs',
    email: 'aisha@lumenlabs.co',
    phone: '+91 99887 12030',
    location: 'Bengaluru, KA',
    status: 'new',
    event: 'SaaStock 2026',
    capturedAt: '12 min',
    capturedBy: 'priya',
    tags: ['Met at booth'],
    note: '',
    score: 92,
    scoreBreak: { designation: 20, company: 19, email: 18, brochure: 17, event: 18 },
    followUp: { date: 'May 17, 2026', daysFromNow: -2, overdue: true, suggested: 'CTO follow-up' },
    reminder: null,
    activity: [{ t: '12 min', k: 'scan', text: 'Captured at SaaStock booth' }],
  },
];
