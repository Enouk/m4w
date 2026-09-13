// Processer: global process map across all Spaces, built directly on each
// Space's pipeline (Rooms). Gives an org-wide view of every process, its
// steps, who/what owns each step, and the gating condition between them —
// the artifact you'd hand an ISO/compliance auditor to show the flow is
// documented and traceable, not tribal knowledge.

const ProcessStep = ({ room, isLast, onOpen }) => (
  <React.Fragment>
    <button type="button" className="procmap-step" onClick={onOpen}>
      <div className="procmap-step-top">
        <span className="procmap-step-name">{room.name}</span>
        <span className="procmap-step-count">{room.itemCount}</span>
      </div>
      <EntityTag entity={room.entity} />
      <div className="procmap-step-subgoal">{room.subgoal}</div>
      <div className="procmap-step-key">{room.key}</div>
    </button>
    {!isLast && (
      <span className="procmap-step-arrow" aria-hidden="true">›</span>
    )}
  </React.Fragment>
);

const ProcessCard = ({ space, onOpen }) => {
  const rooms = space.rooms || [];
  const aiCount = rooms.filter((r) => r.entity.kind === "ai").length;
  const humanCount = rooms.filter((r) => r.entity.kind !== "ai").length;

  return (
    <li className="procmap-card">
      <div className="procmap-card-head">
        <div className="procmap-card-title-row">
          <span className="procmap-card-name">{space.name}</span>
          <span className="mono-sub procmap-card-address">{space.address}</span>
        </div>
        {space.goal && <div className="procmap-card-goal">{space.goal}</div>}
      </div>

      {rooms.length > 0 ? (
        <React.Fragment>
          <div className="procmap-steps">
            {rooms.map((room, idx) => (
              <ProcessStep
                key={room.id}
                room={room}
                isLast={idx === rooms.length - 1}
                onOpen={() => onOpen(space.id)}
              />
            ))}
          </div>
          <div className="procmap-card-foot">
            <span>{rooms.length} steg</span>
            <span className="dot-sep">·</span>
            <span>{aiCount} AI-drivna</span>
            <span className="dot-sep">·</span>
            <span>{humanCount} med mänsklig inblandning</span>
            <button type="button" className="link-btn procmap-card-open" onClick={() => onOpen(space.id)}>
              Öppna pipeline →
            </button>
          </div>
        </React.Fragment>
      ) : (
        <div className="procmap-card-empty">
          Inga steg definierade ännu — gå till Design för att bygga ut pipelinen.
        </div>
      )}
    </li>
  );
};

const ProcessesView = ({ onOpenSpace }) => {
  const [list, setList] = React.useState(null);

  React.useEffect(() => {
    window.API.processes.list().then(setList);
  }, []);

  if (list === null) return null;

  const allRooms = list.flatMap((sp) => sp.rooms || []);
  const aiRooms = allRooms.filter((r) => r.entity.kind === "ai").length;
  const humanRooms = allRooms.filter((r) => r.entity.kind !== "ai").length;

  return (
    <div className="gcontacts-view procmap-view">
      <div className="gcontacts-head">
        <div className="gcontacts-title">Processer</div>
        <div className="gcontacts-sub">
          Alla processer i din organisation, med varje steg, ägare och villkoret som öppnar nästa
          steg — en processkarta som gör det tydligt vad som sker, och redo att visa upp vid en
          ISO- eller efterlevnadsrevision.
        </div>
      </div>

      <div className="passages-stats procmap-stats">
        <div className="passages-stat">
          <span className="passages-stat-num">{list.length}</span>
          <span className="passages-stat-label">processer</span>
        </div>
        <div className="passages-stat">
          <span className="passages-stat-num">{allRooms.length}</span>
          <span className="passages-stat-label">steg totalt</span>
        </div>
        <div className="passages-stat">
          <span className="passages-stat-num">{aiRooms}</span>
          <span className="passages-stat-label">AI-drivna</span>
        </div>
        <div className="passages-stat">
          <span className="passages-stat-num">{humanRooms}</span>
          <span className="passages-stat-label">mänsklig inblandning</span>
        </div>
      </div>

      <ul className="procmap-list">
        {list.map((sp) => (
          <ProcessCard key={sp.id} space={sp} onOpen={onOpenSpace} />
        ))}
        {list.length === 0 && (
          <li className="gcontacts-empty">Inga processer ännu — skapa ett space för att komma igång.</li>
        )}
      </ul>
    </div>
  );
};

window.ProcessesView = ProcessesView;
