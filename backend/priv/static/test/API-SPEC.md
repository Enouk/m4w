# M4W REST API — spec för backend-implementation

Härledd direkt ur prototypens datamodell (`spaces-data.js`, `auth-data.js`) och alla
mutationer som UI:t faktiskt triggar (`app.jsx`, `design-view.jsx`, `run-view.jsx`,
`global-inbox.jsx`, `sidebar.jsx`, `passage-and-views.jsx`). Tanken är att detta är
kontraktet mellan frontend och en riktig backend — frontend byts sen ut mot fetch-anrop
mot dessa endpoints istället för att läsa `window.SPACES` / `window.USERS`.

## Konventioner

- Bas-URL: `/api/v1`
- Auth: `Authorization: Bearer <token>` på allt utom `POST /auth/login`.
- Alla svar JSON. Fel: `{ "error": { "code": "...", "message": "..." } }` + rätt HTTP-status
  (400 valideringsfel, 401 ej inloggad, 403 ingen åtkomst till Space, 404 saknas, 409 konflikt).
- Alla listor kan sidan brytas med `?limit=&cursor=`, men i v1 räcker det med att alltid
  returnera hela listan (datamängderna per Space är små).
- Multi-tenant: en `User` tillhör 0–1 `Org`. Åtkomst till ett `Space` styrs av
  `user.spaces` (många-till-många User↔Space, inte kolumn på User). Alla `/spaces/*`-anrop
  ska serverseidan verifiera att inloggad användare har åtkomst till `:spaceId`.
- Tidsstämplar: lagra som ISO 8601 i backend. (Prototypens `"Igår 16:22"`-strängar är bara
  presentation — formatera i frontend, inte i API:t.)

---

## Datamodell (kärnentiteter)

- **User** — id, name, email, role, orgId, spaceIds[]
- **Space** — id, name, address (unik inkommande mailadress), category, goal, status
- **Room** — id, spaceId, name, order, entity {kind: ai|human|mixed, label}, subgoal, key
  (villkoret som öppnar nästa Room)
- **Item** — id, roomId, title, meta, state (waiting|running|human|live|amber|done), sourceMailId
- **Passage** — id, spaceId, itemId?, timestamp, text/fromRoomId/toRoomId (append-only logg)
- **Artifact** — id, spaceId, roomId, title, kind (PDF|DOCX|CSV|SIE), status, createdBy, size, url
- **Mail** — id, spaceId? (null = orouted), roomId?, from, fromEmail, subject, date, body,
  confidence (high|medium|low), note, status (routed|unclassified)
- **ContextMail** — Mail markerad som `use: bool` — kontext till Design-generering
- **OutboxMessage** — id, spaceId, state (queued|sent|cancelled), from, to, subject, preview/body
- **Contact** — id, spaceId, name, role, email, group (intern|extern|ai), rooms[]
- **Meeting** (Space-specifik, styrelse) — id, spaceId, title, date, status, location,
  attendees[{name, role, present}], decisions[]
- **Decision** — id, meetingId, text, outcome, votes
- **ComplianceCheck** (Space-specifik, bokföring) — id, spaceId, title, ref, status, desc, state
- **Verification** (Space-specifik, bokföring) — ver, spaceId, date, supplier, amount, status,
  archiveUntil, trace (roomFrom→roomTo)

---

## Auth

```
POST   /auth/login          { email, password } -> { token, user }
POST   /auth/logout         -> 204
GET    /me                  -> User (inkl. spaceIds, org)
```

## Space categories

```
GET    /space-categories     -> string[]   (statisk lista, ev. konfigurerbar per org senare)
```

## Spaces

```
GET    /spaces                        -> Space[]  (scoped till inloggad user)
POST   /spaces                        { name, category? } -> Space
                                       // skapar tomt Space, tilldelar unik address
GET    /spaces/:spaceId               -> Space (utan tunga sublistor — se subresurser nedan)
PATCH  /spaces/:spaceId               { name?, category?, goal? } -> Space
DELETE /spaces/:spaceId               -> 204
```

### Design-läge (Space-generering)

```
GET    /spaces/:spaceId/context-mails             -> ContextMail[]
PATCH  /spaces/:spaceId/context-mails/:mailId      { use: bool } -> ContextMail
POST   /spaces/:spaceId/generate                   {}
       -> { rooms: Room[] }
       // Kör AI mot goal + de context-mails som har use=true, returnerar förslag på Rooms.
       // Frontend animerar in dem ett i taget (klientside), ingen serverstate för det.
```

### Rooms

```
GET    /spaces/:spaceId/rooms                      -> Room[]
POST   /spaces/:spaceId/rooms                      { name, entity, subgoal, key } -> Room
PATCH  /spaces/:spaceId/rooms/:roomId               { name?, subgoal?, entity?, key?, order? } -> Room
DELETE /spaces/:spaceId/rooms/:roomId               -> 204
```

### Items (ärenden i en Room)

