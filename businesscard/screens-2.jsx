// Interactive screens — part 2: Lead list, Lead detail, Status/follow-up, LMS (mgmt view), Recap, Profile

// ─── LEAD LIST ────────────────────────────────────────────────────
function ScreenLeadList({ nav, state }) {
  const [query, setQuery] = React.useState('');
  const [filter, setFilter] = React.useState('all');

  const counts = {
    all: state.leads.length,
    new: state.leads.filter(l => l.status === 'new').length,
    contacted: state.leads.filter(l => l.status === 'contacted').length,
    followup: state.leads.filter(l => l.status === 'followup').length,
    converted: state.leads.filter(l => l.status === 'converted').length,
  };

  let visible = state.leads;
  if (filter !== 'all') visible = visible.filter(l => l.status === filter);
  if (query) {
    const q = query.toLowerCase();
    visible = visible.filter(l => (l.name + l.company + l.email + l.role).toLowerCase().includes(q));
  }

  const groups = visible.reduce((acc, l) => {
    (acc[l.event] = acc[l.event] || []).push(l);
    return acc;
  }, {});

  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="Lead list">
      <AppBar
        left={null}
        title="Leads"
        sub={`${state.leads.length} total · ${state.leads.filter(l => l.event === 'SaaStock 2026').length} at SaaStock`}
        right={<>
          <button onClick={() => nav.toast('Sort: Recent first')} style={resetBtn({ width: 32, height: 32, borderRadius: 16, background: EVA.chip, display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
            <Icon name="sort" size={16} color={EVA.body} />
          </button>
          <button onClick={() => nav.toast('Exported · check email')} style={resetBtn({ width: 32, height: 32, borderRadius: 16, background: EVA.chip, display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
            <Icon name="download" size={16} color={EVA.body} />
          </button>
        </>}
      />

      <div style={{ padding: '14px 20px 0' }}>
        <div style={{ background: '#fff', border: '1px solid ' + EVA.hairline, borderRadius: 14, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <Icon name="search" size={18} color={EVA.muted} />
          <input
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Search name, company, email…"
            style={{ flex: 1, fontSize: 14, color: EVA.ink, border: 'none', outline: 'none', background: 'transparent', fontFamily: EVA.font, minWidth: 0 }}
          />
          {query && (
            <button onClick={() => setQuery('')} style={resetBtn({ display: 'flex' })}>
              <Icon name="close" size={14} color={EVA.muted} />
            </button>
          )}
          <div style={{ width: 1, height: 16, background: EVA.hairline }} />
          <Icon name="filter" size={18} color={EVA.body} />
        </div>

        <div style={{ display: 'flex', gap: 8, marginTop: 12, overflowX: 'auto', paddingBottom: 4 }}>
          {[
            { k: 'all',       l: 'All',         dot: null },
            { k: 'new',       l: 'New',         dot: EVA.info },
            { k: 'contacted', l: 'Contacted',   dot: '#7B3DC4' },
            { k: 'followup',  l: 'Follow-up',   dot: EVA.warn },
            { k: 'converted', l: 'Converted',   dot: EVA.green },
          ].map(c => (
            <button key={c.k} onClick={() => setFilter(c.k)} style={resetBtn({
              padding: '7px 12px', borderRadius: 18,
              background: filter === c.k ? EVA.ink : '#fff',
              color: filter === c.k ? '#fff' : EVA.body,
              border: filter === c.k ? '1px solid ' + EVA.ink : '1px solid ' + EVA.hairline,
              fontSize: 12.5, fontWeight: 600, whiteSpace: 'nowrap',
              display: 'inline-flex', alignItems: 'center', gap: 6, flexShrink: 0,
            })}>
              {c.dot && <span style={{ width: 6, height: 6, borderRadius: 3, background: c.dot }} />}
              {c.l} <span style={{ opacity: filter === c.k ? 0.7 : 0.5, fontWeight: 500 }}>{counts[c.k]}</span>
            </button>
          ))}
        </div>
      </div>

      <div style={{ padding: '14px 20px 100px', height: 'calc(100% - 220px)', overflow: 'auto' }}>
        {visible.length === 0 ? (
          <EmptyState
            icon="search"
            title={query ? 'No matches' : 'No leads in this filter'}
            sub={query ? `Nothing found for "${query}"` : 'Try a different status or scan a new card.'}
            ctaLabel={query ? 'Clear search' : 'Scan a card'}
            onCta={() => query ? setQuery('') : nav.go('scan')}
          />
        ) : Object.entries(groups).map(([eventName, leads]) => (
          <div key={eventName} style={{ marginBottom: 18 }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase', padding: '4px 4px 8px' }}>{eventName} · {leads.length}</div>
            <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, overflow: 'hidden' }}>
              {leads.map((l, i, a) => {
                const scanner = TEAM.find(t => t.id === l.capturedBy);
                return (
                  <button key={l.id} onClick={() => nav.openLead(l.id)} style={resetBtn({
                    width: '100%', textAlign: 'left',
                    padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
                    borderBottom: i === a.length - 1 ? 'none' : '1px solid ' + EVA.hairline,
                  })}>
                    <Avatar name={l.name} size={40} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{ fontSize: 14, fontWeight: 600, color: EVA.ink, letterSpacing: -0.1 }}>{l.name}</div>
                        <Status kind={l.status} size="sm" />
                      </div>
                      <div style={{ fontSize: 11.5, color: EVA.muted, marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {l.role} · {l.company}
                      </div>
                      <div style={{ fontSize: 10.5, color: EVA.muted, marginTop: 4, display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                        <span>{l.capturedAt}</span>
                        <span>·</span>
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}>
                          <Icon name="user" size={9} color={EVA.muted} /> {scanner?.name.split(' ')[0] || 'Unknown'}
                        </span>
                        {l.followUp?.overdue && (
                          <>
                            <span>·</span>
                            <span style={{ color: EVA.warn, fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 3 }}>
                              <Icon name="clock" size={9} color={EVA.warn} /> Overdue
                            </span>
                          </>
                        )}
                      </div>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
                      {typeof l.score === 'number' && <ScorePill score={l.score} size="sm" />}
                      <Icon name="chevR" size={14} color={EVA.muted} />
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </div>

      <TabBar active="leads" nav={nav} />
    </div>
  );
}

// ─── LEAD DETAIL ──────────────────────────────────────────────────
function ScreenLeadDetail({ nav, state }) {
  const lead = state.leads.find(l => l.id === state.currentLeadId);
  const [tab, setTab] = React.useState('details');
  const [starred, setStarred] = React.useState(false);
  const [reachChannel, setReachChannel] = React.useState(null); // null | 'mail' | 'whats'
  if (!lead) return null;
  const scanner = TEAM.find(t => t.id === lead.capturedBy);

  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="Lead detail">
      <div style={{ background: EVA.greenInk, padding: '56px 20px 60px', position: 'relative' }}>
        <div style={{ position: 'absolute', top: -20, right: -40, width: 180, height: 180, borderRadius: '50%', background: `radial-gradient(circle, ${EVA.green}33, transparent 70%)` }} />
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
          <button onClick={() => nav.back()} style={resetBtn({ display: 'flex' })}>
            <Icon name="chevL" size={22} color="#fff" />
          </button>
          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={() => nav.go('statusUpdate')} style={resetBtn({ width: 32, height: 32, borderRadius: 16, background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
              <Icon name="edit" size={16} color="#fff" />
            </button>
            <button onClick={() => setStarred(s => !s)} style={resetBtn({ width: 32, height: 32, borderRadius: 16, background: starred ? EVA.green : 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' })}>
              <Icon name="star" size={16} color="#fff" />
            </button>
          </div>
        </div>
      </div>

      <div style={{ padding: '0 20px', marginTop: -42, position: 'relative' }}>
        <div style={{ background: '#fff', borderRadius: 18, padding: 18, border: '1px solid ' + EVA.hairline, boxShadow: '0 8px 24px rgba(0,0,0,0.06)' }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
            <Avatar name={lead.name} size={56} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 18, fontWeight: 700, color: EVA.ink, letterSpacing: -0.3, fontFamily: EVA.fontDisplay }}>{lead.name}</div>
              <div style={{ fontSize: 13, color: EVA.body, marginTop: 2 }}>{lead.role} · {lead.company}</div>
              <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                <Status kind={lead.status} size="sm" />
                {typeof lead.score === 'number' && <ScorePill score={lead.score} size="sm" />}
                <span style={{ fontSize: 10.5, color: EVA.muted, padding: '3px 7px', background: EVA.chip, borderRadius: 8, fontWeight: 500 }}>{lead.event}</span>
              </div>
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginTop: 16 }}>
            {[
              { i: 'phone', l: 'Call', c: EVA.green, action: () => nav.toast(`Calling ${lead.phone}…`) },
              { i: 'mail', l: 'Email', c: EVA.info, action: () => nav.toast(`Drafted email to ${lead.email}`) },
              { i: 'whats', l: 'WhatsApp', c: '#25D366', action: () => nav.toast('Opening WhatsApp…') },
              { i: 'calendar', l: 'Meet', c: '#7B3DC4', action: () => nav.toast('Meeting scheduled') },
            ].map(a => (
              <button key={a.l} onClick={a.action} style={resetBtn({
                background: EVA.chip, borderRadius: 12, padding: '10px 6px',
                display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
              })}>
                <div style={{ width: 30, height: 30, borderRadius: 15, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name={a.i} size={15} color={a.c} stroke={2.2} />
                </div>
                <div style={{ fontSize: 10.5, fontWeight: 600, color: EVA.ink }}>{a.l}</div>
              </button>
            ))}
          </div>
        </div>
      </div>

      <div style={{ padding: '18px 20px 100px', height: 'calc(100% - 250px)', overflow: 'auto' }}>
        <div style={{ display: 'flex', gap: 22, borderBottom: '1px solid ' + EVA.hairline, marginBottom: 14 }}>
          {[
            { k: 'details',  l: 'Details' },
            { k: 'activity', l: 'Activity', n: lead.activity?.length },
            { k: 'notes',    l: 'Notes',    n: lead.note ? 1 : 0 },
          ].map(t => (
            <button key={t.k} onClick={() => setTab(t.k)} style={resetBtn({
              padding: '8px 0',
              borderBottom: tab === t.k ? `2px solid ${EVA.green}` : '2px solid transparent',
              fontSize: 13, fontWeight: 600, color: tab === t.k ? EVA.ink : EVA.muted,
              display: 'flex', alignItems: 'center', gap: 6, marginBottom: -1,
            })}>
              {t.l}
              {t.n ? <span style={{ background: EVA.chip, fontSize: 10, padding: '1px 6px', borderRadius: 8, color: EVA.muted, fontWeight: 700 }}>{t.n}</span> : null}
            </button>
          ))}
        </div>

        {tab === 'details' && (
          <>
            <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, overflow: 'hidden', marginBottom: 14 }}>
              {[
                { i: 'mail',     l: 'Email',    v: lead.email },
                { i: 'phone',    l: 'Phone',    v: lead.phone },
                { i: 'building', l: 'Company',  v: lead.company },
                { i: 'map',      l: 'Location', v: lead.location },
              ].map((r, i, a) => (
                <div key={r.l} style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12, borderBottom: i === a.length - 1 ? 'none' : '1px solid ' + EVA.hairline }}>
                  <div style={{ width: 32, height: 32, borderRadius: 10, background: EVA.chip, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Icon name={r.i} size={15} color={EVA.body} />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 10.5, color: EVA.muted, letterSpacing: 0.5, textTransform: 'uppercase', fontWeight: 600 }}>{r.l}</div>
                    <div style={{ fontSize: 13.5, color: EVA.ink, fontWeight: 500, marginTop: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.v}</div>
                  </div>
                </div>
              ))}
            </div>

            {lead.reminder && (
              <button onClick={() => nav.go('statusUpdate')} style={resetBtn({
                width: '100%', background: EVA.warnSoft, borderRadius: 14, padding: 14, marginBottom: 14,
                display: 'flex', alignItems: 'center', gap: 12, textAlign: 'left',
                border: `1px solid ${EVA.warn}33`,
              })}>
                <div style={{ width: 36, height: 36, borderRadius: 12, background: EVA.warn, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name="clock" size={18} color="#fff" stroke={2} />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 11, fontWeight: 700, color: EVA.warn, letterSpacing: 0.5, textTransform: 'uppercase' }}>Reminder</div>
                  <div style={{ fontSize: 13.5, color: EVA.ink, fontWeight: 600, marginTop: 1 }}>{lead.reminder.label} · {lead.reminder.when}</div>
                </div>
                <Icon name="chevR" size={16} color={EVA.warn} />
              </button>
            )}

            {/* Captured-by trail */}
            <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
              <Avatar name={scanner?.name || 'Unknown'} size={28} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 10.5, color: EVA.muted, letterSpacing: 0.5, textTransform: 'uppercase', fontWeight: 600 }}>Captured by</div>
                <div style={{ fontSize: 13, color: EVA.ink, fontWeight: 600 }}>{scanner?.name || 'Unknown'} · {scanner?.role}</div>
              </div>
              <div style={{ fontSize: 11, color: EVA.muted }}>{lead.capturedAt}</div>
            </div>

            {/* Reach out */}
            <div style={{ fontSize: 11.5, fontWeight: 700, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 8, marginTop: 4 }}>Reach out</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginBottom: reachChannel ? 0 : 14 }}>
              <button onClick={() => setReachChannel(reachChannel === 'whats' ? null : 'whats')} style={resetBtn({
                background: reachChannel === 'whats' ? '#25D366' : '#fff',
                border: '1.5px solid ' + (reachChannel === 'whats' ? '#25D366' : EVA.hairline),
                borderRadius: 12, padding: '12px 10px',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                color: reachChannel === 'whats' ? '#fff' : EVA.ink,
                boxShadow: reachChannel === 'whats' ? '0 4px 12px rgba(37,211,102,0.3)' : 'none',
              })}>
                <Icon name="whats" size={16} color={reachChannel === 'whats' ? '#fff' : '#25D366'} stroke={2.2} />
                <span style={{ fontSize: 13, fontWeight: 700 }}>Send via WhatsApp</span>
              </button>
              <button onClick={() => setReachChannel(reachChannel === 'mail' ? null : 'mail')} style={resetBtn({
                background: reachChannel === 'mail' ? EVA.info : '#fff',
                border: '1.5px solid ' + (reachChannel === 'mail' ? EVA.info : EVA.hairline),
                borderRadius: 12, padding: '12px 10px',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                color: reachChannel === 'mail' ? '#fff' : EVA.ink,
                boxShadow: reachChannel === 'mail' ? `0 4px 12px ${EVA.info}40` : 'none',
              })}>
                <Icon name="mail" size={16} color={reachChannel === 'mail' ? '#fff' : EVA.info} stroke={2.2} />
                <span style={{ fontSize: 13, fontWeight: 700 }}>Send via Email</span>
              </button>
            </div>

            {reachChannel && (
              <div style={{ marginBottom: 14 }}>
                <ReachOutPanel
                  lead={lead}
                  channel={reachChannel}
                  onCancel={() => setReachChannel(null)}
                  onSend={({ channel }) => {
                    setReachChannel(null);
                    nav.toast(channel === 'mail' ? 'Email sent · tracking opens' : 'WhatsApp message sent');
                  }}
                />
              </div>
            )}

            {/* Score breakdown */}
            {typeof lead.score === 'number' && (
              <div style={{ marginBottom: 14 }}>
                <div style={{ fontSize: 11.5, fontWeight: 700, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 8 }}>Score breakdown</div>
                <ScoreBreakdown breakdown={lead.scoreBreak} score={lead.score} />
              </div>
            )}

            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <Button kind="dark" size="md" icon="spark" full onClick={() => nav.go('statusUpdate')}>Update status &amp; reminder</Button>
            </div>
          </>
        )}

        {tab === 'activity' && (
          <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, padding: 14 }}>
            {(lead.activity || [
              { t: lead.capturedAt, k: 'scan', text: `Captured at ${lead.event}` },
            ]).map((a, i, arr) => (
              <div key={i} style={{ display: 'flex', gap: 12, position: 'relative', paddingBottom: i === arr.length - 1 ? 0 : 12 }}>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', minWidth: 28 }}>
                  <div style={{ width: 28, height: 28, borderRadius: 14, background: activityBg(a.k), display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1 }}>
                    <Icon name={activityIcon(a.k)} size={13} color={activityFg(a.k)} stroke={2.2} />
                  </div>
                  {i < arr.length - 1 && <div style={{ width: 2, flex: 1, background: EVA.hairline, marginTop: 2 }} />}
                </div>
                <div style={{ flex: 1, paddingBottom: i === arr.length - 1 ? 0 : 8 }}>
                  <div style={{ fontSize: 13, color: EVA.ink, fontWeight: 500, lineHeight: 1.4 }}>{a.text}</div>
                  <div style={{ fontSize: 11, color: EVA.muted, marginTop: 2 }}>{a.t} ago</div>
                </div>
              </div>
            ))}
          </div>
        )}

        {tab === 'notes' && (
          <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, padding: 14 }}>
            {lead.note ? (
              <>
                <div style={{ fontSize: 13.5, color: EVA.ink, lineHeight: 1.5 }}>{lead.note}</div>
                <div style={{ display: 'flex', gap: 6, marginTop: 12, flexWrap: 'wrap' }}>
                  {lead.tags.map(t => (
                    <span key={t} style={{ padding: '4px 9px', borderRadius: 8, fontSize: 11, fontWeight: 600, background: EVA.chip, color: EVA.body }}>{t}</span>
                  ))}
                </div>
              </>
            ) : (
              <EmptyState icon="note" title="No notes yet" sub="Add context for follow-ups." ctaLabel="Add note" onCta={() => nav.go('statusUpdate')} compact />
            )}
          </div>
        )}
      </div>
    </div>
  );
}

function activityIcon(k) {
  return { scan: 'camera', call: 'phone', mail: 'mail', note: 'note', tag: 'tag', status: 'spark' }[k] || 'spark';
}
function activityBg(k) {
  return { scan: EVA.greenSoft, call: EVA.infoSoft, mail: EVA.infoSoft, note: EVA.chip, tag: EVA.chip, status: EVA.greenSoft }[k] || EVA.chip;
}
function activityFg(k) {
  return { scan: EVA.greenDeep, call: EVA.info, mail: EVA.info, note: EVA.body, tag: EVA.body, status: EVA.greenDeep }[k] || EVA.body;
}

// ─── STATUS / REMINDER UPDATE ─────────────────────────────────────
function ScreenStatusUpdate({ nav, state }) {
  const lead = state.leads.find(l => l.id === state.currentLeadId);
  const [status, setStatus] = React.useState(lead?.status || 'contacted');
  const [when, setWhen] = React.useState('nextweek');
  const [channel, setChannel] = React.useState('mail');
  const [note, setNote] = React.useState(lead?.note || '');
  const [tags, setTags] = React.useState(lead?.tags || []);
  if (!lead) return null;

  const save = () => {
    nav.updateLead(lead.id, {
      status,
      note,
      tags,
      reminder: status === 'followup' || status === 'contacted'
        ? { label: channelLabel(channel) + ' follow-up', when: whenLabel(when) }
        : lead.reminder,
    });
    nav.toast('Status updated');
    nav.back();
  };

  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="Status update">
      <AppBar
        left={<button onClick={() => nav.back()} style={resetBtn({})}><Icon name="close" size={20} color={EVA.ink} /></button>}
        title="Update lead"
        sub={`${lead.name} · ${lead.company}`}
        right={null}
      />

      <div style={{ padding: '14px 20px 140px', height: 'calc(100% - 116px)', overflow: 'auto' }}>
        <SectionLabel>Lead status</SectionLabel>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginBottom: 18 }}>
          {[
            { k: 'new',       l: 'New',        i: 'spark',    d: 'Just captured' },
            { k: 'contacted', l: 'Contacted',  i: 'phone',    d: 'Reached out' },
            { k: 'followup',  l: 'Follow-up',  i: 'clock',    d: 'Reminder set' },
            { k: 'converted', l: 'Converted',  i: 'check',    d: 'Now a customer' },
          ].map(s => {
            const selected = status === s.k;
            return (
              <button key={s.k} onClick={() => setStatus(s.k)} style={resetBtn({
                background: selected ? EVA.ink : '#fff',
                color: selected ? '#fff' : EVA.ink,
                border: `1.5px solid ${selected ? EVA.ink : EVA.hairline}`,
                borderRadius: 14, padding: '14px 14px', textAlign: 'left',
                display: 'flex', flexDirection: 'column', gap: 8,
                position: 'relative',
              })}>
                {selected && (
                  <div style={{ position: 'absolute', top: 10, right: 10, width: 18, height: 18, borderRadius: 9, background: EVA.green, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Icon name="check" size={11} color="#fff" stroke={3} />
                  </div>
                )}
                <Icon name={s.i} size={20} color={selected ? EVA.green : EVA.body} stroke={2} />
                <div style={{ fontSize: 14, fontWeight: 700, letterSpacing: -0.1 }}>{s.l}</div>
                <div style={{ fontSize: 10.5, opacity: 0.6, fontWeight: 500 }}>{s.d}</div>
              </button>
            );
          })}
        </div>

        {(status === 'followup' || status === 'contacted') && (
          <>
            <SectionLabel>Reminder</SectionLabel>
            <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, padding: 14, marginBottom: 12 }}>
              <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
                {[
                  { k: 'tomorrow',  l: 'Tomorrow', s: 'Wed' },
                  { k: 'threedays', l: '3 days',   s: 'Fri' },
                  { k: 'nextweek',  l: 'Next week',s: 'May 26' },
                  { k: 'custom',    l: 'Custom',   s: '' },
                ].map(d => {
                  const selected = when === d.k;
                  return (
                    <button key={d.k} onClick={() => setWhen(d.k)} style={resetBtn({
                      flex: 1, padding: '8px 6px', borderRadius: 10,
                      background: selected ? EVA.greenSoft : EVA.chip,
                      border: selected ? `1.5px solid ${EVA.green}` : '1.5px solid transparent',
                      textAlign: 'center',
                    })}>
                      <div style={{ fontSize: 11.5, fontWeight: 700, color: selected ? EVA.greenDeep : EVA.ink, letterSpacing: -0.1 }}>{d.l}</div>
                      {d.s && <div style={{ fontSize: 10, color: selected ? EVA.greenDeep : EVA.muted, marginTop: 2 }}>{d.s}</div>}
                    </button>
                  );
                })}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px', background: EVA.chip, borderRadius: 10 }}>
                <Icon name="clock" size={16} color={EVA.body} />
                <div style={{ flex: 1, fontSize: 13, color: EVA.ink, fontWeight: 500 }}>10:00 AM IST</div>
                <Icon name="chevR" size={14} color={EVA.muted} />
              </div>
            </div>

            <SectionLabel>Channel</SectionLabel>
            <div style={{ display: 'flex', gap: 8, marginBottom: 18 }}>
              {[
                { k: 'mail',  i: 'mail',  l: 'Email' },
                { k: 'phone', i: 'phone', l: 'Call' },
                { k: 'whats', i: 'whats', l: 'WhatsApp' },
              ].map(c => {
                const selected = channel === c.k;
                return (
                  <button key={c.k} onClick={() => setChannel(c.k)} style={resetBtn({
                    flex: 1, padding: '12px 10px', borderRadius: 12,
                    background: '#fff',
                    border: `1.5px solid ${selected ? EVA.green : EVA.hairline}`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                  })}>
                    <Icon name={c.i} size={15} color={selected ? EVA.greenDeep : EVA.body} stroke={2} />
                    <span style={{ fontSize: 12.5, fontWeight: 600, color: selected ? EVA.greenDeep : EVA.ink }}>{c.l}</span>
                  </button>
                );
              })}
            </div>
          </>
        )}

        <SectionLabel>Note</SectionLabel>
        <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, padding: 14, minHeight: 90 }}>
          <textarea
            value={note}
            onChange={e => setNote(e.target.value)}
            placeholder="Add context for the next conversation…"
            style={{
              width: '100%', minHeight: 60, border: 'none', outline: 'none', resize: 'none',
              background: 'transparent', fontFamily: EVA.font, fontSize: 13.5, color: EVA.ink, lineHeight: 1.5,
            }}
          />
          <div style={{ display: 'flex', gap: 6, marginTop: 8, flexWrap: 'wrap' }}>
            {tags.map(t => (
              <button key={t} onClick={() => setTags(tags.filter(x => x !== t))} style={resetBtn({
                padding: '4px 9px', borderRadius: 8, fontSize: 11, fontWeight: 600,
                background: EVA.chip, color: EVA.body,
                display: 'inline-flex', alignItems: 'center', gap: 4,
              })}>
                {t} <Icon name="close" size={9} color="currentColor" />
              </button>
            ))}
            <button onClick={() => {
              const opts = ['Met at booth', 'Requested deck', 'Bring colleague'].filter(t => !tags.includes(t));
              if (opts.length) setTags([...tags, opts[0]]);
            }} style={resetBtn({
              padding: '4px 9px', borderRadius: 8, fontSize: 11, fontWeight: 600,
              background: 'transparent', color: EVA.muted,
              border: '1px dashed ' + EVA.hairline,
            })}>+ Add tag</button>
          </div>
        </div>
      </div>

      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, padding: '14px 20px 32px', background: '#fff', borderTop: '1px solid ' + EVA.hairline }}>
        <Button kind="primary" size="lg" icon="check" full onClick={save}>Save update</Button>
      </div>
    </div>
  );
}

function channelLabel(k) { return { mail: 'Email', phone: 'Call', whats: 'WhatsApp' }[k]; }
function whenLabel(k) { return { tomorrow: 'Tomorrow · 10 AM', threedays: 'in 3 days', nextweek: 'May 26 · 10 AM', custom: 'Custom' }[k]; }

// ─── LMS — MANAGEMENT VIEW ────────────────────────────────────────
function ScreenLMS({ nav, state }) {
  const [view, setView] = React.useState('team'); // team | status
  const total = state.leads.length;

  // Status counts
  const statusBreakdown = [
    { k: 'new',       l: 'New',        n: state.leads.filter(l => l.status === 'new').length,       c: EVA.info },
    { k: 'contacted', l: 'Contacted',  n: state.leads.filter(l => l.status === 'contacted').length, c: '#7B3DC4' },
    { k: 'followup',  l: 'Follow-up',  n: state.leads.filter(l => l.status === 'followup').length,  c: EVA.warn },
    { k: 'converted', l: 'Converted',  n: state.leads.filter(l => l.status === 'converted').length, c: EVA.green },
  ];
  const maxN = Math.max(1, ...statusBreakdown.map(s => s.n));

  // Team breakdown
  const byUser = TEAM.map(t => ({
    ...t,
    captured: state.leads.filter(l => l.capturedBy === t.id).length || t.captured,
  })).sort((a, b) => b.captured - a.captured);
  const maxUser = Math.max(1, ...byUser.map(t => t.captured));

  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="LMS">
      <AppBar
        left={null}
        title="LMS"
        sub="Management view"
        right={
          <button onClick={() => nav.toast('Filter: This event')} style={resetBtn({
            padding: '6px 10px', borderRadius: 10, background: EVA.chip,
            fontSize: 12, fontWeight: 600, color: EVA.body,
            display: 'flex', alignItems: 'center', gap: 5,
          })}>This event <Icon name="chevD" size={12} color={EVA.body} /></button>
        }
      />

      <div style={{ padding: '14px 20px 100px', height: 'calc(100% - 116px)', overflow: 'auto' }}>
        {/* Hero */}
        <div style={{ background: EVA.greenInk, color: '#fff', borderRadius: 18, padding: 18, position: 'relative', overflow: 'hidden', marginBottom: 16 }}>
          <div style={{ position: 'absolute', top: -30, right: -30, width: 140, height: 140, borderRadius: '50%', background: `radial-gradient(circle, ${EVA.green}55, transparent 70%)` }} />
          <div style={{ position: 'relative' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.55)', fontWeight: 600, letterSpacing: 0.6, textTransform: 'uppercase' }}>SaaStock Bengaluru</div>
              <div style={{ width: 6, height: 6, borderRadius: 3, background: EVA.green, boxShadow: `0 0 0 3px ${EVA.green}33` }} />
              <span style={{ fontSize: 10, color: EVA.green, fontWeight: 700, letterSpacing: 0.5, textTransform: 'uppercase' }}>Live</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 4 }}>
              <div style={{ fontSize: 36, fontWeight: 700, color: '#fff', letterSpacing: -1.2, fontFamily: EVA.fontDisplay }}>{total}</div>
              <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.7)' }}>total contacts captured</div>
            </div>
            <div style={{ display: 'flex', gap: 18, marginTop: 14 }}>
              <Stat v={String(state.leads.filter(l => /min|^[0-9]+ h/.test(l.capturedAt)).length)} l="Today" />
              <Divider />
              <Stat v={String(state.leads.filter(l => l.status === 'followup').length)} l="To follow up" />
              <Divider />
              <Stat v={String(state.leads.filter(l => l.status === 'converted').length)} l="Converted" />
            </div>
          </div>
        </div>

        {/* View switch */}
        <div style={{ display: 'flex', background: EVA.chip, borderRadius: 10, padding: 3, marginBottom: 14, gap: 3 }}>
          {[
            { k: 'team', l: 'By teammate' },
            { k: 'status', l: 'By status' },
          ].map(v => (
            <button key={v.k} onClick={() => setView(v.k)} style={resetBtn({
              flex: 1, padding: '8px 0', borderRadius: 8,
              background: view === v.k ? '#fff' : 'transparent',
              color: view === v.k ? EVA.ink : EVA.muted,
              fontSize: 12.5, fontWeight: 600,
              boxShadow: view === v.k ? '0 1px 2px rgba(0,0,0,0.04)' : 'none',
            })}>{v.l}</button>
          ))}
        </div>

        {view === 'team' ? (
          <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, overflow: 'hidden' }}>
            {byUser.map((t, i, a) => (
              <button key={t.id} onClick={() => nav.toast(`${t.name}: ${t.captured} captured`)} style={resetBtn({
                width: '100%', textAlign: 'left',
                padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
                borderBottom: i === a.length - 1 ? 'none' : '1px solid ' + EVA.hairline,
              })}>
                <div style={{ fontSize: 12, fontWeight: 700, color: EVA.muted, width: 16, textAlign: 'center', fontVariantNumeric: 'tabular-nums' }}>{i + 1}</div>
                <Avatar name={t.name} size={36} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <div style={{ fontSize: 13.5, fontWeight: 600, color: EVA.ink, letterSpacing: -0.1 }}>{t.name}</div>
                    {t.id === 'priya' && <span style={{ fontSize: 9.5, padding: '1px 5px', borderRadius: 4, background: EVA.greenSoft, color: EVA.greenDeep, fontWeight: 700, letterSpacing: 0.3 }}>YOU</span>}
                  </div>
                  <div style={{ fontSize: 11, color: EVA.muted, marginTop: 1 }}>{t.role} · {t.region}</div>
                  <div style={{ height: 4, background: EVA.chip, borderRadius: 2, marginTop: 6, overflow: 'hidden' }}>
                    <div style={{ width: (t.captured / maxUser * 100) + '%', height: '100%', background: t.id === 'priya' ? EVA.green : EVA.body, borderRadius: 2 }} />
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: 15, fontWeight: 700, color: EVA.ink, fontVariantNumeric: 'tabular-nums' }}>{t.captured}</div>
                  <div style={{ fontSize: 10, color: EVA.greenDeep, fontWeight: 600 }}>+{t.todayDelta} today</div>
                </div>
              </button>
            ))}
          </div>
        ) : (
          <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, padding: '14px 14px 10px' }}>
            {statusBreakdown.map((s, i) => (
              <button key={s.k} onClick={() => nav.toast(`${s.l}: ${s.n} contacts`)} style={resetBtn({
                width: '100%', textAlign: 'left',
                marginBottom: i === statusBreakdown.length - 1 ? 0 : 12,
              })}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 5 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ width: 8, height: 8, borderRadius: 4, background: s.c }} />
                    <span style={{ fontSize: 13, fontWeight: 600, color: EVA.ink }}>{s.l}</span>
                  </div>
                  <div style={{ fontSize: 13, fontWeight: 700, color: EVA.ink, fontVariantNumeric: 'tabular-nums' }}>{s.n}</div>
                </div>
                <div style={{ height: 8, background: EVA.chip, borderRadius: 4, overflow: 'hidden' }}>
                  <div style={{ width: (s.n / maxN * 100) + '%', height: '100%', background: s.c, borderRadius: 4, transition: 'width 320ms' }} />
                </div>
              </button>
            ))}
          </div>
        )}

        {/* Daily recap card */}
        <button onClick={() => nav.go('recap')} style={resetBtn({
          width: '100%', marginTop: 16,
          background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline,
          padding: '14px 14px', display: 'flex', alignItems: 'center', gap: 12, textAlign: 'left',
        })}>
          <div style={{ width: 36, height: 36, borderRadius: 12, background: EVA.greenSoft, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="calendar" size={18} color={EVA.greenDeep} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13.5, fontWeight: 700, color: EVA.ink }}>Daily event recap</div>
            <div style={{ fontSize: 11.5, color: EVA.muted, marginTop: 1 }}>Wrap of today's captures, sent at 6 PM</div>
          </div>
          <Icon name="chevR" size={16} color={EVA.muted} />
        </button>

        {/* Top scored leads */}
        <div style={{ marginTop: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: EVA.ink, letterSpacing: -0.1, display: 'flex', alignItems: 'center', gap: 6 }}>
              <Icon name="star" size={14} color={EVA.greenDeep} /> Top scored leads
            </div>
            <button onClick={() => nav.go('leadList')} style={resetBtn({ fontSize: 11.5, color: EVA.green, fontWeight: 600 })}>See all →</button>
          </div>
          <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, overflow: 'hidden' }}>
            {[...state.leads]
              .filter(l => typeof l.score === 'number')
              .sort((a, b) => b.score - a.score)
              .slice(0, 3)
              .map((l, i, a) => (
                <button key={l.id} onClick={() => nav.openLead(l.id)} style={resetBtn({
                  width: '100%', textAlign: 'left',
                  padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
                  borderBottom: i === a.length - 1 ? 'none' : '1px solid ' + EVA.hairline,
                })}>
                  <div style={{ width: 22, height: 22, borderRadius: 11, background: i === 0 ? EVA.green : EVA.chip, color: i === 0 ? '#fff' : EVA.body, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 800, fontVariantNumeric: 'tabular-nums' }}>{i + 1}</div>
                  <Avatar name={l.name} size={34} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13.5, fontWeight: 600, color: EVA.ink }}>{l.name}</div>
                    <div style={{ fontSize: 11, color: EVA.muted, marginTop: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{l.company}</div>
                  </div>
                  <ScorePill score={l.score} size="sm" />
                </button>
              ))}
          </div>
        </div>

        {/* Upcoming reminders */}
        <div style={{ marginTop: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: EVA.ink, letterSpacing: -0.1, display: 'flex', alignItems: 'center', gap: 6 }}>
              <Icon name="clock" size={14} color={EVA.warn} /> Upcoming reminders
            </div>
            <span style={{ fontSize: 11, color: EVA.muted }}>Next 3 scheduled</span>
          </div>
          <UpcomingReminders nav={nav} state={state} />
        </div>

        <div style={{ height: 30 }} />
      </div>

      <TabBar active="lms" nav={nav} />
    </div>
  );
}

