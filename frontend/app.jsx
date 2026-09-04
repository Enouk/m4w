// App shell: auth + state machine + composition.

// Editable Space name + category, lives in the Space header (not the Sidebar).
const SpaceIdentity = ({ space, category, onRename, onChangeCategory }) => {
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
          value={category || ""}
          onChange={(e) => {
            onChangeCategory(e.target.value);
            setEditingCategory(false);
          }}
          onBlur={() => setEditingCategory(false)}
          aria-label={"Kategori för " + space.name}
        >
          <option value="">Ingen kategori</option>
          {window.SPACE_CATEGORIES.map((c) => (
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
          {category || "Ingen kategori"}
        </button>
      )}
      <CopyAddress address={space.address} />
    </div>
  );
};

const App = () => {
  const [userId, setUserId] = React.useState(() => localStorage.getItem("m4w_user_id"));
  const user = userId ? window.USERS[userId] : null;

  const [selectedSpace, setSelectedSpace] = React.useState(() => {
    const uid = localStorage.getItem("m4w_user_id");
    const u = uid ? window.USERS[uid] : null;
    return u ? u.spaces[0] : null;
  });
  const [viewMode, setViewMode] = React.useState("space"); // "space" | "classify" | "contacts" | "inbox" | "processes"
  const [modeBySpace, setModeBySpace] = React.useState({}); // per-space Design/Kör, defaults to "run"
  const [tabBySpace, setTabBySpace] = React.useState({}); // per-space Kör-tab, defaults to "pipeline"
  const [unclassified, setUnclassified] = React.useState(() => {
    const uid = localStorage.getItem("m4w_user_id");
    const u = uid ? window.USERS[uid] : null;
    return u && !u.org ? window.UNCLASSIFIED_SARA : window.UNCLASSIFIED;
  });
  const [openItem, setOpenItem] = React.useState(null);
  const [openMail, setOpenMail] = React.useState(null);
  const [extraSpaceIds, setExtraSpaceIds] = React.useState([]);
  const [removedSpaceIds, setRemovedSpaceIds] = React.useState([]);
  const [confirmDeleteSpace, setConfirmDeleteSpace] = React.useState(null); // { id, name }

  const spaceIds = user
    ? [...user.spaces, ...extraSpaceIds].filter((id) => !removedSpaceIds.includes(id))
    : [];
  const space = user && selectedSpace ? window.SPACES[selectedSpace] : null;
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
      setExtraSpaceIds((prev) => [...prev, sp.id]);
      setSelectedSpace(sp.id);
      setModeBySpace((p) => ({ ...p, [sp.id]: "design" }));
      setViewMode("space");
    });
  };

  const setSpaceCategory = (id, category) => {
    window.API.spaces.update(id, { category: category || null }).then(() => bumpVersion());
  };

  // Space fields live on the shared window.SPACES object; the API mutates in
  // place, so bump a version counter to force a re-render (Sidebar, Processer,
  // etc. all read straight off window.SPACES).
  const [, bumpVersion] = React.useReducer((n) => n + 1, 0);
  const renameSpace = (id, name) => {
    if (!window.SPACES[id]) return;
    window.API.spaces.update(id, { name }).then(() => bumpVersion());
  };

  const requestDeleteSpace = (id, name) => setConfirmDeleteSpace({ id, name });

  const deleteSpace = () => {
    const id = confirmDeleteSpace.id;
    window.API.spaces.delete(id).then(() => {
      setRemovedSpaceIds((prev) => [...prev, id]);
      setConfirmDeleteSpace(null);
      if (selectedSpace === id) {
        const remaining = spaceIds.filter((sid) => sid !== id);
        setSelectedSpace(remaining[0] || null);
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

  const assignClassify = (idx, spaceId) => {
    window.API.unclassified.assign(unclassified, idx, spaceId).then(() => {
      setUnclassified((prev) => prev.filter((_, i) => i !== idx));
    });
  };

  const login = (id) => {
    window.API.auth.login(id).then(({ user: u }) => {
      setUserId(u.id);
      setSelectedSpace(u.spaces[0]);
      setViewMode("space");
      setModeBySpace({});
      setTabBySpace({});
      setExtraSpaceIds([]);
      setRemovedSpaceIds([]);
      setUnclassified(u.org ? window.UNCLASSIFIED : window.UNCLASSIFIED_SARA);
      setOpenItem(null);
    });
  };

  const logout = () => {
    window.API.auth.logout().then(() => setUserId(null));
  };

  if (!user) {
    return <LoginView onLogin={login} />;
  }

  const scopedContacts = window.buildGlobalContacts(window.SPACES, spaceIds);

  const routedItems = spaceIds.flatMap((sid) => {
    const sp = window.SPACES[sid];
    return (sp.inbox || []).map((m) => ({ ...m, spaceId: sid, spaceName: sp.name, spaceAddress: sp.address }));
  });
  const inboxTotal = routedItems.length + unclassified.length;

  // Global Inbox rows already carry spaceId/spaceName/spaceAddress merged in
  // (routed) or not at all (unrouted, falls back to "Att klassificera").
  const openMailFromGlobal = (m) =>
    setOpenMail({ mail: m, spaceId: m.spaceId, spaceName: m.spaceName, spaceAddress: m.spaceAddress });

  return (
    <div className="app">
      <Sidebar
        user={user}
        spaceOrder={spaceIds}
        spaceCategories={Object.fromEntries(
          spaceIds.map((id) => [id, window.SPACES[id].category])
        )}
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
        inboxCount={inboxTotal}
        unclassifiedCount={unclassified.length}
        contactsCount={scopedContacts.length}
        processesCount={spaceIds.length}
      />

      <main className="main">
        {viewMode === "inbox" ? (
          <GlobalInboxView
            routedItems={routedItems}
            unclassified={unclassified}
            spaces={Object.fromEntries(spaceIds.map((id) => [id, window.SPACES[id]]))}
            onAssign={assignClassify}
            onJump={(id) => jumpToSpace(id, "inbox")}
            onOpenMail={openMailFromGlobal}
          />
        ) : viewMode === "classify" ? (
          <ClassifyView
            items={unclassified}
            spaces={Object.fromEntries(spaceIds.map((id) => [id, window.SPACES[id]]))}
            onAssign={assignClassify}
          />
        ) : viewMode === "contacts" ? (
          <ContactsGlobalView contacts={scopedContacts} onJump={jumpToSpace} />
        ) : viewMode === "processes" ? (
          <ProcessesView
            spaces={Object.fromEntries(spaceIds.map((id) => [id, window.SPACES[id]]))}
            onOpenSpace={(id) => jumpToSpace(id, "pipeline")}
          />
        ) : (
          <div className="space-view">
            <header className="space-head">
              <SpaceIdentity
                space={space}
                category={space.category}
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

      <ItemModal
        open={openItem}
        onClose={() => setOpenItem(null)}
        space={space}
      />

      <MailModal
        open={openMail}
        onClose={() => setOpenMail(null)}
        onJump={(id) => jumpToSpace(id, "inbox")}
      />

      <ConfirmModal
        open={!!confirmDeleteSpace}
        title={confirmDeleteSpace ? `Ta bort "${confirmDeleteSpace.name}"?` : ""}
        body="Detta tar bort spacet och all dess data ur den här sessionen. Går inte att ångra."
        confirmLabel="Ta bort space"
        onConfirm={deleteSpace}
        onCancel={() => setConfirmDeleteSpace(null)}
      />
    </div>
  );
};

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(<App />);
