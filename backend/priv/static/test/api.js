// api.js — thin fetch() wrapper around the real Phoenix REST API described in
// API-SPEC.md. Every method here mirrors one endpoint 1:1 (same name, same
// shape) so call sites in the views stay simple: `window.API.<group>.<method>(...)`.
//
// Auth: the bearer token returned by `auth.login` is kept in localStorage and
// attached to every subsequent request automatically.

(function () {
  const BASE = "/api/v1";
  const TOKEN_KEY = "m4w_token";

  const getToken = () => localStorage.getItem(TOKEN_KEY);
  const setToken = (token) => localStorage.setItem(TOKEN_KEY, token);
  const clearToken = () => localStorage.removeItem(TOKEN_KEY);

  const request = async (method, path, body) => {
    const headers = { "Content-Type": "application/json" };
    const token = getToken();
    if (token) headers["Authorization"] = `Bearer ${token}`;

    const res = await fetch(BASE + path, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body)
    });

    if (res.status === 204) return null;

    const json = await res.json().catch(() => ({}));

    if (!res.ok) {
      const message =
        (json.error && json.error.message) ||
        (json.errors && json.errors.detail) ||
        `Något gick fel (${res.status})`;
      const err = new Error(message);
      err.code = json.error && json.error.code;
      err.status = res.status;
      throw err;
    }

    return json;
  };

  const get = (path) => request("GET", path);
  const post = (path, body) => request("POST", path, body || {});
  const patch = (path, body) => request("PATCH", path, body || {});
  const del = (path) => request("DELETE", path);

  const data = (json) => json.data;

  // ---------- Auth ----------
  const auth = {
    login: (email, password) =>
      post("/auth/login", { email, password }).then((json) => {
        setToken(json.token);
        return json;
      }),
    logout: () => post("/auth/logout").finally(clearToken)
  };

  // ---------- Me ----------
  const me = {
    get: () => (getToken() ? get("/me") : Promise.resolve(null))
  };

  // ---------- Space categories ----------
  const spaceCategories = {
    list: () => get("/space-categories")
  };

  // ---------- Spaces ----------
  const spaces = {
    list: () => get("/spaces").then(data),
    get: (id) => get(`/spaces/${id}`).then(data),
    create: ({ name, category }) => post("/spaces", { name, category }).then(data),
    update: (id, patchBody) => patch(`/spaces/${id}`, patchBody).then(data),
    delete: (id) => del(`/spaces/${id}`),
    generate: (id) => post(`/spaces/${id}/generate`).then((json) => json.rooms)
  };

  // ---------- Context mails (design-time) ----------
  const contextMails = {
    list: (spaceId) => get(`/spaces/${spaceId}/context-mails`).then(data),
    update: (spaceId, mailId, patchBody) =>
      patch(`/spaces/${spaceId}/context-mails/${mailId}`, patchBody).then(data)
  };

  // ---------- Rooms ----------
  const rooms = {
    list: (spaceId) => get(`/spaces/${spaceId}/rooms`).then(data),
    create: (spaceId, roomData) => post(`/spaces/${spaceId}/rooms`, roomData).then(data),
    update: (spaceId, roomId, patchBody) =>
      patch(`/spaces/${spaceId}/rooms/${roomId}`, patchBody).then(data),
    delete: (spaceId, roomId) => del(`/spaces/${spaceId}/rooms/${roomId}`)
  };

  // ---------- Items ----------
  const items = {
    listForRoom: (spaceId, roomId) => get(`/spaces/${spaceId}/rooms/${roomId}/items`).then(data),
    get: (itemId) => get(`/items/${itemId}`).then(data),
    update: (itemId, patchBody) => patch(`/items/${itemId}`, patchBody).then(data)
  };

  // ---------- Passages (append-only log) ----------
  const passages = {
    list: (spaceId) => get(`/spaces/${spaceId}/passages`).then(data),
    create: (spaceId, entry) => post(`/spaces/${spaceId}/passages`, entry).then(data)
  };

  // ---------- Artifacts ----------
  const artifacts = {
    list: (spaceId) => get(`/spaces/${spaceId}/artifacts`).then(data),
    get: (artifactId) => get(`/artifacts/${artifactId}`).then(data)
  };

  // ---------- Inbox / mail per Space ----------
  const inbox = {
    listForSpace: (spaceId) => get(`/spaces/${spaceId}/inbox`).then(data)
  };
  const mail = {
    get: (mailId) => get(`/mail/${mailId}`).then(data)
  };

  // ---------- Replay ----------
  const replay = {
    batch: (spaceId) => get(`/spaces/${spaceId}/replay-batch`).then(data),
    run: (spaceId, mailIds) => post(`/spaces/${spaceId}/replay`, { mailIds }).then((json) => json.results)
  };

  // ---------- Outbox ----------
  const outbox = {
    get: (spaceId) => get(`/spaces/${spaceId}/outbox`).then(data),
    approve: (spaceId, messageId) => post(`/spaces/${spaceId}/outbox/${messageId}/approve`).then(data),
    update: (spaceId, messageId, patchBody) =>
      patch(`/spaces/${spaceId}/outbox/${messageId}`, patchBody).then(data),
    cancel: (spaceId, messageId) => del(`/spaces/${spaceId}/outbox/${messageId}`)
  };

  // ---------- Contacts ----------
  const contacts = {
    listForSpace: (spaceId) => get(`/spaces/${spaceId}/contacts`).then(data),
    listGlobal: () => get("/contacts").then(data)
  };

  // ---------- Global inbox & classification ----------
  const globalInbox = {
    get: () => get("/inbox")
  };
  const unclassified = {
    list: () => get("/unclassified").then(data),
    assign: (mailId, spaceId) => post(`/unclassified/${mailId}/assign`, { spaceId }).then(data)
  };

  // ---------- Processes (derived, read-only) ----------
  const processes = {
    list: () => get("/processes").then(data)
  };

  // ---------- Space-specific: Möten / Beslut (styrelse) ----------
  const meetings = {
    listForSpace: (spaceId) => get(`/spaces/${spaceId}/meetings`).then(data),
    get: (meetingId) => get(`/meetings/${meetingId}`).then(data)
  };
  const decisions = {
    listForSpace: (spaceId) => get(`/spaces/${spaceId}/decisions`).then(data)
  };

  // ---------- Space-specific: Efterlevnad / Verifikationer (bokföring) ----------
  const compliance = {
    listForSpace: (spaceId) => get(`/spaces/${spaceId}/compliance`).then(data)
  };
  const verifications = {
    listForSpace: (spaceId) => get(`/spaces/${spaceId}/verifications`).then(data)
  };

  window.API = {
    auth,
    me,
    spaceCategories,
    spaces,
    contextMails,
    rooms,
    items,
    passages,
    artifacts,
    inbox,
    mail,
    replay,
    outbox,
    contacts,
    globalInbox,
    unclassified,
    processes,
    meetings,
    decisions,
    compliance,
    verifications
  };
})();
