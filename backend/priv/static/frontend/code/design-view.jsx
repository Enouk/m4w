// Design-time view: goal prompt + generated rooms.

const isPersistedId = (id) => /^\d+$/.test(String(id));

const DesignView = React.forwardRef(({ space, onSaveToRun }, ref) => {
  const [goal, setGoal] = React.useState(space.goal);
  const [rooms, setRooms] = React.useState(null); // null = loading
  const [originalRooms, setOriginalRooms] = React.useState([]);
  const [generating, setGenerating] = React.useState(false);
  const [saving, setSaving] = React.useState(false);
  const [revealCount, setRevealCount] = React.useState(0);

  React.useEffect(() => {
    window.API.rooms.list(space.id).then((list) => {
      setRooms(list);
      setOriginalRooms(list);
      setRevealCount(list.length);
    });
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

  // Diffs the edited draft (add/remove/edit Rooms) against what's actually
  // persisted and upserts via the regular Room CRUD endpoints. Skips the
  // round-trip entirely if nothing changed since load/last save.
  const persistRooms = () => {
    if (!rooms || rooms.length === 0) return Promise.resolve();
    if (JSON.stringify(rooms) === JSON.stringify(originalRooms)) return Promise.resolve();

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

    return Promise.all([...deletions, ...upserts]);
  };

  // Exposed so the Space header's Design/Karta toggle (app.jsx) can flush an
  // unsaved generated draft before leaving Design — otherwise switching to
  // Karta without clicking "Spara och växla till Karta" silently discards it.
  React.useImperativeHandle(ref, () => ({ flushPendingChanges: persistRooms }));

  const saveToRun = () => {
    setSaving(true);
    persistRooms().then(() => {
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

  if (rooms === null) return null;

  const visibleRooms = rooms.slice(0, revealCount);
  const hasRooms = visibleRooms.length > 0;

  return (
    <div className="design-view">
      <div className="design-main">
        <section className="design-block">
          <div className="design-block-label">Mål</div>
          <textarea
            className="goal-input"
            value={goal}
            onChange={(e) => setGoal(e.target.value)}
            onBlur={() => {
              if (goal !== space.goal) window.API.spaces.update(space.id, { goal });
            }}
            placeholder="Beskriv vad detta Space ska göra. Exempel: Bygg en digital klocka med HTML/CSS/JS, från krav till publicering."
            rows={4}
          />
          <div className="design-actions">
            <button
              type="button"
              className="btn btn--accent"
              onClick={generate}
              disabled={generating}
            >
              {generating ? "Genererar…" : hasRooms ? "Regenerera från mål" : "Generera Space"}
            </button>
            {hasRooms && (
              <button type="button" className="btn btn--ghost" onClick={saveToRun} disabled={saving}>
                {saving ? "Sparar…" : "Spara och växla till Karta"}
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
              Skriv ett mål ovan och klicka <em>Generera Space</em>.
            </div>
          </section>
        )}
      </div>
    </div>
  );
});

window.DesignView = DesignView;
