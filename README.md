# M4w

MUD for Work — see `backend/MAIN.md` for the underlying concept (Goals, Spaces, Rooms, Entities, Doors, Passages, Artifacts).

The application is a single Phoenix app in `backend/`. It's fronted by a self-hosted [Stalwart](https://stalw.art/) mail server so Spaces can receive real incoming email, routed by matching the mail's `To` address against a Space's `address`.

## Getting started

```bash
cd backend
docker compose up
```

This starts three services:

- **`db`** — Postgres, `localhost:5432`
- **`app`** — the Phoenix app, `http://localhost:4000` (runs migrations + seeds on first boot)
- **`mailserver`** — Stalwart, admin UI + JMAP on `http://localhost:8080`, SMTP on `25`/`587`

`db` and `app` need nothing further — they come up and seed themselves. **Stalwart needs a one-time manual setup** (see below) before mail actually flows, because it ships with no configuration and has no non-interactive bootstrap.

## One-time Stalwart setup

Do this once per fresh `stalwart_etc`/`stalwart_data` volume (i.e. once per `docker compose down -v`, not on every `docker compose up`).

### 1. Log in with the bootstrap password

```bash
docker compose logs mailserver | grep -A8 'bootstrap mode'
```

This prints a temporary `admin` / `<random password>`. Go to **`http://localhost:8080/admin`** (the bare path — deep-linking straight to `/admin/login` skips a redirect the login flow needs and it'll fail with a confusing "you have to authenticate first" error) and sign in with those credentials.

### 2. Run the setup wizard

Hostname, domain (e.g. `m4w.local`), storage backend, directory type, log destination — defaults are fine for local dev. On the certificate/TLS step:

- **Turn OFF "Automatically Obtain TLS Certificate"**. It tries to get a real Let's Encrypt certificate via ACME, which will fail for a non-public domain like `m4w.local` (`Domain name does not end with a valid public suffix`) and silently prevents the wizard from saving anything.
- Leave "Generate Email Signing Keys" (DKIM) on — harmless and unrelated.

At the end it generates a **permanent** admin account/password. Write it down — it's shown once.

### 3. Restart Stalwart to apply the config

```bash
docker compose restart mailserver
```

Log back in with the permanent admin credentials from step 2.

### 4. Add a catch-all for the domain

Any Space's `address` needs to actually be reachable at the domain you set up. Rather than provisioning a mailbox per Space, route everything into one mailbox: **Domains → (your domain) → Email section → "Catch-All Address"** → set it to your admin account's address (e.g. `admin@m4w.local`). From then on, any `something@m4w.local` you set as a Space's `address` will be delivered there, and our poller reads the `To:` header per message to route it correctly — no per-Space mailbox needed.

### 5. Create an App Password

**Accounts → (your account) → App Passwords** → create one. This is what the poller authenticates with — don't use the real admin password for it.

### 6. Wire the credentials in

In `backend/docker-compose.yml`, set on the `app` service:

```yaml
STALWART_JMAP_USER: admin@m4w.local        # the account from step 2
STALWART_JMAP_PASSWORD: <the App Password from step 5>
```

Then:

```bash
docker compose up -d app
```

`M4w.Mail.StalwartPoller` (see `backend/lib/m4w/mail/`) starts automatically whenever `STALWART_JMAP_URL` is set, polls Stalwart's Inbox over JMAP every 10s (`STALWART_POLL_INTERVAL_MS`), and feeds new mail into `M4w.Ops.create_inbound_mail/1` — the same path `POST /api/v1/inbound-mail` uses.

## Testing the integration

```bash
cd backend
./scripts/test_stalwart_mail.sh
```

This creates a throwaway Space + Room, sends a real email through Stalwart, waits for the poller, and prints the routed mail — then deletes the test Space. If Stalwart's spam filter files the test message under Junk (likely, since the script's test sender has no SPF/DKIM), the script detects that, moves it to Inbox via JMAP itself, and re-checks — no manual admin UI steps needed. See the script's header comment for env var overrides (`LOGIN_EMAIL`, `SMTP_HOST`, `KEEP_SPACE`, etc).

## Troubleshooting

- **`docker logs backend-mailserver-1` looks frozen after setup**: expected — Stalwart's log destination is chosen during the wizard and typically isn't stdout once configured. Use the admin UI or JMAP directly to check state instead of `docker logs`.
- **App keeps logging `StalwartPoller: could not establish a JMAP session` / `Req.TransportError: socket closed`**: Stalwart's brute-force protection has likely blocked the `app` container's IP (this happens easily during setup, before real credentials exist). Check **Security → Blocked IP addresses** in the admin UI and remove the entry for the `app` container's IP (find it with `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' backend-app-1`), and consider adding it (or the whole `172.18.0.0/16`-style subnet) to **Allowed IP addresses**. Restart `mailserver` afterward — the ban state doesn't always clear until it does.
- **Mail never shows up in a Space's inbox**: check whether it landed in Junk instead (admin UI, or `./scripts/test_stalwart_mail.sh` which does this automatically) — the poller only watches Inbox.
