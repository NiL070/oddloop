#!/bin/bash

# Warna untuk teks
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Tiada warna (reset)

print_user_table() {
    local user="$1"
    local expiry="$2"
    local left="$3"
    printf "\n${YELLOW}%-18s %-12s %-9s${NC}\n" "USERNAME" "EXPIRY" "LEFT"
    printf '%s\n' "---------------------------------------------"
    printf "%-18s %-12s %-9s\n" "$user" "$expiry" "$left"
    printf '\n'
}

CONFIG_FILE="/etc/noobzvpns/config.toml"

edit_config() {
    echo -e "${CYAN}Menu Edit Config /etc/noobzvpns/config.toml${NC}"
    echo -e "${GREEN}1.${NC} Edit identifier"
    echo -e "${GREEN}2.${NC} Buka config file location"
    echo -e "${GREEN}0.${NC} Kembali ke menu utama"
    read -p "Pilih nombor: " choice

    case $choice in
        1)
            current_id=$(sed -n 's/^identifier = "\(.*\)"/\1/p' "$CONFIG_FILE")
            echo -e "${YELLOW}Identifier sekarang:${NC} $current_id"
            read -p "Masukkan identifier baru: " new_id
            if [[ -z "$new_id" ]]; then
                echo -e "${RED}Identifier tidak boleh kosong.${NC}"
            else
                sed -i "s/^identifier = \".*\"/identifier = \"$new_id\"/" "$CONFIG_FILE"
                echo -e "${GREEN}Identifier telah dikemaskini ke $new_id${NC}"
            fi
            ;;
        2)
            echo -e "${CYAN}Buka config file location${NC}"
            sudo nano "$CONFIG_FILE"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Pilihan tidak sah!${NC}"
            ;;
    esac
    read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali..."
}

