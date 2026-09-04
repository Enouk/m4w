// Run-time view: Pipeline, Inbox (Live + Replay), Outbox.

const PipelineTab = ({ space, onOpenItem, onGoToDesign }) => {
  if (!space.rooms || space.rooms.length === 0) {
    return (
      <div className="design-empty">
        <div className="design-empty-mark">∅</div>
        <div className="design-empty-title">Pipeline saknas ännu</div>
        <div className="design-empty-body">
          Det här Spacet har inget mål eller Rooms genererade än. Gå till <em>Design</em> för att
          beskriva målet och skapa en pipeline.
        </div>
        <div className="design-actions" style={{ justifyContent: "center" }}>
          <button type="button" className="btn btn--accent" onClick={onGoToDesign}>
            Gå till Design
          </button>
        </div>
      </div>
    );
  }
  return (
    <div className="pipeline">
      <div className="pipeline-track">
        {space.rooms.map((room, idx) => (
          <React.Fragment key={room.id}>
            <div className="pipeline-room">
              <div className="room-head">
                <div className="room-name">{room.name}</div>
                <div className="room-subgoal">{room.subgoal}</div>
              </div>
              <div className="room-entity">
                <EntityTag entity={room.entity} />
              </div>
              <ul className="room-items">
                {room.items.slice(0, 3).map((it) => (
                  <li key={it.id}>
                    <button
                      type="button"
                      className="room-item"
                      onClick={() => onOpenItem({ room, item: it })}
                    >
                      <StateDot state={it.state} />
                      <div className="room-item-body">
                        <div className="room-item-title">{it.title}</div>
                        <div className="room-item-meta">{it.meta}</div>
                      </div>
                    </button>
                  </li>
                ))}
                {room.items.length > 3 && (
                  <li className="room-item-more">+{room.items.length - 3} fler</li>
                )}
                {room.items.length === 0 && (
                  <li className="room-item-empty">— inga ärenden</li>
                )}
              </ul>
              <div className="room-key">{room.key}</div>
            </div>
            {idx < space.rooms.length - 1 && <div className="pipeline-flow" aria-hidden="true" />}
          </React.Fragment>
        ))}
      </div>
    </div>
  );
};

