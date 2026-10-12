#!/bin/sh
# Sends one message to the owner's iPhone through Linq, the way the app will: a text that the
# Shortcuts automation on the phone picks up and sends on as an iMessage from the owner's own
# number. Reads LINQ_API_TOKEN, LINQ_FROM (the Linq line) and LINQ_TO (the iPhone) from .env.
#
#   tools/relay.sh +4917600000000 "I'll be five minutes late"   # relayed to that number
#   tools/relay.sh "hello"                                       # a plain text, just to see it arrive
set -e
cd "$(dirname "$0")/../.."
. ./.env
if [ $# -eq 2 ]; then
    BODY="quasi|$1|$2"
else
    BODY="$1"
fi
curl -s -X POST https://api.linqapp.com/api/partner/v3/chats \
    -H "Authorization: Bearer $LINQ_API_TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"from": sys.argv[1], "to": [sys.argv[2]], "message": {"parts": [{"type": "text", "value": sys.argv[3]}]}}))' "$LINQ_FROM" "$LINQ_TO" "$BODY")"
echo
