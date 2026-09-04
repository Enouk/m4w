// api.js — async facade in front of the *-data.js in-memory stores.
//
// Every method here mirrors one endpoint in API-SPEC.md 1:1 (same name,
// same shape). Views should call window.API.* instead of touching
// window.SPACES / window.USERS directly. Swapping the bodies below for
// real fetch() calls is the only change needed to move from prototype to
// a real backend — call sites don't change.
//
// All methods return Promises (via `wire`) so call sites already look like
// they're talking to a network API.

(function () {
  const LATENCY = 0; // bump this during dev to rehearse loading states

  const wire = (fn) =>
    new Promise((resolve, reject) => {
      setTimeout(() => {
        try {
          resolve(fn());
        } catch (err) {
          reject(err);
        }
      }, LATENCY);
    });

  const fail = (code, message) => {
    const err = new Error(message);
    err.code = code;
    throw err;
  };

  const requireSpace = (id) => window.SPACES[id] || fail("not_found", `Space "${id}" finns inte`);
  const requireRoom = (space, roomId) => {
    const room = (space.rooms || []).find((r) => r.id === roomId);
    return room || fail("not_found", `Room "${roomId}" finns inte`);
  };
  const slugify = (name) =>
    name
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)/g, "") || "space";

  // ---------- Auth ----------
  const auth = {
    login: (userIdOrEmail) =>
      wire(() => {
        const user =
          window.USERS[userIdOrEmail] ||
          Object.values(window.USERS).find(
            (u) => u.email.toLowerCase() === String(userIdOrEmail).toLowerCase()
          );
        if (!user) fail("not_found", "Okänd användare");
        localStorage.setItem("m4w_user_id", user.id);
        return { user };
      }),
    logout: () =>
      wire(() => {
        localStorage.removeItem("m4w_user_id");
        return null;
      })
  };

  // ---------- Me ----------
  const me = {
    get: () =>
      wire(() => {
        const uid = localStorage.getItem("m4w_user_id");
        return uid ? window.USERS[uid] || null : null;
      })
  };

  // ---------- Space categories ----------
  const spaceCategories = {
    list: () => wire(() => [...window.SPACE_CATEGORIES])
  };

  // ---------- Spaces ----------
  const spaces = {
    list: (spaceIds) => wire(() => spaceIds.map((id) => window.SPACES[id]).filter(Boolean)),
    get: (id) => wire(() => requireSpace(id)),
    create: ({ name, category }) =>
      wire(() => {
        const id = "space-" + Date.now();
        window.SPACES[id] = {
          id,
          name,
          address: slugify(name) + "@m4w.ai",
          category: category || null,
          activeCount: 0,
          goal: "",
          rooms: [],
          artifacts: [],
          passages: [],
          contextMails: [],
          contacts: [],
          inbox: [],
          outbox: { queued: [], sent: [] }
        };
        return window.SPACES[id];
      }),
    update: (id, patch) =>
      wire(() => {
        const sp = requireSpace(id);
        Object.assign(sp, patch);
        return sp;
      }),
    delete: (id) =>
      wire(() => {
        requireSpace(id);
        delete window.SPACES[id];
        return null;
      }),
    // POST /spaces/:id/generate — demo stand-in for an AI call: real backend
    // would read goal + context mails and propose Rooms. Here the seed data
    // already IS the "generated" pipeline, so we just hand back a copy.
    generate: (id) =>
      wire(() => {
        const sp = requireSpace(id);
        return (sp.rooms || []).map((r) => ({ ...r }));
      })
  };

  // ---------- Context mails (design-time) ----------
  const contextMails = {
    list: (spaceId) => wire(() => requireSpace(spaceId).contextMails || []),
    update: (spaceId, idx, patch) =>
      wire(() => {
        const sp = requireSpace(spaceId);
        const m = (sp.contextMails || [])[idx];
        if (!m) fail("not_found", "Context mail finns inte");
        Object.assign(m, patch);
        return m;
      })
  };

  // ---------- Rooms ----------
  const rooms = {
    list: (spaceId) => wire(() => requireSpace(spaceId).rooms || []),
    create: (spaceId, data) =>
      wire(() => {
        const sp = requireSpace(spaceId);
        const room = { id: "room-" + Date.now(), items: [], ...data };
        sp.rooms = [...(sp.rooms || []), room];
        return room;
      }),
    update: (spaceId, roomId, patch) =>
      wire(() => {
        const sp = requireSpace(spaceId);
        const room = requireRoom(sp, roomId);
        Object.assign(room, patch);
        return room;
      }),
    delete: (spaceId, roomId) =>
      wire(() => {
        const sp = requireSpace(spaceId);
        sp.rooms = (sp.rooms || []).filter((r) => r.id !== roomId);
        return null;
      }),
    // Bulk-replace — used when a Design-mode draft (add/remove/reorder Rooms,
    // edited inline) is committed in one go via "Spara och växla till Kör".
    replaceAll: (spaceId, roomList) =>
      wire(() => {
        const sp = requireSpace(spaceId);
        sp.rooms = roomList.map((r) => ({ ...r }));
        return sp.rooms;
      })
  };

  // ---------- Items ----------
  const findItem = (itemId) => {
    for (const sp of Object.values(window.SPACES)) {
      for (const room of sp.rooms || []) {
        const it = (room.items || []).find((i) => i.id === itemId);
        if (it) return { item: it, room, space: sp };
      }
    }
    return null;
  };
  const items = {
    get: (itemId) => wire(() => findItem(itemId) || fail("not_found", "Item finns inte")),
    update: (itemId, patch) =>
      wire(() => {
        const found = findItem(itemId);
        if (!found) fail("not_found", "Item finns inte");
        Object.assign(found.item, patch);
        return found.item;
      })
  };

  // ---------- Passages (append-only log) ----------
  const passages = {
    list: (spaceId) => wire(() => requireSpace(spaceId).passages || []),
    create: (spaceId, entry) =>
      wire(() => {
        const sp = requireSpace(spaceId);
        const passage = { time: "just nu", ...entry };
        sp.passages = [passage, ...(sp.passages || [])];
        return passage;
      })
  };

  // ---------- Artifacts ----------
  const artifacts = {
    list: (spaceId) => wire(() => requireSpace(spaceId).artifacts || []),
    get: (artifactId) =>
      wire(() => {
        for (const sp of Object.values(window.SPACES)) {
          const a = (sp.artifacts || []).find((x) => x.id === artifactId);
          if (a) return a;
        }
        fail("not_found", "Artifact finns inte");
      })
  };

  // ---------- Inbox / mail per Space ----------
  const inbox = {
    listForSpace: (spaceId) => wire(() => requireSpace(spaceId).inbox || [])
  };
  const mail = {
    get: (mailId) =>
      wire(() => {
        for (const sp of Object.values(window.SPACES)) {
          const m = (sp.inbox || []).find((x) => x._id === mailId);
          if (m) return m;
        }
        fail("not_found", "Mail finns inte");
      })
  };

  // ---------- Replay ----------
  const replay = {
    batch: (spaceId) => wire(() => requireSpace(spaceId).replayBatch || []),
    run: (spaceId, mailIndexes) =>
      wire(() => {
        const sp = requireSpace(spaceId);
        const batch = sp.replayBatch || [];
        return mailIndexes.map((i) => batch[i]).filter(Boolean);
      })
  };

  // ---------- Outbox ----------
  const outbox = {
    get: (spaceId) => wire(() => requireSpace(spaceId).outbox || { queued: [], sent: [] }),
    approve: (spaceId, idx) =>
      wire(() => {
        const sp = requireSpace(spaceId);
        const [msg] = sp.outbox.queued.splice(idx, 1);
        if (!msg) fail("not_found", "Köat meddelande finns inte");
        sp.outbox.sent = [
          { from: msg.from, to: msg.to, subject: msg.subject, time: "just nu", passage: "Godkänd manuellt" },
          ...sp.outbox.sent
        ];
        return sp.outbox;
      }),
    update: (spaceId, idx, patch) =>
      wire(() => {
        const sp = requireSpace(spaceId);
        const msg = sp.outbox.queued[idx];
        if (!msg) fail("not_found", "Köat meddelande finns inte");
        Object.assign(msg, patch);
        return msg;
      }),
    cancel: (spaceId, idx) =>
      wire(() => {
        const sp = requireSpace(spaceId);
        const [msg] = sp.outbox.queued.splice(idx, 1);
        if (!msg) fail("not_found", "Köat meddelande finns inte");
        return null;
      })
  };

  // ---------- Contacts ----------
  const contacts = {
    listForSpace: (spaceId) => wire(() => requireSpace(spaceId).contacts || []),
    listGlobal: (spaceIds) => wire(() => window.buildGlobalContacts(window.SPACES, spaceIds))
  };

  // ---------- Global inbox & classification ----------
  const globalInbox = {
    get: (spaceIds, unclassifiedList) =>
      wire(() => {
        const routed = spaceIds.flatMap((sid) => {
          const sp = window.SPACES[sid];
          return (sp.inbox || []).map((m) => ({
            ...m,
            spaceId: sid,
            spaceName: sp.name,
            spaceAddress: sp.address
          }));
        });
        return { routed, unclassified: unclassifiedList };
      })
  };
  const unclassified = {
    // spaceId === null -> "ingen process", just drops the item from the queue.
    assign: (list, idx, spaceId) =>
      wire(() => {
        const item = list[idx];
        if (!item) fail("not_found", "Mail finns inte i triage-kön");
        if (spaceId) {
          const sp = requireSpace(spaceId);
          const room = sp.rooms && sp.rooms[0];
          sp.inbox = [
            ...(sp.inbox || []),
            { ...item, room: room ? room.name : "Inkorg", confidence: "high" }
          ];
        }
        return item;
      })
  };

  // ---------- Processes (derived, read-only) ----------
  const processes = {
    list: (spaceIds) => wire(() => spaceIds.map((id) => window.SPACES[id]).filter(Boolean))
  };

  // ---------- Space-specific: Möten / Beslut (styrelse) ----------
  const meetings = {
    listForSpace: (spaceId) => wire(() => requireSpace(spaceId).meetings || []),
    get: (spaceId, meetingId) =>
      wire(() => {
        const m = (requireSpace(spaceId).meetings || []).find((x) => x.id === meetingId);
        return m || fail("not_found", "Meeting finns inte");
      })
  };
  const decisions = {
    listForSpace: (spaceId) =>
      wire(() => {
        const out = [];
        (requireSpace(spaceId).meetings || []).forEach((m) =>
          (m.decisions || []).forEach((d) => out.push({ ...d, meetingTitle: m.title, date: m.date }))
        );
        return out;
      })
  };

  // ---------- Space-specific: Efterlevnad / Verifikationer (bokföring) ----------
  const compliance = {
    listForSpace: (spaceId) => wire(() => requireSpace(spaceId).compliance || [])
  };
  const verifications = {
    listForSpace: (spaceId) => wire(() => requireSpace(spaceId).verifications || [])
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
