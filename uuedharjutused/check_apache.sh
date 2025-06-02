#!/usr/bin/env bash
#
# Skript: system_tests.sh
# Eesmärk: Kontrollida järjestikku:
#   1) Failide olemasolu
#   2) Teenuste staatust
#   3) Failide omaniku ja õiguseid
# Logifail: ./system_tests.log (töökataloogis)
#
# Kasutus:
#   chmod +x system_tests.sh
#   ./system_tests.sh
#
# Tagastusväärtus:
#   0 = kõik testid läbitud edukalt
#   >0 = vigade arv

LOGFILE="./system_tests.log"
EXIT_CODE=0   # kokku loendame vigade arvu

# --- 1) Defineerime testitavad üksused ---

# 1.1. Failid, mille olemasolu kontrollime
FILES_TO_CHECK=(
  "/etc/passwd"
  "/home/testuser/testfile.txt"
)

# 1.2. Teenused, mille staatust kontrollime
SERVICES_TO_CHECK=(
  "ssh"
  "cron"
  "apache2"
)

# 1.3. Failide omanikuva ja õiguste kontroll
#    Vorm: [failitee]="omanik:grupp:mode"
declare -A PERM_CHECKS=(
  ["/etc/passwd"]="root:root:644"
  ["/home/testuser/testfile.txt"]="testuser:testuser:755"
)

# --- 2) Funktsioon: logi ekraanile ja logifaili ---

log_msg() {
  local level="$1"
  local message="$2"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] [$level] $message" | tee -a "$LOGFILE"
}

# --- 3) Initsialiseerime logifaili, kui seda pole ---

init_log() {
  if [[ ! -e "$LOGFILE" ]]; then
    # Lisa alguses päis
    {
      echo "===== System Tests Log ====="
      echo "Algus: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "============================"
    } > "$LOGFILE"
  fi
}

init_log

# --- 4) 1. OSA: FAILI OLEMASOLU KONTROLL ---

log_msg "INFO" "Alustame failide olemasolu kontrolli..."
for file in "${FILES_TO_CHECK[@]}"; do
  if [[ -e "$file" ]]; then
    log_msg "OK" "Fail leitud: $file"
  else
    log_msg "ERROR" "Fail puudub: $file"
    ((EXIT_CODE++))
  fi
done

# --- 5) 2. OSA: TEENUSE STAATUS KONTROLL ---

log_msg "INFO" "Alustame teenuste staatuse kontrolli..."
for svc in "${SERVICES_TO_CHECK[@]}"; do
  # Esiteks kontrollime, kas unit-file eksisteerib
  if ! systemctl list-unit-files | grep -q "^${svc}\.service"; then
    log_msg "ERROR" "Teenust ei leitud (puudub unit-file): $svc"
    ((EXIT_CODE++))
    continue
  fi

  # Kontrollime, kas teenus töötab
  if systemctl is-active --quiet "$svc"; then
    log_msg "OK" "Teenuse '$svc' olek: RUNNING"
  else
    local status
    status="$(systemctl is-active "$svc")"
    log_msg "WARN" "Teenuse '$svc' olek: $status"
    ((EXIT_CODE++))
  fi
done

# --- 6) 3. OSA: FAILI OMANIKU JA ÕIGUSTE KONTROLL ---

log_msg "INFO" "Alustame faili omaniku/õiguste kontrolli..."
for filepath in "${!PERM_CHECKS[@]}"; do
  expected="${PERM_CHECKS[$filepath]}"
  IFS=":" read -r exp_user exp_group exp_mode <<< "$expected"

  # Kontroll: kas fail olemas?
  if [[ ! -e "$filepath" ]]; then
    log_msg "ERROR" "Faili $filepath pole olemas (ei saa kontrollida õigusi/omanikku)."
    ((EXIT_CODE++))
    continue
  fi

  # Loeme tegeliku omaniku, grupi ja õigused
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

# --- 7) Kokkuvõte ja väljumine ---

if (( EXIT_CODE == 0 )); then
  log_msg "INFO" "Kõik testid läbitud edukalt. Exit code = 0"
else
  log_msg "INFO" "Mõned testid ebaõnnestusid. Vigade arv: $EXIT_CODE"
fi

exit "$EXIT_CODE"
