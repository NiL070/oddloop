#!/bin/bash

GitUser="NiL070"

# Detail VPS
IPVPS=$(curl -sS ipv4.icanhazip.com)
domain=$(cat /usr/local/etc/xray/domain)
ISP=$(curl -s ipinfo.io/org | cut -d " " -f 2-10 )
OS=$(hostnamectl 2>/dev/null | awk -F': ' '/Operating System/ {print $2; exit}')
OS2=$(lsb_release -ds)
CITY=$(curl -s ipinfo.io/city)
WKT=$(curl -s ipinfo.io/timezone)
IPV6=$(curl -s -6 ipv6.icanhazip.com)
clear

# detail cpu ram
cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo)
#cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
freq=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo)
tram=$(free -m | awk 'NR==2 {print $2}')
uram=$(free -m | awk 'NR==2 {print $3}')
fram=$(free -m | awk 'NR==2 {print $4}')
clear

# Dapatkan jumlah CPU cores
cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)

# Tentukan nama berdasarkan jumlah cores
case $cores in
  1)
    name="Single-Core"
    ;;
  2)
    name="Dual-Core"
    ;;
  4)
    name="Quad-Core"
    ;;
  *)
    name="$cores-Core"
    ;;
esac

echo "$name"
clear

# OS Uptime
uptime="$(uptime -p | cut -d " " -f 2-10)"

clear

# Getting CPU Information
cpu_usage1="$(ps aux | awk 'BEGIN {sum=0} {sum+=$3}; END {print sum}')"
cpu_usage="$((${cpu_usage1/\.*/} / ${corediilik:-1}))"
cpu_usage+=" %"

clear

# Xray-Core Version
xrays_path=$(which xray)
xrays_version=$("$xrays_path" --version 2>&1)
current_version=$(echo "$xrays_version" | awk '/Xray/{print $2}')
# CERTIFICATE STATUS
d1=$(date -d "$valid" +%s)
d2=$(date -d "$today" +%s)
certifacate=$(((d1 - d2) / 86400))
# TOTAL ACC CREATE VMESS WS
vmess=$(grep -c -E "^#vms " "/usr/local/etc/xray/config.json")
# TOTAL ACC CREATE  VLESS WS
vless=$(grep -c -E "^#vls " "/usr/local/etc/xray/config.json")
# TOTAL ACC CREATE  VLESS TCP XTLS
xtls=$(grep -c -E "^#vxtls " "/usr/local/etc/xray/config.json")
# TOTAL ACC CREATE  TROJAN
trtls=$(grep -c -E "^#trx " "/usr/local/etc/xray/config.json")
# TOTAL ACC CREATE  TROJAN WS TLS
trws=$(grep -c -E "^#trws " "/usr/local/etc/xray/config.json")
# TOTAL ACC CREATE OVPN SSH
total_ssh="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)"
# PROVIDED
creditt=$(cat /root/provided)
# BANNER COLOUR
banner_colour=$(cat /etc/banner)
# TEXT ON BOX COLOUR
box=$(cat /etc/box)
# LINE COLOUR
line=$(cat /etc/line)
# TEXT COLOUR ON TOP
text=$(cat /etc/text)
# TEXT COLOUR BELOW
below=$(cat /etc/below)
# BACKGROUND TEXT COLOUR
back_text=$(cat /etc/back)
# NUMBER COLOUR
number=$(cat /etc/number)
# BANNER
banner=$(cat /usr/bin/bannerku)
ascii=$(cat /usr/bin/test)
clear

# ------------------------------
# Detect interface yang betul-betul vnstat monitor
# ------------------------------
# 1) cuba ambil interface default route (paling tepat untuk server)
iface="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"

# 2) kalau vnstat ada list interface dia sendiri, guna itu sebagai fallback
if command -v vnstat >/dev/null 2>&1; then
  iflist="$(vnstat --iflist 1 2>/dev/null || vnstat --iflist 2>/dev/null || true)"
  vn_iface="$(printf '%s\n' "$iflist" \
    | awk 'BEGIN{IGNORECASE=1}
           /^[[:space:]]*$/ {next}
           /available/ {next}
           /^[[:space:]]*lo[[:space:]]*$/ {next}
           /^[[:space:]]*[[:alnum:]][[:alnum:]._:-]*[[:space:]]*$/ {gsub(/^[ \t]+|[ \t]+$/, "", $0); print $0; exit}')"

  # kalau default-route iface tak wujud dalam vnstat list, guna vn_iface
  if [ -z "${iface:-}" ] || ! printf '%s\n' "$iflist" | grep -qw "${iface:-}"; then
    [ -n "${vn_iface:-}" ] && iface="$vn_iface"
  fi
