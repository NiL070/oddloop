#!/bin/bash
#wget https://github.com/${GitUser}/
GitUser="NiL070"

#IZIN SCRIPT
MYIP=$(curl -s ipv4.icanhazip.com || curl -s ipinfo.io/ip || curl -s ifconfig.me)
clear

# Detail VPS
OS=$(hostnamectl 2>/dev/null | awk -F': ' '/Operating System/ {print $2; exit}')
OS2=$(lsb_release -ds)
domain=$(cat /usr/local/etc/xray/domain)
ISP=$(curl -s ipv4.icanhazip.com || curl -s ipinfo.io/ip || curl -s ifconfig.me)
CITY=$(curl -s ipinfo.io/city)
WKT=$(curl -s ipinfo.io/timezone)
IPVPS=$(curl -s ipv4.icanhazip.com || curl -s ipinfo.io/ip || curl -s ifconfig.me)
IPV6=$(curl -s -6 ipv6.icanhazip.com)

# if no IPv6
IPVPS=$(curl -s ipv4.icanhazip.com || curl -s ipinfo.io/ip || curl -s ifconfig.me)
IPV6=$(curl -s -6 ipv6.icanhazip.com)

if [ -z "$IPV6" ]; then
    IPV6="\e[32m(IPv4 only)\e[0m"
else
    IPV6="\e[32m($IPV6)\e[0m"
fi

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

