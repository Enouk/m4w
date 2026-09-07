#!/usr/bin/env bash
# Non-interactively provisions the Stalwart mail server, replacing the
# "click through the setup wizard" flow that used to live in README.md.
#
# Uses Stalwart's declarative-deployment mechanism (see
# https://stalw.art/docs/configuration/declarative-deployments/):
#   1. The `mailserver` container is started with STALWART_RECOVERY_ADMIN
#      pinned (see docker-compose.yml), which unlocks its management API
#      before/without a normal admin account existing.
#   2. This script downloads `stalwart-cli` (the official JMAP-management CLI,
#      https://github.com/stalwartlabs/cli) and uses it to fill in the same
#      `Bootstrap` singleton object the setup wizard's web form posts to,
#      then sets the domain's catch-all address and mints a JMAP app
#      password for M4w.Mail.StalwartPoller — the same things README used to
#      tell you to click through by hand.
#
# Safe to re-run: if the server is already past bootstrap, it's a no-op
# (Stalwart's permanent admin password — like the wizard's — is generated
# server-side and shown once, so there's nothing for a re-run to redo unless
# you wipe the volumes and start over: `docker compose down -v`).
#
# Usage: ./scripts/bootstrap_stalwart.sh
#        STALWART_DOMAIN=example.com ./scripts/bootstrap_stalwart.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

STALWART_URL="${STALWART_URL:-http://localhost:8080}"
CLI_VERSION="1.0.12"

# --- .env: create with a random admin password if this is a fresh checkout ---
if [ ! -f .env ]; then
  echo "==> No .env found, creating one from .env.example"
  cp .env.example .env
fi
# shellcheck disable=SC1091
set -a && source .env && set +a
if [ -z "${STALWART_ADMIN_PASSWORD:-}" ]; then
  STALWART_ADMIN_PASSWORD="$(openssl rand -hex 20)"
  sed -i.bak "s/^STALWART_ADMIN_PASSWORD=.*/STALWART_ADMIN_PASSWORD=$STALWART_ADMIN_PASSWORD/" .env
  rm -f .env.bak
  echo "==> Generated STALWART_ADMIN_PASSWORD and saved it to .env"
fi
STALWART_DOMAIN="${STALWART_DOMAIN:-m4w.local}"

# --- stalwart-cli: download the pinned version for this platform, cached ---
case "$(uname -s)" in
  Linux) cli_os="unknown-linux-gnu" ;;
  Darwin) cli_os="apple-darwin" ;;
  *) echo "Unsupported OS for stalwart-cli: $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) cli_arch="x86_64" ;;
  arm64|aarch64) cli_arch="aarch64" ;;
  *) echo "Unsupported architecture for stalwart-cli: $(uname -m)" >&2; exit 1 ;;
esac
CLI_TARGET="${cli_arch}-${cli_os}"
CLI_DIR=".cache/stalwart-cli-${CLI_VERSION}-${CLI_TARGET}"
CLI_BIN="${CLI_DIR}/stalwart-cli"

if [ ! -x "$CLI_BIN" ]; then
  echo "==> Downloading stalwart-cli v${CLI_VERSION} (${CLI_TARGET})"
  mkdir -p "$CLI_DIR"
  base_url="https://github.com/stalwartlabs/cli/releases/download/v${CLI_VERSION}"
  archive="stalwart-cli-${CLI_TARGET}.tar.xz"
  tmp="$(mktemp -d)"
  curl -sL -o "$tmp/$archive" "$base_url/$archive"
  curl -sL -o "$tmp/$archive.sha256" "$base_url/$archive.sha256"
  (cd "$tmp" && sha256sum -c "$archive.sha256")
  tar xf "$tmp/$archive" -C "$tmp"
  mv "$tmp/stalwart-cli-${CLI_TARGET}/stalwart-cli" "$CLI_BIN"
  rm -rf "$tmp"
fi

cli() {
  "$CLI_BIN" --url "$STALWART_URL" --no-color "$@"
}

echo "==> Waiting for mailserver to be reachable"
docker compose up -d mailserver >/dev/null
for _ in $(seq 1 30); do
  if curl -sf -o /dev/null "$STALWART_URL/healthz/live"; then break; fi
  sleep 1