fi

# 3) last fallback: ambil first non-lo dari ip link
if [ -z "${iface:-}" ]; then
  iface="$(ip -o link show | awk -F': ' '$2!="lo"{print $2; exit}')"
fi

# ------------------------------
# Helper: ambil value pertama yang tak kosong
# ------------------------------
first_nonempty() {
  for v in "$@"; do
    if [ -n "$v" ]; then
      printf '%s' "$v"
      return 0
    fi
  done
  printf '%s' "N/A"
}

# ------------------------------
# Paksa vnstat update (kalau ada permission)
# ------------------------------
# Nota: kalau bukan root, command ni mungkin gagal — tak apa.
vnstat -u -i "$iface" >/dev/null 2>&1 || true

# ------------------------------
# Parser line vnstat table: "DATE  RX | TX | TOTAL"
# Ambil nilai RX/TX/TOTAL sebagai "num unit"
# ------------------------------
parse_vn_line() {
  awk -F'\\|' '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    {
      f1=trim($1); f2=trim($2); f3=trim($3);

      # RX berada di hujung field pertama (sebab awal field ada tarikh/label)
      n=split(f1,a,/[ \t]+/); rx=a[n-1]" "a[n];

      # TX dan TOTAL biasanya terus bermula dengan "num unit"
      m=split(f2,b,/[ \t]+/); tx=b[1]" "b[2];
      k=split(f3,c,/[ \t]+/); tt=c[1]" "c[2];

      print rx "|" tx "|" tt;
    }' <<<"$1"
}

# ------------------------------
# Ambil TODAY & YESTERDAY tanpa header "day rx|tx|total"
# Kalau hanya ada 1 baris (today je), yesterday biar kosong (nanti fallback jadi N/A)
# ------------------------------
mapfile -t day_lines < <(
  vnstat --style 0 -i "$iface" -d 2 2>/dev/null \
  | awk -F'\\|' 'NF>=3 && $0 !~ /estimated/ && $0 ~ /[0-9]/ {print $0}'
)

if [ "${#day_lines[@]}" -ge 2 ]; then
  y_line="${day_lines[-2]}"
  t_line="${day_lines[-1]}"

  y_parsed="$(parse_vn_line "$y_line")"
  t_parsed="$(parse_vn_line "$t_line")"

  dyest="$(cut -d'|' -f1 <<<"$y_parsed")"; uyest="$(cut -d'|' -f2 <<<"$y_parsed")"; tyest="$(cut -d'|' -f3 <<<"$y_parsed")"
  dtoday="$(cut -d'|' -f1 <<<"$t_parsed")"; utoday="$(cut -d'|' -f2 <<<"$t_parsed")"; ttoday="$(cut -d'|' -f3 <<<"$t_parsed")"

elif [ "${#day_lines[@]}" -eq 1 ]; then
  # only today exists
  t_line="${day_lines[-1]}"
  t_parsed="$(parse_vn_line "$t_line")"
  dtoday="$(cut -d'|' -f1 <<<"$t_parsed")"; utoday="$(cut -d'|' -f2 <<<"$t_parsed")"; ttoday="$(cut -d'|' -f3 <<<"$t_parsed")"

  dyest=""; uyest=""; tyest=""   # biar fallback jadi N/A
fi

# ------------------------------
# Ambil MONTH (ambil last line yang bukan "estimated")
# ------------------------------
m_line="$(
  vnstat --style 0 -i "$iface" -m 2 2>/dev/null \
  | awk -F'\\|' 'NF>=3 && $0 !~ /estimated/ {line=$0} END{print line}'
)"

if [ -n "$m_line" ]; then
  m_parsed="$(parse_vn_line "$m_line")"
  dmon="$(cut -d'|' -f1 <<<"$m_parsed")"
  umon="$(cut -d'|' -f2 <<<"$m_parsed")"
  tmon="$(cut -d'|' -f3 <<<"$m_parsed")"
fi

# ------------------------------
# Fallback akhir (kalau masih kosong)
# ------------------------------
dmon="$(first_nonempty "${dmon:-}")"
umon="$(first_nonempty "${umon:-}")"
tmon="$(first_nonempty "${tmon:-}")"

