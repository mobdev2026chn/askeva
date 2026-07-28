// Top-level app — state machine, screen routing, transitions, toasts.

// Interactive TabBar override
function TabBar({ active = 'home', nav }) {
  const tabs = [
    { key: 'home',  icon: 'home',  label: 'Home',   target: 'home' },
    { key: 'leads', icon: 'users', label: 'Leads',  target: 'leadList' },
    { key: 'scan',  icon: 'scan',  label: '',       target: 'scan', fab: true },
    { key: 'lms',   icon: 'chart', label: 'LMS',    target: 'lms' },
    { key: 'card',  icon: 'target', label: 'My card', target: 'myCard' },
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
          <button onClick={() => nav.go(t.target)} style={resetBtn({
            width: 54, height: 54, borderRadius: 27,
            background: EVA.green, marginTop: -22,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 6px 14px ${EVA.green}55, 0 2px 6px rgba(0,0,0,0.1)`,
            border: '4px solid #fff',
          })}>
            <Icon name="scan" size={24} color="#fff" stroke={2} />
          </button>
        </div>
      ) : (
        <button key={t.key} onClick={() => nav.go(t.target)} style={resetBtn({
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
        })}>
          <Icon name={t.icon} size={22} color={active === t.key ? EVA.green : EVA.muted} stroke={active === t.key ? 2 : 1.7} />
          <div style={{ fontSize: 10.5, fontWeight: 500, color: active === t.key ? EVA.green : EVA.muted, letterSpacing: 0.1 }}>{t.label}</div>
        </button>
      ))}
    </div>
  );
}
window.TabBar = TabBar;

function App() {
  const [screen, setScreen] = React.useState('login');
  const [history, setHistory] = React.useState(['login']);
  const [leads, setLeads] = React.useState(SEED_LEADS);
  const [currentLeadId, setCurrentLeadId] = React.useState(null);
  const [pendingSave, setPendingSave] = React.useState(null);
  const [dup, setDup] = React.useState(null);
  const [scanScenario, setScanScenario] = React.useState('possible');
  const [toastMsg, setToastMsg] = React.useState(null);
  const [sync, setSync] = React.useState('synced');

  const tabScreens = ['home', 'leadList', 'lms', 'profile', 'myCard'];
  const authScreens = ['login', 'otp', 'biometric'];
  // Status bar dark mode per screen
  const darkScreens = ['login', 'otp', 'biometric', 'scan', 'crop', 'processing', 'home', 'leadDetail', 'myCard'];

  const nav = React.useMemo(() => ({
    go(target) {
      setScreen(target);
      setHistory(h => {
        if (authScreens.includes(target)) return [target];
        if (tabScreens.includes(target)) return [target];
        return [...h, target];
      });
    },
    back() {
      setHistory(h => {
        if (h.length <= 1) { setScreen('home'); return ['home']; }
        const next = h.slice(0, -1);
        setScreen(next[next.length - 1]);
        return next;
      });
    },
    openLead(id) {
      setCurrentLeadId(id);
      setScreen('leadDetail');
      setHistory(h => [...h, 'leadDetail']);
    },
    setDup,
    setPendingSave,
    setScanScenario,
    addLead(draft) {
      const newLead = {
        id: 'new-' + Date.now(),
        ...draft,
        status: 'new',
        event: 'SaaStock 2026',
        capturedAt: 'Just now',
        capturedBy: 'priya',
        activity: [{ t: 'now', k: 'scan', text: 'Captured at SaaStock booth #B12 by Priya Rao' }],
        reminder: null,
      };
      setLeads(ls => [newLead, ...ls]);
      setCurrentLeadId(newLead.id);
      setPendingSave(null);
      // Trigger a brief sync animation
      setSync('syncing');
      setTimeout(() => setSync('synced'), 1200);
    },
    mergeLead(id, incoming, picks, tags) {
      setLeads(ls => ls.map(l => {
        if (l.id !== id) return l;
        const merged = { ...l };
        if (picks.role) merged.role = incoming.role;
        if (picks.email) merged.email = incoming.email;
        if (picks.location) merged.location = incoming.location;
        merged.capturedAt = 'Just now';
        merged.activity = [
          { t: 'now', k: 'scan', text: 'Re-scanned at SaaStock booth #B12 · merged by Priya Rao' },
          ...(l.activity || []),
        ];
        if (tags) merged.tags = Array.from(new Set([...(l.tags || []), ...tags]));
        return merged;
      }));
      setCurrentLeadId(id);
      setDup(null);
      setSync('syncing');
      setTimeout(() => setSync('synced'), 1200);
    },
    updateLead(id, patch) {
      setLeads(ls => ls.map(l => {
        if (l.id !== id) return l;
        return {
          ...l,
          ...patch,
          activity: [
            { t: 'now', k: 'status', text: `Status changed to ${patch.status}` },
            ...(l.activity || []),
          ],
        };
      }));
    },
    runSync() {
      setSync('syncing');
      setTimeout(() => setSync('synced'), 1200);
    },
    toast(msg) {
      setToastMsg(msg);
      setTimeout(() => setToastMsg(null), 1800);
    },
  }), []);

  const state = { leads, currentLeadId, pendingSave, dup, scanScenario, sync };

  const screens = {
    login:        ScreenLogin,
    otp:          ScreenOTP,
    biometric:    ScreenBiometric,
    home:         ScreenHome,
    scan:         ScreenScan,
    crop:         ScreenCrop,
    processing:   ScreenProcessing,
    review:       ScreenReview,
    duplicate:    ScreenDuplicate,
    saving:       ScreenSaving,
    success:      ScreenSuccess,
    leadList:     ScreenLeadList,
    leadDetail:   ScreenLeadDetail,
    statusUpdate: ScreenStatusUpdate,
    lms:          ScreenLMS,
    recap:        ScreenRecap,
    profile:      ScreenProfile,
    myCard:       ScreenMyCard,
  };
  const Current = screens[screen] || ScreenHome;
  const isDark = darkScreens.includes(screen);

  // Scale-to-fit
  const [scale, setScale] = React.useState(1);
  React.useLayoutEffect(() => {
    const fit = () => {
      const vw = window.innerWidth, vh = window.innerHeight;
      const s = Math.min(1, (vh - 32) / 804, (vw - 32) / 372);
      setScale(s);
    };
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, []);

  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ width: 372 * scale, height: 804 * scale, position: 'relative' }}>
        <div style={{ width: 372, height: 804, transform: `scale(${scale})`, transformOrigin: 'top left' }}>
          <IOSDevice width={372} height={804} dark={isDark}>
            <div key={screen} style={{ width: '100%', height: '100%', position: 'relative', animation: 'evaFadeIn 240ms cubic-bezier(0.2,0.8,0.2,1)' }}>
              <Current nav={nav} state={state} />
              {toastMsg && (
                <div style={{
                  position: 'absolute', bottom: 110, left: '50%', transform: 'translateX(-50%)',
                  background: EVA.ink, color: '#fff', padding: '10px 16px', borderRadius: 12,
                  fontSize: 13, fontWeight: 500, fontFamily: EVA.font,
                  boxShadow: '0 8px 24px rgba(0,0,0,0.3)',
                  animation: 'evaToast 220ms cubic-bezier(0.2,0.8,0.2,1)',
                  zIndex: 100, whiteSpace: 'nowrap', display: 'flex', alignItems: 'center', gap: 8,
                }}>
                  <Icon name="check" size={14} color={EVA.green} stroke={2.5} />
                  {toastMsg}
                </div>
              )}
            </div>
          </IOSDevice>
        </div>
      </div>
      <style>{`
        @keyframes evaFadeIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes evaToast { from { opacity: 0; transform: translate(-50%, 8px); } to { opacity: 1; transform: translate(-50%, 0); } }
        @keyframes evaSpin { to { transform: rotate(360deg); } }
      `}</style>
    </div>
  );
}

window.App = App;
