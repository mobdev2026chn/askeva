// Screens & components added in v2: MyCard (digital card exchange),
// ScorePill, ScoreBreakdown, ReachOut composer, OverdueAlert, FollowUpRow, etc.

// ─── Score pill ───────────────────────────────────────────────────
function ScorePill({ score, size = 'md' }) {
  const band = scoreBand(score);
  const palette = {
    high: { bg: EVA.greenSoft, fg: EVA.greenDeep, dot: EVA.green },
    mid:  { bg: EVA.warnSoft,  fg: EVA.warn,      dot: EVA.warn },
    low:  { bg: EVA.dangerSoft,fg: EVA.danger,    dot: EVA.danger },
  }[band];
  const h = size === 'sm' ? 18 : size === 'lg' ? 26 : 22;
  const fs = size === 'sm' ? 10 : size === 'lg' ? 13 : 11.5;
  return (
    <span style={{
      height: h, padding: size === 'sm' ? '0 7px' : '0 9px',
      borderRadius: h / 2,
      background: palette.bg, color: palette.fg,
      fontSize: fs, fontWeight: 700,
      letterSpacing: 0.1, fontVariantNumeric: 'tabular-nums',
      display: 'inline-flex', alignItems: 'center', gap: 5,
      flexShrink: 0,
    }}>
      <span style={{ width: 5, height: 5, borderRadius: 3, background: palette.dot }} />
      {score} pts
    </span>
  );
}

