// Left sidebar: brand, GOALS list, account. Mirrors mail/sidebar.jsx's
// structure and CSS classes, but lists Goals instead of Spaces (no
// category grouping — Goals aren't categorized).

const AccountMenu = ({ user, onLogout }) => {
  const [open, setOpen] = React.useState(false);
  const ref = React.useRef(null);

  React.useEffect(() => {
    if (!open) return;
    const onDocClick = (e) => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, [open]);

  return (
    <div className="account-menu" ref={ref}>
      {open && (
        <div className="account-popover">
          <div className="account-popover-email mono-sub">{user.email}</div>
          <button type="button" className="account-popover-item" onClick={onLogout}>
            Logga ut
          </button>
        </div>
      )}
      <button
        type="button"
        className={"account-row" + (open ? " is-open" : "")}
        onClick={() => setOpen((o) => !o)}
      >
        <span className="account-avatar">{user.initials}</span>
        <span className="account-meta">
          <span className="account-name">{user.name}</span>
          <span className="account-org">{user.org || "Ingen organisation"}</span>
        </span>
      </button>
    </div>
  );
};

const Sidebar = ({ user, goals, selectedGoalId, onSelectGoal, onNewGoal, onDeleteGoal, onLogout }) => {
  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <C4WLogo />
      </div>

      <div className="sidebar-section">
        <div className="sidebar-section-label">Mål</div>
        <ul className="sidebar-list">
          {goals.map((g) => {
            const active = selectedGoalId === g.id;
            return (
              <li key={g.id}>
                <div className="sidebar-item-row">
                  <button
                    type="button"
                    className={"sidebar-item" + (active ? " is-active" : "")}
                    onClick={() => onSelectGoal(g.id)}
                  >
                    <span className="sidebar-item-name">{g.title}</span>
                  </button>
                  <button
                    type="button"
                    className="sidebar-item-delete"
                    onClick={(e) => {
                      e.stopPropagation();
                      onDeleteGoal(g.id, g.title);
                    }}
                    aria-label={"Ta bort " + g.title}
                    title={"Ta bort " + g.title}
                  >
                    ×
                  </button>
                </div>
              </li>
            );
          })}
        </ul>
        <button type="button" className="sidebar-add-btn" onClick={onNewGoal}>
          <span className="sidebar-add-glyph" aria-hidden="true">+</span>
          Nytt mål
        </button>
      </div>

      <div className="sidebar-push" />

      <AccountMenu user={user} onLogout={onLogout} />
    </aside>
  );
};

window.Sidebar = Sidebar;
