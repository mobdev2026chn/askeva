// Shared UI bits for AskEva Lead Capture prototype.

const EVA = {
  // Brand greens, tuned to the AskEva mark (oklch-balanced)
  green: '#52C41A',        // primary action / accent
  greenDeep: '#3B9612',    // pressed / heading accents
  greenSoft: '#E8F8DC',    // tinted bg for chips, success
  greenInk: '#0F1F08',     // near-black, slight green undertone
  // Neutrals (warm, low-chroma)
  ink: '#0E1410',
  body: '#3B4339',
  muted: '#6A7567',
  hairline: '#E6E8E2',
  surface: '#FFFFFF',
  canvas: '#F5F6F2',
  chip: '#F1F3EC',
  // Status colors
  warn: '#E08A1E',
  warnSoft: '#FCEED6',
  danger: '#D93B3B',
  dangerSoft: '#FCE5E5',
  info: '#2E7AE6',
  infoSoft: '#E1ECFB',
  // System
  font: '"Inter", "SF Pro Text", -apple-system, system-ui, sans-serif',
  fontDisplay: '"Inter", "SF Pro Display", -apple-system, system-ui, sans-serif',
};

// Inline SVG icons — small, monoline, professional.
const Icon = ({ name, size = 20, color = 'currentColor', stroke = 1.75 }) => {
  const paths = {
    scan: <><path d="M3 8V5a2 2 0 0 1 2-2h3"/><path d="M21 8V5a2 2 0 0 0-2-2h-3"/><path d="M3 16v3a2 2 0 0 0 2 2h3"/><path d="M21 16v3a2 2 0 0 1-2 2h-3"/><path d="M7 12h10"/></>,
    camera: <><path d="M4 8a2 2 0 0 1 2-2h2l1.5-2h5L16 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/><circle cx="12" cy="13" r="3.5"/></>,
    user: <><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-7 8-7s8 3 8 7"/></>,
    users: <><circle cx="9" cy="8" r="3.5"/><path d="M2 20c0-3.5 3.1-6 7-6s7 2.5 7 6"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7"/><path d="M22 20c0-3-2.4-5.5-5.5-6"/></>,
    home: <><path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/></>,
    chart: <><path d="M4 20V8"/><path d="M10 20V4"/><path d="M16 20v-7"/><path d="M22 20H2"/></>,
    funnel: <><path d="M3 5h18l-7 8v6l-4-2v-4z"/></>,
    search: <><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></>,
    filter: <><path d="M4 5h16"/><path d="M7 12h10"/><path d="M10 19h4"/></>,
    plus: <><path d="M12 5v14"/><path d="M5 12h14"/></>,
    check: <path d="M5 12.5l4.5 4.5L19 7.5"/>,
    chevR: <path d="m9 6 6 6-6 6"/>,
    chevL: <path d="m15 6-6 6 6 6"/>,
    chevD: <path d="m6 9 6 6 6-6"/>,
    close: <><path d="M6 6l12 12"/><path d="M18 6 6 18"/></>,
    phone: <path d="M4.5 4.5h4l1.5 4-2 1.5a12 12 0 0 0 6 6L15.5 14l4 1.5v4a1 1 0 0 1-1.1 1A17 17 0 0 1 3.5 5.6 1 1 0 0 1 4.5 4.5z"/>,
    mail: <><rect x="3" y="5.5" width="18" height="13" rx="2"/><path d="m3.5 7 8.5 6 8.5-6"/></>,
    whats: <><path d="M3.5 20.5l1.4-4.5a8.5 8.5 0 1 1 3.6 3.5z"/><path d="M9 9.5c.2 1.4 1.1 2.8 2.3 4 1.2 1.1 2.6 2 4 2.3.5.1 1-.1 1.3-.5l.6-.8c.2-.3.2-.7-.1-1l-1.6-1c-.3-.2-.7-.2-1 .1l-.3.3c-.7-.3-1.3-.8-1.9-1.4-.6-.6-1.1-1.2-1.4-1.9l.3-.3c.3-.3.3-.7.1-1l-1-1.6c-.3-.3-.7-.3-1-.1l-.8.6c-.4.3-.6.8-.5 1.3z"/></>,
    star: <path d="m12 4 2.5 5.2 5.5.8-4 3.9 1 5.6L12 16.9 6.9 19.5l1-5.6-4-3.9 5.5-.8z"/>,
    edit: <><path d="M4 20h4l11-11-4-4L4 16z"/><path d="m14 7 4 4"/></>,
    note: <><path d="M5 4h11l4 4v12H5z"/><path d="M16 4v4h4"/><path d="M8 12h8M8 16h5"/></>,
    bell: <><path d="M6 9a6 6 0 1 1 12 0c0 5 2 6 2 6H4s2-1 2-6"/><path d="M10 20a2 2 0 0 0 4 0"/></>,
    settings: <><circle cx="12" cy="12" r="2.5"/><path d="M19.4 13.5c.1-.5.1-1 0-1.5l1.7-1.3a8 8 0 0 0-1.7-2.9l-2 .7c-.4-.3-.8-.6-1.3-.8L15.7 5h-3.4l-.4 2.7c-.5.2-.9.5-1.3.8l-2-.7a8 8 0 0 0-1.7 2.9l1.7 1.3c-.1.5-.1 1 0 1.5l-1.7 1.3a8 8 0 0 0 1.7 2.9l2-.7c.4.3.8.6 1.3.8l.4 2.7h3.4l.4-2.7c.5-.2.9-.5 1.3-.8l2 .7a8 8 0 0 0 1.7-2.9z"/></>,
    flash: <path d="M13 3 4 14h6l-1 7 9-11h-6z"/>,
    image: <><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="m3 18 5-5 5 5 3-3 5 5"/></>,
    warn: <><path d="M12 4 2 21h20z"/><path d="M12 10v5"/><circle cx="12" cy="18" r=".5" fill="currentColor" stroke="none"/></>,
    merge: <><path d="M7 4v6c0 4 4 4 4 8v2"/><path d="M17 4v6c0 4-4 4-4 8"/><path d="M14 14l3 3 3-3"/></>,
    calendar: <><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></>,
    clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
    sort: <><path d="M7 4v16M4 16l3 4 3-4"/><path d="M17 20V4M14 8l3-4 3 4"/></>,
    eye: <><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/></>,
    download: <><path d="M12 4v12"/><path d="m7 11 5 5 5-5"/><path d="M5 20h14"/></>,
    tag: <><path d="M3 13V4a1 1 0 0 1 1-1h9l8 8-9 9z"/><circle cx="8" cy="8" r="1.4" fill="currentColor" stroke="none"/></>,
    building: <><path d="M4 21V5l8-2v18"/><path d="M12 21h8V9l-8-2"/><path d="M7 9h1M7 12h1M7 15h1M15 12h1M15 15h1M15 18h1"/></>,
    map: <><path d="M9 3 3 5v16l6-2 6 2 6-2V3l-6 2z"/><path d="M9 3v16M15 5v16"/></>,
    target: <><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.2" fill="currentColor" stroke="none"/></>,
    refresh: <><path d="M4 12a8 8 0 0 1 14-5"/><path d="M18 3v4h-4"/><path d="M20 12a8 8 0 0 1-14 5"/><path d="M6 21v-4h4"/></>,
    spark: <><path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6"/></>,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color}
      strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" style={{ flexShrink: 0 }}>
      {paths[name]}
    </svg>
  );
};

