// Login screen: a real-looking email/password form (matches one of the demo
// users by email, any password accepted) plus one-click testanvändare cards
// for quickly switching between the three account types.

const LoginView = ({ onLogin }) => {
  const [email, setEmail] = React.useState("");
  const [password, setPassword] = React.useState("");
  const [error, setError] = React.useState("");

  const users = Object.values(window.USERS);

  const submit = (e) => {
    e.preventDefault();
    const match = users.find((u) => u.email.toLowerCase() === email.trim().toLowerCase());
    if (!match) {
      setError("Okänd e-postadress — välj en testanvändare nedan.");
      return;
    }
    setError("");
    onLogin(match.id);
  };

  return (
    <div className="login-screen">
      <div className="login-card">
        <M4WLogo />

        <div className="login-heads">
          <h1 className="login-title">Logga in</h1>
          <p className="login-sub">Processlagret som aktiveras av e-post.</p>
        </div>

        <form className="login-form" onSubmit={submit}>
          <label className="login-field">
            <span className="login-label">E-post</span>
            <input
              type="email"
              className="login-input"
              placeholder="namn@företag.se"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="username"
            />
          </label>
          <label className="login-field">
            <span className="login-label">Lösenord</span>
            <input
              type="password"
              className="login-input"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
            />
          </label>
          {error && <div className="login-error">{error}</div>}
          <button type="submit" className="btn btn--accent login-submit">
            Logga in
          </button>
        </form>

        <div className="login-divider">
          <span>eller välj en testanvändare</span>
        </div>

        <ul className="login-users">
          {users.map((u) => (
            <li key={u.id}>
              <button type="button" className="login-user" onClick={() => onLogin(u.id)}>
                <span className="login-user-avatar">{u.initials}</span>
                <span className="login-user-meta">
                  <span className="login-user-name">{u.name}</span>
                  <span className="login-user-org">
                    {u.role}
                    {u.org ? ` · ${u.org}` : " · Ingen organisation"}
                  </span>
                </span>
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

window.LoginView = LoginView;
