#!/bin/sh
# Calls the App Store Connect API with the team key in ~/.appstoreconnect/private_keys, the
# same key xcodebuild uses to upload. Mints a short-lived token with openssl, no other tools.
#
#   tools/asc.sh GET /v1/apps
#   tools/asc.sh POST /v1/betaGroups '{"data": {...}}'
#
# Needs ASC_KEY_ID and ASC_ISSUER_ID in the environment or in the repository's .env.
set -e
cd "$(dirname "$0")/../.."
[ -f .env ] && . ./.env
: "${ASC_KEY_ID:?set ASC_KEY_ID}" "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8"

b64() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
HEADER=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | b64)
NOW=$(date +%s)
CLAIMS=$(printf '{"iss":"%s","iat":%s,"exp":%s,"aud":"appstoreconnect-v1"}' "$ASC_ISSUER_ID" "$NOW" $((NOW + 1200)) | b64)
# openssl gives a DER signature; JWT wants the two 32-byte numbers side by side.
SIGNATURE=$(printf '%s.%s' "$HEADER" "$CLAIMS" | openssl dgst -sha256 -sign "$KEY" | \
    python3 -c '
import sys
der = sys.stdin.buffer.read()
i = 2; parts = []
for _ in range(2):
    assert der[i] == 0x02; n = der[i + 1]; v = der[i + 2:i + 2 + n]; i += 2 + n
    parts.append(int.from_bytes(v, "big").to_bytes(32, "big"))
sys.stdout.buffer.write(b"".join(parts))' | b64)
TOKEN="$HEADER.$CLAIMS.$SIGNATURE"

METHOD=$1; URL="https://api.appstoreconnect.apple.com$2"; BODY=$3
if [ -n "$BODY" ]; then
    curl -sg -X "$METHOD" "$URL" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$BODY"
else
    curl -sg -X "$METHOD" "$URL" -H "Authorization: Bearer $TOKEN"
fi
echo