function Stat({ v, l }) {
  return <div><div style={{ fontSize: 18, fontWeight: 700, color: '#fff' }}>{v}</div><div style={{ fontSize: 10.5, color: 'rgba(255,255,255,0.55)' }}>{l}</div></div>;
}
function Divider() {
  return <div style={{ width: 1, background: 'rgba(255,255,255,0.1)' }} />;
}

// Sub-component used in LMS: list of upcoming reminders with Mark done.
function UpcomingReminders({ nav, state }) {
  const [done, setDone] = React.useState({});
  const upcoming = state.leads
    .filter(l => l.followUp && !l.followUp.overdue)
    .sort((a, b) => (a.followUp.daysFromNow ?? 99) - (b.followUp.daysFromNow ?? 99))
    .slice(0, 3);
  if (!upcoming.length) {
    return (
      <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, padding: 18, textAlign: 'center', fontSize: 12, color: EVA.muted }}>
        Nothing scheduled — you're all caught up.
      </div>
    );
  }
  return (
    <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, overflow: 'hidden' }}>
      {upcoming.map((l, i, a) => {
        const isDone = !!done[l.id];
        const days = l.followUp.daysFromNow;
        const whenLabel = days === 0 ? 'Today' : days === 1 ? 'Tomorrow' : `in ${days} days`;
        return (
          <div key={l.id} style={{
            padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
            borderBottom: i === a.length - 1 ? 'none' : '1px solid ' + EVA.hairline,
            opacity: isDone ? 0.5 : 1,
          }}>
            <div style={{
              width: 36, height: 36, borderRadius: 11,
              background: isDone ? EVA.greenSoft : EVA.warnSoft,
              display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
            }}>
              <Icon name={isDone ? 'check' : 'clock'} size={16} color={isDone ? EVA.greenDeep : EVA.warn} stroke={2.2} />
            </div>
            <button onClick={() => nav.openLead(l.id)} style={resetBtn({ flex: 1, textAlign: 'left', minWidth: 0 })}>
              <div style={{ fontSize: 13, fontWeight: 600, color: EVA.ink, textDecoration: isDone ? 'line-through' : 'none' }}>{l.name}</div>
              <div style={{ fontSize: 11, color: EVA.muted, marginTop: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {l.followUp.suggested} · {l.followUp.date} · <span style={{ color: EVA.warn, fontWeight: 600 }}>{whenLabel}</span>
              </div>
            </button>
            <button onClick={() => {
              if (isDone) return;
              setDone(d => ({ ...d, [l.id]: true }));
              nav.toast(`Marked '${l.followUp.suggested}' done`);
            }} style={resetBtn({
              padding: '6px 10px', borderRadius: 8,
              background: isDone ? EVA.greenSoft : EVA.chip,
              fontSize: 11, fontWeight: 700,
              color: isDone ? EVA.greenDeep : EVA.body,
              display: 'inline-flex', alignItems: 'center', gap: 4,
              flexShrink: 0,
            })}>
              {isDone ? <><Icon name="check" size={10} color={EVA.greenDeep} stroke={3} /> Done</> : 'Mark done'}
            </button>
          </div>
        );
      })}
    </div>
  );
}

