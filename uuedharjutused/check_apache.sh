#!/usr/bin/env bash
#
# check_apache.sh
# Ülesanne: Kontrollib, kas Apache2 (httpd) on installitud ja käimas.
#
# Usage: sudo bash check_apache.sh

SERVICE_NAME="apache2"    # Debian/Ubuntu: apache2. CentOS/Fedora: httpd
LOGFILE="/var/log/check_apache.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Apache check..." | tee -a "$LOGFILE"

# 1) Kontrollime, kas teenus on installitud (kas käsklust saab leida)
if ! command -v systemctl &> /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] systemctl ei ole saadaval. Võib-olla ei kasutata systemd-d?" | tee -a "$LOGFILE"
    exit 1
fi

if ! systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Teenus '${SERVICE_NAME}' ei ole installitud." | tee -a "$LOGFILE"
    exit 1
fi

# 2) Kontrollime teenuse staatust
STATUS=$(systemctl is-active "$SERVICE_NAME")
if [ "$STATUS" = "active" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${SERVICE_NAME} on töökorras (active)." | tee -a "$LOGFILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${SERVICE_NAME} EI ole töökorras (status: $STATUS)." | tee -a "$LOGFILE"
    # Soovi korral võime teenuse käivitada:
    # systemctl start "$SERVICE_NAME"
fi

exit 0
