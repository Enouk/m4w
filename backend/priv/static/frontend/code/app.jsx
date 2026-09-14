// App shell: auth + state machine + composition (Sidebar / ChatView / GoalSpacesPanel).

const App = () => {
  const [user, setUser] = React.useState(null);
  const [checkingSession, setCheckingSession] = React.useState(true);

  const [goals, setGoals] = React.useState([]);
  const [selectedGoalId, setSelectedGoalId] = React.useState(null);
  const [goalDetail, setGoalDetail] = React.useState(null); // full goal incl. spaces, or null
  const [confirmDeleteGoal, setConfirmDeleteGoal] = React.useState(null); // { id, title }

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
    window.API.goals.get(id).then(setGoalDetail);
  };

  const newGoal = () => {
    setSelectedGoalId(null);
    setGoalDetail(null);
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
        <ChatView
          key={selectedGoalId || "compose"}
          goal={goalDetail}
          onGoalCreated={onGoalCreated}
          onPlanConfirmed={onPlanConfirmed}
        />
      </main>

      <GoalSpacesPanel goal={goalDetail} />

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