// ─── DAILY EVENT RECAP ────────────────────────────────────────────
function ScreenRecap({ nav, state }) {
  const today = state.leads.filter(l => /min|^[0-9]+ h|^Just/.test(l.capturedAt));
  const byStatus = ['new', 'contacted', 'followup'].map(k => ({
    k, n: today.filter(l => l.status === k).length,
  }));
  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="Recap">
      <AppBar
        left={<button onClick={() => nav.back()} style={resetBtn({})}><Icon name="chevL" size={22} color={EVA.ink} /></button>}
        title="Today's recap"
        sub="SaaStock Bengaluru · Day 2"
        right={
          <button onClick={() => nav.toast('Recap shared with team')} style={resetBtn({
            padding: '6px 10px', borderRadius: 10, background: EVA.chip,
            fontSize: 12, fontWeight: 600, color: EVA.body,
            display: 'flex', alignItems: 'center', gap: 5,
          })}><Icon name="download" size={12} color={EVA.body} /> Share</button>
        }
      />

      <div style={{ padding: '14px 20px 40px', height: 'calc(100% - 116px)', overflow: 'auto' }}>
        {/* Hero */}
        <div style={{
          background: 'linear-gradient(135deg, ' + EVA.greenInk + ' 0%, #1a3520 100%)',
          color: '#fff', borderRadius: 18, padding: 18, position: 'relative', overflow: 'hidden', marginBottom: 18,
        }}>
          <div style={{ position: 'absolute', top: -30, right: -30, width: 160, height: 160, borderRadius: '50%', background: `radial-gradient(circle, ${EVA.green}55, transparent 70%)` }} />
          <div style={{ position: 'relative' }}>
            <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.55)', fontWeight: 600, letterSpacing: 0.6, textTransform: 'uppercase' }}>Tue · May 19, 2026</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 4 }}>
              <div style={{ fontSize: 44, fontWeight: 700, color: '#fff', letterSpacing: -1.4, fontFamily: EVA.fontDisplay }}>{today.length}</div>
              <div style={{ fontSize: 14, color: 'rgba(255,255,255,0.75)' }}>cards captured today</div>
            </div>
            <div style={{ display: 'flex', gap: 14, marginTop: 14 }}>
              {byStatus.map(s => (
                <div key={s.k}>
                  <div style={{ fontSize: 16, fontWeight: 700, color: '#fff' }}>{s.n}</div>
                  <div style={{ fontSize: 10.5, color: 'rgba(255,255,255,0.55)', textTransform: 'capitalize' }}>{s.k === 'followup' ? 'Follow-up' : s.k}</div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Captured today list */}
        <div style={{ fontSize: 13, fontWeight: 700, color: EVA.ink, marginBottom: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          Captured today
          <span style={{ fontSize: 11, color: EVA.muted, fontWeight: 500 }}>{today.length} of {state.leads.length}</span>
        </div>
        <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, overflow: 'hidden', marginBottom: 18 }}>
          {today.length === 0 ? (
            <EmptyState icon="calendar" title="No captures yet today" sub="Tap Scan to capture your first card of the day." ctaLabel="Scan a card" onCta={() => nav.go('scan')} compact />
          ) : today.map((l, i, a) => (
            <button key={l.id} onClick={() => nav.openLead(l.id)} style={resetBtn({
              width: '100%', textAlign: 'left',
              padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
              borderBottom: i === a.length - 1 ? 'none' : '1px solid ' + EVA.hairline,
            })}>
              <Avatar name={l.name} size={36} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13.5, fontWeight: 600, color: EVA.ink }}>{l.name}</div>
                <div style={{ fontSize: 11.5, color: EVA.muted, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginTop: 1 }}>{l.role} · {l.company}</div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 3 }}>
                <Status kind={l.status} size="sm" />
                <div style={{ fontSize: 10, color: EVA.muted }}>{l.capturedAt}</div>
              </div>
            </button>
          ))}
        </div>

        {/* Reminders due */}
        <div style={{ fontSize: 13, fontWeight: 700, color: EVA.ink, marginBottom: 10 }}>Reminders set today</div>
        <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, overflow: 'hidden', marginBottom: 18 }}>
          {state.leads.filter(l => l.reminder).slice(0, 3).map((l, i, a) => (
            <button key={l.id} onClick={() => nav.openLead(l.id)} style={resetBtn({
              width: '100%', textAlign: 'left',
              padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
              borderBottom: i === a.length - 1 ? 'none' : '1px solid ' + EVA.hairline,
            })}>
              <div style={{ width: 32, height: 32, borderRadius: 10, background: EVA.warnSoft, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="clock" size={15} color={EVA.warn} stroke={2} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: EVA.ink }}>{l.reminder?.label}</div>
                <div style={{ fontSize: 11.5, color: EVA.muted, marginTop: 1 }}>{l.name} · {l.reminder?.when}</div>
              </div>
              <Icon name="chevR" size={14} color={EVA.muted} />
            </button>
          ))}
        </div>

        <Button kind="primary" size="lg" icon="scan" full onClick={() => nav.go('scan')}>Keep scanning</Button>
        <div style={{ height: 20 }} />
      </div>
    </div>
  );
}

