#!/usr/bin/env bash
# Run with root (sudo) so journalctl/ss/lsof can access necessary info.

set -euo pipefail
export LANG=en_US.UTF-8

# temp files
TMP1="$(mktemp /tmp/cek-ssh-XXXXXX)"
TMP2="$(mktemp /tmp/cek-ssh-XXXXXX)"
USERS_DROP_TMP="$(mktemp /tmp/cek-drop-users-XXXXXX)"
USERS_SSH_TMP="$(mktemp /tmp/cek-ssh-users-XXXXXX)"
TMP_SS="$(mktemp /tmp/cek-ss-XXXXXX)"
TMP_JOURNAL="$(mktemp /tmp/cek-journal-XXXXXX)"

cleanup() {
  rm -f "$TMP1" "$TMP2" "$USERS_DROP_TMP" "$USERS_SSH_TMP" "$TMP_SS" "$TMP_JOURNAL" 2>/dev/null || true
}
trap cleanup EXIT

SEED_SINCE="${1:-7 days ago}"

seg() { printf '%*s' "$1" '' | tr ' ' '-'; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

sanitize_field() {
  local s="$1"
  awk -v str="$s" 'BEGIN{gsub(/[[:cntrl:]]/,"",str); print str}'
}

truncate_field() {
  local s="$1"; local w="$2"
  if [ "${w:-0}" -le 0 ]; then printf '%s' ""; return; fi
  s="$(sanitize_field "$s")"
  local len
  len=$(awk -v str="$s" 'BEGIN{print length(str)}')
  if [ "$len" -le "$w" ]; then
    printf '%s' "$s"
  else
    if [ "$w" -le 3 ]; then
      awk -v str="$s" -v w="$w" 'BEGIN{print substr(str,1,w)}'
    else
      local cut=$((w-3))
      awk -v str="$s" -v c="$cut" 'BEGIN{printf "%s...", substr(str,1,c)}'
    fi
  fi
}

parse_peer() {
  local peer="$1"
  local ip port

  peer="${peer#"${peer%%[![:space:]]*}"}"
  peer="${peer%"${peer##*[![:space:]]}"}"

  if [[ "$peer" =~ ^\[.+\]:[0-9]+$ ]]; then
    ip="${peer%%]*}"
    ip="${ip#\[}"
    port="${peer##*:}"
  elif [[ "$peer" == *:* && "$peer" == *.*:* ]]; then
    ip="${peer%:*}"
    port="${peer##*:}"
  elif [[ "$peer" == *:* && "$peer" != *.*:* ]]; then
    ip="${peer%:*}"
    port="${peer##*:}"
  else
    ip="$peer"
    port=""
  fi

  printf '%s %s' "$ip" "$port"
}

get_addr_from_ss() {
  local pid="$1"
  ss -tnp 2>/dev/null | awk -v p="pid=$pid," 'index($0,p){ print $(NF-1); exit }'
}

get_addr_from_lsof() {
  local pid="$1"
  if command -v lsof >/dev/null 2>&1; then
    local out
    out=$(lsof -Pan -p "$pid" -i 2>/dev/null | awk '/ESTABLISHED/ || /->/ { for (i=1;i<=NF;i++) if ($i ~ /->[0-9]/) print $i }' | sed -n '1p' || true)
    if [ -n "$out" ]; then
      if echo "$out" | grep -q '->'; then
        out="${out#*->}"
      fi
      printf '%s' "$out"
    fi
  fi
}

normalize_addr() {
  local addr="$1"
  addr="${addr#\[}"
  addr="${addr%\]}"
  addr="${addr#"${addr%%[![:space:]]*}"}"
  addr="${addr%"${addr##*[![:space:]]}"}"
  printf '%s' "$addr"
}

# ---------------------------
# Dropbear section (pretty table)
# ---------------------------
pids="$(ps -o pid= -C dropbear 2>/dev/null || true)"
echo
echo "-----=[ Dropbear User Login ]=------"

ID_W=6
USER_W=12
IP_W=20
START_W=12
TOTAL_W=4

printf '+-%s-+-%s-+-%s-+-%s-+-%s-+\n' "$(seg $ID_W)" "$(seg $USER_W)" "$(seg $IP_W)" "$(seg $START_W)" "$(seg $TOTAL_W)"
printf '| %-*s | %-*s | %-*s | %-*s | %-*s |\n' "$ID_W" "ID" "$USER_W" "Username" "$IP_W" "IP Address[:port]" "$START_W" "Start" "$TOTAL_W" "Total"
printf '+-%s-+-%s-+-%s-+-%s-+-%s-+\n' "$(seg $ID_W)" "$(seg $USER_W)" "$(seg $IP_W)" "$(seg $START_W)" "$(seg $TOTAL_W)"

if [ -z "${pids// /}" ]; then
  printf '| %-*s | %-*s | %-*s | %-*s | %-*s |\n' $ID_W "(none)" $USER_W "-" $IP_W "-" $START_W "-" $TOTAL_W "-"
  printf '+-%s-+-%s-+-%s-+-%s-+-%s-+\n' "$(seg $ID_W)" "$(seg $USER_W)" "$(seg $IP_W)" "$(seg $START_W)" "$(seg $TOTAL_W)"
  echo "(no dropbear process found)"
else
  SED_EXTRACT_PASS='s/.*dropbear\[\([0-9]\+\)\].*Password auth succeeded for '\''\([^'\'']\+\)'\'' from \([0-9.]\+\):\([0-9]\+\).*/\1 \2 \3 \4/p'
  declare -A pid_to_user pid_to_ip pid_to_port pid_to_start_time

  if command -v journalctl >/dev/null 2>&1; then
    while IFS=' ' read -r pid user ip port; do
      [ -z "$pid" ] && continue
      [ -n "$user" ] && pid_to_user["$pid"]="$user"
      [ -n "$ip" ] && pid_to_ip["$pid"]="$ip"
      [ -n "$port" ] && pid_to_port["$pid"]="$port"
    done < <(journalctl --no-pager -u dropbear --since "$SEED_SINCE" -o short-iso 2>/dev/null | sed -n "$SED_EXTRACT_PASS" || true)
  fi

  for pid in $pids; do
    [ -z "$pid" ] && continue
    user="${pid_to_user[$pid]:-}"
    ip="${pid_to_ip[$pid]:-}"
    port="${pid_to_port[$pid]:-}"

    if [ -z "$user" ]; then
      user="$(journalctl --no-pager -u dropbear --since "$SEED_SINCE" 2>/dev/null | grep -F "dropbear[$pid]" | sed -n "s/.*Password auth succeeded for '\([^']\+\)'.*/\1/p" | tail -n1 || true)"
      [ -n "$user" ] && pid_to_user["$pid"]="$user"
    fi

    if [ -z "$ip" ] || [ -z "$port" ]; then
      addr="$(get_addr_from_ss "$pid" || true)"
      if [ -z "$addr" ]; then
        addr="$(get_addr_from_lsof "$pid" || true)"
      fi
      addr="$(normalize_addr "${addr:-}")"
      if [ -n "$addr" ]; then
        read -r _ip _port <<<"$(parse_peer "$addr")"
        ip="${_ip:-$ip}"
        port="${_port:-$port}"
        [ -n "$ip" ] && pid_to_ip["$pid"]="$ip"
        [ -n "$port" ] && pid_to_port["$pid"]="$port"
      fi
    fi

    start_time="$(ps -p "$pid" -o lstart= 2>/dev/null || true)"
    if [ -n "$start_time" ]; then
      ts="$(date -d "$start_time" +%s 2>/dev/null || echo 0)"
      pid_to_start_time["$pid"]="$ts"
    else
      pid_to_start_time["$pid"]=0
    fi
  done

  declare -A drop_count
  : > "$USERS_DROP_TMP"
  for pid in $pids; do
    [ -z "$pid" ] && continue
    user="${pid_to_user[$pid]:-(unknown)}"
    ip="${pid_to_ip[$pid]:-(unknown)}"
    user_lc="$(lower "$user")"
    if [ "$user_lc" = "root" ] || [ -z "$user" ] || [ "$user" = "(unknown)" ] || [ "$ip" = "(unknown)" ]; then
      continue
    fi
    drop_count["$user"]=$(( ${drop_count["$user"]:-0} + 1 ))
    printf '%s\n' "$user" >> "$USERS_DROP_TMP"
  done

  printed=0
  for pid in $pids; do
    [ -z "$pid" ] && continue
    user="${pid_to_user[$pid]:-(unknown)}"
    ip="${pid_to_ip[$pid]:-(unknown)}"
    port="${pid_to_port[$pid]:-}"
    user_lc="$(lower "$user")"
    if [ "$user_lc" = "root" ]; then
      continue
    fi
    if [ -z "$user" ] || [ -z "$ip" ] || [ "$user" = "(unknown)" ] || [ "$ip" = "(unknown)" ]; then
      continue
    fi
    if [ -n "$port" ]; then
      ipport="${ip}:${port}"
    else
      ipport="${ip}"
    fi
    total="${drop_count[$user]:-1}"
    start_human="${pid_to_start_time[$pid]:-0}"
    if [ "$start_human" -gt 0 ]; then
      start_time_human="$(date -d "@$start_human" '+%H:%M' 2>/dev/null || echo '-')"
    else
      start_time_human="-"
    fi

    sanitized_pid="$(sanitize_field "$pid")"
    if [[ "$sanitized_pid" =~ ^[0-9]+$ ]]; then
      if [ "${#sanitized_pid}" -gt "$ID_W" ]; then
        t_pid="${sanitized_pid:0:$ID_W}"
      else
        t_pid="$sanitized_pid"
      fi
    else
      t_pid="$(truncate_field "$pid" "$ID_W")"
    fi

    t_user="$(truncate_field "$user" "$USER_W")"
    t_ipport="$(truncate_field "$ipport" "$IP_W")"
    t_start="$(truncate_field "$start_time_human" "$START_W")"
    t_total="$(truncate_field "$total" "$TOTAL_W")"

    printf '| %-*s | %-*s | %-*s | %-*s | %-*s |\n' "$ID_W" "$t_pid" "$USER_W" "$t_user" "$IP_W" "$t_ipport" "$START_W" "$t_start" "$TOTAL_W" "$t_total"
    printf '+-%s-+-%s-+-%s-+-%s-+-%s-+\n' "$(seg $ID_W)" "$(seg $USER_W)" "$(seg $IP_W)" "$(seg $START_W)" "$(seg $TOTAL_W)"
    printed=1
  done

  if [ "$printed" -eq 0 ]; then
    printf '| %-*s | %-*s | %-*s | %-*s | %-*s |\n' $ID_W "(none)" $USER_W "-" $IP_W "-" $START_W "-" $TOTAL_W "-"
    printf '+-%s-+-%s-+-%s-+-%s-+-%s-+\n' "$(seg $ID_W)" "$(seg $USER_W)" "$(seg $IP_W)" "$(seg $START_W)" "$(seg $TOTAL_W)"
    echo "(No User Login Detected)"
  fi
fi

echo ""
if [ -s "$USERS_DROP_TMP" ]; then
  total_drop=$(wc -l < "$USERS_DROP_TMP" 2>/dev/null || echo 0)
  echo ""
  echo "Total All Online Users: $total_drop"
else
  echo "(No Dropbear Sessions Detected)"
fi
echo "------------------------------------"

# ---------------------------
# OpenSSH section (phone-friendly)
# ---------------------------

TMP_SS="$(mktemp /tmp/cek-sshd-ss-XXXXXX)" || exit 1
TMP_JOURNAL="$(mktemp /tmp/cek-sshd-journal-XXXXXX)" || exit 1

SKIP_ROOT=1
for a in "$@"; do
  case "$a" in
    --all|-a) SKIP_ROOT=0 ;;
    --no-root|-n) SKIP_ROOT=1 ;;
    *) ;;
  esac
