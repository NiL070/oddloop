#!/bin/bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[97m"
BOLD="\e[1m"
RESET="\e[0m"

LICENSE_KEY_VALID="nilphreakz07"
IP_MODE="ipv4"  # default

check_license() {
    echo
    echo -ne "${YELLOW}Masukkan License Key: ${RESET}"
    read LICENSE_INPUT

    if [ "$LICENSE_INPUT" != "$LICENSE_KEY_VALID" ]; then
        echo
        echo -e "${RED}License Key tidak sah!${RESET}"
        return 1
    fi

    echo -e "${GREEN}License Key diterima.${RESET}"
    return 0
}

ask_ip_mode() {
    echo
    echo -ne "${YELLOW}Enable IPv4 + IPv6? [ default: no (IPv4 only) ] [y/N]: ${RESET}"
    read ans

    ans="$(echo "$ans" | tr '[:upper:]' '[:lower:]')"

    if [ "$ans" = "y" ] || [ "$ans" = "yes" ]; then
        IP_MODE="dual"
        echo -e "${GREEN}Dipilih: IPv4 + IPv6.${RESET}"
    else
        IP_MODE="ipv4"
        echo -e "${GREEN}Dipilih: IPv4 only (default).${RESET}"
    fi
}

set_ip_mode() {
    if [ "$1" = "dual" ]; then
        echo -e "${BLUE}Setting mode: IPv4 + IPv6 (enable IPv6)...${RESET}"
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
        sysctl -w net.ipv6.conf.default.disable_ipv6=0
    else
        echo -e "${BLUE}Setting mode: IPv4 only (disable IPv6)...${RESET}"
        sysctl -w net.ipv6.conf.all.disable_ipv6=1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1
    fi
}

install_v2() {
    local ip_mode="$1"
    echo -e "${YELLOW}${BOLD}>> Installing Script Multiport Version 2.0 [ OLD XRAYCORE ]...${RESET}"

    set_ip_mode "$ip_mode"

    apt update -y && \
    apt upgrade -y && \
    apt dist-upgrade -y && \
    apt update && \
    apt install -y bzip2 gzip coreutils screen wget curl && \
    wget https://raw.githubusercontent.com/NiL070/oddloop/main/setup.sh && \
    chmod +x setup.sh && \
    sed -i -e 's/\r$//' setup.sh && \
    screen -S setup ./setup.sh
}

install_v3() {
    local ip_mode="$1"
    echo -e "${YELLOW}${BOLD}>> Installing Script Multiport Version 3.0 [ LATEST XRAYCORE + NEW SERVICES ]...${RESET}"

    set_ip_mode "$ip_mode"

    apt update -y && \
    apt upgrade -y && \
    apt dist-upgrade -y && \
    apt update && \
    apt install -y bzip2 gzip coreutils screen wget curl && \
    wget https://raw.githubusercontent.com/NiL070/oddloop/main/setup2.sh && \
    chmod +x setup2.sh && \
    sed -i -e 's/\r$//' setup2.sh && \
    screen -S setup ./setup2.sh
}

while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}             ${BOLD}${MAGENTA}SCRIPT MULTIPORT BY NILPHREAKZ${RESET}             ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}1)${RESET} Install Version 2.0 [OLD XRAYCORE]                 ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}2)${RESET} Install Version 3.0 [LATEST XRAYCORE+NEW SERVICES] ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${RED}0)${RESET} Exit                                               ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -ne "${BOLD}${WHITE}Pilih option [0-2]: ${RESET}"
    read choice

    case "$choice" in
        1)
            if check_license; then
                ask_ip_mode
                echo
                install_v2 "$IP_MODE"
                echo
                echo -e "${GREEN}Thank you....${RESET}"
            fi
            echo -ne "${CYAN}Enjoy...${RESET}"
            read dummy
            ;;
        2)
            if check_license; then
                ask_ip_mode
                echo
                install_v3 "$IP_MODE"
                echo
                echo -e "${GREEN}Thank you....${RESET}"
            fi
            echo -ne "${CYAN}Enjoy...${RESET}"
            read dummy
            ;;
        0)
            echo
            echo -e "${RED}${BOLD}Keluar dari installer. Bye!${RESET}"
            exit 0
            ;;
        *)
            echo
            echo -e "${RED}Pilihan tak sah! Sila pilih 0, 1 atau 2.${RESET}"
            echo -ne "${CYAN}Tekan ENTER untuk cuba lagi...${RESET}"
            read dummy
            ;;
    esac
done