// Top bar inside each phone screen.
function AppBar({ left, title, right, sub, dark = false }) {
  return (
    <div style={{
      paddingTop: 56, paddingBottom: 14, padding: '56px 20px 14px',
      background: dark ? EVA.greenInk : EVA.surface,
      borderBottom: `1px solid ${dark ? 'rgba(255,255,255,0.08)' : EVA.hairline}`,
      display: 'flex', alignItems: 'center', gap: 12, minHeight: 48,
    }}>
      <div style={{ width: 28, display: 'flex', alignItems: 'center' }}>{left}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 17, fontWeight: 600, color: dark ? '#fff' : EVA.ink, letterSpacing: -0.2, fontFamily: EVA.fontDisplay }}>{title}</div>
        {sub && <div style={{ fontSize: 12, color: dark ? 'rgba(255,255,255,0.55)' : EVA.muted, marginTop: 1 }}>{sub}</div>}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>{right}</div>
    </div>
  );
}

// Bottom tab bar — Home, Leads, Scan (FAB), LMS, Profile.
function TabBar({ active = 'home' }) {
  const tabs = [
    { key: 'home', icon: 'home', label: 'Home' },
    { key: 'leads', icon: 'users', label: 'Leads' },
    { key: 'scan', icon: 'scan', label: '', fab: true },
    { key: 'lms', icon: 'funnel', label: 'LMS' },
    { key: 'me', icon: 'user', label: 'Me' },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      paddingBottom: 28, paddingTop: 8,
      background: '#fff', borderTop: `1px solid ${EVA.hairline}`,
      display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)',
      zIndex: 5,
    }}>
      {tabs.map(t => t.fab ? (
        <div key={t.key} style={{ display: 'flex', justifyContent: 'center', alignItems: 'flex-start' }}>
          <div style={{
            width: 54, height: 54, borderRadius: 27,
            background: EVA.green, marginTop: -22,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 6px 14px ${EVA.green}55, 0 2px 6px rgba(0,0,0,0.1)`,
            border: '4px solid #fff',
          }}>
            <Icon name="scan" size={24} color="#fff" stroke={2} />
          </div>
        </div>
      ) : (
        <div key={t.key} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
          <Icon name={t.icon} size={22} color={active === t.key ? EVA.green : EVA.muted} stroke={active === t.key ? 2 : 1.7} />
          <div style={{ fontSize: 10.5, fontWeight: 500, color: active === t.key ? EVA.green : EVA.muted, letterSpacing: 0.1 }}>{t.label}</div>
        </div>
      ))}
    </div>
  );
}

// AskEva mini logo — speech-bracket frame around "EVA".
function EvaLogo({ size = 36, color = '#fff' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
      {/* speech-bracket frame */}
      <path d="M14 14 C 14 12, 16 11, 18 12 L20 8 L22 12 C 24 11, 26 12, 26 14
               L26 44 C 26 46, 28 47, 30 46 L 32 52 L 34 46 C 36 47, 38 46, 38 44
               L 38 14 C 38 12, 40 11, 42 12 L 44 8 L 46 12 C 48 11, 50 12, 50 14"
        stroke={color} strokeWidth="3.5" strokeLinejoin="round" strokeLinecap="round" fill="none"
        transform="rotate(90 32 32)" />
      <circle cx="26" cy="14" r="2.2" fill={color} />
      <circle cx="34" cy="14" r="2.2" fill={color} />
      <text x="32" y="40" textAnchor="middle" fontFamily="Inter, sans-serif" fontWeight="900"
        fontSize="14" fill={color} letterSpacing="1">EVA</text>
    </svg>
  );
}

// Primary button
function Button({ children, kind = 'primary', icon, full, size = 'lg', onClick, style = {} }) {
  const palette = {
    primary: { bg: EVA.green, fg: '#fff', border: 'transparent' },
    dark:    { bg: EVA.ink, fg: '#fff', border: 'transparent' },
    ghost:   { bg: 'transparent', fg: EVA.ink, border: EVA.hairline },
    soft:    { bg: EVA.greenSoft, fg: EVA.greenDeep, border: 'transparent' },
    danger:  { bg: EVA.danger, fg: '#fff', border: 'transparent' },
  }[kind];
  const h = size === 'lg' ? 52 : size === 'md' ? 44 : 36;
  return (
    <button onClick={onClick} style={{
      height: h, padding: size === 'sm' ? '0 14px' : '0 20px',
      width: full ? '100%' : 'auto',
      borderRadius: 14, border: `1px solid ${palette.border}`,
      background: palette.bg, color: palette.fg,
      fontSize: size === 'sm' ? 13 : 15, fontWeight: 600, letterSpacing: -0.1,
      fontFamily: EVA.font, cursor: 'pointer',
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      boxShadow: kind === 'primary' ? `0 4px 12px ${EVA.green}30` : 'none',
      ...style,
    }}>
      {icon && <Icon name={icon} size={size === 'sm' ? 16 : 18} color={palette.fg} stroke={2} />}
      {children}
    </button>
  );
}

// Field
function Field({ label, value, hint, icon, badge, error, dark = false }) {
  return (
    <div style={{ marginBottom: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
        <div style={{ fontSize: 11.5, fontWeight: 600, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase' }}>{label}</div>
        {badge}
      </div>
      <div style={{
        background: dark ? 'rgba(255,255,255,0.06)' : '#fff',
        border: `1px solid ${error ? EVA.danger : EVA.hairline}`,
        borderRadius: 12, padding: '12px 14px',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        {icon && <Icon name={icon} size={18} color={EVA.muted} />}
        <div style={{ flex: 1, fontSize: 15, color: dark ? '#fff' : EVA.ink, fontWeight: 500 }}>{value}</div>
        {hint && <div style={{ fontSize: 11, color: EVA.muted }}>{hint}</div>}
      </div>
    </div>
  );
}

// Status pill
function Status({ kind = 'new', size = 'md' }) {
  const map = {
    new:       { label: 'New',          bg: EVA.infoSoft, fg: EVA.info,      dot: EVA.info },
    contacted: { label: 'Contacted',    bg: '#F4ECFB',    fg: '#7B3DC4',     dot: '#7B3DC4' },
    followup:  { label: 'Follow-up',    bg: EVA.warnSoft, fg: EVA.warn,      dot: EVA.warn },
    converted: { label: 'Converted',    bg: EVA.greenSoft,fg: EVA.greenDeep, dot: EVA.green },
    lost:      { label: 'Lost',         bg: '#F2F1EF',    fg: EVA.muted,     dot: EVA.muted },
  };
  const s = map[kind];
  const h = size === 'sm' ? 20 : 24;
  return (
    <span style={{
      height: h, padding: '0 10px', borderRadius: h / 2,
      background: s.bg, color: s.fg,
      fontSize: size === 'sm' ? 10.5 : 12, fontWeight: 600,
      display: 'inline-flex', alignItems: 'center', gap: 6,
      letterSpacing: 0.1,
    }}>
      <span style={{ width: 6, height: 6, borderRadius: 3, background: s.dot }} />
      {s.label}
    </span>
  );
}

// Avatar with initials
function Avatar({ name, size = 40, kind = 'soft' }) {
  const initials = (name || '?').split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase();
  const palettes = [
    { bg: EVA.greenSoft, fg: EVA.greenDeep },
    { bg: '#F4ECFB', fg: '#7B3DC4' },
    { bg: EVA.infoSoft, fg: EVA.info },
    { bg: EVA.warnSoft, fg: EVA.warn },
    { bg: '#F2EBE3', fg: '#8C5A2B' },
  ];
  const idx = (name || '').charCodeAt(0) % palettes.length;
  const p = palettes[idx];
  return (
    <div style={{
      width: size, height: size, borderRadius: size / 2,
      background: p.bg, color: p.fg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontSize: size * 0.36, fontWeight: 700, letterSpacing: 0.2,
      flexShrink: 0,
    }}>{initials}</div>
  );
}

Object.assign(window, { EVA, Icon, AppBar, TabBar, EvaLogo, Button, Field, Status, Avatar });
