// Global Inbox: every mail that has arrived across the user's Spaces — both
// routed (already placed in a Room) and unrouted ("Att klassificera"). This
// is the overview; "Att klassificera" stays as the dedicated triage queue.

const GlobalInboxRow = ({ m, spaceName, roomName, onOpenMail }) => (
  <li className="ginbox-row" onClick={() => onOpenMail(m)}>
    <div className="ginbox-main">
      <div className="ginbox-from">{m.from}</div>
      <div className="ginbox-subject">{m.subject}</div>
    </div>
    <div className="ginbox-date mono-sub">{window.formatDateTime(m.date)}</div>
    <div className="ginbox-target">
      <span className="room-chip">{spaceName}</span>
      <span className="ginbox-target-arrow" aria-hidden="true">›</span>
      <span className="inbox-room-tag" data-confidence={m.confidence}>{roomName}</span>
    </div>
  </li>
);

const GlobalUnroutedRow = ({ m, spaces, onAssign, onOpenMail }) => (
  <li className="classify-row">
    <div className="classify-row-main" onClick={() => onOpenMail(m)} style={{ cursor: "pointer" }}>
      <div className="classify-from">{m.from}</div>
      <div className="classify-subject">{m.subject}</div>
      <div className="classify-meta">
        <span>{window.formatDateTime(m.date)}</span>
        <span className="dot-sep">·</span>
        <span className="classify-reason">{m.reason}</span>
      </div>
    </div>
    <div className="classify-actions">
      <div className="classify-actions-label">Tilldela till</div>
      <div className="classify-buttons">
        {spaces.map((sp) => (
          <button
            key={sp.id}
            type="button"
            className="btn btn--small btn--ghost"
            onClick={() => onAssign(m.id, sp.id)}
          >
            {sp.name}
          </button>
        ))}
        <button
          type="button"
          className="btn btn--small btn--muted"
          onClick={() => onAssign(m.id, null)}
        >
          Ingen process
        </button>
      </div>
    </div>
  </li>
);

const GlobalInboxView = ({ spacesById, roomsById, onOpenMail, onCountsChanged }) => {
  const [routed, setRouted] = React.useState(null);
  const [unclassified, setUnclassified] = React.useState(null);
  const [filter, setFilter] = React.useState("all"); // all | routed | unrouted
  const [query, setQuery] = React.useState("");

  const load = () =>
    window.API.globalInbox.get().then((res) => {
      setRouted(res.routed);
      setUnclassified(res.unclassified);
    });

  React.useEffect(() => { load(); }, []);

  if (routed === null) return null;

  const assign = (mailId, spaceId) =>
    window.API.unclassified.assign(mailId, spaceId).then(() => {
      load();
      onCountsChanged();
    });

  const openRoutedMail = (m) => {
    const sp = spacesById[m.spaceId];
    onOpenMail({ ...m, spaceName: sp && sp.name, spaceAddress: sp && sp.address });
  };

  const q = query.trim().toLowerCase();
  const matches = (from, subject) =>
    !q || from.toLowerCase().includes(q) || subject.toLowerCase().includes(q);

  const routedFiltered = routed.filter((m) => matches(m.from, m.subject));
  const unroutedFiltered = unclassified.filter((m) => matches(m.from, m.subject));

  const showRouted = filter !== "unrouted";
  const showUnrouted = filter !== "routed";
  const total = routed.length + unclassified.length;
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
              <GlobalUnroutedRow
                key={m.id}
                m={m}
                spaces={Object.values(spacesById)}
                onAssign={assign}
                onOpenMail={onOpenMail}
              />
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
            {routedFiltered.map((m) => (
              <GlobalInboxRow
                key={m.id}
                m={m}
                spaceName={(spacesById[m.spaceId] || {}).name}
                roomName={(roomsById[m.roomId] || {}).name}
                onOpenMail={openRoutedMail}
              />
            ))}
          </ul>
        </section>
      )}
    </div>
  );
};

window.GlobalInboxView = GlobalInboxView;