while true; do
    clear
    echo -e "${PURPLE}==================================${NC}"
    echo -e "${BLUE}           NOOBZVPN MENU            ${NC}"
    echo -e "${PURPLE}==================================${NC}"
    echo -e "${GREEN}1.${NC}  Add User"
    echo -e "${GREEN}2.${NC}  Edit User"
    echo -e "${GREEN}3.${NC}  Rename User"
    echo -e "${GREEN}4.${NC}  Block User"
    echo -e "${GREEN}5.${NC}  Unblock User"
    echo -e "${GREEN}6.${NC}  Renew User"
    echo -e "${GREEN}7.${NC}  Reset User"
    echo -e "${GREEN}8.${NC}  Remove User"
    echo -e "${GREEN}9.${NC}  Show User"
    echo -e "${GREEN}10.${NC} Show All Users"
    echo -e "${GREEN}11.${NC} OPTS (Advanced Dangerous Ops)"
    echo -e "${GREEN}12.${NC} Developer/Test Mode"
    echo -e "${GREEN}13.${NC} Start Service"
    echo -e "${GREEN}14.${NC} Restart Service"
    echo -e "${GREEN}15.${NC} Stop Service"
    echo -e "${GREEN}16.${NC} Enable Auto Start Service"
    echo -e "${GREEN}17.${NC} Disable Auto Start Service"
    echo -e "${GREEN}18.${NC} Check Service Status"
    echo -e "${GREEN}19.${NC} Change identifier or open config file"
    echo -e "${GREEN}0.${NC}  Exit"
    echo -e "${PURPLE}==================================${NC}"
    read -p "Sila pilih menu: " opt

    case $opt in
        1)
            read -p "Masukkan USERNAME: " username
            read -s -p "Masukkan PASSWORD: " password
            echo
            read -p "Expired days (kosong/skip untuk default): " exp
            read -p "Bandwidth GB (kosong/skip untuk default): " bw
            read -p "Device Limit (kosong/skip untuk default): " dev

            cmd="noobzvpns add $username -p $password"
            [[ ! -z "$exp" ]] && cmd="$cmd -e $exp"
            [[ ! -z "$bw" ]] && cmd="$cmd -b $bw"
            [[ ! -z "$dev" ]] && cmd="$cmd -d $dev"

            echo -e "${CYAN}Command: $cmd${NC}"
            eval $cmd

            user="$username"
            if [[ -n "$exp" ]]; then
                expiry=$(date -d "+$exp days" +"%Y-%m-%d")
                left="${exp} days"
            else
                expiry="(never)"
                left="-"
            fi

            print_user_table "$user" "$expiry" "$left"
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        2)
            read -p "USERNAME yang hendak diedit: " username
            read -s -p "Password baru (tinggal kosong untuk tak ubah): " password
            echo
            read -p "Expired days (kosong/skip untuk default): " exp
            read -p "Bandwidth GB (kosong/skip untuk default): " bw
            read -p "Device Limit (kosong/skip untuk default): " dev

            cmd="noobzvpns edit $username"
            [[ ! -z "$password" ]] && cmd="$cmd -p $password"
            [[ ! -z "$exp" ]] && cmd="$cmd -e $exp"
            [[ ! -z "$bw" ]] && cmd="$cmd -b $bw"
            [[ ! -z "$dev" ]] && cmd="$cmd -d $dev"

            echo -e "${CYAN}Command: $cmd${NC}"
            eval $cmd
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        3)
            read -p "USERNAME asal: " username
            read -p "USERNAME baru: " newusername
            cmd="noobzvpns rename $username $newusername"
            echo -e "${CYAN}Command: $cmd${NC}"
            eval $cmd
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        4)
            read -p "USERNAME (boleh multiple, ruang): " users
            cmd="noobzvpns block $users"
            echo -e "${CYAN}Command: $cmd${NC}"
            eval $cmd
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        5)
            read -p "USERNAME (boleh multiple, ruang): " users
            cmd="noobzvpns unblock $users"
            echo -e "${CYAN}Command: $cmd${NC}"
            eval $cmd
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        6)
            read -p "USERNAME (boleh multiple, ruang): " users
            read -p "Masukkan bilangan hari untuk set expired selepas renew (contoh: 30): " days
            if [[ -z "$days" ]]; then
                echo -e "${RED}Bilangan hari tidak dibenarkan kosong!${NC}"
            else
                for user in $users; do
                    echo -e "${GREEN}Renewing user: $user${NC}"
                    noobzvpns renew "$user"
                    cmd="noobzvpns edit $user -e $days"
                    echo -e "${CYAN}Command: $cmd${NC}"
                    eval $cmd
                done
            fi
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        7)
            read -p "USERNAME (boleh multiple, ruang): " users
            cmd="noobzvpns reset $users"
            echo -e "${CYAN}Command: $cmd${NC}"
            eval $cmd
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        8)
            read -p "USERNAME (boleh multiple, ruang): " users
            cmd="noobzvpns remove $users"
            echo -e "${CYAN}Command: $cmd${NC}"
            eval $cmd
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        9)
            read -p "USERNAME (boleh multiple, ruang): " users
            cmd="noobzvpns print $users"
            echo -e "${CYAN}Command: $cmd${NC}"
            eval $cmd
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        10)
            cmd="noobzvpns print-all"
            echo -e "${CYAN}Command: $cmd${NC}"
            eval $cmd
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        11)
            echo -e "${GREEN}1.${NC} Renew All User"
            echo -e "${GREEN}2.${NC} Reset All Statistic"
            echo -e "${GREEN}3.${NC} Remove All User"
            read -p "Pilih (1/2/3): " adv
            case $adv in
                1) eval "noobzvpns opts --renew-all" ;;
                2) eval "noobzvpns opts --reset-all" ;;
                3) eval "noobzvpns opts --delete-all" ;;
            esac
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        12)
            echo -e "${CYAN}Developer/Test Mode: Running in foreground with debug${NC}"
            eval "noobzvpns -d start-server"
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        13)
            echo -e "${GREEN}Starting noobzvpns.service...${NC}"
            systemctl start noobzvpns.service
            echo -e "${GREEN}Service started.${NC}"
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        14)
            echo -e "${GREEN}Restarting noobzvpns.service...${NC}"
            systemctl restart noobzvpns.service
            echo -e "${GREEN}Service restarted.${NC}"
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        15)
            echo -e "${RED}Stopping noobzvpns.service...${NC}"
            systemctl stop noobzvpns.service
            echo -e "${RED}Service stopped.${NC}"
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        16)
            echo -e "${GREEN}Enabling auto-start for noobzvpns.service...${NC}"
            systemctl enable noobzvpns.service
            echo -e "${GREEN}Auto-start enabled.${NC}"
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        17)
            echo -e "${RED}Disabling auto-start for noobzvpns.service...${NC}"
            systemctl disable noobzvpns.service
            echo -e "${RED}Auto-start disabled.${NC}"
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        18)
            echo -e "${CYAN}Checking noobzvpns.service status...${NC}"
            systemctl status noobzvpns.service -l
            read -n 1 -s -r -p "Tekan sebarang kekunci untuk kembali ke menu..."
            ;;
        19)
            edit_config
            ;;
        0)
            echo -e "${YELLOW}Terima Kasih...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Pilihan tidak sah! Sila cuba lagi.${NC}"
            sleep 1
            ;;
    esac
done
