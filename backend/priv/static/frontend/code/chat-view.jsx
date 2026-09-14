// Center panel: a chat-style flow for stating a Goal, reviewing the
// LLM-drafted plan (which Spaces are needed), and confirming it. No chat
// messages are persisted — the transcript is reconstructed each time from
// the Goal's stored state: description -> plan draft -> confirmed spaces.

const ChatMessage = ({ role, children }) => (
  <div className={"chat-message chat-message--" + role}>
    <div className="chat-bubble">{children}</div>
  </div>
);

const PlanCard = ({ name, subgoal }) => (
  <div className="plan-card">
    <div className="plan-card-name">{name}</div>
    <div className="plan-card-subgoal">{subgoal}</div>
  </div>
);

const ChatView = ({ goal, onGoalCreated, onPlanConfirmed }) => {
  const [composeText, setComposeText] = React.useState("");
  const [creating, setCreating] = React.useState(false);

  const [draft, setDraft] = React.useState(null); // null = loading/not started
  const [revealCount, setRevealCount] = React.useState(0);
  const [generating, setGenerating] = React.useState(false);
  const [confirming, setConfirming] = React.useState(false);

  const planSpace = goal && goal.spaces.find((sp) => sp.id === goal.planSpaceId);
  const isConfirmed = !!(planSpace && planSpace.status === "done");
  const confirmedSpaces = goal ? goal.spaces.filter((sp) => sp.id !== goal.planSpaceId) : [];

  const runGenerate = () => {
    setGenerating(true);
    setDraft(null);
    window.API.goals.plan(goal.id).then((drafted) => {
      setDraft(drafted);
      setRevealCount(0);
      let i = 0;
      const tick = () => {
        i += 1;
        setRevealCount(i);
        if (i < drafted.length) {
          setTimeout(tick, 320);
        } else {
          setGenerating(false);
        }
      };
      setTimeout(tick, 220);
    });
  };

  React.useEffect(() => {
    if (goal && !isConfirmed) runGenerate();
  }, [goal && goal.id, isConfirmed]);

  const submitGoal = (e) => {
    e.preventDefault();
    const text = composeText.trim();
    if (!text || creating) return;
    setCreating(true);
    const title = text.split("\n")[0].slice(0, 80);
    window.API.goals.create({ title, description: text }).then((newGoal) => {
      setComposeText("");
      setCreating(false);
      onGoalCreated(newGoal);
    });
  };

  const confirmPlan = () => {
    setConfirming(true);
    const spacesAttrs = draft.map((d) => ({ name: d.name, subgoal: d.subgoal }));
    window.API.goals.confirm(goal.id, spacesAttrs).then((updatedGoal) => {
      setConfirming(false);
      onPlanConfirmed(updatedGoal);
    });
  };

  if (!goal) {
    return (
      <div className="chat-shell chat-shell--compose">
        <div className="chat-empty">
          <div className="chat-empty-title">Vad vill du uppnå?</div>
          <div className="chat-empty-body">
            Beskriv målet. c4w skapar direkt en plan för vilka spaces som behövs för att nå det.
          </div>
        </div>
        <form className="chat-composer" onSubmit={submitGoal}>
          <textarea
            className="chat-input"
            rows={3}
            placeholder="T.ex. Skapa en hemsida i HTML där en klocka visar tiden i Stockholm"
            value={composeText}
            onChange={(e) => setComposeText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) submitGoal(e);
            }}
          />
          <button type="submit" className="btn btn--accent" disabled={creating || !composeText.trim()}>
            {creating ? "Skapar…" : "Sätt mål"}
          </button>
        </form>
      </div>
    );
  }

  return (
    <div className="chat-shell">
      <div className="chat-log">
        <ChatMessage role="user">{goal.description || goal.title}</ChatMessage>

        {isConfirmed ? (
          <ChatMessage role="assistant">
            <div className="chat-plan-title">
              Planen är bekräftad — {confirmedSpaces.length} {confirmedSpaces.length === 1 ? "space" : "spaces"} skapade:
            </div>
            <div className="plan-card-list">
              {confirmedSpaces.map((sp) => (
                <PlanCard key={sp.id} name={sp.name} subgoal={sp.goal} />
              ))}
            </div>
          </ChatMessage>
        ) : draft === null ? (
          <ChatMessage role="assistant">
            <span className="chat-thinking">Tänker…</span>
          </ChatMessage>
        ) : (
          <ChatMessage role="assistant">
            <div className="chat-plan-title">Förslag på spaces för att nå målet:</div>
            <div className="plan-card-list">
              {draft.slice(0, revealCount).map((d) => (
                <PlanCard key={d.id} name={d.name} subgoal={d.subgoal} />
              ))}
            </div>
            {!generating && (
              <div className="chat-plan-actions">
                <button type="button" className="btn btn--ghost" onClick={runGenerate}>
                  Regenerera
                </button>
                <button type="button" className="btn btn--accent" onClick={confirmPlan} disabled={confirming}>
                  {confirming ? "Skapar spaces…" : "Bekräfta plan"}
                </button>
              </div>
            )}
          </ChatMessage>
        )}
      </div>
    </div>
  );
};

window.ChatView = ChatView;
