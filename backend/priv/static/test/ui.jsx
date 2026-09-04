// Shared small UI primitives.

const EntityTag = ({ entity }) => {
  // Typographic tag, no color, no emoji.
  const dot = entity.kind === "ai" ? "·" : entity.kind === "human" ? "·" : "+";
  return (
    <span className="entity-tag" data-kind={entity.kind}>
      {entity.label}
    </span>
  );
};

const StateDot = ({ state }) => {
  return <span className="state-dot" data-state={state} aria-hidden="true" />;
};

const M4WLogo = () => (
  <div className="m4w-logo">
    <span className="m4w-mark">M4W</span>
    <span className="m4w-sub">Mail for Work</span>
  </div>
);

// Underlined-on-active typographic link toggle.
const LinkToggle = ({ options, value, onChange, separator = "·" }) => (
  <div className="link-toggle">
    {options.map((opt, i) => (
      <React.Fragment key={opt.value}>
        {i > 0 && <span className="link-toggle-sep">{separator}</span>}
        <button
          type="button"
          className={"link-toggle-link" + (value === opt.value ? " is-active" : "")}
          onClick={() => onChange(opt.value)}
        >
          {opt.label}
        </button>
      </React.Fragment>
    ))}
  </div>
);

const CopyAddress = ({ address }) => {
  return (
    <div className="copy-address">
      <span className="copy-address-glyph" aria-hidden="true">@</span>
      <span className="copy-address-text">{address}</span>
      <a className="copy-address-btn" href={`mailto:${address}`} title={`Mejla ${address}`}>
        Mejla
      </a>
    </div>
  );
};

const ConfirmModal = ({ open, title, body, confirmLabel = "Ta bort", onConfirm, onCancel }) => {
  if (!open) return null;
  return (
    <div className="modal-scrim" onClick={onCancel}>
      <div className="modal-card modal-card--confirm" onClick={(e) => e.stopPropagation()}>
        <div className="modal-title">{title}</div>
        {body && <div className="confirm-body">{body}</div>}
        <div className="confirm-actions">
          <button type="button" className="btn btn--ghost" onClick={onCancel}>
            Avbryt
          </button>
          <button type="button" className="btn btn--danger" onClick={onConfirm}>
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { EntityTag, StateDot, M4WLogo, LinkToggle, CopyAddress, ConfirmModal });
