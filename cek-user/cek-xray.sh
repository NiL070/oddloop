#!/bin/bash

clear
LOGFILE="/var/log/xray/access.log"
LOGLINES=50000

echo -e "\033[0;34m------------------------------------------\033[0m"
echo -e "\E[0;44;37m  ALL USER LOGIN XRAY VLESS/VMESS/TROJAN  \E[0m"
echo -e "\033[0;34m------------------------------------------\033[0m"

if [[ ! -f "$LOGFILE" ]]; then
  echo "Log file tak jumpa: $LOGFILE"
  echo ""
  read -n 1 -s -r -p "Press any key to back on main menu"
  exec menu
fi

tail -n "$LOGLINES" "$LOGFILE" 2>/dev/null | \
awk '
function clean_ip(s) {
  sub(/^tcp:/, "", s)
  sub(/^udp:/, "", s)
  gsub(/^\[/, "", s)
  sub(/\].*/, "", s)
  sub(/:.*/, "", s)
  return s
}
function clean_user(s) {
  sub(/^email:/, "", s)
  gsub(/^[[:space:]]+/, "", s)
  gsub(/[[:space:]]+$/, "", s)
  return s
}
function looks_like_ip(s) {
  # IPv4
  if (s ~ /^[0-9.]+$/ && s ~ /\./) return 1
  # IPv6
  if (s ~ /^[0-9a-fA-F:]+$/ && s ~ /:/) return 1
  return 0
}

{
  ip=""; user="";

  # username/email (support "email: USER" & "email:USER")
  for (i=1; i<=NF; i++) {
    if ($i=="email:" && (i+1)<=NF) { user=$(i+1); break }
    if ($i ~ /^email:/)            { user=clean_user($i); break }
  }
  if (user=="") next

  # Ambil client IP selepas perkataan "from" (format log kau: from IP:PORT)
  for (i=1; i<=NF; i++) {
    if ($i=="from" && (i+1)<=NF) {
      ip = clean_ip($(i+1))
      break
    }
  }

  # fallback: kadang-kadang field tetap (cth: 2025/... from IP:PORT ...)
  if (ip=="" && NF>=4) ip = clean_ip($4)

  if (!looks_like_ip(ip)) next

  key = user SUBSEP ip
  if (!(key in seen)) {
    seen[key]=1
    ips[user] = ips[user] ip "|"
  }
}

END {
  for (u in ips) {
    printf "%s\t%s\n", u, ips[u]
  }
}' | \
sort -t $'\t' -k1,1 | \
awk -F'\t' '
BEGIN { user_idx=0 }
{
  user=$1
  ipstr=$2

  user_idx++
  printf "%d) user : %s\n", user_idx, user

  n = split(ipstr, a, /\|/)
  idx=0
  for (i=1; i<=n; i++) {
    if (a[i] != "") {
      idx++
      printf "%d. %s\n", idx, a[i]
    }
  }
  print ""
  print "------------------------------------------"
}
END {
  if (user_idx==0) {
    print "No User Login Detected."
    print "------------------------------------------"
  }
}'

echo ""
read -n 1 -s -r -p "Press any key to back on main menu"
exec menu
