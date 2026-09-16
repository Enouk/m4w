// api.js — thin fetch() wrapper around the same Phoenix REST API the mail
// frontend uses (see backend/priv/static/frontend/mail/API-SPEC.md), plus
// the new /goals resource this app adds. Shares the "m4w_token" localStorage
// key with the mail app, so a login in one carries into the other.

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

  // ---------- Goals ----------
  const goals = {
    list: () => get("/goals").then(data),
    get: (id) => get(`/goals/${id}`).then(data),
    create: ({ title, description }) => post("/goals", { title, description }).then(data),
    update: (id, patchBody) => patch(`/goals/${id}`, patchBody).then(data),
    delete: (id) => del(`/goals/${id}`),
    plan: (id) => post(`/goals/${id}/plan`).then((json) => json.spaces),
    confirm: (id, spaces) => post(`/goals/${id}/confirm`, { spaces }).then(data)
  };

  // ---------- Spaces (Goals own creation; Design can update goal/rooms here) ----------
  const spaces = {
    get: (id) => get(`/spaces/${id}`).then(data),
    update: (id, patchBody) => patch(`/spaces/${id}`, patchBody).then(data),
    generate: (id) => post(`/spaces/${id}/generate`).then((json) => json.rooms)
  };

  // ---------- Rooms / Items (also used to compute a Space's progress) ----------
  const rooms = {
    list: (spaceId) => get(`/spaces/${spaceId}/rooms`).then(data),
    create: (spaceId, roomData) => post(`/spaces/${spaceId}/rooms`, roomData).then(data),
    update: (spaceId, roomId, patchBody) =>
      patch(`/spaces/${spaceId}/rooms/${roomId}`, patchBody).then(data),
    delete: (spaceId, roomId) => del(`/spaces/${spaceId}/rooms/${roomId}`)
  };
  const items = {
    listForRoom: (spaceId, roomId) => get(`/spaces/${spaceId}/rooms/${roomId}/items`).then(data)
  };

  // ---------- Passages (item movement between rooms, drives the map's travel animation) ----------
  const passages = {
    list: (spaceId) => get(`/spaces/${spaceId}/passages`).then(data)
  };

  window.API = { auth, me, goals, spaces, rooms, items, passages };
})();
