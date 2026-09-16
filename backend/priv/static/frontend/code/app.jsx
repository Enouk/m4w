// App shell: auth + state machine + composition (Sidebar / ChatView / GoalSpacesPanel).

const App = () => {
  const [user, setUser] = React.useState(null);
  const [checkingSession, setCheckingSession] = React.useState(true);

  const [goals, setGoals] = React.useState([]);
  const [selectedGoalId, setSelectedGoalId] = React.useState(null);
  const [goalDetail, setGoalDetail] = React.useState(null); // full goal incl. spaces, or null
  const [confirmDeleteGoal, setConfirmDeleteGoal] = React.useState(null); // { id, title }
  const [openSpace, setOpenSpace] = React.useState(null); // full Space (id, name, goal, address, …) or null
  const [modeBySpace, setModeBySpace] = React.useState({}); // per-space Design/Karta, defaults to "map"
  const designRef = React.useRef(null);

  React.useEffect(() => {
    window.API.me
      .get()
      .then(setUser)
      .catch(() => setUser(null))
      .finally(() => setCheckingSession(false));
  }, []);

  const refreshGoals = () => window.API.goals.list().then(setGoals);

  React.useEffect(() => {
    if (!user) return;
    window.API.goals.list().then((list) => {
      setGoals(list);
      if (list.length && selectedGoalId === null) {
        selectGoal(list[0].id);
      }
    });
  }, [user]);

  const selectGoal = (id) => {
    setSelectedGoalId(id);
    setGoalDetail(null);
    setOpenSpace(null);
    window.API.goals.get(id).then(setGoalDetail);
  };

  const newGoal = () => {
    setSelectedGoalId(null);
    setGoalDetail(null);
    setOpenSpace(null);
  };

  const onGoalCreated = (newGoalDetail) => {
    setSelectedGoalId(newGoalDetail.id);
    setGoalDetail(newGoalDetail);
    refreshGoals();
  };

  const onPlanConfirmed = (updatedGoalDetail) => {
    setGoalDetail(updatedGoalDetail);
    refreshGoals();
  };

  const requestDeleteGoal = (id, title) => setConfirmDeleteGoal({ id, title });

  const deleteGoal = () => {
    const id = confirmDeleteGoal.id;
    window.API.goals.delete(id).then(() => {
      setConfirmDeleteGoal(null);
      if (selectedGoalId === id) {
        setSelectedGoalId(null);
        setGoalDetail(null);
      }
      refreshGoals();
    });
  };

  const login = (email, password) =>
    window.API.auth.login(email, password).then(({ user: u }) => {
      setUser(u);
      setSelectedGoalId(null);
      setGoalDetail(null);
      setGoals([]);
    });

  const logout = () => {
    window.API.auth.logout().finally(() => {
      setUser(null);
      setGoals([]);
      setSelectedGoalId(null);
      setGoalDetail(null);
    });
  };

  const spaceMode = (openSpace && modeBySpace[openSpace.id]) || "map";
  const setSpaceMode = (m) => setModeBySpace((p) => ({ ...p, [openSpace.id]: m }));

  // Leaving Design via the header toggle bypasses DesignView's own "Spara
  // och växla till Karta" button — without this, flipping straight to
  // Karta after generating a draft would silently discard it.
  const changeSpaceMode = (m) => {
    if (spaceMode === "design" && m !== "design" && designRef.current) {
      designRef.current.flushPendingChanges().then(() => setSpaceMode(m));
    } else {
      setSpaceMode(m);
    }
  };

  if (checkingSession) return null;

  if (!user) {
    return <LoginView onLogin={login} />;
  }

  return (
    <div className="app app--code">
      <Sidebar
        user={user}
        goals={goals}
        selectedGoalId={selectedGoalId}
        onSelectGoal={selectGoal}
        onNewGoal={newGoal}
        onDeleteGoal={requestDeleteGoal}
        onLogout={logout}
      />

      <main className="main">
        {openSpace ? (
          <SpaceMapView
            spaceId={openSpace.id}
            spaceName={openSpace.name}
            space={openSpace}
            mode={spaceMode}
            onChangeMode={changeSpaceMode}
            onModeSaved={setSpaceMode}
            designRef={designRef}
            onBack={() => setOpenSpace(null)}
          />
        ) : (
          <ChatView
            key={selectedGoalId || "compose"}
            goal={goalDetail}
            onGoalCreated={onGoalCreated}
            onPlanConfirmed={onPlanConfirmed}
          />
        )}
      </main>

      <GoalSpacesPanel goal={goalDetail} openSpaceId={openSpace && openSpace.id} onOpenSpace={setOpenSpace} />

      <ConfirmModal
        open={!!confirmDeleteGoal}
        title={confirmDeleteGoal ? `Ta bort "${confirmDeleteGoal.title}"?` : ""}
        body="Detta tar bort målet och alla dess spaces. Går inte att ångra."
        confirmLabel="Ta bort mål"
        onConfirm={deleteGoal}
        onCancel={() => setConfirmDeleteGoal(null)}
      />
    </div>
  );
};

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(<App />);
