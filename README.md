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

`db` and `app` need nothing further — they come up and seed themselves. **Stalwart needs a one-time setup** (see below) before mail actually flows.

## One-time Stalwart setup

```bash
cd backend
./scripts/bootstrap_stalwart.sh
docker compose up -d app
```

This fully replaces clicking through Stalwart's setup wizard, using its [declarative-deployment mechanism](https://stalw.art/docs/configuration/declarative-deployments/): it creates `backend/.env` (gitignored — see `.env.example`) with a random admin password if one doesn't exist yet, then drives Stalwart's management API to set the hostname/domain, disable ACME (a real Let's Encrypt cert can't be issued for a non-public domain like `m4w.local`), generate DKIM keys, add a catch-all address for the domain (so any `something@m4w.local` you set as a Space's `address` is delivered without provisioning a mailbox per Space — our poller reads the `To:` header per message to route it), and mint a JMAP app password — writing `STALWART_JMAP_USER`/`STALWART_JMAP_PASSWORD` into `.env` for the `app` service to pick up.

Safe to re-run: if Stalwart is already bootstrapped it's a no-op. Do this once per fresh `stalwart_etc`/`stalwart_data` volume (i.e. once per `docker compose down -v`, not on every `docker compose up`) — Stalwart's permanent admin password, like the wizard's, is generated server-side and shown once, so a re-run can't recover it if `.env` gets wiped; in that case wipe the volumes and start over (`docker compose down -v && ./scripts/bootstrap_stalwart.sh`).

If you'd rather do it by hand, the admin UI is still there at `http://localhost:8080/admin` — `docker compose logs mailserver | grep -A8 'bootstrap mode'` prints the temporary login (deep-linking straight to `/admin/login` skips a redirect the login flow needs and fails with a confusing "you have to authenticate first" error, so start at the bare `/admin` path).

`M4w.Mail.StalwartPoller` (see `backend/lib/m4w/mail/`) starts automatically whenever `STALWART_JMAP_URL` is set, polls Stalwart's Inbox over JMAP every 10s (`STALWART_POLL_INTERVAL_MS`), and feeds new mail into `M4w.Ops.create_inbound_mail/1` — the same path `POST /api/v1/inbound-mail` uses.

## Testing the integration

```bash
cd backend
./scripts/test_stalwart_mail.sh
```

This creates a throwaway Space + Room, sends a real email through Stalwart, waits for the poller, and prints the routed mail — then deletes the test Space. If Stalwart's spam filter files the test message under Junk (likely, since the script's test sender has no SPF/DKIM), the script detects that, moves it to Inbox via JMAP itself, and re-checks — no manual admin UI steps needed. See the script's header comment for env var overrides (`LOGIN_EMAIL`, `SMTP_HOST`, `KEEP_SPACE`, etc).

## Troubleshooting

- **`docker logs backend-mailserver-1` looks frozen after setup**: expected — Stalwart's log destination is chosen during bootstrap and typically isn't stdout once configured. Use the admin UI or JMAP/`stalwart-cli` directly to check state instead of `docker logs`.
- **App keeps logging `StalwartPoller: could not establish a JMAP session` / `Req.TransportError: socket closed`**: Stalwart's brute-force protection has likely blocked the `app` container's IP (this happens easily during setup, before real credentials exist). Check **Security → Blocked IP addresses** in the admin UI and remove the entry for the `app` container's IP (find it with `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' backend-app-1`), and consider adding it (or the whole `172.18.0.0/16`-style subnet) to **Allowed IP addresses**. Restart `mailserver` afterward — the ban state doesn't always clear until it does.
- **Mail never shows up in a Space's inbox**: check whether it landed in Junk instead (admin UI, or `./scripts/test_stalwart_mail.sh` which does this automatically) — the poller only watches Inbox.
- **Mail server state disappears after `docker compose down` (without `-v`) + `up`**: this image reads/writes `/etc/stalwart` and `/var/lib/stalwart`, not `/opt/stalwart/*` (some older guides reference that path). If `docker-compose.yml`'s `mailserver` volumes ever get pointed at the wrong path again, Docker silently falls back to an anonymous volume — state survives a plain `restart` but resets on every recreate, and `docker compose logs mailserver` will show `Server started in bootstrap mode` / `No configuration file was found` even though you already ran the setup.
