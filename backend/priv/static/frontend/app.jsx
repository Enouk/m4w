// App shell: auth + state machine + composition.

// Editable Space name + category, lives in the Space header (not the Sidebar).
const SpaceIdentity = ({ space, categories, onRename, onChangeCategory }) => {
  const [editingName, setEditingName] = React.useState(false);
  const [draftName, setDraftName] = React.useState(space.name);
  const [editingCategory, setEditingCategory] = React.useState(false);
  const inputRef = React.useRef(null);
  const categoryRef = React.useRef(null);

  React.useEffect(() => {
    if (!editingName) setDraftName(space.name);
  }, [space.name, space.id]);

  React.useEffect(() => {
    if (editingName && inputRef.current) {
      inputRef.current.focus();
      inputRef.current.select();
    }
  }, [editingName]);

  React.useEffect(() => {
    if (editingCategory && categoryRef.current) categoryRef.current.focus();
  }, [editingCategory]);

  const commit = () => {
    const trimmed = draftName.trim();
    setEditingName(false);
    if (trimmed && trimmed !== space.name) {
      onRename(trimmed);
    } else {
      setDraftName(space.name);
    }
  };

  return (
    <div className="space-title-row">
      {editingName ? (
        <input
          ref={inputRef}
          type="text"
          className="space-title-input"
          value={draftName}
          onChange={(e) => setDraftName(e.target.value)}
          onBlur={commit}
          onKeyDown={(e) => {
            if (e.key === "Enter") commit();
            if (e.key === "Escape") {
              setDraftName(space.name);
              setEditingName(false);
            }
          }}
        />
      ) : (
        <button
          type="button"
          className="space-title-edit"
          onClick={() => setEditingName(true)}
          title="Byt namn på space"
        >
          <h1 className="space-title">{space.name}</h1>
        </button>
      )}
      {editingCategory ? (
        <select
          ref={categoryRef}
          className="space-category-select"
          value={space.category || ""}
          onChange={(e) => {
            onChangeCategory(e.target.value);
            setEditingCategory(false);
          }}
          onBlur={() => setEditingCategory(false)}
          aria-label={"Kategori för " + space.name}
        >
          <option value="">Ingen kategori</option>
          {categories.map((c) => (
            <option key={c} value={c}>{c}</option>
          ))}
        </select>
      ) : (
        <button
          type="button"
          className="entity-tag space-category-tag"
          onClick={() => setEditingCategory(true)}
          title="Byt kategori"
        >
          {space.category || "Ingen kategori"}
        </button>
      )}
      <CopyAddress address={space.address} />
    </div>
  );
};

