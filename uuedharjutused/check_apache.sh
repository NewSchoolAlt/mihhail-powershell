#!/usr/bin/env bash
#
# Skript: apache_check.sh
# Eesmärk: Kontrollida, kas Apache2 on paigaldatud ja käivitunud.
# Logifail: ./apache_check.log (töökataloogis)
#
# Kasutus:
#   chmod +x apache_check.sh
#   ./apache_check.sh

SERVICE="apache2"
LOGFILE="./apache_check.log"

# Funktsioon: logib sõnumid koos timestampiga käivituskausta faili ja STDOUT-i
log_msg() {
  local level="$1"
  local message="$2"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] [$level] $message" | tee -a "$LOGFILE"
}

# 1) Kontrolli, kas käsk 'apache2' eksisteerib (kas Apache paigaldatud)
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