// ─── Score breakdown panel (used on Review + Lead detail) ─────────
function ScoreBreakdown({ breakdown, score }) {
  const band = scoreBand(score);
  const accent = { high: EVA.green, mid: EVA.warn, low: EVA.danger }[band];
  return (
    <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, padding: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
        <div style={{ width: 44, height: 44, borderRadius: 22, background: accent + '22', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
          <div style={{ fontSize: 14, fontWeight: 800, color: accent, letterSpacing: -0.3, fontFamily: EVA.fontDisplay }}>{score}</div>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <div style={{ fontSize: 13.5, fontWeight: 700, color: EVA.ink, letterSpacing: -0.1 }}>Lead score</div>
            <ScorePill score={score} size="sm" />
          </div>
          <div style={{ fontSize: 11, color: EVA.muted, marginTop: 2 }}>
            {band === 'high' ? 'High-fit lead — prioritise outreach' : band === 'mid' ? 'Mid-tier — nurture this week' : 'Low fit — recycle or de-prioritise'}
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {SCORE_FIELDS.map(f => {
          const v = breakdown?.[f.k] ?? 0;
          const pct = (v / f.max) * 100;
          return (
            <div key={f.k}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                <span style={{ fontSize: 11.5, color: EVA.body, fontWeight: 500 }}>{f.l}</span>
                <span style={{ fontSize: 11, color: EVA.ink, fontWeight: 700, fontVariantNumeric: 'tabular-nums' }}>{v}<span style={{ color: EVA.muted, fontWeight: 500 }}>/{f.max}</span></span>
              </div>
              <div style={{ height: 5, background: EVA.chip, borderRadius: 3, overflow: 'hidden' }}>
                <div style={{ width: pct + '%', height: '100%', background: accent, borderRadius: 3, transition: 'width 320ms' }} />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ─── Smart follow-up row (used on Review screen) ──────────────────
function FollowUpRow({ value, onChange, reminderOn, onReminder }) {
  return (
    <div style={{ background: '#fff', border: '1px solid ' + EVA.hairline, borderRadius: 14, padding: 14, marginTop: 6 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
        <Icon name="spark" size={14} color={EVA.greenDeep} stroke={2.2} />
        <div style={{ fontSize: 13, fontWeight: 700, color: EVA.ink, letterSpacing: -0.1 }}>Smart follow-up</div>
        <span style={{ fontSize: 10, fontWeight: 700, color: EVA.greenDeep, background: EVA.greenSoft, padding: '2px 6px', borderRadius: 6, letterSpacing: 0.4 }}>AI</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px', background: EVA.chip, borderRadius: 10 }}>
        <Icon name="calendar" size={16} color={EVA.body} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 10.5, color: EVA.muted, letterSpacing: 0.5, textTransform: 'uppercase', fontWeight: 600 }}>Suggested</div>
          <div style={{ fontSize: 13, color: EVA.ink, fontWeight: 600, marginTop: 1 }}>{value} <span style={{ color: EVA.muted, fontWeight: 500 }}>· 3 days after event</span></div>
        </div>
        <button onClick={onChange} style={resetBtn({ width: 30, height: 30, borderRadius: 8, background: '#fff', border: '1px solid ' + EVA.hairline, display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
          <Icon name="calendar" size={14} color={EVA.body} />
        </button>
      </div>
      <label style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 12, cursor: 'pointer' }}>
        <div onClick={onReminder} style={{
          width: 36, height: 22, borderRadius: 11, padding: 2,
          background: reminderOn ? EVA.green : EVA.hairline,
          display: 'flex', alignItems: 'center',
          transition: 'background 200ms',
        }}>
          <div style={{
            width: 18, height: 18, borderRadius: 9, background: '#fff',
            transform: reminderOn ? 'translateX(14px)' : 'translateX(0)',
            transition: 'transform 200ms',
            boxShadow: '0 2px 4px rgba(0,0,0,0.15)',
          }} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: EVA.ink }}>Set reminder</div>
          <div style={{ fontSize: 11, color: EVA.muted, marginTop: 1 }}>We'll nudge you at 10:00 AM IST</div>
        </div>
      </label>
    </div>
  );
}

// ─── Overdue follow-ups alert card (Dashboard) ────────────────────
function OverdueAlert({ count, onView }) {
  if (!count) return null;
  return (
    <button onClick={onView} style={resetBtn({
      width: '100%', textAlign: 'left',
      background: EVA.warnSoft, border: `1px solid ${EVA.warn}55`,
      borderRadius: 14, padding: '12px 14px',
      display: 'flex', alignItems: 'center', gap: 12,
    })}>
      <div style={{ width: 38, height: 38, borderRadius: 12, background: EVA.warn, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, boxShadow: `0 4px 10px ${EVA.warn}55` }}>
        <Icon name="clock" size={18} color="#fff" stroke={2.2} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13.5, fontWeight: 700, color: '#7A4A0E', letterSpacing: -0.1 }}>
          {count} follow-up{count > 1 ? 's' : ''} overdue
        </div>
        <div style={{ fontSize: 11.5, color: '#9C6418', marginTop: 1 }}>Re-engage before the lead goes cold</div>
      </div>
      <div style={{ fontSize: 12, fontWeight: 700, color: EVA.warn, display: 'inline-flex', alignItems: 'center', gap: 2 }}>
        View all <Icon name="chevR" size={13} color={EVA.warn} />
      </div>
    </button>
  );
}

// ─── Fake QR code — deterministic pattern from a seed string ──────
function FakeQR({ seed = 'EVA', size = 200 }) {
  const N = 33;
  const cell = size / N;
  // Simple deterministic hash for cell on/off
  const hash = (i, j) => {
    let h = 2166136261 ^ i * 16777619 ^ j * 31;
    for (let k = 0; k < seed.length; k++) h = (h ^ seed.charCodeAt(k)) * 16777619;
    return (h >>> 0) % 100;
  };
  const cells = [];
  for (let i = 0; i < N; i++) {
    for (let j = 0; j < N; j++) {
      // Reserve corners for finder patterns
      const inFinder = (i < 7 && j < 7) || (i < 7 && j >= N - 7) || (i >= N - 7 && j < 7);
      if (inFinder) continue;
      // Alignment pattern bottom-right
      const inAlign = (i >= N - 9 && i <= N - 5 && j >= N - 9 && j <= N - 5);
      if (inAlign) continue;
      const on = hash(i, j) > 50;
      if (on) cells.push(<rect key={`${i}-${j}`} x={j * cell} y={i * cell} width={cell} height={cell} fill="#0F1F08" />);
    }
  }
  const finder = (x, y) => (
    <g key={`f-${x}-${y}`}>
      <rect x={x * cell} y={y * cell} width={cell * 7} height={cell * 7} fill="#0F1F08" />
      <rect x={(x + 1) * cell} y={(y + 1) * cell} width={cell * 5} height={cell * 5} fill="#fff" />
      <rect x={(x + 2) * cell} y={(y + 2) * cell} width={cell * 3} height={cell * 3} fill="#0F1F08" />
    </g>
  );
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ display: 'block' }}>
      <rect width={size} height={size} fill="#fff" />
      {cells}
      {finder(0, 0)}
      {finder(N - 7, 0)}
      {finder(0, N - 7)}
      {/* Alignment square */}
      <g>
        <rect x={(N - 9) * cell} y={(N - 9) * cell} width={cell * 5} height={cell * 5} fill="#0F1F08" />
        <rect x={(N - 8) * cell} y={(N - 8) * cell} width={cell * 3} height={cell * 3} fill="#fff" />
        <rect x={(N - 7) * cell} y={(N - 7) * cell} width={cell} height={cell} fill="#0F1F08" />
      </g>
      {/* Center logo bubble */}
      <g>
        <rect x={size / 2 - 22} y={size / 2 - 22} width={44} height={44} rx={10} fill="#fff" />
        <rect x={size / 2 - 18} y={size / 2 - 18} width={36} height={36} rx={8} fill={EVA.green} />
        <text x={size / 2} y={size / 2 + 5} textAnchor="middle" fontFamily="Inter, sans-serif" fontWeight="800" fontSize="14" fill="#fff" letterSpacing="0.5">EVA</text>
      </g>
    </svg>
  );
}

// ─── MY CARD — digital card exchange ──────────────────────────────
function ScreenMyCard({ nav, state }) {
  const u = CURRENT_USER;
  const vcardSeed = `BEGIN:VCARD VERSION:3.0 FN:${u.name} ORG:${u.company} TEL:${u.phone} EMAIL:${u.email}`;
  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="My Card">
      <div style={{ background: EVA.greenInk, padding: '56px 20px 80px', position: 'relative', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', top: -30, right: -40, width: 220, height: 220, borderRadius: '50%', background: `radial-gradient(circle, ${EVA.green}33, transparent 70%)` }} />
        <div style={{ position: 'absolute', bottom: -50, left: -30, width: 180, height: 180, borderRadius: '50%', background: `radial-gradient(circle, ${EVA.green}22, transparent 70%)` }} />
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={() => nav.back()} style={resetBtn({ width: 36, height: 36, borderRadius: 18, background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
            <Icon name="chevL" size={18} color="#fff" />
          </button>
          <div style={{ fontSize: 13, fontWeight: 600, color: '#fff' }}>My digital card</div>
          <button onClick={() => nav.toast('Edit your card')} style={resetBtn({ width: 36, height: 36, borderRadius: 18, background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
            <Icon name="edit" size={16} color="#fff" />
          </button>
        </div>
      </div>

      <div style={{ padding: '0 20px 110px', marginTop: -56, position: 'relative', height: 'calc(100% - 116px)', overflow: 'auto' }}>
        {/* Card with QR */}
        <div style={{ background: '#fff', borderRadius: 22, padding: 22, border: '1px solid ' + EVA.hairline, boxShadow: '0 12px 32px rgba(0,0,0,0.08)' }}>
          {/* Identity row */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
            <Avatar name={u.name} size={48} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 17, fontWeight: 700, color: EVA.ink, letterSpacing: -0.3, fontFamily: EVA.fontDisplay }}>{u.name}</div>
              <div style={{ fontSize: 12, color: EVA.muted, marginTop: 1 }}>{u.role} · {u.company}</div>
            </div>
          </div>

          {/* QR */}
          <div style={{ background: EVA.canvas, borderRadius: 16, padding: 14, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
            <div style={{ borderRadius: 12, overflow: 'hidden', boxShadow: '0 2px 8px rgba(0,0,0,0.05)' }}>
              <FakeQR seed={vcardSeed} size={196} />
            </div>
            {/* corner brackets */}
            {[
              { t: 6, l: 6, edges: 'tl' }, { t: 6, r: 6, edges: 'tr' },
              { b: 6, l: 6, edges: 'bl' }, { b: 6, r: 6, edges: 'br' },
            ].map((p, i) => (
              <div key={i} style={{
                position: 'absolute',
                top: p.t, left: p.l, right: p.r, bottom: p.b,
                width: 18, height: 18,
                borderTop: p.edges.includes('t') ? `2px solid ${EVA.green}` : 'none',
                borderBottom: p.edges.includes('b') ? `2px solid ${EVA.green}` : 'none',
                borderLeft: p.edges.includes('l') ? `2px solid ${EVA.green}` : 'none',
                borderRight: p.edges.includes('r') ? `2px solid ${EVA.green}` : 'none',
                borderRadius: 4,
              }} />
            ))}
          </div>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, marginTop: 12, padding: '8px 12px', background: EVA.greenSoft, borderRadius: 10 }}>
            <Icon name="scan" size={14} color={EVA.greenDeep} stroke={2.2} />
            <div style={{ fontSize: 12, fontWeight: 700, color: EVA.greenDeep, letterSpacing: 0.1 }}>Tap to scan mine</div>
          </div>

          {/* Contact rows */}
          <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 8 }}>
            {[
              { i: 'phone', l: 'Phone', v: u.phone },
              { i: 'mail',  l: 'Email', v: u.email },
              { i: 'map',   l: 'Based in', v: u.region },
            ].map(r => (
              <div key={r.l} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 4px' }}>
                <div style={{ width: 28, height: 28, borderRadius: 9, background: EVA.chip, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name={r.i} size={13} color={EVA.body} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 10, color: EVA.muted, letterSpacing: 0.5, textTransform: 'uppercase', fontWeight: 600 }}>{r.l}</div>
                  <div style={{ fontSize: 13, color: EVA.ink, fontWeight: 600, marginTop: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.v}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Share row */}
        <div style={{ fontSize: 11.5, fontWeight: 700, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase', margin: '18px 4px 10px' }}>Share via</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <button onClick={() => nav.toast('Opening WhatsApp share…')} style={resetBtn({
            background: '#25D366', borderRadius: 14, padding: '14px 12px',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            boxShadow: '0 4px 12px rgba(37, 211, 102, 0.3)',
          })}>
            <Icon name="whats" size={18} color="#fff" stroke={2} />
            <span style={{ fontSize: 13.5, fontWeight: 700, color: '#fff' }}>WhatsApp</span>
          </button>
          <button onClick={() => nav.toast('Drafting email…')} style={resetBtn({
            background: EVA.ink, borderRadius: 14, padding: '14px 12px',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          })}>
            <Icon name="mail" size={18} color="#fff" stroke={2} />
            <span style={{ fontSize: 13.5, fontWeight: 700, color: '#fff' }}>Email</span>
          </button>
        </div>

        {/* Scan theirs */}
        <button onClick={() => nav.go('scan')} style={resetBtn({
          width: '100%', marginTop: 10,
          background: '#fff', border: '1.5px solid ' + EVA.hairline, borderRadius: 14, padding: '14px',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        })}>
          <Icon name="scan" size={17} color={EVA.green} stroke={2.2} />
          <span style={{ fontSize: 13.5, fontWeight: 700, color: EVA.ink }}>Scan theirs</span>
        </button>

        <div style={{ marginTop: 16, padding: '12px 14px', background: '#fff', border: '1px dashed ' + EVA.hairline, borderRadius: 12, display: 'flex', alignItems: 'center', gap: 10 }}>
          <Icon name="spark" size={14} color={EVA.greenDeep} />
          <div style={{ fontSize: 11.5, color: EVA.muted, lineHeight: 1.4 }}>
            Show your QR or have them point a camera. Eva detects either and adds them to your Lead page instantly.
          </div>
        </div>
      </div>

      <TabBar active="card" nav={nav} />
    </div>
  );
}

// ─── REACH OUT panel (used inside Lead detail) ────────────────────
function ReachOutPanel({ lead, channel, onSend, onCancel }) {
  const eventName = lead.event || 'the event';
  const firstName = (lead.name || '').split(' ')[0];
  const defaultMsg = channel === 'mail'
    ? `Hi ${firstName},\n\nGreat meeting you at ${eventName} ${eventName.includes('2026') ? '' : '2026'}! Here's our overview deck: askeva.io/deck\n\nLooking forward to connecting.\n\n— Priya, AskEva`
    : `Hi ${firstName}, great meeting you at ${eventName}! Here's our deck: askeva.io/deck. Looking forward to connecting. — Priya`;
  const [msg, setMsg] = React.useState(defaultMsg);
  const [track, setTrack] = React.useState(true);
  const isMail = channel === 'mail';
  const accent = isMail ? EVA.info : '#25D366';

  return (
    <div style={{
      background: '#fff', borderRadius: 14, border: `1.5px solid ${accent}55`,
      padding: 14, marginTop: 10,
      boxShadow: `0 8px 20px ${accent}1A`,
      animation: 'evaFadeIn 220ms cubic-bezier(0.2,0.8,0.2,1)',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
        <div style={{ width: 28, height: 28, borderRadius: 9, background: accent + '22', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name={isMail ? 'mail' : 'whats'} size={15} color={accent} stroke={2.2} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 12.5, fontWeight: 700, color: EVA.ink }}>{isMail ? 'New email' : 'WhatsApp message'}</div>
          <div style={{ fontSize: 10.5, color: EVA.muted, marginTop: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            To: {isMail ? lead.email : lead.phone}
          </div>
        </div>
        <button onClick={onCancel} style={resetBtn({ width: 24, height: 24, borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
          <Icon name="close" size={14} color={EVA.muted} />
        </button>
      </div>

      {isMail && (
        <div style={{ padding: '8px 10px', background: EVA.chip, borderRadius: 8, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ fontSize: 10, color: EVA.muted, letterSpacing: 0.5, textTransform: 'uppercase', fontWeight: 600 }}>Subject</div>
          <div style={{ flex: 1, fontSize: 12.5, color: EVA.ink, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>Great meeting at {eventName}</div>
        </div>
      )}

      <textarea
        value={msg}
        onChange={e => setMsg(e.target.value)}
        style={{
          width: '100%', minHeight: 110, padding: 10,
          border: '1px solid ' + EVA.hairline, borderRadius: 10,
          background: EVA.canvas, fontFamily: EVA.font, fontSize: 13,
          color: EVA.ink, lineHeight: 1.55, outline: 'none', resize: 'none',
        }}
      />

      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 10 }}>
        <div style={{ fontSize: 10, fontWeight: 700, color: EVA.greenDeep, background: EVA.greenSoft, padding: '3px 8px', borderRadius: 6, letterSpacing: 0.4 }}>TEMPLATE</div>
        <div style={{ fontSize: 11, color: EVA.muted }}>Event intro · Eva-suggested</div>
      </div>

      {isMail && (
        <label style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 12, cursor: 'pointer' }}>
          <div onClick={() => setTrack(t => !t)} style={{
            width: 34, height: 20, borderRadius: 10, padding: 2,
            background: track ? EVA.green : EVA.hairline,
            display: 'flex', alignItems: 'center',
            transition: 'background 200ms',
          }}>
            <div style={{
              width: 16, height: 16, borderRadius: 8, background: '#fff',
              transform: track ? 'translateX(14px)' : 'translateX(0)',
              transition: 'transform 200ms',
              boxShadow: '0 2px 4px rgba(0,0,0,0.15)',
            }} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12.5, fontWeight: 600, color: EVA.ink }}>Track opens</div>
            <div style={{ fontSize: 10.5, color: EVA.muted, marginTop: 1 }}>Notify me when {firstName} opens this</div>
          </div>
        </label>
      )}

      <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
        <Button kind="ghost" size="md" onClick={onCancel} style={{ flex: '0 0 auto' }}>Cancel</Button>
        <Button
          kind="primary"
          size="md"
          icon={isMail ? 'mail' : 'whats'}
          onClick={() => onSend({ channel, msg, track })}
          style={{ flex: 1, background: accent, boxShadow: `0 4px 12px ${accent}40` }}
        >Send {isMail ? 'email' : 'WhatsApp'}</Button>
      </div>
    </div>
  );
}

Object.assign(window, { ScorePill, ScoreBreakdown, FollowUpRow, OverdueAlert, FakeQR, ScreenMyCard, ReachOutPanel });