const App = () => {
  const [user, setUser] = React.useState(null);
  const [checkingSession, setCheckingSession] = React.useState(true);

  const [spaces, setSpaces] = React.useState([]);
  const [categories, setCategories] = React.useState([]);
  const [roomsById, setRoomsById] = React.useState({});
  const [inboxCount, setInboxCount] = React.useState(0);
  const [unclassifiedCount, setUnclassifiedCount] = React.useState(0);
  const [contactsCount, setContactsCount] = React.useState(0);

  const [selectedSpace, setSelectedSpace] = React.useState(null);
  const [viewMode, setViewMode] = React.useState("space"); // "space" | "classify" | "contacts" | "inbox" | "processes"
  const [modeBySpace, setModeBySpace] = React.useState({}); // per-space Design/Kör, defaults to "run"
  const [tabBySpace, setTabBySpace] = React.useState({}); // per-space Kör-tab, defaults to "pipeline"
  const [openItem, setOpenItem] = React.useState(null);
  const [openMail, setOpenMail] = React.useState(null);
  const [confirmDeleteSpace, setConfirmDeleteSpace] = React.useState(null); // { id, name }

  React.useEffect(() => {
    window.API.me
      .get()
      .then(setUser)
      .catch(() => setUser(null))
      .finally(() => setCheckingSession(false));
  }, []);

  const refreshSpaces = () => window.API.spaces.list().then(setSpaces);

  const refreshCounts = () => {
    window.API.globalInbox.get().then(({ routed, unclassified }) => {
      setInboxCount(routed.length + unclassified.length);
      setUnclassifiedCount(unclassified.length);
    });
    window.API.contacts.listGlobal().then((list) => setContactsCount(list.length));
  };

  React.useEffect(() => {
    if (!user) return;
    window.API.spaceCategories.list().then(setCategories);
    refreshSpaces();
    refreshCounts();
    setSelectedSpace((prev) => prev || (user.spaces.length ? user.spaces[0] : null));
  }, [user]);

  React.useEffect(() => {
    if (spaces.length === 0) {
      setRoomsById({});
      return;
    }
    Promise.all(spaces.map((sp) => window.API.rooms.list(sp.id))).then((lists) => {
      const map = {};
      lists.forEach((rs) => rs.forEach((r) => (map[r.id] = r)));
      setRoomsById(map);
    });
  }, [spaces]);

  const space = spaces.find((sp) => sp.id === selectedSpace) || null;
  const mode = (space && modeBySpace[space.id]) || "run";
  const tab = (space && tabBySpace[space.id]) || "pipeline";

  const setMode = (m) => setModeBySpace((p) => ({ ...p, [space.id]: m }));
  const setTab = (t) => setTabBySpace((p) => ({ ...p, [space.id]: t }));

  const selectSpace = (id) => {
    setSelectedSpace(id);
    setViewMode("space");
  };

  // Creates a fresh, empty Space (via the API) and drops the user straight
  // into Design mode so they can set a goal and generate its Rooms.
  const createSpace = (name, category) => {
    window.API.spaces.create({ name, category }).then((sp) => {
      refreshSpaces();
      refreshCounts();
      setSelectedSpace(sp.id);
      setModeBySpace((p) => ({ ...p, [sp.id]: "design" }));
      setViewMode("space");
    });
  };

  const setSpaceCategory = (id, category) => {
    window.API.spaces.update(id, { category: category || null }).then(refreshSpaces);
  };

  const renameSpace = (id, name) => {
    window.API.spaces.update(id, { name }).then(refreshSpaces);
  };

  const requestDeleteSpace = (id, name) => setConfirmDeleteSpace({ id, name });

  const deleteSpace = () => {
    const id = confirmDeleteSpace.id;
    window.API.spaces.delete(id).then(() => {
      setConfirmDeleteSpace(null);
      refreshSpaces();
      refreshCounts();
      if (selectedSpace === id) {
        const remaining = spaces.filter((sp) => sp.id !== id);
        setSelectedSpace(remaining[0] ? remaining[0].id : null);
        setViewMode(remaining[0] ? "space" : "inbox");
      }
    });
  };

  // Jump into a Space at a specific Kör-tab (used by the global Kontakter and
  // Inbox views to deep-link into a Space's scoped view).
  const jumpToSpace = (id, targetTab) => {
    setSelectedSpace(id);
    setModeBySpace((p) => ({ ...p, [id]: "run" }));
    setTabBySpace((p) => ({ ...p, [id]: targetTab || "kontakter" }));
    setViewMode("space");
  };

  const login = (email, password) =>
    window.API.auth.login(email, password).then(({ user: u }) => {
      setUser(u);
      setSelectedSpace(u.spaces[0] || null);
      setViewMode("space");
      setModeBySpace({});
      setTabBySpace({});
      setOpenItem(null);
      setOpenMail(null);
    });

  const logout = () => {
    window.API.auth.logout().finally(() => {
      setUser(null);
      setSpaces([]);
      setSelectedSpace(null);
    });
  };

  const openMailFromGlobal = (m) =>
    setOpenMail({ mail: m, spaceId: m.spaceId, spaceName: m.spaceName, spaceAddress: m.spaceAddress });

  if (checkingSession) return null;

  if (!user) {
    return <LoginView onLogin={login} />;
  }

  return (
    <div className="app">
      <Sidebar
        user={user}
        spaces={spaces}
        categories={categories}
        selectedSpace={selectedSpace}
        viewMode={viewMode}
        onSelectSpace={selectSpace}
        onCreateSpace={createSpace}
        onDeleteSpace={requestDeleteSpace}
        onSelectInbox={() => setViewMode("inbox")}
        onSelectClassify={() => setViewMode("classify")}
        onSelectContacts={() => setViewMode("contacts")}
        onSelectProcesses={() => setViewMode("processes")}
        onLogout={logout}
        inboxCount={inboxCount}
        unclassifiedCount={unclassifiedCount}
        contactsCount={contactsCount}
        processesCount={spaces.length}
      />

      <main className="main">
        {viewMode === "inbox" ? (
          <GlobalInboxView
            spacesById={Object.fromEntries(spaces.map((sp) => [sp.id, sp]))}
            roomsById={roomsById}
            onOpenMail={openMailFromGlobal}
            onCountsChanged={refreshCounts}
          />
        ) : viewMode === "classify" ? (
          <ClassifyView spaces={spaces} onCountsChanged={refreshCounts} />
        ) : viewMode === "contacts" ? (
          <ContactsGlobalView onJump={jumpToSpace} />
        ) : viewMode === "processes" ? (
          <ProcessesView onOpenSpace={(id) => jumpToSpace(id, "pipeline")} />
        ) : !space ? null : (
          <div className="space-view">
            <header className="space-head">
              <SpaceIdentity
                space={space}
                categories={categories}
                onRename={(name) => renameSpace(selectedSpace, name)}
                onChangeCategory={(cat) => setSpaceCategory(selectedSpace, cat)}
              />
              <div className="mode-toggle">
                <LinkToggle
                  options={[
                    { label: "Design", value: "design" },
                    { label: "Kör", value: "run" }
                  ]}
                  value={mode}
                  onChange={setMode}
                />
              </div>
            </header>

            <div className="space-body">
              {mode === "design" ? (
                <DesignView key={space.id} space={space} onSaveToRun={() => setMode("run")} />
              ) : (
                <RunView
                  key={space.id}
                  space={space}
                  tab={tab}
                  onSetTab={setTab}
                  onOpenItem={setOpenItem}
                  onOpenMail={(m) =>
                    setOpenMail({ mail: m, spaceId: space.id, spaceName: space.name, spaceAddress: space.address })
                  }
                  onGoToDesign={() => setMode("design")}
                />
              )}
            </div>
          </div>
        )}
      </main>

      <ItemModal open={openItem} onClose={() => setOpenItem(null)} />

      <MailModal
        open={openMail}
        onClose={() => setOpenMail(null)}
        onJump={(id) => jumpToSpace(id, "inbox")}
      />

      <ConfirmModal
        open={!!confirmDeleteSpace}
        title={confirmDeleteSpace ? `Ta bort "${confirmDeleteSpace.name}"?` : ""}
        body="Detta tar bort spacet och all dess data. Går inte att ångra."
        confirmLabel="Ta bort space"
        onConfirm={deleteSpace}
        onCancel={() => setConfirmDeleteSpace(null)}
      />
    </div>
  );
};

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(<App />);
