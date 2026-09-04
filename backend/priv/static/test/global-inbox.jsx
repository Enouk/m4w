// Global Inbox: every mail that has arrived across the user's Spaces — both
// routed (already placed in a Room) and unrouted ("Att klassificera"). This
// is the overview; "Att klassificera" stays as the dedicated triage queue.
//
// Future: a "skicka test-mail" affordance will let users fire a synthetic
// mail at a Space's address to see how it routes — not built yet.

const GlobalInboxRow = ({ m, onOpenMail }) => (
  <li className="ginbox-row" onClick={() => onOpenMail(m)}>
    <div className="ginbox-main">
      <div className="ginbox-from">{m.from}</div>
      <div className="ginbox-subject">{m.subject}</div>
    </div>
    <div className="ginbox-date mono-sub">{m.date}</div>
    <div className="ginbox-target">
      <span className="room-chip">{m.spaceName}</span>
      <span className="ginbox-target-arrow" aria-hidden="true">›</span>
      <span className="inbox-room-tag" data-confidence={m.confidence}>{m.room}</span>
    </div>
  </li>
);

const GlobalUnroutedRow = ({ m, spaces, onAssign, onOpenMail }) => (
  <li className="classify-row">
    <div className="classify-row-main" onClick={() => onOpenMail(m)} style={{ cursor: "pointer" }}>
      <div className="classify-from">{m.from}</div>
      <div className="classify-subject">{m.subject}</div>
      <div className="classify-meta">
        <span>{m.date}</span>
        <span className="dot-sep">·</span>
        <span className="classify-reason">{m.reason}</span>
      </div>
    </div>
    <div className="classify-actions">
      <div className="classify-actions-label">Tilldela till</div>
      <div className="classify-buttons">
        {Object.values(spaces).map((sp) => (
          <button
            key={sp.id}
            type="button"
            className="btn btn--small btn--ghost"
            onClick={() => onAssign(m._idx, sp.id)}
          >
            {sp.name}
          </button>
        ))}
        <button
          type="button"
          className="btn btn--small btn--muted"
          onClick={() => onAssign(m._idx, null)}
        >
          Ingen process
        </button>
      </div>
    </div>
  </li>
);

const GlobalInboxView = ({ routedItems, unclassified, spaces, onAssign, onJump, onOpenMail }) => {
  const [filter, setFilter] = React.useState("all"); // all | routed | unrouted
  const [query, setQuery] = React.useState("");

  const q = query.trim().toLowerCase();
  const matches = (from, subject) =>
    !q || from.toLowerCase().includes(q) || subject.toLowerCase().includes(q);

  const unroutedIndexed = unclassified.map((m, i) => ({ ...m, _idx: i }));
  const routedFiltered = routedItems.filter((m) => matches(m.from, m.subject));
  const unroutedFiltered = unroutedIndexed.filter((m) => matches(m.from, m.subject));

  const showRouted = filter !== "unrouted";
  const showUnrouted = filter !== "routed";
  const total = routedItems.length + unclassified.length;
  const nothingToShow =
    (!showRouted || routedFiltered.length === 0) &&
    (!showUnrouted || unroutedFiltered.length === 0);

  return (
    <div className="ginbox-view">
      <div className="ginbox-head">
        <div className="ginbox-title">Inbox</div>
        <div className="ginbox-sub">
          Allt inkommet över dina Spaces — {total} mail totalt, {unclassified.length} väntar på
          klassificering.
        </div>
      </div>

      <div className="ginbox-controls">
        <input
          className="gcontacts-search"
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Sök avsändare eller ämne…"
        />
        <LinkToggle
          options={[
            { label: "Alla", value: "all" },
            { label: "Routade", value: "routed" },
            { label: "Oroutade", value: "unrouted" }
          ]}
          value={filter}
          onChange={setFilter}
        />
      </div>

      {nothingToShow && <div className="gcontacts-empty">Inga mail matchar din sökning.</div>}

      {showUnrouted && unroutedFiltered.length > 0 && (
        <section className="ginbox-section">
          <div className="contact-group-label">
            Oroutade <span className="contact-group-count">{unroutedFiltered.length}</span>
          </div>
          <ul className="classify-list">
            {unroutedFiltered.map((m) => (
              <GlobalUnroutedRow key={m._idx} m={m} spaces={spaces} onAssign={onAssign} onOpenMail={onOpenMail} />
            ))}
          </ul>
        </section>
      )}

      {showRouted && routedFiltered.length > 0 && (
        <section className="ginbox-section">
          <div className="contact-group-label">
            Routade <span className="contact-group-count">{routedFiltered.length}</span>
          </div>
          <ul className="ginbox-list">
            {routedFiltered.map((m, i) => (
              <GlobalInboxRow key={i} m={m} onOpenMail={onOpenMail} />
            ))}
          </ul>
        </section>
      )}
    </div>
  );
};

window.GlobalInboxView = GlobalInboxView;
