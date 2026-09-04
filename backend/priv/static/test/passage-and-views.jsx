// Right panel: passage log + the unclassified-mails view and the expanded item card.

const PassageLog = ({ space }) => (
  <aside className="passage-log">
    <div className="passage-head">
      <div className="passage-title">Passages</div>
      <div className="passage-sub">{space.name} · senaste först</div>
    </div>
    <ul className="passage-list">
      {space.passages.map((p, i) => (
        <li key={i} className="passage-row">
          <span className="passage-time">{p.time}</span>
          <span className="passage-sep" aria-hidden="true">·</span>
          <span className="passage-text">{p.text}</span>
        </li>
      ))}
    </ul>
  </aside>
);

const ClassifyView = ({ items, spaces, onAssign }) => {
  return (
    <div className="classify-view">
      <div className="classify-head">
        <div className="classify-title">Att klassificera</div>
        <div className="classify-sub">
          {items.length} mail som AI:n inte kunde routa till ett Space. Tilldela manuellt — eller
          markera som ingen process.
        </div>
      </div>
      <ul className="classify-list">
        {items.map((m, i) => (
          <li key={i} className="classify-row">
            <div className="classify-row-main">
              <div className="classify-from">{m.from}</div>
              <div className="classify-subject">{m.subject}</div>
              <div className="classify-meta">
                <span>{m.date}</span>
                <span className="dot-sep">·</span>
                <span className="classify-reason">{m.reason}</span>
              </div>
            </div>
            <div className="classify-actions">
              <div className="classify-actions-label">Tilldela till</div>
              <div className="classify-buttons">
                {Object.values(spaces).map((sp) => (
                  <button
                    key={sp.id}
                    type="button"
                    className="btn btn--small btn--ghost"
                    onClick={() => onAssign(i, sp.id)}
                  >
                    {sp.name}
                  </button>
                ))}
                <button
                  type="button"
                  className="btn btn--small btn--muted"
                  onClick={() => onAssign(i, null)}
                >
                  Ingen process
                </button>
              </div>
            </div>
          </li>
        ))}
        {items.length === 0 && (
          <li className="classify-empty">Inga mail att klassificera. AI:n routade allt.</li>
        )}
      </ul>
    </div>
  );
};

const ItemModal = ({ open, onClose, space }) => {
  if (!open) return null;
  const { room, item } = open;
  return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-breadcrumb">
            <span>{space.name}</span>
            <span className="dot-sep">·</span>
            <span>{room.name}</span>
          </div>
          <button type="button" className="modal-close" onClick={onClose} aria-label="Stäng">
            ×
          </button>
        </div>
        <div className="modal-title">{item.title}</div>
        <div className="modal-meta">
          <EntityTag entity={room.entity} />
          <span className="dot-sep">·</span>
          <span>{item.meta}</span>
        </div>

        <div className="modal-section-label">Originalmail</div>
        <div className="modal-mail">
          <div className="modal-mail-head">
            <div><span className="modal-mail-key">Från</span> Karin Lindqvist &lt;karin.lindqvist@acme.se&gt;</div>
            <div><span className="modal-mail-key">Till</span> {space.address}</div>
            <div><span className="modal-mail-key">Datum</span> Idag 14:32</div>
            <div><span className="modal-mail-key">Ämne</span> {item.title}</div>
          </div>
          <div className="modal-mail-body">
            <p>Hej,</p>
            <p>
              Här kommer underlaget inför nästa station i flödet. AI:n har redan parsat de
              relevanta fälten och knutit ärendet till rätt nyckelvillkor — kolla gärna att
              tolkningen ser rimlig ut innan ni går vidare.
            </p>
            <p>Vänliga hälsningar,<br/>Karin</p>
          </div>
        </div>

        <div className="modal-section-label">Passages för detta ärende</div>
        <ul className="modal-passages">
          <li><span className="passage-time">10:04</span><span className="passage-sep">·</span><span>routat till {room.name}</span></li>
          <li><span className="passage-time">10:06</span><span className="passage-sep">·</span><span>nyckelvillkor utvärderat</span></li>
          <li><span className="passage-time">14:32</span><span className="passage-sep">·</span><span>status uppdaterad — {item.meta}</span></li>
        </ul>
      </div>
    </div>
  );
};

const MailModal = ({ open, onClose, onJump }) => {
  if (!open) return null;
  const { mail, spaceId, spaceName, spaceAddress } = open;
  return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-breadcrumb">
            <span>{spaceName || "Att klassificera"}</span>
            {mail.room && (
              <React.Fragment>
                <span className="dot-sep">·</span>
                <span>{mail.room}</span>
              </React.Fragment>
            )}
          </div>
          <button type="button" className="modal-close" onClick={onClose} aria-label="Stäng">
            ×
          </button>
        </div>
        <div className="modal-title">{mail.subject}</div>
        <div className="modal-meta">
          {mail.room ? (
            <span className="inbox-room-tag" data-confidence={mail.confidence}>{mail.room}</span>
          ) : (
            <span className="classify-reason">{mail.reason}</span>
          )}
          {mail.note && (
            <React.Fragment>
              <span className="dot-sep">·</span>
              <span>{mail.note}</span>
            </React.Fragment>
          )}
        </div>

        <div className="modal-section-label">Originalmail</div>
        <div className="modal-mail">
          <div className="modal-mail-head">
            <div><span className="modal-mail-key">Från</span> {mail.from}{mail.fromEmail ? ` <${mail.fromEmail}>` : ""}</div>
            <div>
              <span className="modal-mail-key">Till</span>{" "}
              {spaceAddress || "ej routat till en Space-adress"}
            </div>
            <div><span className="modal-mail-key">Datum</span> {mail.date}</div>
            <div><span className="modal-mail-key">Ämne</span> {mail.subject}</div>
          </div>
          <div className="modal-mail-body">
            {(mail.body || ["(inget mailinnehåll tillagt för denna demo-rad)"]).map((p, i) => (
              <p key={i}>{p}</p>
            ))}
          </div>
        </div>

        {spaceId && onJump && (
          <button
            type="button"
            className="btn btn--ghost mail-modal-jump"
            onClick={() => {
              onJump(spaceId);
              onClose();
            }}
          >
            Öppna i {spaceName} →
          </button>
        )}
      </div>
    </div>
  );
};

Object.assign(window, { PassageLog, ClassifyView, ItemModal, MailModal });