dtoday="$(first_nonempty "${dtoday:-}")"
utoday="$(first_nonempty "${utoday:-}")"
ttoday="$(first_nonempty "${ttoday:-}")"

dyest="$(first_nonempty "${dyest:-}")"
uyest="$(first_nonempty "${uyest:-}")"
tyest="$(first_nonempty "${tyest:-}")"
clear
echo -e "\e[$banner_colour"
figlet -f $ascii "$banner"
echo -e "\e[$text VPS Script"
GREEN=$'\e[32m'
RED=$'\e[31m'
NC=$'\e[0m'
# ================== PREP DATA ==================
cname_clean=$(echo "$cname" | sed 's/^[[:space:]]*//')
freq_clean="$(echo "$freq" | sed 's/^[[:space:]]*//') MHz"
os_raw=$(hostnamectl | awk -F ': ' '/Operating System/ {print $2}')
os=$(echo "$os_raw" | sed 's/ GNU\/Linux//')
# Expired text
if [ "$exp" = "LIFETIME" ]; then
  expired_display="$exp ${GREEN}(Active)${NC}"
else
  expired_display="$exp ${RED}(Expired)${NC}"
fi
# ================== LEBAR BOX ==================
# BOXW = lebar ruang teks di dalam di antara dua │ │
BOXW=59          # <-- UBAH NILAI INI UNTUK KECIL/BESAR BOX
LABELW=11        # lebar label (supaya ":" sejajar)
BORDER=$(printf '═%.0s' $(seq 1 $((BOXW+2))))
row_info() {
  local label="$1"
  local value="$2"
  local raw plain plen pad
  printf -v raw "%-*s : %s" "$LABELW" "$label" "$value"
  plain=$(printf '%s' "$raw" | sed -r 's/\x1B\[[0-9;]*m//g')
  plen=${#plain}

  pad=$((BOXW - plen))
  if [ "$pad" -lt 0 ]; then
    pad=0
  fi
  printf " \e[$line│\e[m \e[$text%s%*s\e[m \e[$line│\e[m\n" "$raw" "$pad" ""
}
# ================== HEADER BOX ==================
echo -e " \e[$line╒${BORDER}╕\e[m"
echo -e "  \e[$back_text                    \e[30m[\e[$box SERVER INFORMATION\e[30m ]\e[1m                   \e[m"
echo -e " \e[$line╞${BORDER}╡\e[m"
# ================== ISI BOX ==================
row_info "CPU Model"   "$cname_clean"
row_info "CPU Freq"    "$freq_clean"
row_info "CPU Cores"   "$cores"
row_info "CPU Usage"   "$cpu_usage"
row_info "OS"          "$os"
row_info "Kernel"      "$(uname -r)"
row_info "RAM"         "$uram MB / $tram MB"
row_info "Uptime"      "$uptime"
row_info "IP Address"  "$IPVPS"
row_info "Domain"      "$domain"
row_info "XrayCore"    "$current_version"
row_info "Provider"    "$creditt"
echo -e " \e[$line╘${BORDER}╛\e[m"
# --- kemaskan output table (ANSI color betul) ---

# pastikan $text boleh jadi "1;37" atau "1;37m"
if [ -n "${text:-}" ]; then
  textc="${text%m}"               # buang trailing 'm' kalau ada
  C1="$(printf '\033[%sm' "$textc")"
  C0="$(printf '\033[0m')"
else
  C1=""; C0=""
fi

# fallback kalau kosong
dtoday="${dtoday:-N/A}"; dyest="${dyest:-N/A}"; dmon="${dmon:-N/A}"
utoday="${utoday:-N/A}"; uyest="${uyest:-N/A}"; umon="${umon:-N/A}"
ttoday="${ttoday:-N/A}"; tyest="${tyest:-N/A}"; tmon="${tmon:-N/A}"

# trim whitespace (bash)
trim() { local s="$*"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
dtoday="$(trim "$dtoday")"; dyest="$(trim "$dyest")"; dmon="$(trim "$dmon")"
utoday="$(trim "$utoday")"; uyest="$(trim "$uyest")"; umon="$(trim "$umon")"
ttoday="$(trim "$ttoday")"; tyest="$(trim "$tyest")"; tmon="$(trim "$tmon")"

# widths
wlabel=10
wcol=14
tmon_br="[$tmon]"

printf "  %s%-*s%s %s%*s %*s %*s%s\n" \
  "$C1" "$wlabel" "Traffic" "$C0" \
  "$C1" "$wcol" "Today" "$wcol" "Yesterday" "$wcol" "Month" "$C0"

printf "  %s%-*s%s %s%*s %*s %*s%s\n" \
  "$C1" "$wlabel" "Download" "$C0" \
  "$C1" "$wcol" "$dtoday" "$wcol" "$dyest" "$wcol" "$dmon" "$C0"

printf "  %s%-*s%s %s%*s %*s %*s%s\n" \
  "$C1" "$wlabel" "Upload" "$C0" \
  "$C1" "$wcol" "$utoday" "$wcol" "$uyest" "$wcol" "$umon" "$C0"

printf "  %s%-*s%s %s%*s %*s %*s%s\n" \
  "$C1" "$wlabel" "Total" "$C0" \
  "$C1" "$wcol" "$ttoday" "$wcol" "$tyest" "$wcol" "$tmon_br" "$C0"
echo -e " \e[$line╘═════════════════════════════════════════════════════════════╛\e[m"
echo -e " \e[$text Ssh/Ovpn   V2ray   Vless   Vlessxtls   Trojan-Ws   Trojan-Tls \e[0m "    
echo -e " \e[$below    $total_ssh         $vmess       $vless        $xtls           $trws           $trtls \e[0m "
echo -e " \e[$line╒═════════════════════════════════════════════════════════════╕\e[m"
echo -e "  \e[$back_text                        \e[30m[\e[$box PANEL MENU\e[30m ]\e[1m                       \e[m"
echo -e " \e[$line╘═════════════════════════════════════════════════════════════╛\e[m"
echo -e "  \e[$number (•1)\e[m \e[$below XRAY VMESS & VLESS\e[m"
echo -e "  \e[$number (•2)\e[m \e[$below TROJAN XRAY & WS\e[m"
echo -e "  \e[$number (•3)\e[m \e[$below SSHWS & OPENVPN\e[m" 
echo -e "  \e[$number (•4)\e[m \e[$below NOOBZVPN MENU\e[m" 
echo -e " \e[$line╒═════════════════════════════════════════════════════════════╕\e[m"
echo -e "  \e[$back_text                        \e[30m[\e[$box VPS MENU\e[30m ]\e[1m                         \e[m"
echo -e " \e[$line╘═════════════════════════════════════════════════════════════╛\e[m"
echo -e "  \e[$number (•5)\e[m \e[$below SYSTEM MENU\e[m          \e[$number (•9)\e[m \e[$below INFO ALL PORT\e[m"
echo -e "  \e[$number (•6)\e[m \e[$below THEMES MENU\e[m          \e[$number (10)\e[m \e[$below CLEAR EXPIRED FILES\e[m"
echo -e "  \e[$number (•7)\e[m \e[$below CHANGE PORT\e[m          \e[$number (11)\e[m \e[$below CLEAR LOG VPS\e[m"
echo -e "  \e[$number (•8)\e[m \e[$below CHECK RUNNING\e[m        \e[$number (12)\e[m \e[$below REBOOT VPS\e[m"
echo -e ""
echo -e "  \e[$below[Ctrl + C] For exit from main menu\e[m"
echo -e " \e[$line╒═════════════════════════════════════════════════════════════╕\e[m"
echo -e "  \e[$below Version Name         : SSH XRAY WEBSOCKET MULTIPORT V3.0"
echo -e "  \e[$below Autoscript By        : NiLphreakz"
echo -e "  \e[$below Certificate Status   : Expired in $certifacate days"
echo -e " \e[$line╘═════════════════════════════════════════════════════════════╛\e[m"
echo -e "\e[$below "
read -p " Select menu :  " menu
echo -e ""
case $menu in
1)
    xraay
    ;;
2)
    trojaan
    ;;
3)
    ssh2
    ;;
4)
    menu-noobzvpn
    ;;	
5)
    system
    ;;
6)
    themes
    ;;
7)
    change-port
    ;;
8)
    check-sc
    ;;
9)
    cat log-install.txt
    ;;
10)
    delete && xp
    ;;
11)
    clear-log
    ;;
12)
    reboot
    ;;
x)
    clear
    exit
    echo -e "\e[1;31mPlease Type menu For More Option, Thank You\e[0m"
    ;;
*)
    clear
    echo -e "\e[1;31mPlease enter an correct number\e[0m"
    sleep 1
    menu
    ;;
esac
