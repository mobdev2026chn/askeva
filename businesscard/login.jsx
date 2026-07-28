// Login flow: Welcome → Credentials (email/phone+password) OR OTP → Biometric → Home

// ─── 0a. WELCOME / SIGN-IN ENTRY ───────────────────────────────────
function ScreenLogin({ nav, state }) {
  const [mode, setMode] = React.useState('password'); // 'password' | 'otp'
  const [id, setId] = React.useState('priya.rao@askeva.io');
  const [pwd, setPwd] = React.useState('••••••••••');
  const [phone, setPhone] = React.useState('+91 98765 43210');
  const [showPwd, setShowPwd] = React.useState(false);

  const submit = () => nav.go(mode === 'otp' ? 'otp' : 'biometric');

  return (
    <div style={{ width: '100%', height: '100%', background: EVA.greenInk, position: 'relative', overflow: 'hidden', fontFamily: EVA.font }} data-screen-label="Login">
      <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(120% 70% at 50% 0%, ${EVA.green}33 0%, transparent 55%), radial-gradient(80% 40% at 90% 110%, ${EVA.greenDeep}88 0%, transparent 60%)` }} />

      <div style={{ position: 'relative', height: '100%', display: 'flex', flexDirection: 'column', padding: '90px 28px 36px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 44 }}>
          <div style={{ width: 44, height: 44, borderRadius: 12, background: EVA.green, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 8px 20px ${EVA.green}66` }}>
            <EvaLogo size={28} color="#fff" />
          </div>
          <div>
            <div style={{ fontSize: 18, fontWeight: 700, color: '#fff', letterSpacing: -0.3, fontFamily: EVA.fontDisplay }}>AskEva</div>
            <div style={{ fontSize: 11, fontWeight: 500, color: 'rgba(255,255,255,0.55)', letterSpacing: 0.8, textTransform: 'uppercase' }}>Card Capture</div>
          </div>
        </div>

        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 30, fontWeight: 700, color: '#fff', letterSpacing: -0.8, lineHeight: 1.08, fontFamily: EVA.fontDisplay, textWrap: 'pretty' }}>
            Welcome back.
          </div>
          <div style={{ marginTop: 10, fontSize: 14, color: 'rgba(255,255,255,0.6)', lineHeight: 1.5, maxWidth: 280 }}>
            Sign in to capture business cards into your Lead page.
          </div>

          {/* Tab switch */}
          <div style={{ display: 'flex', marginTop: 28, background: 'rgba(255,255,255,0.06)', borderRadius: 12, padding: 4, gap: 4 }}>
            {[
              { k: 'password', l: 'Password' },
              { k: 'otp', l: 'OTP' },
            ].map(t => (
              <button key={t.k} onClick={() => setMode(t.k)} style={resetBtn({
                flex: 1, padding: '10px 0', borderRadius: 8,
                background: mode === t.k ? '#fff' : 'transparent',
                color: mode === t.k ? EVA.ink : 'rgba(255,255,255,0.7)',
                fontSize: 13, fontWeight: 600,
              })}>{t.l}</button>
            ))}
          </div>

          {/* Fields */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 16 }}>
            {mode === 'password' ? (
              <>
                <LoginField icon="mail" value={id} onChange={setId} />
                <LoginField icon="settings" value={showPwd ? pwd : '••••••••••'} onChange={setPwd}
                  right={<button onClick={() => setShowPwd(s => !s)} style={resetBtn({ display: 'flex' })}><Icon name="eye" size={16} color="rgba(255,255,255,0.45)" /></button>} />
                <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: -2 }}>
                  <button onClick={() => nav.toast('Reset link sent')} style={resetBtn({ fontSize: 12, color: EVA.green, fontWeight: 600 })}>Forgot password?</button>
                </div>
              </>
            ) : (
              <>
                <LoginField icon="phone" value={phone} onChange={setPhone} />
                <div style={{ fontSize: 11.5, color: 'rgba(255,255,255,0.5)', padding: '0 4px', lineHeight: 1.4 }}>
                  We'll text you a 6-digit code to verify it's you.
                </div>
              </>
            )}
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <Button kind="primary" full size="lg" onClick={submit}>
            {mode === 'otp' ? 'Send code' : 'Sign in'}
          </Button>

          <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '8px 4px' }}>
            <div style={{ flex: 1, height: 1, background: 'rgba(255,255,255,0.1)' }} />
            <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.45)', letterSpacing: 0.8 }}>OR</div>
            <div style={{ flex: 1, height: 1, background: 'rgba(255,255,255,0.1)' }} />
          </div>

          <button onClick={() => nav.toast('SSO redirect (mock)')} style={resetBtn({
            height: 48, borderRadius: 12, background: 'rgba(255,255,255,0.08)',
            border: '1px solid rgba(255,255,255,0.12)', color: '#fff',
            fontSize: 14, fontWeight: 600,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
          })}>
            <Icon name="building" size={16} color="#fff" /> Continue with SSO
          </button>

          <div style={{ textAlign: 'center', marginTop: 12, fontSize: 11, color: 'rgba(255,255,255,0.4)' }}>
            v2.4.1 · AskEva Internal
          </div>
        </div>
      </div>
    </div>
  );
}

