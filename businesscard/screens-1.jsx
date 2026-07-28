// Interactive screens — part 1: Home, Scan, Crop, Processing, Review, Duplicate, Saving, Success

// helper — strip default button styling
function resetBtn(extra) {
  return { background: 'transparent', border: 'none', padding: 0, margin: 0, cursor: 'pointer', fontFamily: EVA.font, color: 'inherit', ...extra };
}

// ─── HOME / DASHBOARD ─────────────────────────────────────────────
function ScreenHome({ nav, state }) {
  const recent = state.leads.slice(0, 4);
  const followups = state.leads.filter(l => l.status === 'followup').length;
  const todayCount = state.leads.filter(l => /min|^[0-9]+ h|^Just/.test(l.capturedAt)).length;
  const myLeads = state.leads.filter(l => l.capturedBy === 'priya').length;
  const overdueCount = state.leads.filter(l => l.followUp?.overdue).length;
  const sync = state.sync;

  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="Home">
      <div style={{ padding: '56px 20px 30px', background: EVA.greenInk, position: 'relative' }}>
        <div style={{ position: 'absolute', top: -40, right: -40, width: 200, height: 200, borderRadius: '50%', background: `radial-gradient(circle, ${EVA.green}33, transparent 70%)` }} />
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 12 }}>
          <button onClick={() => nav.go('profile')} style={resetBtn({ display: 'flex', alignItems: 'center', gap: 12, flex: 1, textAlign: 'left' })}>
            <Avatar name="Priya Rao" size={40} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.55)' }}>Good morning</div>
              <div style={{ fontSize: 16, fontWeight: 600, color: '#fff', letterSpacing: -0.2 }}>Priya Rao</div>
            </div>
          </button>
          <button onClick={() => nav.go('myCard')} style={resetBtn({ width: 36, height: 36, borderRadius: 18, background: 'rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
            <Icon name="users" size={17} color="#fff" />
          </button>
          <button onClick={() => nav.toast('No new notifications')} style={resetBtn({ width: 36, height: 36, borderRadius: 18, background: 'rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', marginLeft: 8 })}>
            <Icon name="bell" size={18} color="#fff" />
            <div style={{ position: 'absolute', top: 8, right: 8, width: 8, height: 8, borderRadius: 4, background: EVA.green, border: '2px solid ' + EVA.greenInk }} />
          </button>
        </div>

        {/* Active event + sync */}
        <div style={{ marginTop: 18, background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 14, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 8, height: 8, borderRadius: 4, background: EVA.green, boxShadow: `0 0 0 4px ${EVA.green}33` }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.55)', letterSpacing: 0.8, textTransform: 'uppercase', fontWeight: 600 }}>Active event</div>
            <div style={{ fontSize: 14, fontWeight: 600, color: '#fff', marginTop: 1 }}>SaaStock Bengaluru · Day 2</div>
          </div>
          <SyncBadge sync={sync} onSync={() => nav.runSync()} dark />
        </div>
      </div>

      {/* Overdue follow-ups alert */}
      {overdueCount > 0 && (
        <div style={{ padding: '0 20px', marginTop: -18, position: 'relative', marginBottom: 10 }}>
          <OverdueAlert count={overdueCount} onView={() => { nav.toast('Filtered to overdue'); nav.go('leadList'); }} />
        </div>
      )}

      {/* Search */}
      <div style={{ padding: '0 20px', marginTop: overdueCount > 0 ? 0 : -18, position: 'relative' }}>
        <button onClick={() => nav.go('leadList')} style={resetBtn({
          width: '100%', textAlign: 'left',
          background: '#fff', borderRadius: 14, padding: '13px 14px',
          border: '1px solid ' + EVA.hairline,
          boxShadow: '0 4px 14px rgba(0,0,0,0.04)',
          display: 'flex', alignItems: 'center', gap: 10,
        })}>
          <Icon name="search" size={18} color={EVA.muted} />
          <div style={{ flex: 1, fontSize: 14, color: EVA.muted }}>Search name, company, email…</div>
          <div style={{ fontSize: 11, fontWeight: 600, color: EVA.muted, padding: '3px 7px', borderRadius: 6, background: EVA.chip }}>⌘K</div>
        </button>
      </div>

      {/* Scan CTA */}
      <div style={{ padding: '12px 20px 0' }}>
        <button onClick={() => nav.go('scan')} style={resetBtn({
          width: '100%', textAlign: 'left',
          background: '#fff', borderRadius: 18, padding: 18,
          border: '1px solid ' + EVA.hairline,
          display: 'flex', alignItems: 'center', gap: 14,
        })}>
          <div style={{ width: 52, height: 52, borderRadius: 14, background: EVA.green, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 4px 12px ${EVA.green}40` }}>
            <Icon name="camera" size={26} color="#fff" stroke={2} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 700, color: EVA.ink, letterSpacing: -0.2 }}>Scan a card</div>
            <div style={{ fontSize: 12, color: EVA.muted, marginTop: 2 }}>One tap to capture, OCR &amp; save</div>
          </div>
          <Icon name="chevR" size={18} color={EVA.muted} />
        </button>
      </div>

      {/* Stats */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
          {[
            { v: String(todayCount), l: 'Today',       c: EVA.green, action: () => nav.go('recap') },
            { v: String(myLeads),    l: 'Captured by me', c: EVA.ink,   action: () => nav.go('leadList') },
            { v: String(followups),  l: 'Follow-ups',  c: EVA.warn,  action: () => nav.go('leadList') },
          ].map(s => (
            <button key={s.l} onClick={s.action} style={resetBtn({ background: '#fff', borderRadius: 14, padding: '14px 12px', border: '1px solid ' + EVA.hairline, textAlign: 'left' })}>
              <div style={{ fontSize: 24, fontWeight: 700, color: s.c, letterSpacing: -0.6, fontFamily: EVA.fontDisplay }}>{s.v}</div>
              <div style={{ fontSize: 11, color: EVA.muted, fontWeight: 500, marginTop: 2 }}>{s.l}</div>
            </button>
          ))}
        </div>
      </div>

      {/* Recent scans */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <div style={{ fontSize: 14, fontWeight: 700, color: EVA.ink, letterSpacing: -0.1 }}>Recent scans</div>
          <button onClick={() => nav.go('leadList')} style={resetBtn({ fontSize: 12, color: EVA.green, fontWeight: 600 })}>See all →</button>
        </div>
        <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, overflow: 'hidden' }}>
          {recent.map((l, i, a) => (
            <button key={l.id} onClick={() => nav.openLead(l.id)} style={resetBtn({
              width: '100%', textAlign: 'left',
              padding: '12px 14px',
              borderBottom: i === a.length - 1 ? 'none' : '1px solid ' + EVA.hairline,
              display: 'flex', alignItems: 'center', gap: 12,
            })}>
              <Avatar name={l.name} size={36} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 600, color: EVA.ink, letterSpacing: -0.1 }}>{l.name}</div>
                <div style={{ fontSize: 11.5, color: EVA.muted, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginTop: 1 }}>{l.company} · {l.role}</div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
                {typeof l.score === 'number' && <ScorePill score={l.score} size="sm" />}
                <Status kind={l.status} size="sm" />
                <div style={{ fontSize: 10.5, color: EVA.muted }}>{l.capturedAt}</div>
              </div>
            </button>
          ))}
        </div>
      </div>

      <div style={{ height: 110 }} />
      <TabBar active="home" nav={nav} />
    </div>
  );
}

// Compact sync indicator
function SyncBadge({ sync, onSync, dark }) {
  const tone = dark ? { fg: '#fff', mute: 'rgba(255,255,255,0.6)' } : { fg: EVA.ink, mute: EVA.muted };
  const map = {
    synced:  { dot: EVA.green, txt: 'Synced',     spin: false },
    syncing: { dot: EVA.info,  txt: 'Syncing…',   spin: true },
    offline: { dot: EVA.warn,  txt: 'Offline · 3 queued', spin: false },
  };
  const m = map[sync] || map.synced;
  return (
    <button onClick={onSync} style={resetBtn({
      padding: '6px 10px', borderRadius: 10,
      background: dark ? 'rgba(255,255,255,0.06)' : EVA.chip,
      display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 11.5, fontWeight: 600, color: tone.fg,
    })}>
      <span style={{
        width: 7, height: 7, borderRadius: 4, background: m.dot,
        animation: m.spin ? 'evaSpin 1s linear infinite' : 'none',
        boxShadow: `0 0 0 3px ${m.dot}22`,
      }} />
      {m.txt}
    </button>
  );
}

// ─── SCAN VIEWFINDER ──────────────────────────────────────────────
function ScreenScan({ nav, state }) {
  const [detected, setDetected] = React.useState(false);
  const [mode, setMode] = React.useState('Single');
  const [flash, setFlash] = React.useState(false);
  const [scenario, setScenario] = React.useState('possible'); // controls which dup state happens

  React.useEffect(() => {
    const t = setTimeout(() => setDetected(true), 800);
    return () => clearTimeout(t);
  }, []);

  const shoot = () => {
    setFlash(true);
    nav.setScanScenario(scenario);
    setTimeout(() => nav.go('crop'), 240);
  };

  return (
    <div style={{ width: '100%', height: '100%', background: '#0A0E0A', position: 'relative', overflow: 'hidden', fontFamily: EVA.font }} data-screen-label="Scan">
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, #1a1f1a 0%, #0f140f 100%)' }}>
        <div style={{ position: 'absolute', inset: 0, backgroundImage: 'repeating-linear-gradient(45deg, transparent 0 10px, rgba(255,255,255,0.015) 10px 11px)' }} />
      </div>

      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, zIndex: 10, padding: '56px 16px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'linear-gradient(180deg, rgba(0,0,0,0.5), transparent)' }}>
        <button onClick={() => nav.go('home')} style={resetBtn({ width: 36, height: 36, borderRadius: 18, background: 'rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
          <Icon name="close" size={18} color="#fff" stroke={2} />
        </button>
        <div style={{ background: 'rgba(0,0,0,0.4)', padding: '6px 12px', borderRadius: 16, fontSize: 12, color: '#fff', fontWeight: 500, display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{ width: 6, height: 6, borderRadius: 3, background: EVA.green }} />
          SaaStock Bengaluru
        </div>
        <button onClick={() => nav.toast('Flash auto')} style={resetBtn({ width: 36, height: 36, borderRadius: 18, background: 'rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
          <Icon name="flash" size={18} color="#fff" stroke={2} />
        </button>
      </div>

      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column' }}>
        <div style={{ width: 300, height: 190, position: 'relative' }}>
          <div style={{
            position: 'absolute', inset: 8, borderRadius: 10,
            background: scenario === 'fresh'
              ? 'linear-gradient(135deg, #fff 0%, #f4f4f0 100%)'
              : 'linear-gradient(135deg, #f9f7f1 0%, #efebe1 100%)',
            transform: detected ? 'rotate(-3deg)' : 'rotate(-1deg) scale(0.96)',
            opacity: detected ? 1 : 0.7,
            transition: 'all 320ms cubic-bezier(0.2,0.8,0.2,1)',
            boxShadow: '0 20px 40px rgba(0,0,0,0.4)',
            padding: 18, display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
          }}>
            {scenario === 'fresh' ? (
              <>
                <div style={{ width: 36, height: 18, background: '#0E5F4E', borderRadius: 2 }} />
                <div>
                  <div style={{ fontSize: 14, fontWeight: 700, color: '#1a1a1a' }}>Sara Lopez</div>
                  <div style={{ fontSize: 9, color: '#5a5a5a', marginTop: 2 }}>Product Marketing Lead · Tessera Cloud</div>
                  <div style={{ fontSize: 8, color: '#5a5a5a', marginTop: 4 }}>sara.lopez@tessera.cloud · +34 612 778 940</div>
                </div>
              </>
            ) : (
              <>
                <div style={{ width: 32, height: 32, borderRadius: 6, background: '#1a3a8c', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, color: '#fff', fontSize: 14 }}>Z</div>
                <div>
                  <div style={{ fontSize: 14, fontWeight: 700, color: '#1a1a1a', letterSpacing: -0.2 }}>Rohan Mehta</div>
                  <div style={{ fontSize: 9, color: '#5a5a5a', marginTop: 2 }}>VP, Sales · Zinith Analytics</div>
                  <div style={{ fontSize: 8, color: '#5a5a5a', marginTop: 6 }}>+91 98213 44021 · rohan{scenario === 'possible' ? '' : '.m'}@zinith.io</div>
                </div>
              </>
            )}
          </div>

          {[
            { t: 0, l: 0, edges: 'tl' }, { t: 0, r: 0, edges: 'tr' },
            { b: 0, l: 0, edges: 'bl' }, { b: 0, r: 0, edges: 'br' },
          ].map((p, i) => (
            <div key={i} style={{
              position: 'absolute',
              top: p.t, left: p.l, right: p.r, bottom: p.b,
              width: 26, height: 26,
              borderTop: p.edges.includes('t') ? `3px solid ${detected ? EVA.green : 'rgba(255,255,255,0.45)'}` : 'none',
              borderBottom: p.edges.includes('b') ? `3px solid ${detected ? EVA.green : 'rgba(255,255,255,0.45)'}` : 'none',
              borderLeft: p.edges.includes('l') ? `3px solid ${detected ? EVA.green : 'rgba(255,255,255,0.45)'}` : 'none',
              borderRight: p.edges.includes('r') ? `3px solid ${detected ? EVA.green : 'rgba(255,255,255,0.45)'}` : 'none',
              transition: 'all 200ms',
            }} />
          ))}
        </div>

        <div style={{
          marginTop: 24,
          background: detected ? EVA.green : 'rgba(0,0,0,0.5)',
          padding: '8px 14px', borderRadius: 20,
          fontSize: 12, fontWeight: 600,
          color: detected ? '#fff' : 'rgba(255,255,255,0.7)',
          display: 'flex', alignItems: 'center', gap: 8,
          boxShadow: detected ? `0 6px 16px ${EVA.green}66` : 'none',
        }}>
          {detected ? <><Icon name="check" size={14} color="#fff" stroke={2.5} /> Card detected · Tap to capture</> : <>Looking for a card…</>}
        </div>

        {/* Tweakable: which card to scan, for demoing dup states */}
        <div style={{ marginTop: 18, display: 'flex', gap: 6, background: 'rgba(0,0,0,0.4)', padding: 4, borderRadius: 12 }}>
          {[
            { k: 'fresh',    l: 'New card' },
            { k: 'possible', l: 'Possible dup' },
            { k: 'exact',    l: 'Exact dup' },
          ].map(s => (
            <button key={s.k} onClick={() => setScenario(s.k)} style={resetBtn({
              padding: '6px 10px', borderRadius: 8, fontSize: 11, fontWeight: 600,
              background: scenario === s.k ? '#fff' : 'transparent',
              color: scenario === s.k ? EVA.ink : 'rgba(255,255,255,0.7)',
            })}>{s.l}</button>
          ))}
        </div>
        <div style={{ marginTop: 6, fontSize: 10, color: 'rgba(255,255,255,0.4)' }}>Demo: pick the card to show different dup states</div>
      </div>

      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 10, padding: '20px 20px 40px', background: 'linear-gradient(0deg, rgba(0,0,0,0.7), transparent)' }}>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 14, marginBottom: 18 }}>
          {['Single', 'Batch', 'Front + Back'].map(m => (
            <button key={m} onClick={() => setMode(m)} style={resetBtn({
              padding: '7px 14px', borderRadius: 16, fontSize: 12, fontWeight: 600,
              background: mode === m ? 'rgba(255,255,255,0.18)' : 'transparent',
              color: mode === m ? '#fff' : 'rgba(255,255,255,0.55)',
              border: mode === m ? '1px solid rgba(255,255,255,0.2)' : '1px solid transparent',
            })}>{m}</button>
          ))}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 20px' }}>
          <button onClick={() => nav.toast('Gallery picker (mock)')} style={resetBtn({ width: 48, height: 48, borderRadius: 12, background: 'rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' })}>
            <Icon name="image" size={20} color="#fff" />
            <div style={{ position: 'absolute', top: -4, right: -4, minWidth: 18, height: 18, borderRadius: 9, background: EVA.green, color: '#fff', fontSize: 10, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '0 5px' }}>3</div>
          </button>

          <button onClick={shoot} disabled={!detected} style={resetBtn({
            width: 76, height: 76, borderRadius: 38, background: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            border: '5px solid rgba(255,255,255,0.2)',
            boxShadow: '0 10px 30px rgba(0,0,0,0.4)',
            opacity: detected ? 1 : 0.55,
            transform: flash ? 'scale(0.92)' : 'scale(1)',
            transition: 'transform 120ms',
          })}>
            <div style={{ width: 60, height: 60, borderRadius: 30, background: EVA.green, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="camera" size={24} color="#fff" stroke={2} />
            </div>
          </button>

          <button onClick={() => nav.toast('Camera flipped')} style={resetBtn({ width: 48, height: 48, borderRadius: 12, background: 'rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
            <Icon name="refresh" size={20} color="#fff" />
          </button>
        </div>

        <div style={{ textAlign: 'center', marginTop: 12, fontSize: 11, color: 'rgba(255,255,255,0.5)' }}>
          {detected ? 'Tap the shutter to capture' : 'Hold steady · auto-detect in progress'}
        </div>
      </div>

      {flash && <div style={{ position: 'absolute', inset: 0, background: '#fff', opacity: 0.7, zIndex: 20, pointerEvents: 'none' }} />}
    </div>
  );
}

// ─── CROP / ROTATE ────────────────────────────────────────────────
function ScreenCrop({ nav, state }) {
  const [rot, setRot] = React.useState(0);
  const [zoom, setZoom] = React.useState(1);
  const scenario = state.scanScenario;
  const isFresh = scenario === 'fresh';

  return (
    <div style={{ width: '100%', height: '100%', background: '#0A0E0A', position: 'relative', overflow: 'hidden', fontFamily: EVA.font, color: '#fff' }} data-screen-label="Crop">
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, zIndex: 10, padding: '56px 16px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button onClick={() => nav.go('scan')} style={resetBtn({ fontSize: 14, color: '#fff', fontWeight: 600 })}>Retake</button>
        <div style={{ fontSize: 13, color: '#fff', fontWeight: 600 }}>Adjust crop</div>
        <button onClick={() => nav.go('processing')} style={resetBtn({ fontSize: 14, color: EVA.green, fontWeight: 700 })}>Next</button>
      </div>

      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '90px 24px 200px' }}>
        <div style={{ position: 'relative', width: 280, height: 176, borderRadius: 8, overflow: 'visible' }}>
          {/* Captured "image" */}
          <div style={{
            position: 'absolute', inset: 0, borderRadius: 8,
            background: isFresh ? 'linear-gradient(135deg, #fff 0%, #f4f4f0 100%)' : 'linear-gradient(135deg, #f9f7f1 0%, #efebe1 100%)',
            transform: `rotate(${rot}deg) scale(${zoom})`,
            transformOrigin: 'center',
            transition: 'transform 220ms',
            boxShadow: '0 20px 40px rgba(0,0,0,0.5)',
            padding: 16, display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
          }}>
            {isFresh ? (
              <>
                <div style={{ width: 36, height: 18, background: '#0E5F4E', borderRadius: 2 }} />
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700, color: '#1a1a1a' }}>Sara Lopez</div>
                  <div style={{ fontSize: 9, color: '#5a5a5a' }}>Product Marketing Lead · Tessera Cloud</div>
                  <div style={{ fontSize: 8, color: '#5a5a5a', marginTop: 4 }}>sara.lopez@tessera.cloud · +34 612 778 940</div>
                </div>
              </>
            ) : (
              <>
                <div style={{ width: 28, height: 28, borderRadius: 6, background: '#1a3a8c', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, color: '#fff', fontSize: 13 }}>Z</div>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 700, color: '#1a1a1a' }}>Rohan Mehta</div>
                  <div style={{ fontSize: 9, color: '#5a5a5a' }}>VP, Sales · Zinith Analytics</div>
                  <div style={{ fontSize: 8, color: '#5a5a5a', marginTop: 4 }}>+91 98213 44021 · rohan{scenario === 'possible' ? '' : '.m'}@zinith.io</div>
                </div>
              </>
            )}
          </div>

          {/* Crop grid overlay */}
          <div style={{ position: 'absolute', inset: 0, border: `2px solid ${EVA.green}`, borderRadius: 4, pointerEvents: 'none' }}>
            {/* corner handles */}
            {[
              { t: -7, l: -7 }, { t: -7, r: -7 }, { b: -7, l: -7 }, { b: -7, r: -7 },
            ].map((p, i) => (
              <div key={i} style={{ position: 'absolute', top: p.t, left: p.l, right: p.r, bottom: p.b, width: 14, height: 14, background: EVA.green, borderRadius: 3, border: '2px solid #fff' }} />
            ))}
            {/* thirds grid */}
            <div style={{ position: 'absolute', inset: 0 }}>
              <div style={{ position: 'absolute', left: '33.33%', top: 0, bottom: 0, width: 1, background: 'rgba(255,255,255,0.3)' }} />
              <div style={{ position: 'absolute', left: '66.66%', top: 0, bottom: 0, width: 1, background: 'rgba(255,255,255,0.3)' }} />
              <div style={{ position: 'absolute', top: '33.33%', left: 0, right: 0, height: 1, background: 'rgba(255,255,255,0.3)' }} />
              <div style={{ position: 'absolute', top: '66.66%', left: 0, right: 0, height: 1, background: 'rgba(255,255,255,0.3)' }} />
            </div>
          </div>
        </div>
      </div>

      {/* Bottom controls */}
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, padding: '20px 20px 40px' }}>
        {/* Tool row */}
        <div style={{ display: 'flex', gap: 10, justifyContent: 'center', marginBottom: 16 }}>
          {[
            { i: 'refresh', l: 'Rotate ↻', action: () => setRot(r => r + 90) },
            { i: 'refresh', l: 'Rotate ↺', action: () => setRot(r => r - 90), flip: true },
            { i: 'plus', l: 'Auto', action: () => { setRot(0); setZoom(1); nav.toast('Auto-fit applied'); } },
          ].map(t => (
            <button key={t.l} onClick={t.action} style={resetBtn({
              padding: '10px 14px', borderRadius: 12,
              background: 'rgba(255,255,255,0.1)',
              display: 'flex', alignItems: 'center', gap: 6,
              fontSize: 12, fontWeight: 600, color: '#fff',
            })}>
              <span style={{ display: 'inline-flex', transform: t.flip ? 'scaleX(-1)' : 'none' }}>
                <Icon name={t.i} size={14} color="#fff" />
              </span>
              {t.l}
            </button>
          ))}
        </div>

        {/* Zoom slider */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '0 8px' }}>
          <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.6)', minWidth: 30 }}>Zoom</div>
          <input
            type="range" min="0.8" max="1.3" step="0.01" value={zoom}
            onChange={e => setZoom(parseFloat(e.target.value))}
            style={{ flex: 1, accentColor: EVA.green }}
          />
          <div style={{ fontSize: 11, color: '#fff', fontVariantNumeric: 'tabular-nums', minWidth: 36, textAlign: 'right', fontWeight: 600 }}>{Math.round(zoom * 100)}%</div>
        </div>
      </div>
    </div>
  );
}

// ─── PROCESSING / OCR LOADER ──────────────────────────────────────
function ScreenProcessing({ nav }) {
  const steps = [
    { k: 'detect',  l: 'Detecting edges' },
    { k: 'ocr',     l: 'Reading text · OCR' },
    { k: 'parse',   l: 'Parsing fields' },
    { k: 'dedupe',  l: 'Checking for duplicates' },
  ];
  const [stage, setStage] = React.useState(0);
  React.useEffect(() => {
    const timers = [
      setTimeout(() => setStage(1), 500),
      setTimeout(() => setStage(2), 1050),
      setTimeout(() => setStage(3), 1500),
      setTimeout(() => setStage(4), 1950),
      setTimeout(() => nav.go('review'), 2400),
    ];
    return () => timers.forEach(clearTimeout);
  }, []);

  return (
    <div style={{ width: '100%', height: '100%', background: EVA.greenInk, fontFamily: EVA.font, position: 'relative', overflow: 'hidden', color: '#fff' }} data-screen-label="Processing">
      <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(120% 60% at 50% 30%, ${EVA.green}22 0%, transparent 60%)` }} />

      <div style={{ position: 'relative', height: '100%', padding: '80px 28px 40px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 20 }}>
          <div style={{ width: 220, height: 138, borderRadius: 12, background: 'linear-gradient(135deg, #f9f7f1, #efebe1)', position: 'relative', overflow: 'hidden', boxShadow: '0 14px 40px rgba(0,0,0,0.4)' }}>
            <div style={{ position: 'absolute', inset: '14px 16px', display: 'flex', flexDirection: 'column', gap: 6 }}>
              <div style={{ width: 22, height: 22, borderRadius: 4, background: '#1a3a8c' }} />
              <div style={{ marginTop: 'auto' }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: '#1a1a1a' }}>Card text…</div>
                <div style={{ fontSize: 8, color: '#5a5a5a' }}>Designation · Company</div>
                <div style={{ fontSize: 7, color: '#5a5a5a', marginTop: 3 }}>email@domain · +XX XXXXX</div>
              </div>
            </div>
            <div style={{
              position: 'absolute', left: 0, right: 0, height: 26,
              background: `linear-gradient(180deg, transparent, ${EVA.green}66, transparent)`,
              animation: 'evaScan 1.2s linear infinite',
            }} />
            <style>{`@keyframes evaScan { 0% { top: -26px; } 100% { top: 138px; } }`}</style>
          </div>

          <div style={{ fontSize: 22, fontWeight: 700, color: '#fff', letterSpacing: -0.4, fontFamily: EVA.fontDisplay, textAlign: 'center' }}>
            Reading the card…
          </div>
          <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.55)', textAlign: 'center', maxWidth: 260, lineHeight: 1.45 }}>
            Eva is extracting contact details and checking against your existing leads.
          </div>
        </div>

        <div style={{ marginTop: 32, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {steps.map((s, i) => {
            const done = i < stage;
            const active = i === stage;
            return (
              <div key={s.k} style={{
                background: 'rgba(255,255,255,0.05)',
                border: `1px solid ${active ? EVA.green + '66' : 'rgba(255,255,255,0.08)'}`,
                borderRadius: 12, padding: '12px 14px',
                display: 'flex', alignItems: 'center', gap: 12,
                transition: 'all 220ms',
              }}>
                <div style={{
                  width: 22, height: 22, borderRadius: 11,
                  background: done ? EVA.green : (active ? 'transparent' : 'rgba(255,255,255,0.08)'),
                  border: active ? `2px solid ${EVA.green}` : 'none',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  {done && <Icon name="check" size={12} color="#fff" stroke={3} />}
                  {active && <div style={{ width: 8, height: 8, borderRadius: 4, background: EVA.green, animation: 'evaPulse 0.8s ease-in-out infinite' }} />}
                </div>
                <div style={{ flex: 1, fontSize: 13.5, fontWeight: 500, color: done || active ? '#fff' : 'rgba(255,255,255,0.4)' }}>
                  {s.l}
                </div>
                {done && <div style={{ fontSize: 10.5, color: 'rgba(255,255,255,0.5)' }}>Done</div>}
                {active && <div style={{ fontSize: 10.5, color: EVA.green, fontWeight: 600 }}>…</div>}
              </div>
            );
          })}
          <style>{`@keyframes evaPulse { 0%,100% { transform: scale(0.7); opacity: 0.6; } 50% { transform: scale(1); opacity: 1; } }`}</style>
        </div>
      </div>
    </div>
  );
}

// ─── REVIEW / EDIT ────────────────────────────────────────────────
function ScreenReview({ nav, state }) {
  const scenario = SCAN_SCENARIOS[state.scanScenario || 'possible'];
  const [draft, setDraft] = React.useState(() => ({ ...scenario.data, note: '' }));
  const [editing, setEditing] = React.useState(null);
  const [tags, setTags] = React.useState(['SaaStock 2026', 'Met at booth']);
  const [reminderOn, setReminderOn] = React.useState(true);
  // Predicted score for the scanned card — based on field confidence + scenario.
  const predicted = React.useMemo(() => {
    if (scenario.matchType === 'exact') return { score: 87, br: { designation: 18, company: 17, email: 18, brochure: 16, event: 18 } };
    if (scenario.matchType === 'possible') return { score: 84, br: { designation: 17, company: 18, email: 16, brochure: 15, event: 18 } };
    return { score: 73, br: { designation: 16, company: 16, email: 13, brochure: 12, event: 16 } };
  }, [scenario.matchType]);

  const fields = [
    { k: 'name',     label: 'Full name',   icon: 'user' },
    { k: 'role',     label: 'Designation', icon: 'tag' },
    { k: 'company',  label: 'Company',     icon: 'building' },
    { k: 'email',    label: 'Email',       icon: 'mail' },
    { k: 'phone',    label: 'Phone',       icon: 'phone' },
    { k: 'location', label: 'Location',    icon: 'map' },
  ];

  const save = () => {
    const matchType = scenario.matchType;
    const matchedId = scenario.matchedId;
    const enriched = {
      ...draft,
      tags,
      score: predicted.score,
      scoreBreak: predicted.br,
      followUp: { date: 'May 22, 2026', daysFromNow: 3, overdue: false, suggested: '3 days after event' },
      reminder: reminderOn ? { label: 'Follow-up', when: 'May 22 · 10 AM' } : null,
    };
    if (matchType === 'new') {
      nav.setPendingSave(enriched);
      nav.go('saving');
    } else {
      const match = state.leads.find(l => l.id === matchedId);
      nav.setDup({ existing: match, incoming: enriched, tags, matchType });
      nav.go('duplicate');
    }
  };

  const lowConfCount = fields.filter(f => draft.conf[f.k] < 0.8).length;

  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="Review">
      <AppBar
        left={<button onClick={() => nav.go('scan')} style={resetBtn({})}><Icon name="chevL" size={22} color={EVA.ink} /></button>}
        title="Review &amp; save"
        sub="Auto-filled from scan"
        right={<button onClick={() => nav.go('scan')} style={resetBtn({ fontSize: 12, fontWeight: 600, color: EVA.green })}>Retake</button>}
      />

      <div style={{ padding: '14px 20px 120px', height: 'calc(100% - 116px)', overflow: 'auto' }}>
        <div style={{ background: '#fff', borderRadius: 16, padding: 12, border: '1px solid ' + EVA.hairline, display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
          <div style={{ width: 92, height: 56, borderRadius: 8, background: 'linear-gradient(135deg, #f5f1e6 0%, #e9e3d2 100%)', position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', top: 6, left: 6, width: 14, height: 14, borderRadius: 3, background: '#1a3a8c' }} />
            <div style={{ position: 'absolute', bottom: 6, left: 6, right: 6 }}>
              <div style={{ height: 4, background: '#3a3a3a', borderRadius: 1, marginBottom: 3 }} />
              <div style={{ height: 2, background: '#8a8a8a', borderRadius: 1, width: '70%' }} />
            </div>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 8px', background: EVA.greenSoft, borderRadius: 10, marginBottom: 4 }}>
              <Icon name="spark" size={11} color={EVA.greenDeep} stroke={2.2} />
              <span style={{ fontSize: 10.5, fontWeight: 600, color: EVA.greenDeep, letterSpacing: 0.2 }}>OCR · 0.7s</span>
            </div>
            <div style={{ fontSize: 13, color: EVA.muted }}>6 fields extracted</div>
            <div style={{ fontSize: 11.5, color: lowConfCount > 0 ? EVA.warn : EVA.muted, marginTop: 1, fontWeight: 500 }}>
              {lowConfCount > 0 ? `${lowConfCount} low-confidence field${lowConfCount > 1 ? 's' : ''} flagged` : 'All fields look good'}
            </div>
          </div>
        </div>

        {fields.map(f => {
          const conf = draft.conf[f.k];
          const lowConf = conf < 0.8;
          const isEditing = editing === f.k;
          return (
            <div key={f.k} style={{ marginBottom: 12 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
                <div style={{ fontSize: 11.5, fontWeight: 600, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase' }}>{f.label}</div>
                {lowConf ? (
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 10, fontWeight: 600, color: EVA.warn, background: EVA.warnSoft, padding: '2px 7px', borderRadius: 8 }}>
                    <Icon name="warn" size={10} color={EVA.warn} stroke={2.4} /> Verify · {Math.round(conf * 100)}%
                  </span>
                ) : (
                  <ConfBar conf={conf} />
                )}
              </div>
              <div onClick={() => setEditing(f.k)} style={{
                background: '#fff',
                border: `1px solid ${isEditing ? EVA.green : (lowConf ? EVA.warn + '66' : EVA.hairline)}`,
                boxShadow: isEditing ? `0 0 0 3px ${EVA.green}22` : 'none',
                borderRadius: 12, padding: '12px 14px',
                display: 'flex', alignItems: 'center', gap: 10,
                cursor: 'text',
              }}>
                <Icon name={f.icon} size={18} color={EVA.muted} />
                {isEditing ? (
                  <input
                    autoFocus
                    value={draft[f.k]}
                    onChange={e => setDraft({ ...draft, [f.k]: e.target.value, conf: { ...draft.conf, [f.k]: 1 } })}
                    onBlur={() => setEditing(null)}
                    onKeyDown={e => { if (e.key === 'Enter') setEditing(null); }}
                    style={{ flex: 1, fontSize: 15, color: EVA.ink, fontWeight: 500, border: 'none', outline: 'none', background: 'transparent', fontFamily: EVA.font }}
                  />
                ) : (
                  <div style={{ flex: 1, fontSize: 15, color: EVA.ink, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{draft[f.k]}</div>
                )}
                <Icon name="edit" size={14} color={EVA.muted} />
              </div>
            </div>
          );
        })}

        {/* Notes */}
        <div style={{ marginTop: 4 }}>
          <div style={{ fontSize: 11.5, fontWeight: 600, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 6 }}>Notes</div>
          <div style={{ background: '#fff', border: '1px solid ' + EVA.hairline, borderRadius: 12, padding: 12 }}>
            <textarea
              value={draft.note}
              onChange={e => setDraft({ ...draft, note: e.target.value })}
              placeholder="Add context for the next conversation…"
              style={{
                width: '100%', minHeight: 56, border: 'none', outline: 'none', resize: 'none',
                background: 'transparent', fontFamily: EVA.font, fontSize: 14, color: EVA.ink, lineHeight: 1.5,
              }}
            />
          </div>
        </div>

        <div style={{ marginTop: 16 }}>
          <div style={{ fontSize: 11.5, fontWeight: 600, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 8 }}>Tags</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {tags.map(t => (
              <button key={t} onClick={() => setTags(tags.filter(x => x !== t))} style={resetBtn({
                padding: '6px 10px', borderRadius: 10, background: EVA.chip,
                fontSize: 12, fontWeight: 500, color: EVA.body,
                display: 'inline-flex', alignItems: 'center', gap: 6,
              })}>
                <Icon name="tag" size={11} color={EVA.muted} /> {t}
                <Icon name="close" size={10} color={EVA.muted} />
              </button>
            ))}
            <button onClick={() => {
              const candidates = ['Requested deck', 'Bring colleague', 'Day 2'].filter(t => !tags.includes(t));
              if (candidates.length) setTags([...tags, candidates[0]]);
            }} style={resetBtn({
              padding: '6px 10px', borderRadius: 10, background: 'transparent', border: '1px dashed ' + EVA.hairline,
              fontSize: 12, fontWeight: 500, color: EVA.muted, display: 'inline-flex', alignItems: 'center', gap: 4,
            })}>
              <Icon name="plus" size={11} color={EVA.muted} /> Add
            </button>
          </div>
        </div>

        {/* Score breakdown */}
        <div style={{ marginTop: 18 }}>
          <div style={{ fontSize: 11.5, fontWeight: 600, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 8 }}>Predicted lead score</div>
          <ScoreBreakdown breakdown={predicted.br} score={predicted.score} />
        </div>

        {/* Smart follow-up */}
        <div style={{ marginTop: 16 }}>
          <div style={{ fontSize: 11.5, fontWeight: 600, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 8 }}>Smart follow-up</div>
          <FollowUpRow
            value="May 22, 2026"
            onChange={() => nav.toast('Calendar picker')}
            reminderOn={reminderOn}
            onReminder={() => setReminderOn(v => !v)}
          />
        </div>
      </div>

      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, padding: '14px 20px 32px', background: '#fff', borderTop: '1px solid ' + EVA.hairline, display: 'flex', gap: 10 }}>
        <Button kind="ghost" size="lg" onClick={() => nav.go('home')} style={{ flex: '0 0 auto' }}>Cancel</Button>
        <Button kind="primary" size="lg" icon="check" onClick={save} style={{ flex: 1 }}>Save to Leads</Button>
      </div>
    </div>
  );
}

function ConfBar({ conf }) {
  const pct = Math.round(conf * 100);
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
      <div style={{ width: 36, height: 4, background: EVA.hairline, borderRadius: 2, overflow: 'hidden' }}>
        <div style={{ width: pct + '%', height: '100%', background: conf >= 0.95 ? EVA.green : EVA.greenDeep, borderRadius: 2 }} />
      </div>
      <span style={{ fontSize: 10, color: EVA.muted, fontWeight: 600, fontVariantNumeric: 'tabular-nums', minWidth: 22 }}>{pct}%</span>
    </div>
  );
}

// ─── DUPLICATE — 3 STATES: new / possible / exact ─────────────────
function ScreenDuplicate({ nav, state }) {
  const dup = state.dup;
  if (!dup) return null;
  const e = dup.existing, n = dup.incoming;
  const isExact = dup.matchType === 'exact';

  // Always-on picks for "possible" merge
  const initialPicks = {
    role: e?.role !== n.role,
    email: e?.email !== n.email,
    location: e?.location !== n.location,
  };
  const [picks, setPicks] = React.useState(initialPicks);

  const merge = () => {
    nav.mergeLead(e.id, n, picks, dup.tags);
    nav.go('success');
  };
  const keepBoth = () => {
    nav.setPendingSave({ ...n, tags: dup.tags });
    nav.go('saving');
  };

  // EXACT — single record exists, no diffs — just open existing
  if (isExact) {
    return (
      <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="Duplicate">
        <AppBar
          left={<button onClick={() => nav.go('review')} style={resetBtn({})}><Icon name="chevL" size={22} color={EVA.ink} /></button>}
          title="Already in Leads"
          sub="Exact match found"
          right={null}
        />

        <div style={{ padding: '18px 20px', height: 'calc(100% - 116px)', overflow: 'auto' }}>
          <div style={{ background: EVA.dangerSoft, border: `1px solid ${EVA.danger}33`, borderRadius: 14, padding: '14px 16px', display: 'flex', gap: 12, marginBottom: 18 }}>
            <div style={{ width: 36, height: 36, borderRadius: 18, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Icon name="close" size={18} color={EVA.danger} stroke={2.2} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: EVA.ink, letterSpacing: -0.1 }}>Exact duplicate</div>
              <div style={{ fontSize: 12.5, color: EVA.body, marginTop: 3, lineHeight: 1.4 }}>
                Every field matches a record in your Lead page. We won't create a copy.
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '0 4px', marginBottom: 14 }}>
            <div style={{ fontSize: 11, fontWeight: 600, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase' }}>Match score</div>
            <div style={{ flex: 1, height: 4, background: EVA.hairline, borderRadius: 2, overflow: 'hidden' }}>
              <div style={{ width: '100%', height: '100%', background: EVA.danger, borderRadius: 2 }} />
            </div>
            <div style={{ fontSize: 13, fontWeight: 700, color: EVA.danger, fontVariantNumeric: 'tabular-nums' }}>100%</div>
          </div>

          {/* Existing card */}
          <div style={{ background: '#fff', borderRadius: 14, padding: 16, border: '1.5px solid ' + EVA.hairline, marginBottom: 14 }}>
            <div style={{ display: 'inline-block', fontSize: 10, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase', color: EVA.muted, background: EVA.chip, padding: '3px 7px', borderRadius: 6, marginBottom: 12 }}>In your Lead page</div>
            <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
              <Avatar name={e.name} size={48} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 15, fontWeight: 700, color: EVA.ink, letterSpacing: -0.2 }}>{e.name}</div>
                <div style={{ fontSize: 12.5, color: EVA.body, marginTop: 2 }}>{e.role} · {e.company}</div>
                <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                  <Status kind={e.status} size="sm" />
                  <span style={{ fontSize: 10.5, color: EVA.muted, padding: '3px 7px', background: EVA.chip, borderRadius: 8, fontWeight: 500 }}>Added {e.capturedAt} ago</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, padding: '14px 20px 32px', background: '#fff', borderTop: '1px solid ' + EVA.hairline, display: 'flex', flexDirection: 'column', gap: 8 }}>
          <Button kind="primary" size="lg" icon="user" full onClick={() => { nav.setDup(null); nav.openLead(e.id); }}>Open existing lead</Button>
          <Button kind="ghost" size="md" full onClick={() => nav.go('scan')}>Scan another card</Button>
        </div>
      </div>
    );
  }

  // POSSIBLE — diffs, smart merge
  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="Duplicate">
      <AppBar
        left={<button onClick={() => nav.go('review')} style={resetBtn({})}><Icon name="chevL" size={22} color={EVA.ink} /></button>}
        title="Possible duplicate"
        sub="Review before saving"
        right={null}
      />

      <div style={{ padding: '14px 20px 180px', height: 'calc(100% - 116px)', overflow: 'auto' }}>
        <div style={{ background: EVA.warnSoft, border: `1px solid ${EVA.warn}33`, borderRadius: 14, padding: '14px 16px', display: 'flex', gap: 12, marginBottom: 18 }}>
          <div style={{ width: 36, height: 36, borderRadius: 18, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Icon name="warn" size={18} color={EVA.warn} stroke={2.2} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: EVA.ink, letterSpacing: -0.1 }}>1 likely match found</div>
            <div style={{ fontSize: 12.5, color: EVA.body, marginTop: 3, lineHeight: 1.4 }}>
              Matched on <span style={{ fontWeight: 600 }}>phone + company</span>. Some fields differ.
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '0 4px', marginBottom: 10 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase' }}>Match score</div>
          <div style={{ flex: 1, height: 4, background: EVA.hairline, borderRadius: 2, overflow: 'hidden' }}>
            <div style={{ width: '92%', height: '100%', background: EVA.warn, borderRadius: 2 }} />
          </div>
          <div style={{ fontSize: 13, fontWeight: 700, color: EVA.warn, fontVariantNumeric: 'tabular-nums' }}>92%</div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 14 }}>
          {[
            { tag: 'Existing', highlight: false, lead: e },
            { tag: 'New scan', highlight: true,  lead: n },
          ].map((c) => (
            <div key={c.tag} style={{ background: '#fff', borderRadius: 14, padding: 14, border: `1.5px solid ${c.highlight ? EVA.green : EVA.hairline}` }}>
              <div style={{ display: 'inline-block', fontSize: 10, fontWeight: 700, letterSpacing: 0.6, textTransform: 'uppercase', color: c.highlight ? EVA.greenDeep : EVA.muted, background: c.highlight ? EVA.greenSoft : EVA.chip, padding: '3px 7px', borderRadius: 6, marginBottom: 10 }}>{c.tag}</div>
              <Avatar name={c.lead.name} size={32} />
              <div style={{ fontSize: 13, fontWeight: 700, color: EVA.ink, marginTop: 8, letterSpacing: -0.1 }}>{c.lead.name}</div>
              <div style={{ fontSize: 11, color: EVA.muted, marginTop: 1 }}>{c.lead.role}</div>
              <div style={{ height: 1, background: EVA.hairline, margin: '10px 0' }} />
              {[
                { l: 'Email',  v: c.lead.email,    diff: c.lead.email !== e.email },
                { l: 'Phone',  v: c.lead.phone,    diff: false },
                { l: 'Office', v: c.lead.location, diff: c.lead.location !== e.location },
              ].map(r => (
                <div key={r.l} style={{ marginBottom: 8 }}>
                  <div style={{ fontSize: 9.5, color: EVA.muted, letterSpacing: 0.5, textTransform: 'uppercase', fontWeight: 600 }}>{r.l}</div>
                  <div style={{ fontSize: 11.5, color: EVA.ink, marginTop: 1, fontWeight: 500, background: r.diff && c.highlight ? EVA.greenSoft : 'transparent', display: 'inline-block', padding: r.diff && c.highlight ? '1px 4px' : 0, borderRadius: 4, wordBreak: 'break-all' }}>{r.v}</div>
                </div>
              ))}
            </div>
          ))}
        </div>

        <div style={{ background: '#fff', border: '1px solid ' + EVA.hairline, borderRadius: 14, padding: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
            <Icon name="spark" size={14} color={EVA.greenDeep} stroke={2.2} />
            <div style={{ fontSize: 13, fontWeight: 700, color: EVA.ink, letterSpacing: -0.1 }}>Smart merge</div>
            <div style={{ flex: 1 }} />
            <div style={{ fontSize: 11, color: EVA.muted }}>{Object.values(picks).filter(Boolean).length} changes</div>
          </div>
          {[
            { k: 'role',     l: 'Designation', from: e.role,     to: n.role,     diff: e.role !== n.role },
            { k: 'email',    l: 'Email',       from: e.email,    to: n.email,    diff: e.email !== n.email },
            { k: 'location', l: 'Office',      from: e.location, to: n.location, diff: e.location !== n.location },
          ].filter(r => r.diff).map(r => (
            <label key={r.k} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '7px 0', borderTop: '1px solid ' + EVA.hairline, cursor: 'pointer' }}>
              <input type="checkbox" checked={picks[r.k]} onChange={ev => setPicks({ ...picks, [r.k]: ev.target.checked })} style={{ accentColor: EVA.green, width: 16, height: 16 }} />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 11, color: EVA.muted, letterSpacing: 0.4, textTransform: 'uppercase', fontWeight: 600 }}>{r.l}</div>
                <div style={{ fontSize: 12.5, color: EVA.ink, fontWeight: 500, marginTop: 1 }}>
                  <span style={{ color: EVA.muted, textDecoration: 'line-through', marginRight: 6 }}>{r.from}</span>
                  {r.to}
                </div>
              </div>
            </label>
          ))}
        </div>
      </div>

      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, padding: '14px 20px 32px', background: '#fff', borderTop: '1px solid ' + EVA.hairline, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <Button kind="primary" size="lg" icon="merge" full onClick={merge}>Merge into existing</Button>
        <div style={{ display: 'flex', gap: 8 }}>
          <Button kind="ghost" size="md" onClick={keepBoth} style={{ flex: 1 }}>Keep both</Button>
          <Button kind="ghost" size="md" onClick={() => nav.go('review')} style={{ flex: 1 }}>Cancel</Button>
        </div>
      </div>
    </div>
  );
}

// ─── SAVING ───────────────────────────────────────────────────────
function ScreenSaving({ nav, state }) {
  const [stage, setStage] = React.useState(0);
  React.useEffect(() => {
    const t1 = setTimeout(() => setStage(1), 500);
    const t2 = setTimeout(() => setStage(2), 1000);
    const t3 = setTimeout(() => {
      if (state.pendingSave) nav.addLead(state.pendingSave);
      nav.go('success');
    }, 1500);
    return () => [t1, t2, t3].forEach(clearTimeout);
  }, []);
  const steps = [
    { l: 'Saving to device' },
    { l: 'Syncing to Lead page' },
    { l: 'Mirroring to LMS' },
  ];
  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 28, fontFamily: EVA.font }} data-screen-label="Saving">
      <div style={{ width: 60, height: 60, borderRadius: 30, border: `4px solid ${EVA.greenSoft}`, borderTopColor: EVA.green, animation: 'evaSpin 0.8s linear infinite' }} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, fontSize: 13, color: EVA.body, alignItems: 'flex-start' }}>
        {steps.map((s, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, opacity: i <= stage ? 1 : 0.3, transition: 'opacity 200ms' }}>
            <div style={{ width: 18, height: 18, borderRadius: 9, background: i < stage ? EVA.green : (i === stage ? 'transparent' : EVA.chip), border: i === stage ? `2px solid ${EVA.green}` : 'none', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {i < stage && <Icon name="check" size={11} color="#fff" stroke={3} />}
            </div>
            <span style={{ fontWeight: 500 }}>{s.l}</span>
          </div>
        ))}
      </div>
      <style>{`@keyframes evaSpin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

// ─── SUCCESS ──────────────────────────────────────────────────────
function ScreenSuccess({ nav, state }) {
  const last = state.leads[0];
  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }} data-screen-label="Success">
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', padding: 28 }}>
        <div style={{ width: 96, height: 96, borderRadius: 48, background: EVA.greenSoft, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 24, position: 'relative', animation: 'evaPop 360ms cubic-bezier(0.2,1.4,0.4,1)' }}>
          <div style={{ width: 64, height: 64, borderRadius: 32, background: EVA.green, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 8px 20px ${EVA.green}55` }}>
            <Icon name="check" size={36} color="#fff" stroke={3} />
          </div>
          {[0,1,2,3,4,5].map(i => (
            <div key={i} style={{
              position: 'absolute', width: 6, height: 6, borderRadius: 3,
              background: i % 2 ? EVA.green : '#7B3DC4',
              top: 50, left: 50,
              transform: `rotate(${i * 60}deg) translateY(-60px)`,
              opacity: 0.8,
            }} />
          ))}
        </div>
        <div style={{ fontSize: 26, fontWeight: 700, color: EVA.ink, letterSpacing: -0.6, fontFamily: EVA.fontDisplay, marginBottom: 8 }}>Saved to Leads</div>
        <div style={{ fontSize: 14, color: EVA.muted, textAlign: 'center', maxWidth: 280, lineHeight: 1.5 }}>
          {last?.name} is now on the Lead page and visible in LMS.
        </div>

        <div style={{ marginTop: 24, background: '#fff', borderRadius: 14, padding: 14, border: '1px solid ' + EVA.hairline, width: '100%', maxWidth: 320, display: 'flex', alignItems: 'center', gap: 12 }}>
          <Avatar name={last?.name || 'New'} size={40} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: EVA.ink }}>{last?.name}</div>
            <div style={{ fontSize: 11.5, color: EVA.muted, marginTop: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{last?.role} · {last?.company}</div>
          </div>
          <Status kind={last?.status || 'new'} size="sm" />
        </div>

        <div style={{ marginTop: 12, fontSize: 11.5, color: EVA.muted, display: 'flex', alignItems: 'center', gap: 6 }}>
          <Icon name="user" size={12} color={EVA.muted} />
          Tagged as captured by <span style={{ fontWeight: 600, color: EVA.ink }}>Priya Rao</span> · just now
        </div>

        <style>{`@keyframes evaPop { from { transform: scale(0.5); opacity: 0; } to { transform: scale(1); opacity: 1; } }`}</style>
      </div>

      <div style={{ padding: '14px 20px 36px', display: 'flex', gap: 10, flexDirection: 'column' }}>
        <Button kind="primary" size="lg" icon="scan" full onClick={() => nav.go('scan')}>Scan another</Button>
        <div style={{ display: 'flex', gap: 8 }}>
          <Button kind="ghost" size="md" style={{ flex: 1 }} onClick={() => nav.openLead(last?.id)}>View lead</Button>
          <Button kind="ghost" size="md" style={{ flex: 1 }} onClick={() => nav.go('home')}>Done</Button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ScreenHome, ScreenScan, ScreenCrop, ScreenProcessing, ScreenReview, ScreenDuplicate, ScreenSaving, ScreenSuccess, SyncBadge, resetBtn });
