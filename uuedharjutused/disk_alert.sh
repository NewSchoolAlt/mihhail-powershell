#!/usr/bin/env bash
#
# Skript: disk_alert.sh
# Eesmärk: Kontrollida "/" ketta kasutust ja saata Gmaili kaudu e-post, kui ≥70%.
# Kasutus: chmod +x disk_alert.sh; sudo /opt/scripts/disk_alert.sh
#
# NB! Eeldame, et msmtp on õigesti seadistatud (/etc/msmtprc).

# === 1. Konfiguratsioon ===

# Threshold protsentides (kui > threshold, saadame meili)
THRESHOLD=70

# Disk mount point, mida kontrollime (näiteks '/')
CHECK_MOUNT="/"

# E-post saatja (see peab kattuma msmtprc 'from' realt)
FROM_EMAIL="YOUR_GMAIL_ADDRESS@gmail.com"
# E-post saaja (kellele hoiatus saadetakse, eralda mitu ';'-ga)
TO_EMAIL="admin@example.com"
CC_EMAIL=""   # vajadusel lisa siia cc-aadressid

# Logifail, kuhu salvestame kõik jooksud (võib olla kasulik järelevalve tarbeks)
LOGFILE="/var/log/disk_alert.log"

# === 2. Funktsioon: logi ekraanile ja faili ===
log_msg() {
  local level="$1"
  local message="$2"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] [$level] $message" | tee -a "$LOGFILE"
}

# === 3. Initsialiseerime logifaili, kui seda pole ===
init_log() {
  if [[ ! -e "$LOGFILE" ]]; then
    local logdir
    logdir="$(dirname "$LOGFILE")"
    [[ ! -d "$logdir" ]] && mkdir -p "$logdir"
    echo "===== Disk Alert Log =====" > "$LOGFILE"
    echo "Algus: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOGFILE"
    echo "============================" >> "$LOGFILE"
  fi
}
init_log

# === 4. Kontrolli ketta kasutust ===
# Kasutame 'df -P' (POSIX-formaadis) ja võtame 2. rea, 5. veeru (kasutuse protsent).
# Näide: df -P /  →  /dev/sda1   20511356 3054120 16473736  16%  /
usage_line=$(df -P "$CHECK_MOUNT" | awk 'NR==2')
used_percent=$(echo "$usage_line" | awk '{ print $5 }' | tr -d '%')

# Logime hetke kasutuse
log_msg "INFO" "Mount '$CHECK_MOUNT' kasutus: ${used_percent}%  (THRESHOLD=${THRESHOLD}%)"

# === 5. Kui kasutus ≥ threshold, saadame e‐posti ===
if (( used_percent >= THRESHOLD )); then
  SUBJECT="[ALERT] Disk käyttö ≥ ${THRESHOLD}% on $(hostname)"
  BODY="Hoiatus: Ketta '$CHECK_MOUNT' kasutus on nüüd ${used_percent}% (künnis ${THRESHOLD}%).\n\n"
  BODY+="Täpsem info:\n"
  BODY+="Host: $(hostname)\n"
  BODY+="Aeg: $(date '+%Y-%m-%d %H:%M:%S')\n"
  BODY+="Mount: $CHECK_MOUNT\n"
  BODY+="Kasutus: ${used_percent}%\n"
  BODY+="Käsk 'df -h $CHECK_MOUNT' andmed:\n"
  BODY+="$(df -h "$CHECK_MOUNT")\n"

  # Koostame e-kirja ja saadame msmtp kaudu
  {
    echo -e "Subject: $SUBJECT"
    echo -e "From: $FROM_EMAIL"
    echo -e "To: $TO_EMAIL"
    [[ -n "$CC_EMAIL" ]] && echo -e "Cc: $CC_EMAIL"
    echo -e
    echo -e "$BODY"
  } | msmtp --debug --read-envelope-from --from="$FROM_EMAIL" "$TO_EMAIL" $([[ -n "$CC_EMAIL" ]] && echo "-c $CC_EMAIL")

  if [[ $? -eq 0 ]]; then
    log_msg "OK" "E‐post edukalt saadetud aadressile $TO_EMAIL"
  else
    log_msg "ERROR" "E‐posti saatmine ebaõnnestus (msmtp tagastas vea)."
  fi
else
  log_msg "OK" "Kasutus all thresholdi; e‐posti ei saadetud."
fi

exit 0