done

declare -A j_pid_user j_pid_ip j_pid_port
declare -A pid_user pid_ip pid_port pid_cmd pid_owner
declare -A pid_start

if command -v journalctl >/dev/null 2>&1; then
  journalctl --no-pager -u sshd --since "$SEED_SINCE" -o short-iso 2>/dev/null \
    | sed -n "s/.*sshd\[\([0-9]\+\)\].*Accepted [^ ]* for \([^ ]\+\) from \(\[[^]]\+\|\([0-9.]\+\|[0-9a-fA-F:]\+\)\) port \([0-9]\+\).*/\1 \2 \3 \5/p" \
    > "$TMP_JOURNAL" 2>/dev/null || true

  if [ -s "$TMP_JOURNAL" ]; then
    while IFS=' ' read -r pid user ip port; do
      [ -z "$pid" ] && continue
      [ -n "$user" ] && j_pid_user["$pid"]="$user"
      [ -n "$ip" ] && j_pid_ip["$pid"]="$ip"
      [ -n "$port" ] && j_pid_port["$pid"]="$port"
    done <"$TMP_JOURNAL"
  fi
fi

if ! command -v ss >/dev/null 2>&1; then
  echo "Perintah 'ss' tidak ditemui. Pasang package 'iproute2'."
  exit 1
