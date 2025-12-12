#!/bin/bash

# ensure root
if [ "$(id -u)" -ne 0 ]; then
    echo "Sila jalankan skrip ini sebagai root."
    exit 1
fi

read -p " Username :  " User
if ! egrep -q "^${User}:" /etc/passwd; then
    echo "Username tidak wujud."
    exit 1
fi

read -p " Day Extend :  " Days
if ! [[ "$Days" =~ ^-?[0-9]+$ ]]; then
    echo "Error: Days mesti integer (cth: 30 atau -5)."
    exit 1
fi

# baca expiry dalam 'days since epoch' dari /etc/shadow (field ke-8)
expiry_days=$(awk -F: -v u="$User" '$1==u{print $8}' /etc/shadow)

# normalize (jika kosong atau bukan nombor -> 0)
if ! [[ "$expiry_days" =~ ^[0-9]+$ ]]; then
    expiry_days=0
fi

# hari hari ini (UTC-based)
today_days=$(( $(date -u +%s) / 86400 ))

# mula dari expiry jika masih aktif, else mula dari hari ini
if [ "$expiry_days" -gt "$today_days" ]; then
    start_days=$expiry_days
else
    start_days=$today_days
fi

# kira tarikh baru (dalam hari sejak epoch)
new_expiry_days=$(( start_days + Days ))
if [ "$new_expiry_days" -lt 0 ]; then
    new_expiry_days=0
fi

# format tarikh (gunakan UTC untuk konsisten)
new_expire_date=$(date -u -d "1970-01-01 +${new_expiry_days} days" +%Y-%m-%d)
old_expire_display="(tiada)"
if [ "$expiry_days" -gt 0 ]; then
    old_expire_display=$(date -u -d "1970-01-01 +${expiry_days} days" '+%d %b %Y')
fi
new_expire_display=$(date -u -d "1970-01-01 +${new_expiry_days} days" '+%d %b %Y')

echo "----------------------------------------"
echo "User: $User"
echo "Current expiry : $old_expire_display"
if [ "$Days" -ge 0 ]; then
    echo "Requested: +$Days hari"
else
    echo "Requested: $Days hari (tolak)"
fi
echo "Expired On: $new_expire_display"
echo "----------------------------------------"

# Unlock if locked
passwd -u "$User" 2>/dev/null

# First attempt: use chage -E (explicit)
chage -E "$new_expire_date" "$User" 2>/dev/null
rc1=$?

# verify by re-reading /etc/shadow
expiry_after=$(awk -F: -v u="$User" '$1==u{print $8}' /etc/shadow)
if ! [[ "$expiry_after" =~ ^[0-9]+$ ]]; then
    expiry_after=0
fi

after_display=$(date -u -d "1970-01-01 +${expiry_after} days" '+%d %b %Y' 2>/dev/null || echo "(tiada)")

if [ "$expiry_after" -eq "$new_expiry_days" ]; then
    echo -e "\e[32mSuccess: expiry updated to $after_display\e[0m"
    exit 0
fi

# Fallback: try usermod -e (some systems)
usermod -e "$new_expire_date" "$User" 2>/dev/null
rc2=$?

expiry_after2=$(awk -F: -v u="$User" '$1==u{print $8}' /etc/shadow)
if ! [[ "$expiry_after2" =~ ^[0-9]+$ ]]; then
    expiry_after2=0
fi
after_display2=$(date -u -d "1970-01-01 +${expiry_after2} days" '+%d %b %Y' 2>/dev/null || echo "(tiada)")

if [ "$expiry_after2" -eq "$new_expiry_days" ]; then
    echo -e "\e[32mSuccess (via usermod): expiry updated to $after_display2\e[0m"
    exit 0
fi

# If still not match, give helpful diagnostic
echo -e "\e[31mGagal mengemaskini expiry secara automatik.\e[0m"
echo "Nilai selepas percubaan (chage/usermod) yang dibaca di /etc/shadow:"

echo " - After chage read:  $after_display"
echo " - After usermod read: $after_display2"

echo ""
echo "Kemungkinan punca:"
echo " 1) Akaun dikendalikan oleh LDAP/NIS/SSSD — perubahan tempatan ke /etc/shadow mungkin tidak berkesan."
echo " 2) /etc/shadow tiada kebenaran tulis atau sistem read-only."
echo " 3) Terdapat mekanisme pengurusan akaun lain yang menulis semula nilai."
echo ""
echo "Jika anda guna LDAP/NIS/SSSD, anda mesti ubah expiry di locus yang mengurus pengguna (contoh: ldapmodify / AD / pusat)."
echo "Untuk debug lanjut, jalankan sebagai root:"
echo "  sudo chage -l $User"
echo "  sudo getent shadow $User"
echo "  sudo awk -F: '\$1==\"$User\"{print \$8}' /etc/shadow"
echo ""
exit 1

