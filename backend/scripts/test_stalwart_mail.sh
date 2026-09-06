#!/usr/bin/env bash
# Sends a real email through the Stalwart mail server and checks that
# M4w.Mail.StalwartPoller picked it up and routed it — into a Space's inbox
# if the space has a Room, or into its Design-mode context mail list if it
# doesn't (see M4w.Ops.create_inbound_mail/1: a Space with no Rooms yet is
# still "in design", so inbound mail is captured as context instead of
# being routed).
#
# Creates its own throwaway Space (+ Room, unless WITH_ROOM=0) for the test
# (so it never touches real seed data) and deletes them again when done,
# unless KEEP_SPACE=1.
#
# Usage: ./scripts/test_stalwart_mail.sh
#        WITH_ROOM=0 ./scripts/test_stalwart_mail.sh   # test the context-mail path instead
#
# Override any of these via env vars, e.g.:
#   LOGIN_EMAIL=sara@ahlenkonsult.se ./scripts/test_stalwart_mail.sh
#
# Note: a script-sent email with a made-up "from" address has no SPF/DKIM,
# so Stalwart's spam filter will usually file it under Junk instead of
# Inbox — the poller only watches Inbox. This script detects that and moves
# the message to Inbox itself (via JMAP, using STALWART_USER/PASSWORD) so
# the test still completes without manual intervention.
set -euo pipefail

APP_URL="${APP_URL:-http://localhost:4000}"
SMTP_HOST="${SMTP_HOST:-localhost}"
SMTP_PORT="${SMTP_PORT:-25}"
LOGIN_EMAIL="${LOGIN_EMAIL:-marcus@acme.se}"
FROM_ADDRESS="${FROM_ADDRESS:-me@example.com}"
SUBJECT="${SUBJECT:-Stalwart test $(date +%s)}"
BODY="${BODY:-Testing the Stalwart -> m4w inbound mail integration.}"
POLL_WAIT="${POLL_WAIT:-12}"
KEEP_SPACE="${KEEP_SPACE:-1}"
WITH_ROOM="${WITH_ROOM:-1}"
STALWART_URL="${STALWART_URL:-http://localhost:8080}"
STALWART_USER="${STALWART_USER:-admin@m4w.local}"
STALWART_PASSWORD="${STALWART_PASSWORD:-app_aaaaaamls0axqze3ks0oidx3a0jwdwlrmuaq}"

MAIL_ADDRESS="stalwart-test-$(date +%s)@m4w.local"
SPACE_ID=""

cleanup() {
  if [ -n "$SPACE_ID" ] && [ "$KEEP_SPACE" != "1" ]; then
    echo "==> Deleting test space $SPACE_ID"
    curl -sf -X DELETE "$APP_URL/api/v1/spaces/$SPACE_ID" -H "Authorization: Bearer $TOKEN" >/dev/null || true
  fi
}
trap cleanup EXIT

