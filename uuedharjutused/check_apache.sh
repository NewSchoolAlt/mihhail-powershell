#!/usr/bin/env bash
#
# Skript: apache_check.sh
# Eesmärk: Kontrollida, kas Apache2 on paigaldatud ja käivitunud.
# Kasutus: chmod +x apache_check.sh; ./apache_check.sh

SERVICE="apache2"
LOGFILE="/var/log/apache_check.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Funktsioon: logi jooksvaid sõnumeid nii ekraanile kui failile
log_msg() {
  local level="$1"
  local message="$2"
  echo "[$TIMESTAMP] [$level] $message" | tee -a "$LOGFILE"
}

# 1) Kontrolli, kas käsk 'apache2' üldse eksisteerib (paigaldatud)
if ! command -v "$SERVICE" &>/dev/null; then
  log_msg "ERROR" "Teenust '$SERVICE' ei leitud (mitte paigaldatud)."
  exit 1
else
  log_msg "OK" "Teenus '$SERVICE' on paigaldatud."
fi

# 2) Kontrolli, kas teenus on aktiivne (running)
if systemctl is-active --quiet "$SERVICE"; then
  log_msg "OK" "Teenus '$SERVICE' töötab: aktiivne (running)."
  exit 0
else
  # Teenus paigaldatud, aga ei tööta
  log_msg "WARN" "Teenus '$SERVICE' on paigaldatud, kuid ei tööta (inactive/stopped)."
  exit 2
fi
