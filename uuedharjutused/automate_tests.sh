#!/usr/bin/env bash
#
# automate_tests.sh
# Testib kolmel tingimusel katseautomaatselt:
#   1) /var/www/html/index.html olemasolu
#   2) apache2 teenuse staatus
#   3) /var/www/html kataloogi failide omanikud

LOGFILE="/var/log/automate_tests.log"
WEBROOT="/var/www/html"
INDEX_FILE="$WEBROOT/index.html"
SERVICE="apache2"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting automated tests..." | tee -a "$LOGFILE"

# 1) Faili olemasolu
if [ -f "$INDEX_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST 1 PASS: $INDEX_FILE leidub." | tee -a "$LOGFILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST 1 FAIL: $INDEX_FILE puudub!" | tee -a "$LOGFILE"
fi

# 2) Apache2 teenuse staatus
if systemctl is-active --quiet "$SERVICE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST 2 PASS: $SERVICE on töökorras." | tee -a "$LOGFILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST 2 FAIL: $SERVICE EI OLE töökorras!" | tee -a "$LOGFILE"
fi

# 3) Kasutajapõhised õigused /var/www/html sisu peal
#    Kõik failid peab olema omanikuks root või www-data
#    Kui leidub fail, mille omanik on mõni muu, siis failib test
FAIL_COUNT=0
for filepath in "$WEBROOT"/*; do
    if [ -e "$filepath" ]; then
        OWNER=$(stat -c '%U' "$filepath")
        if [ "$OWNER" != "root" ] && [ "$OWNER" != "www-data" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST 3 FAIL: $filepath omanik ($OWNER) ei ole root või www-data." | tee -a "$LOGFILE"
            ((FAIL_COUNT++))
        fi
    fi
done

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST 3 PASS: Kõik failid oma õigete omanikega (root või www-data)." | tee -a "$LOGFILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST 3 kokkuvõte: $FAIL_COUNT faili omanikud ei vasta nõuetele." | tee -a "$LOGFILE"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Automated tests completed." | tee -a "$LOGFILE"
exit 0
