#!/bin/sh
# Copies a backup of the iPhone app's Documents folder back into the app, file by file.
#
#   tools/restore_phone.sh <backup folder containing Recordings/ and Logs/>
#
# The app must have been launched once, so that it has created its own folders: a folder copied in
# whole arrives owned by root, and the app cannot save into it.
set -e
backup=${1:?usage: restore_phone.sh <backup folder>}
device=$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ {for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-/) print $i}' | head -1)
[ -n "$device" ] || { echo "No iPhone connected."; exit 1; }
for folder in Recordings Logs; do
    [ -d "$backup/$folder" ] || continue
    find "$backup/$folder" -type f -maxdepth 1 | while read -r file; do
        xcrun devicectl device copy to --device "$device" --domain-type appDataContainer --domain-identifier com.alexisrondeau.Quasi \
            --source "$file" --destination "Documents/$folder/$(basename "$file")" >/dev/null 2>&1 || echo "failed: $file"
    done
done
echo "Restored. Relaunch the app to load the log."
