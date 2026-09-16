// SpaceMapView: a pannable/zoomable path through a Space's Rooms — the
// game-like "step inside the space" view. Rooms are laid out in pipeline
// order (Room.position) connected by corridors, since M4w.Ops.RoomBlueprintSchema
// deliberately keeps the Room graph a flat ordered list (no branching door
// graph) — this is a level-map read of that same linear pipeline, not a
// free-roam grid.
//
// Each Room shows its Entities (the AI/human "NPCs" working there) as
// AgentIcons whose state ring reflects M4w.Ops.Entity.state (idle/working/
// done), polled every 4s to match M4w.Ops.AgentRunner's own cadence. New
// Passages (Item moving room -> room) trigger a short "token" animation
// along the corridor between the two rooms.

const clamp = (n, min, max) => Math.min(max, Math.max(min, n));

const AiGlyph = () => (
  <React.Fragment>
    <rect x="6" y="9" width="12" height="10" rx="2.5" />
    <line x1="12" y1="9" x2="12" y2="5" />
    <circle cx="12" cy="4" r="1.4" />
    <circle cx="9.4" cy="14" r="1.1" />
    <circle cx="14.6" cy="14" r="1.1" />
  </React.Fragment>
);

const HumanGlyph = () => (
  <React.Fragment>
    <circle cx="12" cy="8.5" r="3.6" />
    <path d="M4.5 19.5c0-4.1 3.4-7.5 7.5-7.5s7.5 3.4 7.5 7.5" />
  </React.Fragment>
);

const AgentIcon = ({ entity }) => (
  <div
    className="agent-icon"
    data-kind={entity.kind}
    data-state={entity.state}
    title={`${entity.name}${entity.agentType ? " · " + entity.agentType : ""} — ${entity.state}`}
  >
    {entity.state === "working" && <span className="agent-icon-pulse" aria-hidden="true" />}
    <svg className="agent-icon-glyph" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {entity.kind === "ai" ? <AiGlyph /> : <HumanGlyph />}
    </svg>
    {entity.state === "done" && <span className="agent-icon-check" aria-hidden="true">✓</span>}
  </div>
);

const RoomNode = ({ room, isOpen, onOpen }) => (
  <button type="button" className={"room-node" + (isOpen ? " is-open" : "")} onClick={() => onOpen(room)}>
    <div className="room-node-agents">
      {room.entities.length === 0 ? (
        <div className="room-node-agents-empty">Obemannat</div>
      ) : (
        room.entities.map((e) => <AgentIcon key={e.id} entity={e} />)
      )}
    </div>
    <div className="room-node-name">{room.name}</div>
    {room.subgoal && <div className="room-node-subgoal">{room.subgoal}</div>}
    {room.key && <div className="room-node-key">🔑 {room.key}</div>}
    <div className="room-node-count">{room.itemCount} {room.itemCount === 1 ? "ärende" : "ärenden"}</div>
  </button>
);

const MapCorridor = ({ traveling }) => (
  <div className="map-corridor" aria-hidden="true">
    <div className="map-corridor-line" />
    <span className="map-corridor-arrow">›</span>
    {traveling && <span className="map-token" />}
  </div>
);

const RoomDrawer = ({ spaceId, room, onClose }) => {
  const [items, setItems] = React.useState(null);

  React.useEffect(() => {
    let cancelled = false;
    setItems(null);
    window.API.items.listForRoom(spaceId, room.id).then((list) => {
      if (!cancelled) setItems(list);
    });
    return () => {
      cancelled = true;
    };
  }, [spaceId, room.id]);

  return (
    <aside className="room-drawer">
      <div className="room-drawer-head">
        <div>
          <div className="room-drawer-title">{room.name}</div>
          {room.subgoal && <div className="room-drawer-subgoal">{room.subgoal}</div>}
        </div>
        <button type="button" className="room-drawer-close" onClick={onClose} aria-label="Stäng">
          ×
        </button>
      </div>

      {room.key && <div className="room-drawer-key">🔑 Öppnar när: {room.key}</div>}

      <div className="room-drawer-agents">
        {room.entities.length === 0 ? (
          <div className="room-node-agents-empty">Inga agenter tilldelade det här rummet.</div>
        ) : (
          room.entities.map((e) => (
            <div key={e.id} className="room-drawer-agent">
              <AgentIcon entity={e} />
              <div>
                <div className="room-drawer-agent-name">{e.name}</div>
                <div className="room-drawer-agent-state">{e.state}</div>
              </div>
            </div>
          ))
        )}
      </div>

      <div className="room-drawer-items-label">Ärenden i rummet</div>
      {items === null ? (
        <div className="room-drawer-loading">Laddar…</div>
      ) : items.length === 0 ? (
        <div className="room-drawer-empty">Inga ärenden här just nu.</div>
      ) : (
        <ul className="room-drawer-items">
          {items.map((it) => (
            <li key={it.id} className="room-drawer-item">
              <StateDot state={it.state} />
              <span className="room-drawer-item-title">{it.title}</span>
            </li>
          ))}
        </ul>
      )}
    </aside>
  );
};