# USERNAME
rm -f /usr/bin/user
username=$(curl https://raw.githubusercontent.com/${GitUser}/allow/main/ipvps.conf | grep $MYIP | awk '{print $2}')
echo "$username" >/usr/bin/user

# Order ID
rm -f /usr/bin/ver
user=$(curl https://raw.githubusercontent.com/${GitUser}/allow/main/ipvps.conf | grep $MYIP | awk '{print $3}')
echo "$user" >/usr/bin/ver

# validity
rm -f /usr/bin/e
valid=$(curl https://raw.githubusercontent.com/${GitUser}/allow/main/ipvps.conf | grep $MYIP | awk '{print $4}')
echo "$valid" >/usr/bin/e

# DETAIL ORDER
username=$(cat /usr/bin/user)
oid=$(cat /usr/bin/ver)
exp=$(cat /usr/bin/e)
clear
version=$(cat /home/ver)
ver=$( curl https://raw.githubusercontent.com/${GitUser}/version/main/version.conf )
clear

# CEK UPDATE
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info1="${Green_font_prefix}($version)${Font_color_suffix}"
Info2="${Green_font_prefix}(LATEST VERSION)${Font_color_suffix}"
Error="Version ${Green_font_prefix}[$ver]${Font_color_suffix} available${Red_font_prefix}[Please Update]${Font_color_suffix}"
version=$(cat /home/ver)
new_version=$( curl https://raw.githubusercontent.com/${GitUser}/version/main/version.conf | grep $version )
#Status Version
if [ $version = $new_version ]; then
stl="${Info2}"
else
stl="${Error}"
fi
clear

# Getting CPU Information
cpu_usage1="$(ps aux | awk 'BEGIN {sum=0} {sum+=$3}; END {print sum}')"
cpu_usage="$((${cpu_usage1/\.*/} / ${corediilik:-1}))"
cpu_usage+=" %"

# STATUS EXPIRED ACTIVE
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[4$below" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}(Active)${Font_color_suffix}"
Error="${Green_font_prefix}${Font_color_suffix}${Red_font_prefix}[EXPIRED]${Font_color_suffix}"

today=$(date -d "0 days" +"%Y-%m-%d")
Exp1=$(curl https://raw.githubusercontent.com/${GitUser}/allow/main/ipvps.conf | grep $MYIP | awk '{print $4}')
if [[ $today < $Exp1 ]]; then
    sts="${Info}"
else
    sts="${Error}"
fi
echo -e "\e[32mloading...\e[0m"
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
vmess=$(grep -c -E "^#vms " "/usr/local/etc/xray/vmess.json")
# TOTAL ACC CREATE  VLESS WS
vless=$(grep -c -E "^#vls " "/usr/local/etc/xray/vless.json")
# TOTAL ACC CREATE  VLESS TCP XTLS
xtls=$(grep -c -E "^#vxtls " "/usr/local/etc/xray/config.json")
# TOTAL ACC CREATE  TROJAN
trtls=$(grep -c -E "^#trx " "/usr/local/etc/xray/tcp.json")
# TOTAL ACC CREATE  TROJAN WS TLS
trws=$(grep -c -E "^#trws " "/usr/local/etc/xray/trojan.json")
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
# Detect interface vnstat
# ------------------------------
iface="$(ifconfig 2>/dev/null | awk 'NR==1 {sub(/:$/, "", $1); print $1}')"
if [ -z "$iface" ]; then
    iface=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
fi

# ------------------------------
# Prepare date variables
# ------------------------------
today=$(date +%Y-%m-%d)
yesterday=$(date -d 'yesterday' +%Y-%m-%d)
month=$(date +%Y-%m)
month_deb=$(date +"%b '%y")  # For Debian old format
totalmon="$(vnstat | grep "total:" | awk '{print $8, $9}')"

# ------------------------------
# 1️⃣ Modern v2 global
# ------------------------------
dmon="$(vnstat -m | grep "$month" | awk '{print $2, $3}')"
umon="$(vnstat -m | grep "$month" | awk '{print $5, $6}')"
tmon="$(vnstat -m | grep "$month" | awk '{print $8, $9}')"

dtoday="$(vnstat -d | grep "$today" | awk '{print $2, $3}')"
utoday="$(vnstat -d | grep "$today" | awk '{print $5, $6}')"
ttoday="$(vnstat -d | grep "$today" | awk '{print $8, $9}')"

dyest="$(vnstat -d | grep "$yesterday" | awk '{print $2, $3}')"
uyest="$(vnstat -d | grep "$yesterday" | awk '{print $5, $6}')"
tyest="$(vnstat -d | grep "$yesterday" | awk '{print $8, $9}')"

# ------------------------------
# 2️⃣ Modern v2 interface (-i $iface)
# ------------------------------
dmon_if2="$(vnstat -i $iface -m | grep "$month" | awk '{print $2, $3}')"
umon_if2="$(vnstat -i $iface -m | grep "$month" | awk '{print $5, $6}')"
tmon_if2="$(vnstat -i $iface -m | grep "$month" | awk '{print $8, $9}')"

dtoday_if2="$(vnstat -i $iface -d | grep "$today" | awk '{print $2, $3}')"
utoday_if2="$(vnstat -i $iface -d | grep "$today" | awk '{print $5, $6}')"
ttoday_if2="$(vnstat -i $iface -d | grep "$today" | awk '{print $8, $9}')"

dyest_if2="$(vnstat -i $iface -d | grep "$yesterday" | awk '{print $2, $3}')"
uyest_if2="$(vnstat -i $iface -d | grep "$yesterday" | awk '{print $5, $6}')"
tyest_if2="$(vnstat -i $iface -d | grep "$yesterday" | awk '{print $8, $9}')"

# ------------------------------
# 3️⃣ v1 global (fallback)
# ------------------------------
dmon_v1="$(vnstat -m | grep "$month_deb" | awk '{print $3" "substr($4,1,1)}')"
umon_v1="$(vnstat -m | grep "$month_deb" | awk '{print $6" "substr($7,1,1)}')"
tmon_v1="$(vnstat -m | grep "$month_deb" | awk '{print $9" "substr($10,1,1)}')"

dtoday_v1="$(vnstat -d | grep "today" | awk '{print $2" "substr($3,1,1)}')"
utoday_v1="$(vnstat -d | grep "today" | awk '{print $5" "substr($6,1,1)}')"
ttoday_v1="$(vnstat -d | grep "today" | awk '{print $8" "substr($9,1,1)}')"

dyest_v1="$(vnstat -d | grep "yesterday" | awk '{print $2" "substr($3,1,1)}')"
uyest_v1="$(vnstat -d | grep "yesterday" | awk '{print $5" "substr($6,1,1)}')"
tyest_v1="$(vnstat -d | grep "yesterday" | awk '{print $8" "substr($9,1,1)}')"

# ------------------------------
# 4️⃣ v1 interface (-i $iface)
# ------------------------------
dmon_if1="$(vnstat -i $iface -m | grep "$month_deb" | awk '{print $3" "substr($4,1,1)}')"
umon_if1="$(vnstat -i $iface -m | grep "$month_deb" | awk '{print $6" "substr($7,1,1)}')"
tmon_if1="$(vnstat -i $iface -m | grep "$month_deb" | awk '{print $9" "substr($10,1,1)}')"

dtoday_if1="$(vnstat -i $iface | grep "today" | awk '{print $2" "substr($3,1,1)}')"
utoday_if1="$(vnstat -i $iface | grep "today" | awk '{print $5" "substr($6,1,1)}')"
ttoday_if1="$(vnstat -i $iface | grep "today" | awk '{print $8" "substr($9,1,1)}')"

dyest_if1="$(vnstat -i $iface | grep "yesterday" | awk '{print $2" "substr($3,1,1)}')"
uyest_if1="$(vnstat -i $iface | grep "yesterday" | awk '{print $5" "substr($6,1,1)}')"
tyest_if1="$(vnstat -i $iface | grep "yesterday" | awk '{print $8" "substr($9,1,1)}')"

# ------------------------------
# Fallback logic: pilih yang ada output
# ------------------------------
dmon="${dmon:-$dmon_if2:-$dmon_v1:-$dmon_if1}"
umon="${umon:-$umon_if2:-$umon_v1:-$umon_if1}"
tmon="${tmon:-$tmon_if2:-$tmon_v1:-$tmon_if1}"

dtoday="${dtoday:-$dtoday_if2:-$dtoday_v1:-$dtoday_if1}"
utoday="${utoday:-$utoday_if2:-$utoday_v1:-$utoday_if1}"
ttoday="${ttoday:-$ttoday_if2:-$ttoday_v1:-$ttoday_if1}"

dyest="${dyest:-$dyest_if2:-$dyest_v1:-$dyest_if1}"
uyest="${uyest:-$uyest_if2:-$uyest_v1:-$uyest_if1}"
tyest="${tyest:-$tyest_if2:-$tyest_v1:-$tyest_if1}"
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
echo -e "  \e[$text Traffic\e[0m       \e[${text}Today      Yesterday        Month   "
echo -e "  \e[$text Download\e[0m   \e[${text}   $dtoday    $dyest       $dmon   \e[0m"
echo -e "  \e[$text Upload\e[0m     \e[${text}   $utoday    $uyest       $umon   \e[0m"
echo -e "  \e[$text Total\e[0m       \e[${text}  $ttoday    $tyest       [$tmon]  \e[0m "
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
echo -e "  \e[$below Version Name         : SSH XRAY WEBSOCKET MULTIPORT V2.0"
echo -e "  \e[$below Autoscript By        : NiLphreakz"
echo -e "  \e[$below Certificate Status   : Expired in $certifacate days"
echo -e "  \e[$below Client Name          : $username"
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
