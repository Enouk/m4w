// Design-time view: address, goal prompt, generated rooms, mail context panel.

const isPersistedId = (id) => /^\d+$/.test(String(id));

const DesignView = ({ space, onSaveToRun }) => {
  const [goal, setGoal] = React.useState(space.goal);
  const [rooms, setRooms] = React.useState(null); // null = loading
  const [originalRooms, setOriginalRooms] = React.useState([]);
  const [generating, setGenerating] = React.useState(false);
  const [saving, setSaving] = React.useState(false);
  const [revealCount, setRevealCount] = React.useState(0);
  const [mails, setMails] = React.useState([]);

  React.useEffect(() => {
    window.API.rooms.list(space.id).then((list) => {
      setRooms(list);
      setOriginalRooms(list);
      setRevealCount(list.length);
    });
    window.API.contextMails.list(space.id).then(setMails);
  }, [space.id]);

  const generate = () => {
    setGenerating(true);
    window.API.spaces.generate(space.id).then((generatedRooms) => {
      setRooms(generatedRooms);
      setRevealCount(0);
      let i = 0;
      const tick = () => {
        i += 1;
        setRevealCount(i);
        if (i < generatedRooms.length) {
          setTimeout(tick, 320);
        } else {
          setGenerating(false);
        }
      };
      setTimeout(tick, 220);
    });
  };

  // Commits the edited draft (add/remove/edit Rooms) back to the Space via
  // the API — diffed against what's actually persisted — then switches to Kör.
  const saveToRun = () => {
    setSaving(true);
    const keptIds = new Set(rooms.filter((r) => isPersistedId(r.id)).map((r) => r.id));
    const deletions = originalRooms
      .filter((r) => !keptIds.has(r.id))
      .map((r) => window.API.rooms.delete(space.id, r.id));

    const upserts = rooms.map((r, idx) => {
      const payload = { name: r.name, subgoal: r.subgoal, key: r.key, entity: r.entity, order: idx };
      return isPersistedId(r.id)
        ? window.API.rooms.update(space.id, r.id, payload)
        : window.API.rooms.create(space.id, payload);
    });

    Promise.all([...deletions, ...upserts]).then(() => {
      setSaving(false);
      onSaveToRun();
    });
  };

  const updateRoom = (idx, patch) => {
    setRooms((rs) => rs.map((r, i) => (i === idx ? { ...r, ...patch } : r)));
  };
  const removeRoom = (idx) => {
    setRooms((rs) => rs.filter((_, i) => i !== idx));
    setRevealCount((c) => Math.max(0, c - 1));
  };
  const addRoom = () => {
    setRooms((rs) => [
      ...rs,
      {
        id: "new-" + Date.now(),
        name: "Nytt Room",
        entity: { kind: "ai", label: "AI" },
        subgoal: "Beskriv delmålet…",
        key: "öppnar när…"
      }
    ]);
    setRevealCount((c) => c + 1);
  };

  const toggleMail = (idx) => {
    const m = mails[idx];
    const next = !m.use;
    window.API.contextMails.update(space.id, m.id, { use: next }).then(() => {
      setMails((ms) => ms.map((mm, i) => (i === idx ? { ...mm, use: next } : mm)));
    });
  };

  if (rooms === null) return null;

  const visibleRooms = rooms.slice(0, revealCount);
  const hasRooms = visibleRooms.length > 0;

  return (
    <div className="design-view">
      <div className="design-main">
        <section className="design-block">
          <div className="design-block-label">Spacets mailadress</div>
          <CopyAddress address={space.address} />
          <div className="design-hint">
            Vidarebefordra mail hit så använder AI:n dem för att förstå ditt flöde.
          </div>
        </section>

        <section className="design-block">
          <div className="design-block-label">Mål</div>
          <textarea
            className="goal-input"
            value={goal}
            onChange={(e) => setGoal(e.target.value)}
            onBlur={() => {
              if (goal !== space.goal) window.API.spaces.update(space.id, { goal });
            }}
            placeholder="Beskriv vad detta Space ska göra. Exempel: Driv styrelsearbete från kallelse till protokoll med full spårbarhet av beslut."
            rows={4}
          />
          <div className="design-actions">
            <button
              type="button"
              className="btn btn--accent"
              onClick={generate}
              disabled={generating}
            >
              {generating ? "Genererar…" : hasRooms ? "Regenerera från mål och valda mail" : "Generera Space"}
            </button>
            {hasRooms && (
              <button type="button" className="btn btn--ghost" onClick={saveToRun} disabled={saving}>
                {saving ? "Sparar…" : "Spara och växla till Kör"}
              </button>
            )}
          </div>
        </section>

        {hasRooms ? (
          <section className="design-block">
            <div className="design-block-label">Struktur · {visibleRooms.length} Rooms</div>
            <ul className="room-edit-list">
              {visibleRooms.map((r, idx) => (
                <li key={r.id} className="room-edit" style={{ animationDelay: `${idx * 40}ms` }}>
                  <div className="room-edit-handle" aria-hidden="true">⋮⋮</div>
                  <div className="room-edit-body">
                    <input
                      className="room-edit-name"
                      value={r.name}
                      onChange={(e) => updateRoom(idx, { name: e.target.value })}
                    />
                    <input
                      className="room-edit-field"
                      value={r.subgoal}
                      onChange={(e) => updateRoom(idx, { subgoal: e.target.value })}
                      placeholder="Sub-goal"
                    />
                    <div className="room-edit-grid">
                      <input
                        className="room-edit-field"
                        value={r.entity.label}
                        onChange={(e) =>
                          updateRoom(idx, { entity: { ...r.entity, label: e.target.value } })
                        }
                        placeholder="Entity"
                      />
                      <input
                        className="room-edit-field"
                        value={r.key}
                        onChange={(e) => updateRoom(idx, { key: e.target.value })}
                        placeholder="Key — villkor som öppnar nästa Room"
                      />
                    </div>
                  </div>
                  <button
                    type="button"
                    className="room-edit-remove"
                    onClick={() => removeRoom(idx)}
                    aria-label="Ta bort"
                  >
                    ×
                  </button>
                </li>
              ))}
            </ul>
            <button type="button" className="room-add" onClick={addRoom}>
              + lägg till Room
            </button>
          </section>
        ) : (
          <section className="design-empty">
            <div className="design-empty-mark">∅</div>
            <div className="design-empty-title">Inget genererat ännu</div>
            <div className="design-empty-body">
              Skriv ett mål ovan och klicka <em>Generera Space</em>. AI:n läser också mailen du
              vidarebefordrat till adressen för att förstå hur arbetet ser ut.
            </div>
          </section>
        )}
      </div>

      <aside className="design-context">
        <div className="design-context-head">
          <div className="design-context-title">Mail som kontext</div>
          <div className="design-context-sub">
            Vidarebefordrade till <span className="mono-sub">{space.address}</span>
          </div>
        </div>
        {mails.length === 0 ? (
          <div className="context-empty">
            Inga mail forwardade än. AI:n genererar enbart från målet ovan.
          </div>
        ) : (
          <ul className="context-list">
            {mails.map((m, i) => (
              <li key={m.id} className={"context-item" + (!m.use ? " is-off" : "")}>
                <label className="context-check">
                  <input
                    type="checkbox"
                    checked={m.use}
                    onChange={() => toggleMail(i)}
                  />
                  <span className="context-box" aria-hidden="true" />
                </label>
                <div className="context-body">
                  <div className="context-from">{m.from}</div>
                  <div className="context-subject">{m.subject}</div>
                  <div className="context-date">{window.formatDateTime(m.date)}</div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </aside>
    </div>
  );
};

window.DesignView = DesignView;