const InboxTab = ({ space, onOpenMail }) => {
  const [inboxMode, setInboxMode] = React.useState("live");
  const [selected, setSelected] = React.useState(new Set());
  const [running, setRunning] = React.useState(false);
  const [revealed, setRevealed] = React.useState([]);

  const inbox = space.inbox.length
    ? space.inbox
    : [
        { from: "—", subject: "Inget inkommet ännu i detta Space.", date: "", room: "—", confidence: "high" }
      ];

  const toggleSelected = (i) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(i)) next.delete(i);
      else next.add(i);
      return next;
    });
  };

  const selectAll = () => {
    const batch = space.replayBatch || [];
    if (selected.size === batch.length) setSelected(new Set());
    else setSelected(new Set(batch.map((_, i) => i)));
  };

  const runReplay = () => {
    setRunning(true);
    setRevealed([]);
    const batch = (space.replayBatch || []).filter((_, i) => selected.has(i));
    let i = 0;
    const tick = () => {
      i += 1;
      setRevealed(batch.slice(0, i));
      if (i < batch.length) {
        setTimeout(tick, 280);
      } else {
        setRunning(false);
      }
    };
    setTimeout(tick, 250);
  };

  const resetReplay = () => {
    setRevealed([]);
    setSelected(new Set());
  };

  const replayBatch = space.replayBatch || [];
  const routed = revealed.filter((r) => !r.uncertain).length;
  const uncertain = revealed.filter((r) => r.uncertain).length;

  return (
    <div className="inbox">
      <div className="inbox-modeswitch">
        <LinkToggle
          options={[{ label: "Live", value: "live" }, { label: "Replay", value: "replay" }]}
          value={inboxMode}
          onChange={(v) => {
            setInboxMode(v);
            resetReplay();
          }}
        />
      </div>

      {inboxMode === "live" && (
        <ul className="inbox-list">
          {inbox.map((m, i) => (
            <li
              key={i}
              className="inbox-row"
              onClick={() => m.from !== "—" && onOpenMail && onOpenMail(m)}
              style={{ cursor: m.from !== "—" ? "pointer" : "default" }}
            >
              <div className="inbox-from">{m.from}</div>
              <div className="inbox-subject">{m.subject}</div>
              <div className="inbox-date">{m.date}</div>
              <div className="inbox-room">
                <span className="inbox-room-tag" data-confidence={m.confidence}>
                  {m.room}
                </span>
                {m.note && <span className="inbox-note">{m.note}</span>}
              </div>
            </li>
          ))}
        </ul>
      )}

      {inboxMode === "replay" && (
        <div className="replay">
          <div className="replay-banner">
            Replay-läge — inga mail skickas. Du tränar ditt Space.
          </div>

          <div className="replay-pick">
            <div className="replay-pick-head">
              <div className="replay-pick-title">Välj mail att köra mot ditt Space</div>
              <button
                type="button"
                className="link-btn"
                onClick={selectAll}
                disabled={running}
              >
                {selected.size === replayBatch.length ? "Avmarkera alla" : "Markera alla"}
              </button>
            </div>
            <ul className="replay-pick-list">
              {replayBatch.map((r, i) => (
                <li key={i}>
                  <label className="replay-pick-row">
                    <input
                      type="checkbox"
                      checked={selected.has(i)}
                      onChange={() => toggleSelected(i)}
                      disabled={running}
                    />
                    <span className="context-box" aria-hidden="true" />
                    <span className="replay-pick-from">{r.from}</span>
                    <span className="replay-pick-subject">{r.subject}</span>
                  </label>
                </li>
              ))}
            </ul>
            <div className="replay-actions">
              <button
                type="button"
                className="btn btn--accent"
                onClick={runReplay}
                disabled={running || selected.size === 0}
              >
                {running ? "Kör replay…" : `Kör replay (${selected.size})`}
              </button>
              {revealed.length > 0 && !running && (
                <button type="button" className="btn btn--ghost" onClick={resetReplay}>
                  Rensa resultat
                </button>
              )}
            </div>
          </div>

          {revealed.length > 0 && (
            <div className="replay-results">
              <div className="replay-results-head">Resultat</div>
              <ul className="replay-result-list">
                {revealed.map((r, i) => (
                  <li
                    key={i}
                    className={"replay-result-row" + (r.uncertain ? " is-uncertain" : "")}
                    style={{ animationDelay: `${i * 40}ms` }}
                  >
                    <div className="replay-result-from">{r.from}</div>
                    <div className="replay-result-subject">{r.subject}</div>
                    <div className="replay-result-room">
                      <span className="inbox-room-tag" data-confidence={r.uncertain ? "medium" : "high"}>
                        {r.room}
                      </span>
                      <span className="replay-conf">{r.confidence}% säker</span>
                      {r.key && <span className="replay-key">→ {r.key}</span>}
                    </div>
                    <button type="button" className="link-btn">Rätta</button>
                  </li>
                ))}
              </ul>

              {!running && (
                <div className="replay-summary">
                  <span><strong>{routed}</strong> av {revealed.length} routade enligt din historik</span>
                  <span className="dot-sep">·</span>
                  <span><strong>{uncertain}</strong> osäkra</span>
                  <span className="dot-sep">·</span>
                  <span><strong>0</strong> felrättade</span>
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

// Group passages by day-bucket inferred from the time prefix.
const groupPassages = (passages) => {
  const groups = [];
  const bucketOf = (time) => {
    if (/^igår/i.test(time)) return "Igår";
    if (/^\d{1,2}\s/.test(time)) return time.replace(/\s+\d{1,2}[:.]\d{2}.*$/, "").trim();
    return "Idag";
  };
  passages.forEach((p) => {
    const bucket = bucketOf(p.time);
    let g = groups.find((x) => x.bucket === bucket);
    if (!g) {
      g = { bucket, rows: [] };
      groups.push(g);
    }
    // strip the day prefix from the displayed time inside a dated bucket
    const shortTime = p.time.replace(/^igår\s*/i, "").replace(/^\d{1,2}\s+\w+\s*/, "").trim() || p.time;
    g.rows.push({ ...p, shortTime });
  });
  return groups;
};

// Parse a freeform passage string into a structured shape so we can render
// room → room transitions graphically instead of as flat text.
const parsePassage = (text) => {
  const t = text.match(/^(.*?)\s+passerade\s+från\s+(.+?)\s+till\s+(.+)$/i);
  if (t) return { kind: "transition", subject: t[1].trim(), from: t[2].trim(), to: t[3].trim() };
  // single-room events: "… i/till <Room>" or terminal logs
  let tone = "neutral";
  if (/loggad|loggade|exporterad|bekräftad|klar|signerat/i.test(text)) tone = "done";
  else if (/skickad|skickat|påminnelse/i.test(text)) tone = "send";
  else if (/osäker|överskriden|avvikelse/i.test(text)) tone = "amber";
  const r = text.match(/\b(?:i|till)\s+([A-ZÅÄÖ][\wÅÄÖåäö-]+)\s*$/);
  return { kind: "event", text, tone, room: r ? r[1] : null };
};

const RoomChip = ({ name }) => <span className="room-chip">{name}</span>;

// ---------- Artifacts (shared) — documents the Space has produced ----------

const ARTIFACT_STATUS = {
  signerad: "Signerad", skickad: "Skickad", utkast: "Utkast", arkiverad: "Arkiverad",
  exporterad: "Exporterad", uppdaterad: "Uppdaterad", bekräftad: "Bekräftad", granskas: "Granskas"
};
const ARTIFACT_TONE = {
  signerad: "done", bekräftad: "done", exporterad: "done", arkiverad: "done",
  skickad: "send", uppdaterad: "send",
  utkast: "neutral", granskas: "amber"
};

const ArtifactsTab = ({ space }) => {
  const items = space.artifacts || [];
  return (
    <div className="artifacts-tab">
      <div className="meetings-intro">
        Dokument som detta Space har producerat — protokoll, exporter och rapporter. Varje artifact
        är kopplad till det Room som skapade den och arkiveras oföränderligt.
      </div>
      <ul className="artifact-grid">
        {items.map((a) => (
          <li key={a.id} className="artifact-card">
            <div className="artifact-top">
              <span className="artifact-ext" data-kind={a.kind}>{a.kind}</span>
              <RoomChip name={a.room} />
            </div>
            <div className="artifact-title">{a.title}</div>
            <div className="artifact-meta">
              <span className="artifact-status" data-tone={ARTIFACT_TONE[a.status] || "neutral"}>
                {ARTIFACT_STATUS[a.status] || a.status}
              </span>
              <span className="dot-sep">·</span>
              <span className="mono-sub">{a.date}</span>
            </div>
            <div className="artifact-foot">
              <span className="artifact-by">{a.by}</span>
              <span className="artifact-size mono-sub">{a.size}</span>
            </div>
          </li>
        ))}
        {items.length === 0 && <li className="decision-empty">Inga artifacts skapade ännu.</li>}
      </ul>
    </div>
  );
};

// ---------- Space-specific (Styrelsearbete): Möten + Beslut ----------

const MEETING_STATUS_LABEL = { planerat: "Planerat", genomfört: "Genomfört", pagar: "Pågår" };

const MeetingsTab = ({ space }) => {
  const meetings = space.meetings || [];
  return (
    <div className="meetings-tab">
      <div className="meetings-intro">
        Alla styrelsemöten i detta Space — närvaro och fattade beslut, sammanställt automatiskt från
        protokollen.
      </div>
      <ul className="meeting-list">
        {meetings.map((m) => {
          const present = m.attendees.filter((a) => a.present === true).length;
          const absent = m.attendees.filter((a) => a.present === false).length;
          const total = m.attendees.length;
          const decided = m.status === "genomfört";
          return (
            <li key={m.id} className="meeting-card">
              <div className="meeting-head">
                <div className="meeting-head-main">
                  <span className="meeting-status" data-status={m.status}>
                    {MEETING_STATUS_LABEL[m.status] || m.status}
                  </span>
                  <span className="meeting-title">{m.title}</span>
                </div>
                <div className="meeting-sub mono-sub">{m.location}</div>
              </div>

              <div className="meeting-cols">
                <div className="meeting-col">
                  <div className="meeting-col-label">
                    Närvaro
                    {decided && (
                      <span className="meeting-col-count">
                        {present} av {total}
                      </span>
                    )}
                  </div>
                  <ul className="attendee-list">
                    {m.attendees.map((a, i) => (
                      <li key={i} className="attendee-row" data-present={String(a.present)}>
                        <span className="attendee-mark" aria-hidden="true" />
                        <span className="attendee-name">{a.name}</span>
                        <span className="attendee-role">{a.role}</span>
                      </li>
                    ))}
                  </ul>
                  {decided && absent > 0 && (
                    <div className="attendee-foot">{absent} frånvarande</div>
                  )}
                </div>

                <div className="meeting-col">
                  <div className="meeting-col-label">
                    Beslut
                    {decided && <span className="meeting-col-count">{m.decisions.length}</span>}
                  </div>
                  {m.decisions.length ? (
                    <ul className="decision-list">
                      {m.decisions.map((d) => (
                        <li key={d.id} className="decision-row">
                          <div className="decision-text">{d.text}</div>
                          <div className="decision-meta">
                            <span className="decision-outcome" data-outcome={d.outcome}>
                              {d.outcome}
                            </span>
                            <span className="dot-sep">·</span>
                            <span className="decision-votes mono-sub">{d.votes}</span>
                          </div>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <div className="decision-empty">
                      {m.status === "planerat"
                        ? "Inga beslut än — mötet har inte hållits."
                        : "Inga beslut fattade."}
                    </div>
                  )}
                </div>
              </div>
            </li>
          );
        })}
      </ul>
    </div>
  );
};

const DecisionsTab = ({ space }) => {
  const meetings = (space.meetings || []).filter((m) => m.decisions.length);
  const all = [];
  meetings.forEach((m) =>
    m.decisions.forEach((d) => all.push({ ...d, meetingTitle: m.title, date: m.date }))
  );
  return (
    <div className="decisions-tab">
      <div className="meetings-intro">
        Beslutsregister — alla beslut som fattats, spårbara till mötet de togs på.
      </div>
      <ul className="register-list">
        {all.map((d, i) => (
          <li key={i} className="register-row">
            <div className="register-date mono-sub">{d.date}</div>
            <div className="register-node" aria-hidden="true">
              <span className="register-dot" data-outcome={d.outcome} />
            </div>
            <div className="register-body">
              <div className="register-text">{d.text}</div>
              <div className="register-meta">
                <span className="decision-outcome" data-outcome={d.outcome}>
                  {d.outcome}
                </span>
                <span className="dot-sep">·</span>
                <span className="mono-sub">{d.votes}</span>
                <span className="dot-sep">·</span>
                <span className="register-meeting">{d.meetingTitle}</span>
              </div>
            </div>
          </li>
        ))}
        {all.length === 0 && <li className="decision-empty">Inga beslut loggade ännu.</li>}
      </ul>
    </div>
  );
};

const PassagesTab = ({ space }) => {
  const groups = groupPassages(space.passages || []);
  const total = (space.passages || []).length;
  const transitions = (space.passages || []).filter((p) => /passerade/i.test(p.text)).length;
  return (
    <div className="passages-tab">
      <div className="passages-header">
        <div>
          <div className="passages-h-title">Passages</div>
          <div className="passages-intro">
            Varje gång ett ärende passerar en Door mellan två Rooms loggas en oföränderlig Passage.
          </div>
        </div>
        <div className="passages-stats">
          <div className="passages-stat">
            <span className="passages-stat-num">{total}</span>
            <span className="passages-stat-label">loggade</span>
          </div>
          <div className="passages-stat">
            <span className="passages-stat-num">{transitions}</span>
            <span className="passages-stat-label">transitioner</span>
          </div>
        </div>
      </div>

      <div className="passages-timeline">
        {groups.map((g) => (
          <div key={g.bucket} className="passages-group">
            <div className="passages-day">{g.bucket}</div>
            <ul className="passages-rows">
              {g.rows.map((p, i) => {
                const parsed = parsePassage(p.text);
                return (
                  <li key={i} className="passages-row" data-kind={parsed.kind} data-tone={parsed.tone || "transition"}>
                    <span className="passages-row-time">{p.shortTime}</span>
                    <span className="passages-row-node" aria-hidden="true">
                      <span className="passages-row-dot" />
                    </span>
                    <div className="passages-row-body">
                      {parsed.kind === "transition" ? (
                        <React.Fragment>
                          <div className="passages-transition">
                            <RoomChip name={parsed.from} />
                            <span className="passages-door" aria-hidden="true">
                              <span className="passages-door-line" />
                              <span className="passages-door-glyph">›</span>
                              <span className="passages-door-line" />
                            </span>
                            <RoomChip name={parsed.to} />
                          </div>
                          <div className="passages-subject">{parsed.subject}</div>
                        </React.Fragment>
                      ) : (
                        <div className="passages-event">
                          <span className="passages-event-text">{parsed.text}</span>
                          {parsed.room && <RoomChip name={parsed.room} />}
                        </div>
                      )}
                    </div>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
        {groups.length === 0 && (
          <div className="passages-empty">Inga passages loggade ännu.</div>
        )}
      </div>
    </div>
  );
};

const OutboxTab = ({ space }) => {
  const [tab, setTab] = React.useState("queued");
  const [, force] = React.useReducer((n) => n + 1, 0);
  const ob = space.outbox || { queued: [], sent: [] };

  const approve = (idx) => window.API.outbox.approve(space.id, idx).then(force);
  const cancel = (idx) => window.API.outbox.cancel(space.id, idx).then(force);

  return (
    <div className="outbox">
      <div className="outbox-intro">
        Här ser du allt som skickas från detta Space innan det går ut.
      </div>

      <div className="outbox-tabs">
        <LinkToggle
          options={[
            { label: `Köade (${ob.queued.length})`, value: "queued" },
            { label: `Skickade (${ob.sent.length})`, value: "sent" }
          ]}
          value={tab}
          onChange={setTab}
        />
      </div>

      {tab === "queued" && (
        <ul className="queued-list">
          {ob.queued.map((q, i) => (
            <li key={i} className="queued-card">
              <div className="queued-meta">
                <span className="queued-from">från {q.from}</span>
                <span className="dot-sep">·</span>
                <span className="queued-status" data-status={q.status}>
                  {q.status}
                </span>
              </div>
              <div className="queued-to">till {q.to}</div>
              <div className="queued-subject">{q.subject}</div>
              <div className="queued-preview">{q.preview}</div>
              <div className="queued-actions">
                <button type="button" className="btn btn--small btn--accent" onClick={() => approve(i)}>Godkänn</button>
                <button type="button" className="btn btn--small btn--ghost">Redigera</button>
                <button type="button" className="btn btn--small btn--ghost" onClick={() => cancel(i)}>Avbryt</button>
              </div>
            </li>
          ))}
          {ob.queued.length === 0 && (
            <li className="queued-empty">Inga köade meddelanden just nu.</li>
          )}
        </ul>
      )}

      {tab === "sent" && (
        <ul className="sent-list">
          {ob.sent.map((s, i) => (
            <li key={i} className="sent-row">
              <div className="sent-time">{s.time}</div>
              <div className="sent-body">
                <div className="sent-subject">{s.subject}</div>
                <div className="sent-meta">
                  <span>från {s.from}</span>
                  <span className="dot-sep">·</span>
                  <span>till {s.to}</span>
                  <span className="dot-sep">·</span>
                  <a className="sent-link" href="#">{s.passage}</a>
                </div>
              </div>
            </li>
          ))}
          {ob.sent.length === 0 && (
            <li className="queued-empty">Inget skickat ännu.</li>
          )}
        </ul>
      )}
    </div>
  );
};

// ---------- Space-specific (Bokföring): Efterlevnad + Verifikationer ----------

const COMPLIANCE_STATUS_LABEL = { uppfyllt: "Uppfyllt", avvikelse: "Avvikelse", pagar: "Pågår" };

const ComplianceTab = ({ space }) => {
  const items = space.compliance || [];
  const met = items.filter((c) => c.status === "uppfyllt").length;
  const dev = items.filter((c) => c.status === "avvikelse").length;
  return (
    <div className="compliance-tab">
      <div className="compliance-head">
        <div>
          <div className="passages-h-title">Efterlevnad</div>
          <div className="meetings-intro">
            En giltig bokföring måste uppfylla bokföringslagens krav. M4W bevakar varje krav löpande
            mot flödet i detta Space.
          </div>
        </div>
        <div className="compliance-score" data-clean={String(dev === 0)}>
          <span className="compliance-score-num">{met} / {items.length}</span>
          <span className="compliance-score-label">
            krav uppfyllda{dev > 0 ? ` · ${dev} avvikelse` : ""}
          </span>
        </div>
      </div>

      <ul className="compliance-list">
        {items.map((c) => (
          <li key={c.id} className="compliance-card" data-status={c.status}>
            <span className="compliance-mark" aria-hidden="true" />
            <div className="compliance-body">
              <div className="compliance-title-row">
                <span className="compliance-title">{c.title}</span>
                <span className="compliance-ref mono-sub">{c.ref}</span>
              </div>
              <div className="compliance-desc">{c.desc}</div>
              <div className="compliance-state">
                <span className="compliance-status" data-status={c.status}>
                  {COMPLIANCE_STATUS_LABEL[c.status]}
                </span>
                <span className="compliance-state-text">{c.state}</span>
              </div>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
};

const VER_STATUS_LABEL = { bokförd: "Bokförd", exporterad: "Exporterad", avvikelse: "Avvikelse" };

const VerificationsTab = ({ space }) => {
  const list = space.verifications || [];
  return (
    <div className="decisions-tab">
      <div className="meetings-intro">
        Verifikationsregister — varje bokförd post styrks av en verifikation, spårbar genom flödet
        och arkiverad i minst sju år.
      </div>
      <div className="ver-table">
        <div className="ver-row ver-row--head">
          <span>Verifikation</span>
          <span>Datum</span>
          <span>Motpart</span>
          <span className="ver-amount">Belopp</span>
          <span>Status</span>
          <span>Spårbarhet</span>
          <span>Arkiverad</span>
        </div>
        {list.map((v) => (
          <div key={v.ver} className="ver-row" data-status={v.status}>
            <span className="ver-num mono-sub">{v.ver}</span>
            <span className="ver-date">{v.date}</span>
            <span className="ver-supplier">{v.supplier}</span>
            <span className="ver-amount">{v.amount}</span>
            <span>
              <span className="ver-status" data-status={v.status}>{VER_STATUS_LABEL[v.status]}</span>
            </span>
            <span className="ver-trace">
              <RoomChip name={v.trace.split(" → ")[0]} />
              <span className="ver-trace-arrow" aria-hidden="true">›</span>
              <RoomChip name={v.trace.split(" → ")[1]} />
            </span>
            <span className="ver-archive mono-sub">{v.archive}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

const RunView = ({ space, tab, onSetTab, onOpenItem, onOpenMail, onGoToDesign }) => {
  const spaceTabs = space.spaceTabs || [];
  const spaceTabValues = spaceTabs.map((t) => t.value);
  const commonValues = ["inbox", "pipeline", "passages", "artifacts", "outbox", "kontakter"];
  // Guard: if a space-specific tab is active but this Space doesn't offer it, fall back.
  const effectiveTab =
    !commonValues.includes(tab) && !spaceTabValues.includes(tab) ? "pipeline" : tab;

  return (
    <div className="run-view">
      {spaceTabs.length > 0 && (
        <div className="space-tabs">
          <span className="space-tabs-label">{space.name}</span>
          <LinkToggle options={spaceTabs} value={effectiveTab} onChange={onSetTab} />
        </div>
      )}

      <div className="run-tabs">
        <LinkToggle
          options={[
            { label: "Inbox", value: "inbox" },
            { label: "Pipeline", value: "pipeline" },
            { label: "Passages", value: "passages" },
            { label: "Artifacts", value: "artifacts" },
            { label: "Outbox", value: "outbox" },
            { label: "Kontakter", value: "kontakter" }
          ]}
          value={effectiveTab}
          onChange={onSetTab}
        />
      </div>

      {effectiveTab === "moten" && <MeetingsTab space={space} />}
      {effectiveTab === "beslut" && <DecisionsTab space={space} />}
      {effectiveTab === "efterlevnad" && <ComplianceTab space={space} />}
      {effectiveTab === "verifikationer" && <VerificationsTab space={space} />}
      {effectiveTab === "pipeline" && (
        <PipelineTab space={space} onOpenItem={onOpenItem} onGoToDesign={onGoToDesign} />
      )}
      {effectiveTab === "passages" && <PassagesTab space={space} />}
      {effectiveTab === "artifacts" && <ArtifactsTab space={space} />}
      {effectiveTab === "inbox" && <InboxTab space={space} onOpenMail={onOpenMail} />}
      {effectiveTab === "outbox" && <OutboxTab space={space} />}
      {effectiveTab === "kontakter" && <ContactsTab space={space} />}
    </div>
  );
};

window.RunView = RunView;