fi

ss -tnp 2>/dev/null | awk '/sshd/ { print $0 }' > "$TMP_SS" || true

while IFS= read -r line; do
  [ -z "$line" ] && continue
  peer="$(awk '{ print $(NF-1) }' <<<"$line")"
  users_part="$(sed -n 's/.*users:(\(.*\))/\1/p' <<<"$line" || true)"
  users_part="${users_part#(}"
  users_part="${users_part%)}"
  IFS=')' read -ra entries <<<"$users_part"
  for ent in "${entries[@]}"; do
    ent_clean="$(sed 's/^,//; s/^[(]//; s/[()"]//g' <<<"$ent" | tr -d ' ')"
    pid="$(awk -F',' '{ for(i=1;i<=NF;i++) if ($i ~ /^pid=/) { split($i,a,"="); print a[2]; exit } }' <<<"$ent_clean" || true)"
    [ -z "$pid" ] && continue

    read -r ip port <<<"$(parse_peer "$peer")"
    [ -n "$ip" ] && pid_ip["$pid"]="$ip"
    [ -n "$port" ] && pid_port["$pid"]="$port"

    owner="$(ps -p "$pid" -o user= 2>/dev/null || true)"
    pid_owner["$pid"]="$owner"

    cmd="$(ps -p "$pid" -o cmd= 2>/dev/null || true)"
    pid_cmd["$pid"]="$cmd"
    if [[ "$cmd" =~ sshd[^:]*:\ ([^@[:space:][]+) ]]; then
      pid_user["$pid"]="${BASH_REMATCH[1]}"
    elif [[ "$cmd" =~ sshd[^:]*:\ ([^@[:space:]]+)@ ]]; then
      pid_user["$pid"]="${BASH_REMATCH[1]}"
    fi

    start="$(ps -p "$pid" -o lstart= 2>/dev/null || true)"
    if [ -n "$start" ]; then
      ts="$(date -d "$start" +%s 2>/dev/null || echo 0)"
      pid_start["$pid"]="$ts"
    else
      pid_start["$pid"]=0
    fi

    if [ -n "${j_pid_user[$pid]:-}" ]; then pid_user["$pid"]="${j_pid_user[$pid]}"; fi
    if [ -n "${j_pid_ip[$pid]:-}" ]; then pid_ip["$pid"]="${j_pid_ip[$pid]}"; fi
    if [ -n "${j_pid_port[$pid]:-}" ]; then pid_port["$pid"]="${j_pid_port[$pid]}"; fi
  done
done < "$TMP_SS"

pids_all=()
set +u
pid_start_count="${#pid_start[@]}"
set -u

if [ "$pid_start_count" -eq 0 ]; then
  mapfile -t pids_all < <(ps -eo pid,cmd --no-headers | awk '/\[priv\]/{print $1}' || true)
else
  set +u
  mapfile -t pids_all < <(printf "%s\n" "${!pid_start[@]}" | sort -n)
  set -u
fi

if command -v lsof >/dev/null 2>&1; then
  for pid in "${pids_all[@]}"; do
    [ -z "$pid" ] && continue
    if [ -z "${pid_ip[$pid]:-}" ]; then
      out="$(lsof -Pan -p "$pid" -i 2>/dev/null | awk '/ESTABLISHED/ || /->/ { for (i=1;i<=NF;i++) if ($i ~ /->[0-9]/) print $i }' | sed -n '1p' || true)"
      if [ -n "$out" ]; then
        if echo "$out" | grep -q '->'; then out="${out#*->}"; fi
        read -r oip oport <<<"$(parse_peer "$out")"
        [ -n "$oip" ] && pid_ip["$pid"]="$oip"
        [ -n "$oport" ] && pid_port["$pid"]="$oport"
      fi
    fi
  done
fi

rows_pid=()
rows_user=()
rows_ip=()
rows_port=()
rows_start_ts=()
rows_start_human=()
declare -A seen_key_ts_list

for pid in "${pids_all[@]}"; do
  [ -z "$pid" ] && continue

  user="${pid_user[$pid]:-}"
  owner="${pid_owner[$pid]:-}"
  if [ -z "$user" ]; then user="$owner"; fi
  if [ -z "$user" ]; then continue; fi

  user_lc="$(lower "$user" || true)"

  if [ "$user_lc" = "root" ] && [ "$SKIP_ROOT" -eq 1 ]; then continue; fi
  if [ "$user_lc" = "sshd" ] || [ "$user_lc" = "unknown" ]; then continue; fi

  ip="${pid_ip[$pid]:-unknown}"
  if [ "$ip" != "127.0.0.1" ]; then continue; fi

  port="${pid_port[$pid]:-}"
  if [ -n "$port" ]; then ipport="${ip}:${port}"; else ipport="$ip"; fi

  start_ts="${pid_start[$pid]:-0}"
  if [ "$start_ts" -gt 0 ]; then
    start_human="$(date -d "@$start_ts" '+%H:%M' 2>/dev/null || echo '-')"
  else
    start_human='-'
  fi

  rows_pid+=("$pid"); rows_user+=("$user"); rows_ip+=("$ipport"); rows_port+=("$port")
  rows_start_ts+=("$start_ts"); rows_start_human+=("$start_human")
done

rows_count=${#rows_pid[@]}
if [ "$rows_count" -gt 0 ]; then
  tmp_sort="$(mktemp /tmp/cek-sshd-sort-XXXXXX)" || tmp_sort="/tmp/cek-sshd-sort-fallback"
  : > "$tmp_sort"
  for i in "${!rows_pid[@]}"; do
    printf '%s\t%s\n' "${rows_start_ts[$i]:-0}" "$i" >> "$tmp_sort"
  done
  mapfile -t sorted_idx < <(sort -rn "$tmp_sort" | awk -F'\t' '{print $2}')
  rm -f "$tmp_sort" 2>/dev/null || true
else
  sorted_idx=()
fi

declare -A user_total
for u in "${rows_user[@]}"; do
  user_total["$u"]=$(( ${user_total["$u"]:-0} + 1 ))
done

ID_W=6
USER_W=12
IP_W=20
START_W=12
TOTAL_W=4

echo
echo "-----=[ OpenSSH User Login ]=------"
printf '+-%s-+-%s-+-%s-+-%s-+-%s-+\n' "$(seg $ID_W)" "$(seg $USER_W)" "$(seg $IP_W)" "$(seg $START_W)" "$(seg $TOTAL_W)"
printf '| %-*s | %-*s | %-*s | %-*s | %-*s |\n' "$ID_W" "ID" "$USER_W" "Username" "$IP_W" "IP Address[:port]" "$START_W" "Start" "$TOTAL_W" "Total"
printf '+-%s-+-%s-+-%s-+-%s-+-%s-+\n' "$(seg $ID_W)" "$(seg $USER_W)" "$(seg $IP_W)" "$(seg $START_W)" "$(seg $TOTAL_W)"

printed=0
for idx in "${sorted_idx[@]}"; do
  pid="${rows_pid[$idx]}"; user="${rows_user[$idx]}"
  ipport="${rows_ip[$idx]}"; start_human="${rows_start_human[$idx]}"
  total="${user_total[$user]:-1}"

  sanitized_pid="$(sanitize_field "$pid")"
  if [[ "$sanitized_pid" =~ ^[0-9]+$ ]]; then
    if [ "${#sanitized_pid}" -gt "$ID_W" ]; then
      t_pid="${sanitized_pid:0:$ID_W}"
    else
      t_pid="$sanitized_pid"
    fi
  else
    t_pid="$(truncate_field "$pid" "$ID_W")"
  fi

  t_user="$(truncate_field "$user" "$USER_W")"
  t_ipport="$(truncate_field "$ipport" "$IP_W")"
  t_start="$(truncate_field "$start_human" "$START_W")"
  t_total="$(truncate_field "$total" "$TOTAL_W")"

  printf '| %-*s | %-*s | %-*s | %-*s | %-*s |\n' "$ID_W" "$t_pid" "$USER_W" "$t_user" "$IP_W" "$t_ipport" "$START_W" "$t_start" "$TOTAL_W" "$t_total"
  printf '+-%s-+-%s-+-%s-+-%s-+-%s-+\n' "$(seg $ID_W)" "$(seg $USER_W)" "$(seg $IP_W)" "$(seg $START_W)" "$(seg $TOTAL_W)"
  printed=1
done

if [ "$printed" -eq 0 ]; then
  printf '| %-*s | %-*s | %-*s | %-*s | %-*s |\n' $ID_W "(none)" $USER_W "-" $IP_W "-" $START_W "-" $TOTAL_W "-"
  printf '+-%s-+-%s-+-%s-+-%s-+-%s-+\n' "$(seg $ID_W)" "$(seg $USER_W)" "$(seg $IP_W)" "$(seg $START_W)" "$(seg $TOTAL_W)"
  echo "(No User Login Detected)"
fi

echo ""
if [ "${rows_count:-0}" -gt 0 ]; then
  echo "Total All Online Users: $rows_count"
else
  echo "(No OpenSSH Sessions Detected)"
fi
echo "------------------------------------"

# ---------------------------
# OpenVPN TCP
# ---------------------------
if [ -f "/etc/openvpn/server/openvpn-tcp.log" ]; then
  echo
  echo "----=[ OpenVPN TCP User Login ]=----"
  echo "Username  |  IP Address  |  Connected Since"
  echo "------------------------------------"
  grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-tcp.log 2>/dev/null | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' || true
fi

# ---------------------------
# OpenVPN UDP
# ---------------------------
if [ -f "/etc/openvpn/server/openvpn-udp.log" ]; then
  echo
  echo "----=[ OpenVPN UDP User Login ]=----"
  echo "Username  |  IP Address  |  Connected Since"
  echo "------------------------------------"
  grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-udp.log 2>/dev/null | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' || true
fi

exit 0
