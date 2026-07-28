// Seed data for the prototype. Includes leads, team members (for LMS mgmt view),
// and three different scan scenarios so we can demo new/possible/exact-duplicate states.

const CURRENT_USER = {
  id: 'priya',
  name: 'Priya Rao',
  role: 'Account Executive',
  company: 'AskEva',
  region: 'Bengaluru',
  phone: '+91 98453 21100',
  email: 'priya.rao@askeva.io',
  website: 'askeva.io',
};

// Scoring rubric — 5 components, each 0–20 max, summed for the lead score.
const SCORE_FIELDS = [
  { k: 'designation', l: 'Designation match', max: 20 },
  { k: 'company', l: 'Company size', max: 20 },
  { k: 'email', l: 'Email replied', max: 20 },
  { k: 'brochure', l: 'Brochure opened', max: 20 },
  { k: 'event', l: 'Event relevance', max: 20 },
];

// Helpers: score color band
function scoreBand(s) {
  if (s >= 75) return 'high';
  if (s >= 40) return 'mid';
  return 'low';
}

const TEAM = [
  { id: 'priya', name: 'Priya Rao', role: 'AE', region: 'Bengaluru', captured: 24, todayDelta: 6 },
  { id: 'arjun', name: 'Arjun Iyer', role: 'AE', region: 'Bengaluru', captured: 18, todayDelta: 4 },
  { id: 'neha', name: 'Neha Verma', role: 'SDR', region: 'Mumbai', captured: 14, todayDelta: 3 },
  { id: 'kabir', name: 'Kabir Sharma', role: 'SDR', region: 'Mumbai', captured: 11, todayDelta: 2 },
  { id: 'leah', name: 'Leah Fernandes', role: 'Manager', region: 'Bengaluru', captured: 7, todayDelta: 1 },
];

const SEED_LEADS = [
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
  },
  {
    id: 'daniel',
    name: 'Daniel Park',
    role: 'Head of GTM',
    company: 'Northbeam',
    email: 'daniel@northbeam.io',
    phone: '+1 415 555 0188',
    location: 'San Francisco, CA',
    status: 'followup',
    event: 'SaaStock 2026',
    capturedAt: '1 h',
    capturedBy: 'arjun',
    tags: ['Booth visitor', 'Day 1'],
    note: 'Asked us to send the team a demo invite next week.',
    score: 78,
    scoreBreak: { designation: 16, company: 17, email: 15, brochure: 14, event: 16 },
    followUp: { date: 'May 20, 2026', daysFromNow: 1, overdue: false, suggested: 'Demo invite' },
    reminder: { label: 'Send demo invite', when: 'Tomorrow · 10 AM' },
  },
  {
    id: 'mariana',
    name: 'Mariana Costa',
    role: 'Procurement Lead',
    company: 'Vetra',
    email: 'm.costa@vetra.com',
    phone: '+55 11 9876 5432',
    location: 'São Paulo, BR',
    status: 'new',
    event: 'SaaStock 2026',
    capturedAt: '3 h',
    capturedBy: 'priya',
    tags: [],
    note: '',
    score: 52,
    scoreBreak: { designation: 12, company: 14, email: 8, brochure: 10, event: 8 },
    followUp: { date: 'May 15, 2026', daysFromNow: -4, overdue: true, suggested: 'Procurement intro' },
    reminder: null,
  },
  {
    id: 'jin',
    name: 'Jin Park',
    role: 'Founder & CEO',
    company: 'Foundry Robotics',
    email: 'jin@foundryrobotics.com',
    phone: '+82 10 4477 2255',
    location: 'Seoul, KR',
    status: 'converted',
    event: 'Dreamforce',
    capturedAt: 'Yesterday',
    capturedBy: 'neha',
    tags: ['Booth visitor'],
    note: 'Followed up after Dreamforce. Now an active customer.',
    score: 95,
    scoreBreak: { designation: 20, company: 20, email: 19, brochure: 18, event: 18 },
    followUp: { date: 'May 25, 2026', daysFromNow: 6, overdue: false, suggested: 'QBR prep' },
    reminder: { label: 'QBR prep', when: 'Mon · 3 PM' },
  },
  {
    id: 'hannah',
    name: 'Hannah Becker',
    role: 'RevOps Manager',
    company: 'Brightline',
    email: 'hannah.b@brightline.io',
    phone: '+1 206 555 0142',
    location: 'Seattle, WA',
    status: 'contacted',
    event: 'Dreamforce',
    capturedAt: '2 d',
    capturedBy: 'arjun',
    tags: ['Booth visitor'],
    note: '',
    score: 64,
    scoreBreak: { designation: 14, company: 15, email: 12, brochure: 11, event: 12 },
    followUp: { date: 'May 22, 2026', daysFromNow: 3, overdue: false, suggested: 'Re-engage' },
    reminder: null,
  },
  {
    id: 'omar',
    name: 'Omar Siddiqui',
    role: 'Clinical Director',
    company: 'Helix Health',
    email: 'o.siddiqui@helixhealth.org',
    phone: '+971 50 887 9911',
    location: 'Dubai, AE',
    status: 'followup',
    event: 'HIMSS',
    capturedAt: '5 d',
    capturedBy: 'kabir',
    tags: ['Healthcare'],
    note: '',
    score: 38,
    scoreBreak: { designation: 10, company: 11, email: 5, brochure: 6, event: 6 },
    followUp: { date: 'May 22, 2026', daysFromNow: 3, overdue: false, suggested: 'Case study' },
    reminder: { label: 'Send case study', when: 'in 3 days' },
  },
];

// Three scan scenarios — chosen at runtime to demo the three dup states.
// Each lists the matchType the system will infer when this card is saved.
const SCAN_SCENARIOS = {
  // Same phone+company as Rohan — system should call this an EXACT duplicate.
  exact: {
    matchType: 'exact',
    matchedId: 'rohan',
    data: {
      name: 'Rohan Mehta',
      role: 'VP, Sales',
      company: 'Zinith Analytics',
      email: 'rohan.m@zinith.io',
      phone: '+91 98213 44021',
      location: 'Mumbai, MH',
      conf: { name: 0.99, role: 0.96, company: 0.98, email: 0.99, phone: 0.95, location: 0.88 },
    },
  },
  // Same phone, but email/location updated — POSSIBLE duplicate, asks for merge decision.
  possible: {
    matchType: 'possible',
    matchedId: 'rohan',
    data: {
      name: 'Rohan Mehta',
      role: 'VP, Sales',
      company: 'Zinith Analytics',
      email: 'rohan@zinith.io',
      phone: '+91 98213 44021',
      location: 'Bengaluru, KA',
      conf: { name: 0.98, role: 0.94, company: 0.97, email: 0.99, phone: 0.92, location: 0.71 },
    },
  },
  // Brand new — Sara, no overlap with anyone — NEW.
  fresh: {
    matchType: 'new',
    matchedId: null,
    data: {
      name: 'Sara Lopez',
      role: 'Product Marketing Lead',
      company: 'Tessera Cloud',
      email: 'sara.lopez@tessera.cloud',
      phone: '+34 612 778 940',
      location: 'Madrid, ES',
      conf: { name: 0.97, role: 0.89, company: 0.95, email: 0.98, phone: 0.93, location: 0.66 },
    },
  },
};

const STATUS_ORDER = { new: 0, followup: 1, contacted: 2, converted: 3 };

Object.assign(window, { SEED_LEADS, SCAN_SCENARIOS, STATUS_ORDER, TEAM, CURRENT_USER, SCORE_FIELDS, scoreBand });
