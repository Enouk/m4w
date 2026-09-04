// Left sidebar: SPACES list + ATT KLASSIFICERA + account.

// Groups space ids into ordered category buckets (SPACE_CATEGORIES order,
// uncategorized spaces last under "Övrigt"). Empty buckets are omitted.
function groupSpacesByCategory(spaceOrder, spaceCategories) {
  const order = [...window.SPACE_CATEGORIES, "Övrigt"];
  const buckets = new Map(order.map((c) => [c, []]));
  spaceOrder.forEach((id) => {
    const cat = spaceCategories[id];
    const key = cat && buckets.has(cat) ? cat : "Övrigt";
    buckets.get(key).push(id);
  });
  return order
    .map((category) => ({ category, ids: buckets.get(category) }))
    .filter((g) => g.ids.length > 0);
}

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

const NewSpaceControl = ({ onCreate }) => {
  const [adding, setAdding] = React.useState(false);
  const [name, setName] = React.useState("");
  const [category, setCategory] = React.useState("");
  const inputRef = React.useRef(null);

  React.useEffect(() => {
    if (adding && inputRef.current) inputRef.current.focus();
  }, [adding]);

  const cancel = () => {
    setAdding(false);
    setName("");
    setCategory("");
  };

  const submit = (e) => {
    e.preventDefault();
    const trimmed = name.trim();
    if (!trimmed) {
      cancel();
      return;
    }
    onCreate(trimmed, category);
    cancel();
  };

  if (!adding) {
    return (
      <button type="button" className="sidebar-add-btn" onClick={() => setAdding(true)}>
        <span className="sidebar-add-glyph" aria-hidden="true">+</span>
        Nytt space
      </button>
    );
  }

  return (
    <form className="sidebar-add-form" onSubmit={submit}>
      <input
        ref={inputRef}
        type="text"
        className="sidebar-add-input"
        value={name}
        onChange={(e) => setName(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Escape") cancel();
        }}
        placeholder="Namn på space…"
      />
      <select
        className="sidebar-add-category"
        value={category}
        onChange={(e) => setCategory(e.target.value)}
        onBlur={(e) => {
          if (!name.trim() && !e.relatedTarget) cancel();
        }}
      >
        <option value="">Ingen kategori</option>
        {window.SPACE_CATEGORIES.map((c) => (
          <option key={c} value={c}>{c}</option>
        ))}
      </select>
      <button type="submit" className="sidebar-add-submit">Skapa</button>
    </form>
  );
};

const Sidebar = ({
  user,
  spaceOrder,
  spaceCategories,
  selectedSpace,
  onSelectSpace,
  onCreateSpace,
  onDeleteSpace,
  viewMode,
  onSelectInbox,
  onSelectClassify,
  onSelectContacts,
  onSelectProcesses,
  onLogout,
  inboxCount,
  unclassifiedCount,
  contactsCount,
  processesCount
}) => {
  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <M4WLogo />
      </div>

      <div className="sidebar-section">
        <button
          type="button"
          className={"sidebar-item sidebar-item--ghost" + (viewMode === "inbox" ? " is-active" : "")}
          onClick={onSelectInbox}
        >
          <span className="sidebar-item-name">Inbox</span>
          <span className="sidebar-item-count">{inboxCount}</span>
        </button>
      </div>

      <div className="sidebar-section">
        <div className="sidebar-section-label">Spaces</div>
        {groupSpacesByCategory(spaceOrder, spaceCategories).map((group) => (
          <div key={group.category} className="sidebar-category-group">
            <div className="sidebar-category-label">{group.category}</div>
            <ul className="sidebar-list">
              {group.ids.map((id) => {
                const sp = window.SPACES[id];
                const active = viewMode === "space" && selectedSpace === id;
                return (
                  <li key={id}>
                    <div className="sidebar-item-row">
                      <button
                        type="button"
                        className={"sidebar-item" + (active ? " is-active" : "")}
                        onClick={() => onSelectSpace(id)}
                      >
                        <span className="sidebar-item-name">{sp.name}</span>
                        <span className="sidebar-item-count">{sp.activeCount}</span>
                      </button>
                      <button
                        type="button"
                        className="sidebar-item-delete"
                        onClick={(e) => {
                          e.stopPropagation();
                          onDeleteSpace(id, sp.name);
                        }}
                        aria-label={"Ta bort " + sp.name}
                        title={"Ta bort " + sp.name}
                      >
                        ×
                      </button>
                    </div>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
        <NewSpaceControl onCreate={onCreateSpace} />
      </div>

      <div className="sidebar-foot">
        <button
          type="button"
          className={"sidebar-item sidebar-item--ghost" + (viewMode === "processes" ? " is-active" : "")}
          onClick={onSelectProcesses}
        >
          <span className="sidebar-item-name">Processer</span>
          <span className="sidebar-item-count">{processesCount}</span>
        </button>
        <button
          type="button"
          className={"sidebar-item sidebar-item--ghost" + (viewMode === "contacts" ? " is-active" : "")}
          onClick={onSelectContacts}
        >
          <span className="sidebar-item-name">Kontakter</span>
          <span className="sidebar-item-count">{contactsCount}</span>
        </button>
        <button
          type="button"
          className={"sidebar-item sidebar-item--ghost" + (viewMode === "classify" ? " is-active" : "")}
          onClick={onSelectClassify}
        >
          <span className="sidebar-item-name">Att klassificera</span>
          <span className="sidebar-item-count">{unclassifiedCount}</span>
        </button>
      </div>

      <AccountMenu user={user} onLogout={onLogout} />
    </aside>
  );
};

window.Sidebar = Sidebar;

