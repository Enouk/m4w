// Center panel: state a Goal and land straight in its Space — no more
// reviewing/confirming a drafted list of Spaces, since a Goal now always
// gets exactly one Space (staffed by a small team of role Entities) instead
// of being split across several.

const ChatMessage = ({ role, children }) => (
  <div className={"chat-message chat-message--" + role}>
    <div className="chat-bubble">{children}</div>
  </div>
);

const ChatView = ({ goal, onGoalCreated, onOpenSpace }) => {
  const [composeText, setComposeText] = React.useState("");
  const [creating, setCreating] = React.useState(false);

  const space = goal && goal.spaces[0];

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

  if (!goal) {
    return (
      <div className="chat-shell chat-shell--compose">
        <div className="chat-empty">
          <div className="chat-empty-title">Vad vill du uppnå?</div>
          <div className="chat-empty-body">
            Beskriv målet. c4w skapar direkt ett space med ett team av roller som jobbar mot det.
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

        <ChatMessage role="assistant">
          <div className="chat-plan-title">Space skapat: {space.name}</div>
          <div className="chat-plan-actions">
            <button type="button" className="btn btn--accent" onClick={() => onOpenSpace(space)}>
              Öppna karta →
            </button>
          </div>
        </ChatMessage>
      </div>
    </div>
  );
};

window.ChatView = ChatView;
