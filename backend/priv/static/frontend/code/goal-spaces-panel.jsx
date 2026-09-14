// Right sidebar: every Space that belongs to the selected Goal, with a
// progress indicator per implementation Space computed from its Room/Item
// pipeline — same done/total aggregation mail's PipelineTab already does,
// just reused here instead of rendering the full pipeline board.

const SpaceProgress = ({ space }) => {
  const [progress, setProgress] = React.useState(null); // null = loading

  React.useEffect(() => {
    let cancelled = false;
    window.API.rooms.list(space.id).then((rooms) =>
      Promise.all(rooms.map((r) => window.API.items.listForRoom(space.id, r.id))).then((itemLists) => {
        if (cancelled) return;
        const items = itemLists.flat();
        setProgress({ done: items.filter((it) => it.state === "done").length, total: items.length });
      })
    );
    return () => {
      cancelled = true;
    };
  }, [space.id]);

  if (progress === null) return null;

  if (progress.total === 0) {
    return <div className="goal-space-progress-empty">Inga aktiviteter ännu</div>;
  }

  const pct = Math.round((progress.done / progress.total) * 100);
  return (
    <div className="goal-space-progress">
      <div className="goal-space-progress-track">
        <div className="goal-space-progress-fill" style={{ width: pct + "%" }} />
      </div>
      <div className="goal-space-progress-label">{progress.done}/{progress.total} klart</div>
    </div>
  );
};

const GoalSpacesPanel = ({ goal }) => {
  if (!goal) {
    return (
      <aside className="goal-panel goal-panel--empty">
        <div className="goal-panel-empty-body">Välj eller sätt ett mål för att se dess spaces.</div>
      </aside>
    );
  }

  const planSpace = goal.spaces.find((sp) => sp.id === goal.planSpaceId);
  const implementationSpaces = goal.spaces.filter((sp) => sp.id !== goal.planSpaceId);

  return (
    <aside className="goal-panel">
      <div className="goal-panel-title">Spaces för målet</div>

      {planSpace && (
        <div className="goal-space-card goal-space-card--plan">
          <div className="goal-space-name">{planSpace.name}</div>
          <div className="goal-space-status">{planSpace.status === "done" ? "Plan klar" : "Planerar…"}</div>
        </div>
      )}

      {implementationSpaces.length === 0 ? (
        <div className="goal-panel-empty-body">Inga spaces skapade ännu — bekräfta planen i chatten.</div>
      ) : (
        implementationSpaces.map((sp) => (
          <div key={sp.id} className="goal-space-card">
            <div className="goal-space-name">{sp.name}</div>
            <div className="goal-space-subgoal">{sp.goal}</div>
            <SpaceProgress space={sp} />
          </div>
        ))
      )}
    </aside>
  );
};

window.GoalSpacesPanel = GoalSpacesPanel;