const SpaceMapView = ({ spaceId, spaceName, onBack, space, mode, onChangeMode, onModeSaved, designRef }) => {
  const [rooms, setRooms] = React.useState(null); // null = loading
  const [openRoomId, setOpenRoomId] = React.useState(null);
  const [travels, setTravels] = React.useState([]); // [{ fromRoomId, toRoomId }]
  const [view, setView] = React.useState({ x: 40, y: 40, scale: 1 });

  const viewportRef = React.useRef(null);
  const seenPassagesRef = React.useRef(null);
  const dragRef = React.useRef(null);

  React.useEffect(() => {
    if (mode !== "map") return;

    setRooms(null);
    setOpenRoomId(null);
    seenPassagesRef.current = null;
    setTravels([]);
    setView({ x: 40, y: 40, scale: 1 });

    let cancelled = false;

    const poll = () => {
      window.API.rooms.list(spaceId).then((list) => {
        if (!cancelled) setRooms(list);
      });
      window.API.passages.list(spaceId).then((list) => {
        if (cancelled) return;
        if (seenPassagesRef.current === null) {
          seenPassagesRef.current = new Set(list.map((p) => p.id));
          return;
        }
        const fresh = list.filter((p) => p.fromRoomId && p.toRoomId && !seenPassagesRef.current.has(p.id));
        fresh.forEach((p) => seenPassagesRef.current.add(p.id));
        if (fresh.length === 0) return;
        setTravels((t) => [...t, ...fresh]);
        fresh.forEach((p) => {
          setTimeout(() => {
            setTravels((t) => t.filter((x) => x.id !== p.id));
          }, 1500);
        });
      });
    };

    poll();
    const intervalId = setInterval(poll, 4000);
    return () => {
      cancelled = true;
      clearInterval(intervalId);
    };
  }, [spaceId, mode]);

  // React's synthetic onWheel is attached as a passive listener, so
  // e.preventDefault() there is silently ignored (and logs a console
  // warning) — bind a native, non-passive listener instead so wheel-zoom
  // doesn't also scroll the page.
  React.useEffect(() => {
    const node = viewportRef.current;
    if (!node) return;

    const onWheel = (e) => {
      e.preventDefault();
      const rect = node.getBoundingClientRect();
      const cx = e.clientX - rect.left;
      const cy = e.clientY - rect.top;
      setView((v) => {
        const nextScale = clamp(v.scale * (e.deltaY < 0 ? 1.1 : 0.9), 0.5, 2.2);
        const canvasX = (cx - v.x) / v.scale;
        const canvasY = (cy - v.y) / v.scale;
        return { x: cx - canvasX * nextScale, y: cy - canvasY * nextScale, scale: nextScale };
      });
    };

    node.addEventListener("wheel", onWheel, { passive: false });
    return () => node.removeEventListener("wheel", onWheel);
  }, [rooms !== null]);

  const onPointerDown = (e) => {
    if (e.target.closest(".room-node")) return;
    dragRef.current = { startX: e.clientX, startY: e.clientY, originX: view.x, originY: view.y };
    e.currentTarget.setPointerCapture(e.pointerId);
  };

  const onPointerMove = (e) => {
    const drag = dragRef.current;
    if (!drag) return;
    const dx = e.clientX - drag.startX;
    const dy = e.clientY - drag.startY;
    setView((v) => ({ ...v, x: drag.originX + dx, y: drag.originY + dy }));
  };

  const onPointerUp = () => {
    dragRef.current = null;
  };

  const openRoom = rooms && rooms.find((r) => r.id === openRoomId);

  return (
    <div className="space-map">
      <div className="space-map-head">
        <button type="button" className="link-btn" onClick={onBack}>
          ← Tillbaka till mål
        </button>
        <div className="space-map-title">{spaceName}</div>
        <div className="mode-toggle" style={{ marginLeft: "auto" }}>
          <LinkToggle
            options={[
              { label: "Design", value: "design" },
              { label: "Karta", value: "map" }
            ]}
            value={mode}
            onChange={onChangeMode}
          />
        </div>
      </div>

      {mode === "design" ? (
        <DesignView ref={designRef} key={space.id} space={space} onSaveToRun={() => onModeSaved("map")} />
      ) : rooms === null ? (
        <div className="space-map-loading">Laddar karta…</div>
      ) : rooms.length === 0 ? (
        <div className="space-map-empty">
          Inga rum designade för det här spacet ännu.
          <button type="button" className="link-btn" onClick={() => onChangeMode("design")} style={{ marginLeft: 8 }}>
            Designa rum →
          </button>
        </div>
      ) : (
        <div
          className="space-map-viewport"
          ref={viewportRef}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerLeave={onPointerUp}
        >
          <div
            className="space-map-canvas"
            style={{ transform: `translate(${view.x}px, ${view.y}px) scale(${view.scale})` }}
          >
            {rooms.map((room, idx) => {
              const next = rooms[idx + 1];
              const traveling = next && travels.some((t) => t.fromRoomId === room.id && t.toRoomId === next.id);
              return (
                <React.Fragment key={room.id}>
                  <RoomNode room={room} isOpen={room.id === openRoomId} onOpen={(r) => setOpenRoomId(r.id)} />
                  {next && <MapCorridor traveling={traveling} />}
                </React.Fragment>
              );
            })}
          </div>
        </div>
      )}

      {openRoom && <RoomDrawer spaceId={spaceId} room={openRoom} onClose={() => setOpenRoomId(null)} />}
    </div>
  );
};

window.SpaceMapView = SpaceMapView;