echo "==> Logging in as $LOGIN_EMAIL"
TOKEN=$(curl -s -X POST "$APP_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$LOGIN_EMAIL\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')

if [ -z "$TOKEN" ]; then
  echo "Login failed for $LOGIN_EMAIL" >&2
  exit 1
fi

echo "==> Creating a throwaway test space"
SPACE_ID=$(curl -sf -X POST "$APP_URL/api/v1/spaces" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Stalwart test"}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')
echo "    space $SPACE_ID created"

echo "==> Pointing space $SPACE_ID at $MAIL_ADDRESS"
curl -sf -X PATCH "$APP_URL/api/v1/spaces/$SPACE_ID" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"address\":\"$MAIL_ADDRESS\"}" >/dev/null

if [ "$WITH_ROOM" = "1" ]; then
  echo "==> Adding a room so inbound mail has somewhere to route to"
  curl -sf -X POST "$APP_URL/api/v1/spaces/$SPACE_ID/rooms" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d '{"name":"Inkorg"}' >/dev/null
else
  echo "==> WITH_ROOM=0: leaving space roomless (mail should land as Design-mode context instead of being routed)"
fi

echo "==> Sending test email to $MAIL_ADDRESS via $SMTP_HOST:$SMTP_PORT"
python3 - "$SMTP_HOST" "$SMTP_PORT" "$FROM_ADDRESS" "$MAIL_ADDRESS" "$SUBJECT" "$BODY" <<'PY'
import smtplib
import sys
from email.mime.text import MIMEText

smtp_host, smtp_port, from_addr, to_addr, subject, body = sys.argv[1:7]
msg = MIMEText(body)
msg["Subject"] = subject
msg["From"] = from_addr
msg["To"] = to_addr

with smtplib.SMTP(smtp_host, int(smtp_port), timeout=10) as smtp:
    smtp.sendmail(from_addr, [to_addr], msg.as_string())
PY

echo "==> Waiting ${POLL_WAIT}s for the poller to pick it up"
sleep "$POLL_WAIT"

if [ "$WITH_ROOM" = "1" ]; then
  RESULT_ENDPOINT="$APP_URL/api/v1/spaces/$SPACE_ID/inbox"
  RESULT_LABEL="inbox"
else
  RESULT_ENDPOINT="$APP_URL/api/v1/spaces/$SPACE_ID/context-mails"
  RESULT_LABEL="context mails"
fi

result_json() {
  curl -sf "$RESULT_ENDPOINT" -H "Authorization: Bearer $TOKEN"
}

RESULT="$(result_json)"

if [ "$(echo "$RESULT" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["data"]))')" = "0" ]; then
  echo "==> Not in $RESULT_LABEL yet — checking whether Stalwart filed it as spam"
  RESCUE_OUTPUT="$(python3 - "$STALWART_URL" "$STALWART_USER" "$STALWART_PASSWORD" "$SUBJECT" <<'PY'
import base64
import json
import sys
import urllib.request

stalwart_url, user, password, subject = sys.argv[1:5]
api_url = stalwart_url.rstrip("/") + "/jmap/"
auth = base64.b64encode(f"{user}:{password}".encode()).decode()


def jmap(method_calls):
    req = urllib.request.Request(
        api_url,
        data=json.dumps(
            {
                "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
                "methodCalls": method_calls,
            }
        ).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Basic {auth}"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.load(resp)["methodResponses"]


session_req = urllib.request.Request(
    stalwart_url.rstrip("/") + "/.well-known/jmap",
    headers={"Authorization": f"Basic {auth}"},
)
with urllib.request.urlopen(session_req, timeout=10) as resp:
    session = json.load(resp)
account_id = session["primaryAccounts"]["urn:ietf:params:jmap:mail"]

[[_, mailboxes, _]] = jmap([["Mailbox/get", {"accountId": account_id, "properties": ["id", "role", "name"]}, "m0"]])
mailbox_name_by_id = {mb["id"]: (mb["role"] or mb["name"]) for mb in mailboxes["list"]}
inbox_id = next(mb["id"] for mb in mailboxes["list"] if mb["role"] == "inbox")

[[_, query_result, _], [_, get_result, _]] = jmap(
    [
        ["Email/query", {"accountId": account_id, "filter": {"subject": subject}}, "q0"],
        [
            "Email/get",
            {"accountId": account_id, "#ids": {"resultOf": "q0", "name": "Email/query", "path": "/ids"}, "properties": ["id", "mailboxIds"]},
            "g0",
        ],
    ]
)

emails = get_result["list"]
if not emails:
    print("STATUS:not-found")
    sys.exit(0)

email = emails[0]
current_mailboxes = [mailbox_name_by_id.get(mid, mid) for mid in email["mailboxIds"]]

if inbox_id in email["mailboxIds"]:
    print("STATUS:already-in-inbox")
    sys.exit(0)

print(f"INFO:found-in:{','.join(current_mailboxes)}")

jmap(
    [
        [
            "Email/set",
            {
                "accountId": account_id,
                "update": {email["id"]: {f"mailboxIds/{inbox_id}": True, "keywords/$junk": None}},
            },
            "s0",
        ]
    ]
)
print("STATUS:moved-to-inbox")
PY
  )"

  FOUND_IN_LINE="$(echo "$RESCUE_OUTPUT" | grep '^INFO:found-in:' || true)"
  if [ -n "$FOUND_IN_LINE" ]; then
    echo "==> Stalwart's spam filter caught this one: found in [${FOUND_IN_LINE#INFO:found-in:}], not Inbox"
  fi

  case "$(echo "$RESCUE_OUTPUT" | grep '^STATUS:')" in
  STATUS:not-found)
    echo "==> Message hasn't reached Stalwart at all yet (delivery may still be in progress)"
    ;;
  STATUS:already-in-inbox)
    echo "==> Message is already in Inbox — the earlier API check just raced the poller, no spam filtering involved"
    ;;
  STATUS:moved-to-inbox)
    echo "==> Moved it from spam to Inbox so the poller can import it"
    echo "==> Waiting ${POLL_WAIT}s for the poller to pick up the rescued mail"
    sleep "$POLL_WAIT"
    RESULT="$(result_json)"
    ;;
  esac
fi

echo "==> Space $SPACE_ID $RESULT_LABEL:"
echo "$RESULT" | python3 -m json.tool

if [ "$KEEP_SPACE" = "1" ]; then
  echo "==> KEEP_SPACE=1: leaving space $SPACE_ID in place"
fi
