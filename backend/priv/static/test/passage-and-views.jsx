// Right panel: the unclassified-mails view and the expanded item/mail cards.

const ClassifyView = ({ spaces, onCountsChanged }) => {
  const [items, setItems] = React.useState(null);

  const load = () => window.API.unclassified.list().then(setItems);
  React.useEffect(() => { load(); }, []);

  if (items === null) return null;

  const assign = (mailId, spaceId) =>
    window.API.unclassified.assign(mailId, spaceId).then(() => {
      load();
      onCountsChanged();
    });

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
        {items.map((m) => (
          <li key={m.id} className="classify-row">
            <div className="classify-row-main">
              <div className="classify-from">{m.from}</div>
              <div className="classify-subject">{m.subject}</div>
              <div className="classify-meta">
                <span>{window.formatDateTime(m.date)}</span>
                <span className="dot-sep">·</span>
                <span className="classify-reason">{m.reason}</span>
              </div>
            </div>
            <div className="classify-actions">
              <div className="classify-actions-label">Tilldela till</div>
              <div className="classify-buttons">
                {spaces.map((sp) => (
                  <button
                    key={sp.id}
                    type="button"
                    className="btn btn--small btn--ghost"
                    onClick={() => assign(m.id, sp.id)}
                  >
                    {sp.name}
                  </button>
                ))}
                <button
                  type="button"
                  className="btn btn--small btn--muted"
                  onClick={() => assign(m.id, null)}
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

const ItemModal = ({ open, onClose }) => {
  const [detail, setDetail] = React.useState(null);

  React.useEffect(() => {
    if (!open) {
      setDetail(null);
      return;
    }
    window.API.items.get(open.item.id).then(setDetail);
  }, [open && open.item.id]);

  if (!open) return null;
  const { room, item, spaceName } = open;

  return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div className="modal-breadcrumb">
            <span>{spaceName}</span>
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

        {!detail ? (
          <div className="modal-section-label">Laddar…</div>
        ) : (
          <React.Fragment>
            {detail.sourceMail ? (
              <React.Fragment>
                <div className="modal-section-label">Originalmail</div>
                <div className="modal-mail">
                  <div className="modal-mail-head">
                    <div>
                      <span className="modal-mail-key">Från</span> {detail.sourceMail.from}
                      {detail.sourceMail.fromEmail ? ` <${detail.sourceMail.fromEmail}>` : ""}
                    </div>
                    <div><span className="modal-mail-key">Datum</span> {window.formatDateTime(detail.sourceMail.date)}</div>
                    <div><span className="modal-mail-key">Ämne</span> {detail.sourceMail.subject}</div>
                  </div>
                  <div className="modal-mail-body">
                    {(detail.sourceMail.body || []).map((p, i) => (
                      <p key={i}>{p}</p>
                    ))}
                  </div>
                </div>
              </React.Fragment>
            ) : (
              <div className="context-empty">Inget källmail kopplat till detta ärende.</div>
            )}

            <div className="modal-section-label">Passages för detta ärende</div>
            <ul className="modal-passages">
              {detail.passages.map((p) => (
                <li key={p.id}>
                  <span className="passage-time">{window.formatTime(p.timestamp)}</span>
                  <span className="passage-sep">·</span>
                  <span>{p.text}</span>
                </li>
              ))}
              {detail.passages.length === 0 && (
                <li>Inga passages loggade för detta ärende ännu.</li>
              )}
            </ul>
          </React.Fragment>
        )}
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
          </div>
          <button type="button" className="modal-close" onClick={onClose} aria-label="Stäng">
            ×
          </button>
        </div>
        <div className="modal-title">{mail.subject}</div>
        <div className="modal-meta">
          {spaceId ? (
            <span className="inbox-room-tag" data-confidence={mail.confidence}>{mail.status}</span>
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
            <div><span className="modal-mail-key">Datum</span> {window.formatDateTime(mail.date)}</div>
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

Object.assign(window, { ClassifyView, ItemModal, MailModal });