function LoginField({ icon, value, onChange, right }) {
  return (
    <div style={{
      background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.12)',
      borderRadius: 14, padding: '12px 14px',
      display: 'flex', alignItems: 'center', gap: 12,
    }}>
      <Icon name={icon} size={18} color="rgba(255,255,255,0.5)" />
      <input value={value} onChange={e => onChange(e.target.value)} style={{
        flex: 1, background: 'transparent', border: 'none', outline: 'none',
        color: '#fff', fontSize: 15, fontWeight: 500, fontFamily: EVA.font, minWidth: 0,
      }} />
      {right}
    </div>
  );
}

// ─── 0b. OTP ───────────────────────────────────────────────────────
function ScreenOTP({ nav }) {
  const [digits, setDigits] = React.useState(['', '', '', '', '', '']);
  const refs = React.useRef([]);
  const [resend, setResend] = React.useState(30);

  React.useEffect(() => {
    refs.current[0]?.focus();
  }, []);

  React.useEffect(() => {
    if (resend <= 0) return;
    const t = setTimeout(() => setResend(r => r - 1), 1000);
    return () => clearTimeout(t);
  }, [resend]);

  const setDigit = (i, v) => {
    if (v && !/^\d$/.test(v)) return;
    const next = [...digits];
    next[i] = v;
    setDigits(next);
    if (v && i < 5) refs.current[i + 1]?.focus();
    if (next.every(d => d)) {
      setTimeout(() => nav.go('biometric'), 220);
    }
  };

  const filled = digits.filter(Boolean).length;

  return (
    <div style={{ width: '100%', height: '100%', background: EVA.greenInk, fontFamily: EVA.font, position: 'relative', overflow: 'hidden', color: '#fff' }} data-screen-label="OTP">
      <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(120% 60% at 50% 20%, ${EVA.green}22 0%, transparent 60%)` }} />

      <div style={{ position: 'relative', padding: '56px 24px 32px', display: 'flex', flexDirection: 'column', height: '100%' }}>
        <button onClick={() => nav.go('login')} style={resetBtn({ width: 36, height: 36, borderRadius: 18, background: 'rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 32 })}>
          <Icon name="chevL" size={20} color="#fff" />
        </button>

        <div style={{ fontSize: 28, fontWeight: 700, color: '#fff', letterSpacing: -0.6, fontFamily: EVA.fontDisplay, lineHeight: 1.1 }}>
          Enter verification code
        </div>
        <div style={{ marginTop: 8, fontSize: 14, color: 'rgba(255,255,255,0.6)', lineHeight: 1.5 }}>
          Sent to <span style={{ color: '#fff', fontWeight: 500 }}>+91 98765 43210</span>. <button onClick={() => nav.go('login')} style={resetBtn({ color: EVA.green, fontWeight: 600, fontSize: 14 })}>Change</button>
        </div>

        <div style={{ display: 'flex', gap: 10, marginTop: 32, justifyContent: 'space-between' }}>
          {digits.map((d, i) => (
            <input
              key={i}
              ref={el => refs.current[i] = el}
              value={d}
              onChange={e => setDigit(i, e.target.value.slice(-1))}
              onKeyDown={e => {
                if (e.key === 'Backspace' && !d && i > 0) refs.current[i - 1]?.focus();
              }}
              maxLength={1}
              inputMode="numeric"
              style={{
                width: 44, height: 56, borderRadius: 12,
                background: 'rgba(255,255,255,0.06)',
                border: `1.5px solid ${d ? EVA.green : 'rgba(255,255,255,0.12)'}`,
                color: '#fff', textAlign: 'center', fontSize: 22, fontWeight: 700,
                fontFamily: EVA.fontDisplay, outline: 'none',
              }}
            />
          ))}
        </div>

        <div style={{ marginTop: 20, fontSize: 13, color: 'rgba(255,255,255,0.55)', display: 'flex', alignItems: 'center', gap: 8 }}>
          {resend > 0 ? (
            <>Resend code in <span style={{ fontWeight: 600, color: '#fff', fontVariantNumeric: 'tabular-nums' }}>0:{String(resend).padStart(2, '0')}</span></>
          ) : (
            <button onClick={() => { setResend(30); nav.toast('Code resent'); }} style={resetBtn({ color: EVA.green, fontWeight: 600, fontSize: 13 })}>Resend code</button>
          )}
        </div>

        <div style={{ flex: 1 }} />

        <Button kind="primary" full size="lg" onClick={() => nav.go('biometric')} style={{ opacity: filled === 6 ? 1 : 0.5, pointerEvents: filled === 6 ? 'auto' : 'none' }}>
          Verify &amp; continue
        </Button>
      </div>
    </div>
  );
}

// ─── 0c. BIOMETRIC ─────────────────────────────────────────────────
function ScreenBiometric({ nav }) {
  const [auth, setAuth] = React.useState('idle'); // idle | scanning | done
  React.useEffect(() => {
    if (auth !== 'scanning') return;
    const t = setTimeout(() => {
      setAuth('done');
      setTimeout(() => nav.go('home'), 500);
    }, 1200);
    return () => clearTimeout(t);
  }, [auth]);

  return (
    <div style={{ width: '100%', height: '100%', background: EVA.greenInk, fontFamily: EVA.font, position: 'relative', overflow: 'hidden', color: '#fff' }} data-screen-label="Biometric">
      <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(120% 60% at 50% 50%, ${auth === 'done' ? EVA.green + '44' : EVA.green + '18'} 0%, transparent 60%)`, transition: 'background 400ms' }} />

      <div style={{ position: 'relative', height: '100%', padding: '90px 24px 36px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', maxWidth: 280 }}>
          <Avatar name="Priya Rao" size={64} />
          <div style={{ fontSize: 22, fontWeight: 700, color: '#fff', letterSpacing: -0.4, fontFamily: EVA.fontDisplay, marginTop: 14 }}>
            Hi, Priya
          </div>
          <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.55)', marginTop: 4 }}>
            priya.rao@askeva.io
          </div>
        </div>

        {/* Face ID / Touch ID symbol */}
        <button onClick={() => auth === 'idle' && setAuth('scanning')} style={resetBtn({ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 })}>
          <div style={{
            width: 116, height: 116, borderRadius: 28,
            border: `3px solid ${auth === 'done' ? EVA.green : (auth === 'scanning' ? EVA.green : 'rgba(255,255,255,0.2)')}`,
            position: 'relative', transition: 'all 300ms',
            background: auth === 'done' ? EVA.green + '22' : 'transparent',
            boxShadow: auth !== 'idle' ? `0 0 30px ${EVA.green}55` : 'none',
          }}>
            {/* corner brackets */}
            {[
              { t: -3, l: -3, edges: 'tl' }, { t: -3, r: -3, edges: 'tr' },
              { b: -3, l: -3, edges: 'bl' }, { b: -3, r: -3, edges: 'br' },
            ].map((p, i) => (
              <div key={i} style={{
                position: 'absolute', top: p.t, left: p.l, right: p.r, bottom: p.b,
                width: 22, height: 22,
                borderTop: p.edges.includes('t') ? `3px solid ${EVA.green}` : 'none',
                borderBottom: p.edges.includes('b') ? `3px solid ${EVA.green}` : 'none',
                borderLeft: p.edges.includes('l') ? `3px solid ${EVA.green}` : 'none',
                borderRight: p.edges.includes('r') ? `3px solid ${EVA.green}` : 'none',
                borderTopLeftRadius: p.edges === 'tl' ? 8 : 0,
                borderTopRightRadius: p.edges === 'tr' ? 8 : 0,
                borderBottomLeftRadius: p.edges === 'bl' ? 8 : 0,
                borderBottomRightRadius: p.edges === 'br' ? 8 : 0,
              }} />
            ))}
            {/* face icon */}
            <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {auth === 'done' ? (
                <Icon name="check" size={56} color={EVA.green} stroke={2.5} />
              ) : (
                <svg width="60" height="60" viewBox="0 0 60 60" fill="none" stroke={auth === 'scanning' ? EVA.green : 'rgba(255,255,255,0.7)'} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M20 22v4M40 22v4" />
                  <path d="M30 24v8l-3 2M22 38c2 2 5 3 8 3s6-1 8-3" />
                </svg>
              )}
            </div>
            {auth === 'scanning' && (
              <div style={{ position: 'absolute', left: '50%', top: '50%', width: 116, height: 116, marginLeft: -58, marginTop: -58, borderRadius: 28, border: `3px solid ${EVA.green}`, opacity: 0, animation: 'evaRing 1.2s ease-out infinite' }} />
            )}
          </div>
          <div style={{ fontSize: 14, fontWeight: 500, color: '#fff' }}>
            {auth === 'idle' && 'Tap to unlock with Face ID'}
            {auth === 'scanning' && 'Scanning your face…'}
            {auth === 'done' && 'Authenticated'}
          </div>
        </button>
        <style>{`@keyframes evaRing { 0% { transform: scale(1); opacity: 0.6; } 100% { transform: scale(1.4); opacity: 0; } }`}</style>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, width: '100%' }}>
          <Button kind="dark" full size="md" onClick={() => nav.go('home')}>
            Use password instead
          </Button>
          <button onClick={() => nav.go('login')} style={resetBtn({ fontSize: 12, color: 'rgba(255,255,255,0.45)', textAlign: 'center', padding: 8 })}>
            Sign in as a different user
          </button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ScreenLogin, ScreenOTP, ScreenBiometric });