```
GET    /spaces/:spaceId/rooms/:roomId/items         -> Item[]
GET    /items/:itemId                               -> Item (inkl. sourceMail + passages, för ItemModal)
PATCH  /items/:itemId                                { state? } -> Item
```

### Passages (oföränderlig logg — append-only, ingen edit/delete-endpoint)

```
GET    /spaces/:spaceId/passages                    -> Passage[]   (senaste först)
POST   /spaces/:spaceId/passages                    { itemId?, text, fromRoomId?, toRoomId? } -> Passage
       // skrivs av backend-processen själv när ett ärende flyttas — inte tänkt att
       // anropas direkt av UI, men behövs för systemintegrationer/tester.
```

### Artifacts

```
GET    /spaces/:spaceId/artifacts                   -> Artifact[]
GET    /artifacts/:artifactId                        -> Artifact (inkl. nedladdnings-url)
```

### Inbox / mail per Space

```
GET    /spaces/:spaceId/inbox                        -> Mail[]   (live, routade till detta Space)
GET    /mail/:mailId                                  -> Mail    (för MailModal)
POST   /inbound-mail                                  { to, from, fromEmail, subject, body, date }
       -> Mail  { spaceId | null, room | null, confidence }
       // Webhook: riktig inkommande mailhantering. Backend matchar `to`-adress mot
       // Space.address, klassificerar in i en Room, sätter confidence. Om ingen match:
       // spaceId=null -> hamnar i /unclassified.
```

### Replay (testkörning mot historik, ingen mail skickas)

```
GET    /spaces/:spaceId/replay-batch                  -> Mail[]  (kandidatmail att välja bland)
POST   /spaces/:spaceId/replay                         { mailIds: string[] }
       -> { results: [{ mailId, room, confidence, key?, uncertain }] }
```

### Outbox

```
GET    /spaces/:spaceId/outbox                        -> { queued: OutboxMessage[], sent: OutboxMessage[] }
POST   /spaces/:spaceId/outbox/:messageId/approve      -> OutboxMessage (state: sent)
PATCH  /spaces/:spaceId/outbox/:messageId              { subject?, body? } -> OutboxMessage
DELETE /spaces/:spaceId/outbox/:messageId              -> 204   (avbryt köad)
```

### Contacts

```
GET    /spaces/:spaceId/contacts                      -> Contact[]     (scoped till ett Space)
GET    /contacts                                       -> Contact[]     (global, deduplicerad
                                                           över alla Spaces user har åtkomst
                                                           till — merge-nyckel: email, annars
                                                           namn+spaceId för AI-agenter)
```

### Global inbox & klassificering

```
GET    /inbox                                          -> { routed: Mail[], unclassified: Mail[] }
GET    /unclassified                                   -> Mail[]
POST   /unclassified/:mailId/assign                    { spaceId: string | null } -> Mail
       // spaceId=null -> markeras "ingen process", tas bort ur triage-kön
```

### Processer (org-övergripande processkarta — härledd, read-only)

```
GET    /processes    -> Space[] med rooms[] inbäddade (samma data som /spaces + /rooms,
                        men i en enda batch för processkarte-vyn — kan implementeras som
                        ren aggregation ovanpå /spaces och /spaces/:id/rooms)
```

### Space-specifika flikar

Styrelsearbete (`spaceTabs: möten, beslut`):
```
GET    /spaces/:spaceId/meetings              -> Meeting[]
GET    /meetings/:meetingId                    -> Meeting
GET    /spaces/:spaceId/decisions              -> Decision[]   (flattened ur meetings)
```

Bokföring (`spaceTabs: efterlevnad, verifikationer`):
```
GET    /spaces/:spaceId/compliance             -> ComplianceCheck[]
GET    /spaces/:spaceId/verifications           -> Verification[]
```

---

## Vad som INTE är en egen endpoint (klientlogik, ingen serverstate)

- Sidopanelens grupp-per-kategori-sortering (`groupSpacesByCategory`) — ren rendering av
  `GET /spaces`.
- `activeCount` per Space i sidebaren — antingen ett fält på Space (backend räknar) eller
  härlett från `items` med `state != done`. Rekommendation: låt backend beräkna och skicka
  som fält på `Space` så frontend slipper aggregera.
- Login-formulärets användarval i prototypen (klick på en av tre demo-users) — ersätts av
  riktig `/auth/login`.

## Öppna frågor att besluta innan implementation

1. Ska `Room`-ordning vara ett explicit `order`-fält, eller array-index i svaret? (rekommenderar explicit fält — stödjer drag-to-reorder senare.)
2. Ska Passages kunna skapas av flera samtidiga bakgrundsjobb (race conditions vid samma Item)? Om ja, gör `POST /items/:id` till en optimistic-lock (`If-Match`/version-fält).
3. Realtidsuppdatering (nya mail, nya passages) — polling eller websocket/SSE? Inboxen och Passages-loggen känns som de mest värdefulla att pusha live.
