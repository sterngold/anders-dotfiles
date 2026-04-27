#!/bin/bash
# Relay notification poller — checks Alex's machine for new incoming relays
# Runs via launchd every 5 minutes. Sends macOS notification + Telegram on new relay.
# Transport: peer-to-peer via Tailscale (no central server since Mar 24)
#
# Config:
MY_NAME="vlad"
ALEX_HOST="alexair"
ALEX_RELAYS="/Users/alex/relays/sent"
LOCAL_INBOX="$HOME/Code/my-projects/VladContext/relays/inbox"
SEEN_FILE="$HOME/.relay-seen"
SENDER_ALIAS="Winnetou"                     # Alex's display name
TG_ENV="$HOME/.config/anders-loc/.env"
TG_CHAT_ID="8771351464"                     # Vlad

# Load Telegram token (absence = skip Telegram leg, macOS notification still fires)
[ -f "$TG_ENV" ] && . "$TG_ENV"

mkdir -p "$LOCAL_INBOX"
touch "$SEEN_FILE"

# Check Alex's sent folder for relays addressed to vlad
RELAYS=$(ssh -o ConnectTimeout=5 "$ALEX_HOST" "ls $ALEX_RELAYS/REL-*.md 2>/dev/null" 2>/dev/null)
SSH_EXIT=$?

if [ $SSH_EXIT -ne 0 ]; then
    echo "relay-inbox-sync: unreachable (alexair offline) ($(date '+%Y-%m-%dT%H:%M:%S%z'))"
    exit 0
fi

[ -z "$RELAYS" ] && { echo "relay-inbox-sync: success, inbox empty ($(date '+%Y-%m-%dT%H:%M:%S%z'))"; exit 0; }

for relay_path in $RELAYS; do
    relay_id=$(basename "$relay_path" .md)
    grep -q "^${relay_id}$" "$SEEN_FILE" 2>/dev/null && continue

    # Download relay to local inbox
    scp -o ConnectTimeout=5 "${ALEX_HOST}:${relay_path}" "$LOCAL_INBOX/" 2>/dev/null || continue

    subject=$(grep '^subject:' "$LOCAL_INBOX/${relay_id}.md" 2>/dev/null | sed 's/subject: *"*//;s/"*$//')
    type=$(grep '^type:' "$LOCAL_INBOX/${relay_id}.md" 2>/dev/null | sed 's/type: *//')

    # macOS notification (AndersStar)
    osascript -e "display notification \"${type}: ${subject}\" with title \"📨 ${SENDER_ALIAS}\" subtitle \"${relay_id}\" sound name \"Ping\""

    # Telegram notification (iPhone + any Telegram client)
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        curl -s -o /dev/null --max-time 10 \
            --data-urlencode "chat_id=${TG_CHAT_ID}" \
            --data-urlencode "text=📨 ${SENDER_ALIAS} → ${relay_id}
${type}: ${subject}" \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    fi

    echo "$relay_id" >> "$SEEN_FILE"
done

echo "relay-inbox-sync: success ($(date '+%Y-%m-%dT%H:%M:%S%z'))"
