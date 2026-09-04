// Login screen: a real email/password form against POST /auth/login, plus
// one-click testanvändare cards for quickly switching between the three demo
// accounts seeded in the backend (any password is accepted for them).

const DEMO_USERS = [
  { email: "karin.lindqvist@acme.se", name: "Karin Lindqvist", initials: "KL", role: "Styrelseordförande", org: "Acme AB" },
  { email: "marcus@acme.se", name: "Marcus Nilsson", initials: "MN", role: "Ekonomiansvarig · CFO", org: "Acme AB" },
  { email: "sara@ahlenkonsult.se", name: "Sara Ahlén", initials: "SA", role: "Enskild firma", org: null }
];

const LoginView = ({ onLogin }) => {
  const [email, setEmail] = React.useState("");
  const [password, setPassword] = React.useState("");
  const [error, setError] = React.useState("");
  const [submitting, setSubmitting] = React.useState(false);

  const attemptLogin = (loginEmail) => {
    setSubmitting(true);
    setError("");
    onLogin(loginEmail, password).catch((err) => {
      setError(err.message || "Kunde inte logga in.");
      setSubmitting(false);
    });
  };

  const submit = (e) => {
    e.preventDefault();
    if (!email.trim()) {
      setError("Ange en e-postadress.");
      return;
    }
    attemptLogin(email.trim());
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
          <button type="submit" className="btn btn--accent login-submit" disabled={submitting}>
            {submitting ? "Loggar in…" : "Logga in"}
          </button>
        </form>

        <div className="login-divider">
          <span>eller välj en testanvändare</span>
        </div>

        <ul className="login-users">
          {DEMO_USERS.map((u) => (
            <li key={u.email}>
              <button
                type="button"
                className="login-user"
                disabled={submitting}
                onClick={() => attemptLogin(u.email)}
              >
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