done

# --- Already bootstrapped? ---
if cli --user admin --password "$STALWART_ADMIN_PASSWORD" query Domain >/tmp/m4w-stalwart-query.$$ 2>&1; then
  already_configured=1
else
  if grep -qi "bootstrap mode" /tmp/m4w-stalwart-query.$$; then
    already_configured=0
  else
    echo "==> Unexpected error talking to Stalwart:" >&2
    cat /tmp/m4w-stalwart-query.$$ >&2
    rm -f /tmp/m4w-stalwart-query.$$
    exit 1
  fi
fi
rm -f /tmp/m4w-stalwart-query.$$

if [ "$already_configured" = "1" ]; then
  if [ -n "${STALWART_JMAP_USER:-}" ] && [ -n "${STALWART_JMAP_PASSWORD:-}" ] \
      && curl -sf -u "$STALWART_JMAP_USER:$STALWART_JMAP_PASSWORD" "$STALWART_URL/jmap/session" >/dev/null; then
    echo "==> Stalwart is already bootstrapped and STALWART_JMAP_USER/PASSWORD in .env work. Nothing to do."
    exit 0
  fi
  echo "==> Stalwart is already bootstrapped, but STALWART_JMAP_USER/PASSWORD in .env are missing or no longer valid." >&2
  echo "    The permanent admin password is only ever shown once (by this script or the wizard)," >&2
  echo "    so it can't be recovered. Wipe the mail server and start over:" >&2
  echo "      docker compose down -v && ./scripts/bootstrap_stalwart.sh" >&2
  exit 1
fi

echo "==> Running first-time setup for domain $STALWART_DOMAIN"
bootstrap_out="$(cli --user admin --password "$STALWART_ADMIN_PASSWORD" update Bootstrap --json "$(cat <<JSON
{
  "serverHostname": "$STALWART_DOMAIN",
  "defaultDomain": "$STALWART_DOMAIN",
  "requestTlsCertificate": false,
  "generateDkimKeys": true
}
JSON
)")"
admin_user="$(grep -oP '(?<=username: ")[^"]+' <<<"$bootstrap_out")"
admin_secret="$(grep -oP '(?<=secret: ")[^"]+' <<<"$bootstrap_out")"
if [ -z "$admin_user" ] || [ -z "$admin_secret" ]; then
  echo "==> Could not parse the generated admin credentials out of:" >&2
  echo "$bootstrap_out" >&2
  exit 1
fi

echo "==> Restarting mailserver to apply the new configuration"
docker compose restart mailserver >/dev/null

echo "==> Waiting for mailserver to come back up as $admin_user"
domain_id=""
for _ in $(seq 1 60); do
  if out="$(cli --user "$admin_user" --password "$admin_secret" query Domain --json 2>/dev/null)" && [ -n "$out" ]; then
    domain_id="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.readline())["id"])' <<<"$out")"
    break
  fi
  sleep 1
done
if [ -z "$domain_id" ]; then
  echo "==> Timed out waiting for mailserver to restart" >&2
  exit 1
fi

echo "==> Setting catch-all address on $STALWART_DOMAIN"
cli --user "$admin_user" --password "$admin_secret" \
  update Domain "$domain_id" --field "catchAllAddress=$admin_user" >/dev/null

echo "==> Creating a JMAP app password for M4w.Mail.StalwartPoller"
app_password_out="$(cli --user "$admin_user" --password "$admin_secret" \
  create AppPassword --field description="m4w JMAP poller")"
app_password="$(grep -oP '(?<=Secret: ).+' <<<"$app_password_out" | tr -d '[:space:]')"
if [ -z "$app_password" ]; then
  echo "==> Could not parse the app password out of:" >&2
  echo "$app_password_out" >&2
  exit 1
fi

sed -i.bak \
  -e "s/^STALWART_JMAP_USER=.*/STALWART_JMAP_USER=$admin_user/" \
  -e "s/^STALWART_JMAP_PASSWORD=.*/STALWART_JMAP_PASSWORD=$app_password/" \
  .env
rm -f .env.bak

echo "==> Done. Wrote STALWART_JMAP_USER/PASSWORD to .env — restart the app to pick them up:"
echo "      docker compose up -d app"
