// Contacts: per-Space (scoped, a Kör tab) + global directory (sidebar view).

const GROUP_LABEL = { intern: "Interna", extern: "Externa", ai: "AI-agenter" };
const GROUP_ORDER = ["intern", "extern", "ai"];

// Small typographic kind marker — no avatars, no color.
const ContactKind = ({ group }) => (
  <span className="contact-kind" data-group={group}>
    {group === "ai" ? "AI" : group === "extern" ? "Extern" : "Intern"}
  </span>
);

// Tags showing the Rooms a contact is active in.
const RoomTags = ({ rooms }) =>
  rooms && rooms.length ? (
    <div className="contact-rooms">
      {rooms.map((r, i) => (
        <span key={i} className="contact-room-tag">{r}</span>
      ))}
    </div>
  ) : null;

// One contact row, used inside a Space.
const ContactRow = ({ c }) => (
  <li className="contact-row">
    <div className="contact-main">
      <div className="contact-name-line">
        <span className="contact-name">{c.name}</span>
        <ContactKind group={c.group} />
      </div>
      <div className="contact-role">{c.role}</div>
      {c.email && (
        <div className="contact-email-row">
          <div className="contact-email mono-sub">{c.email}</div>
          <a className="contact-mail-btn" href={`mailto:${c.email}`} title={`Mejla ${c.email}`}>
            Mejla
          </a>
        </div>
      )}
    </div>
    <RoomTags rooms={c.rooms} />
  </li>
);

const groupContacts = (list) => {
  const out = {};
  GROUP_ORDER.forEach((g) => {
    const items = list.filter((c) => c.group === g);
    if (items.length) out[g] = items;
  });
  return out;
};

// ---------- Scoped: contacts for the selected Space (a Kör tab) ----------

const ContactsTab = ({ space }) => {
  const groups = groupContacts(space.contacts || []);
  const total = (space.contacts || []).length;
  return (
    <div className="contacts">
      <div className="contacts-intro">
        {total} aktörer inblandade i detta Space — människor och AI-agenter.
      </div>
      {GROUP_ORDER.filter((g) => groups[g]).map((g) => (
        <section key={g} className="contact-group">
          <div className="contact-group-label">
            {GROUP_LABEL[g]} <span className="contact-group-count">{groups[g].length}</span>
          </div>
          <ul className="contact-list">
            {groups[g].map((c, i) => (
              <ContactRow key={i} c={c} />
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
};

// ---------- Global: directory across all Spaces ----------

const GlobalContactRow = ({ c, onJump }) => (
  <li className="gcontact-row">
    <div className="gcontact-main">
      <div className="contact-name-line">
        <span className="contact-name">{c.name}</span>
        <ContactKind group={c.group} />
      </div>
      <div className="contact-role">{c.roles.join(" · ")}</div>
      {c.email && (
        <div className="contact-email-row">
          <div className="contact-email mono-sub">{c.email}</div>
          <a className="contact-mail-btn" href={`mailto:${c.email}`} title={`Mejla ${c.email}`}>
            Mejla
          </a>
        </div>
      )}
    </div>
    <div className="gcontact-spaces">
      <div className="gcontact-spaces-label">
        {c.spaces.length > 1 ? `${c.spaces.length} Spaces` : "1 Space"}
      </div>
      <div className="gcontact-space-tags">
        {c.spaces.map((s, i) => (
          <button
            key={i}
            type="button"
            className="gcontact-space-tag"
            onClick={() => onJump(s.id)}
            title={s.rooms.length ? "Rooms: " + s.rooms.join(", ") : s.name}
          >
            {s.name}
          </button>
        ))}
      </div>
    </div>
  </li>
);

const ContactsGlobalView = ({ contacts, onJump }) => {
  const [query, setQuery] = React.useState("");
  const [filter, setFilter] = React.useState("all");

  const q = query.trim().toLowerCase();
  const filtered = contacts.filter((c) => {
    if (filter !== "all" && c.group !== filter) return false;
    if (!q) return true;
    return (
      c.name.toLowerCase().includes(q) ||
      (c.email && c.email.toLowerCase().includes(q)) ||
      c.roles.join(" ").toLowerCase().includes(q) ||
      c.spaces.some((s) => s.name.toLowerCase().includes(q))
    );
  });

  const groups = groupContacts(filtered);

  return (
    <div className="gcontacts-view">
      <div className="gcontacts-head">
        <div className="gcontacts-title">Kontakter</div>
        <div className="gcontacts-sub">
          Alla personer och aktörer över dina Spaces. Samma person slås ihop — klicka på ett Space
          för att hoppa dit.
        </div>
      </div>

      <div className="gcontacts-controls">
        <input
          className="gcontacts-search"
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Sök namn, roll, mail eller Space…"
        />
        <LinkToggle
          options={[
            { label: "Alla", value: "all" },
            { label: "Interna", value: "intern" },
            { label: "Externa", value: "extern" },
            { label: "AI", value: "ai" }
          ]}
          value={filter}
          onChange={setFilter}
        />
      </div>

      {filtered.length === 0 ? (
        <div className="gcontacts-empty">Inga kontakter matchar din sökning.</div>
      ) : (
        GROUP_ORDER.filter((g) => groups[g]).map((g) => (
          <section key={g} className="contact-group">
            <div className="contact-group-label">
              {GROUP_LABEL[g]} <span className="contact-group-count">{groups[g].length}</span>
            </div>
            <ul className="gcontact-list">
              {groups[g].map((c, i) => (
                <GlobalContactRow key={i} c={c} onJump={onJump} />
              ))}
            </ul>
          </section>
        ))
      )}
    </div>
  );
};

Object.assign(window, { ContactsTab, ContactsGlobalView });