// ─── PROFILE ──────────────────────────────────────────────────────
function ScreenProfile({ nav, state }) {
  return (
    <div style={{ width: '100%', height: '100%', background: EVA.canvas, fontFamily: EVA.font, position: 'relative', overflow: 'hidden' }} data-screen-label="Profile">
      <AppBar left={null} title="Account" sub="AskEva Internal" right={null} />

      <div style={{ padding: '14px 20px 100px', height: 'calc(100% - 116px)', overflow: 'auto' }}>
        <div style={{ background: '#fff', borderRadius: 16, padding: 18, border: '1px solid ' + EVA.hairline, display: 'flex', alignItems: 'center', gap: 14, marginBottom: 14 }}>
          <Avatar name="Priya Rao" size={56} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 700, color: EVA.ink, letterSpacing: -0.2 }}>Priya Rao</div>
            <div style={{ fontSize: 12, color: EVA.muted, marginTop: 2 }}>Account Executive · Bengaluru</div>
            <div style={{ fontSize: 11.5, color: EVA.muted, marginTop: 1 }}>priya.rao@askeva.io</div>
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 16 }}>
          <div style={{ background: '#fff', borderRadius: 14, padding: 14, border: '1px solid ' + EVA.hairline }}>
            <div style={{ fontSize: 24, fontWeight: 700, color: EVA.green, letterSpacing: -0.6, fontFamily: EVA.fontDisplay }}>{state.leads.filter(l => l.capturedBy === 'priya').length}</div>
            <div style={{ fontSize: 11, color: EVA.muted, fontWeight: 500, marginTop: 2 }}>Cards captured</div>
          </div>
          <div style={{ background: '#fff', borderRadius: 14, padding: 14, border: '1px solid ' + EVA.hairline }}>
            <div style={{ fontSize: 24, fontWeight: 700, color: EVA.ink, letterSpacing: -0.6, fontFamily: EVA.fontDisplay }}>3</div>
            <div style={{ fontSize: 11, color: EVA.muted, fontWeight: 500, marginTop: 2 }}>Events attended</div>
          </div>
        </div>

        <SectionLabel>Active event</SectionLabel>
        <button onClick={() => nav.toast('Event picker')} style={resetBtn({ width: '100%', background: '#fff', borderRadius: 14, padding: 14, border: '1px solid ' + EVA.hairline, display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16, textAlign: 'left' })}>
          <div style={{ width: 36, height: 36, borderRadius: 10, background: EVA.greenSoft, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="target" size={18} color={EVA.greenDeep} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13.5, fontWeight: 600, color: EVA.ink }}>SaaStock Bengaluru</div>
            <div style={{ fontSize: 11.5, color: EVA.muted, marginTop: 1 }}>Day 2 · live</div>
          </div>
          <Icon name="chevR" size={16} color={EVA.muted} />
        </button>

        <SectionLabel>Sync &amp; storage</SectionLabel>
        <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, padding: '14px 14px', marginBottom: 16, display: 'flex', alignItems: 'center', gap: 12 }}>
          <SyncBadge sync={state.sync} onSync={() => nav.runSync()} />
          <div style={{ flex: 1, fontSize: 11.5, color: EVA.muted, lineHeight: 1.4 }}>
            Records live on your device first, then sync to the Lead page.
          </div>
        </div>

        <SectionLabel>Settings</SectionLabel>
        <div style={{ background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline, overflow: 'hidden', marginBottom: 16 }}>
          {[
            { i: 'spark',    l: 'Auto-capture',     v: 'On' },
            { i: 'eye',      l: 'Biometric unlock', v: 'Face ID' },
            { i: 'mail',     l: 'Email signature',  v: 'Default' },
            { i: 'settings', l: 'Privacy & data',   v: '' },
          ].map((r, i, a) => (
            <button key={r.l} onClick={() => nav.toast(`${r.l} settings`)} style={resetBtn({
              width: '100%', textAlign: 'left',
              padding: '14px 14px', display: 'flex', alignItems: 'center', gap: 12,
              borderBottom: i === a.length - 1 ? 'none' : '1px solid ' + EVA.hairline,
            })}>
              <Icon name={r.i} size={18} color={EVA.body} />
              <div style={{ flex: 1, fontSize: 13.5, fontWeight: 500, color: EVA.ink }}>{r.l}</div>
              {r.v && <div style={{ fontSize: 12, color: EVA.muted }}>{r.v}</div>}
              <Icon name="chevR" size={14} color={EVA.muted} />
            </button>
          ))}
        </div>

        <button onClick={() => nav.go('login')} style={resetBtn({
          width: '100%', padding: '14px', textAlign: 'center',
          background: '#fff', borderRadius: 14, border: '1px solid ' + EVA.hairline,
          color: EVA.danger, fontSize: 13.5, fontWeight: 600,
        })}>Sign out</button>
      </div>

      <TabBar active="me" nav={nav} />
    </div>
  );
}

