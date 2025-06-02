#!/usr/bin/env bash
#
# Skript: system_tests.sh
# Eesmärk: Automatiseerida hulga süsteemiteste:
#   1) Faili olemasolu kontroll
#   2) Teenuse staatus (running/inactive) kontroll
#   3) Faili omanik/õiguste kontroll
#
# Kasutus:
#   sudo chmod +x /opt/scripts/system_tests.sh
#   sudo /opt/scripts/system_tests.sh
#
# Väljund: logitakse nii ekraanile kui ka logifaili /var/log/system_tests.log
# Tagastusväärtus: 0 = kõik testid läbitud, muidu ≠0 (vigade arv).

LOGFILE="/var/log/system_tests.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
EXIT_CODE=0   # Selle muutuja abil kokku loendame vigade arvu

# 1) Defineerime testitavad üksused

# 1.1. Failid, mille olemasolu kontrollime
#    Näiteks /etc/passwd, /home/testuser/testfile.txt (loo eelnevalt dummy-fail)
FILES_TO_CHECK=(
  "/etc/passwd"
  "/home/testuser/testfile.txt"
)

# 1.2. Teenused, mille staatust kontrollime
#    Näiteks ssh, cron, apache2 jne.
SERVICES_TO_CHECK=(
  "ssh"
  "cron"
  "apache2"
)

# 1.3. Failide omanikuva ja õiguste kontroll
#    Vorm: [failitee]="omanikuNimi:grupinimi:mode"
#    Näiteks /etc/passwd peab olema root:root 644, ja
#    /home/testuser/testfile.txt tuleb omada testuser:testuser 755
declare -A PERM_CHECKS=(
  ["/etc/passwd"]="root:root:644"
  ["/home/testuser/testfile.txt"]="testuser:testuser:755"
)


# 2) Funktsioon: logi ekraanile ja logifaili
log_msg() {
  local level="$1"
  local message="$2"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')" 
  echo "[$ts] [$level] $message" | tee -a "$LOGFILE"
}

# 3) Kontrolli, kas logifail olemas; vajadusel loo see ja lisa päis
init_log() {
  if [[ ! -e "$LOGFILE" ]]; then
    # Loo logikataloog, kui puudub
    local logdir
    logdir="$(dirname "$LOGFILE")"
    if [[ ! -d "$logdir" ]]; then
      mkdir -p "$logdir"
    fi
    # Lisa alguses päis
    echo "===== System Tests Log =====" > "$LOGFILE"
    echo "Algus: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOGFILE"
    echo "============================" >> "$LOGFILE"
  fi
}

# 4) Käivita logi initsialiseerimine
init_log


# 5) 1. OSA: FAILI OLEMASOLU KONTROLL
log_msg "INFO" "Alustame failide olemasolu kontrolli..."
for file in "${FILES_TO_CHECK[@]}"; do
  if [[ -e "$file" ]]; then
    log_msg "OK" "Fail leitud: $file"
  else
    log_msg "ERROR" "Fail puudub: $file"
    ((EXIT_CODE++))
  fi
done


# 6) 2. OSA: TEENUSE STAATUS
log_msg "INFO" "Alustame teenuste staatuse kontrolli..."
for svc in "${SERVICES_TO_CHECK[@]}"; do
  # Esiteks kontrollime, kas teenuse nimetus üldse eksisteerib
  if ! systemctl list-unit-files | grep -q "^${svc}\.service"; then
    log_msg "ERROR" "Teenust ei leitud (puudub unit-file): $svc"
    ((EXIT_CODE++))
    continue
  fi

  # Nüüd kontrollime, kas teenus on aktiivne (running)
  if systemctl is-active --quiet "$svc"; then
    log_msg "OK" "Teenuse '$svc' olek: RUNNING"
  else
    # Teenus kas stoppunud või disabled
    local status
    status="$(systemctl is-active "$svc")"
    log_msg "WARN" "Teenuse '$svc' olek: $status"
    ((EXIT_CODE++))
  fi
done


# 7) 3. OSA: FAILI OMANIKU JA ÕIGUSTE KONTROLL
log_msg "INFO" "Alustame faili omaniku/õiguste kontrolli..."
for filepath in "${!PERM_CHECKS[@]}"; do
  expected="${PERM_CHECKS[$filepath]}"
  # Eraldame oodatud väärtused: kasutaja:grupp:mode
  IFS=":" read -r exp_user exp_group exp_mode <<< "$expected"

  # Kontroll: kas fail olemas?
  if [[ ! -e "$filepath" ]]; then
    log_msg "ERROR" "Faili $filepath pole olemas (ei saa kontrollida õigusi/omanikku)."
    ((EXIT_CODE++))
    continue
  fi

  # Loeme tegeliku omaniku, grupi ja õigused
  # stat -c "%U:%G:%a" tagastab nt "root:root:644"
  actual="$(stat -c "%U:%G:%a" "$filepath")"
  IFS=":" read -r act_user act_group act_mode <<< "$actual"

  # Võrdleme eeldatuga
  if [[ "$exp_user" != "$act_user" || "$exp_group" != "$act_group" || "$exp_mode" != "$act_mode" ]]; then
    log_msg "ERROR" "Omanik/õigused ei vasta (fail: $filepath). Oodatud: $expected, Tegelik: $actual"
    ((EXIT_CODE++))
  else
    log_msg "OK" "Faili $filepath omanik/õigused on korrektsed: $actual"
  fi
done


# 8) Kokkuvõte ja väljumine
if (( EXIT_CODE == 0 )); then
  log_msg "INFO" "Kõik testid läbitud edukalt. Exit code = 0"
else
  log_msg "INFO" "Mõningad testid ebaõnnestusid. Vigade arv: $EXIT_CODE"
fi

exit "$EXIT_CODE"