// ─── Shared bits ──────────────────────────────────────────────────
function SectionLabel({ children }) {
  return <div style={{ fontSize: 11.5, fontWeight: 700, color: EVA.muted, letterSpacing: 0.6, textTransform: 'uppercase', marginBottom: 10 }}>{children}</div>;
}

function EmptyState({ icon, title, sub, ctaLabel, onCta, compact }) {
  return (
    <div style={{ padding: compact ? '20px 10px' : '50px 20px', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', gap: 10 }}>
      <div style={{ width: 56, height: 56, borderRadius: 28, background: EVA.greenSoft, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 4 }}>
        <Icon name={icon} size={24} color={EVA.greenDeep} stroke={1.8} />
      </div>
      <div style={{ fontSize: 16, fontWeight: 700, color: EVA.ink, letterSpacing: -0.2 }}>{title}</div>
      <div style={{ fontSize: 13, color: EVA.muted, lineHeight: 1.5, maxWidth: 240 }}>{sub}</div>
      {ctaLabel && <Button kind="soft" size="md" onClick={onCta} style={{ marginTop: 6 }}>{ctaLabel}</Button>}
    </div>
  );
}

Object.assign(window, { ScreenLeadList, ScreenLeadDetail, ScreenStatusUpdate, ScreenLMS, ScreenRecap, ScreenProfile, SectionLabel, EmptyState });
